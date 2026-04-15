import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { extractFromAudio } from "./gemini";
import {
  determineRecipients,
  sendFcmNotifications,
  createNotificationDocs,
  buildNotificationContent,
} from "./routing";
import {
  validateSubmitMemoPayload,
  validateAssignTaskPayload,
  validateUpdateTaskStatusPayload,
} from "./validators";
import { seedDemoData } from "./seed";
import {
  SubmitVoiceMemoResponse,
  AssignTaskResponse,
  UpdateTaskStatusResponse,
  GenerateDailyDigestResponse,
  TaskStatus,
} from "./types";

// Initialize Firebase Admin once
admin.initializeApp();

const db = admin.firestore();

// ─── Helper: require authenticated user ───────────────────────────────────────

function requireAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to call this function."
    );
  }
  return context.auth.uid;
}

async function getUserDoc(uid: string) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "User profile not found.");
  }
  return snap.data()!;
}

// ─── 1. submitVoiceMemo ───────────────────────────────────────────────────────
//
// Flow:
//   Client uploads audio → Firebase Storage
//   Client calls this function with storagePath + projectId + siteId
//   This function:
//     1. Creates a voice_memo doc (status: processing)
//     2. Downloads audio from Storage
//     3. Sends to Gemini (or demo fallback)
//     4. Validates response
//     5. Writes extracted_items
//     6. Routes notifications
//     7. Updates voice_memo doc (status: completed / failed)
//

export const submitVoiceMemo = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onCall(async (data, context): Promise<SubmitVoiceMemoResponse> => {
    const uid = requireAuth(context);

    let payload: {
      storagePath: string;
      projectId: string;
      siteId: string;
      mimeType: string;
    };
    try {
      payload = validateSubmitMemoPayload(data);
    } catch (e: any) {
      throw new functions.https.HttpsError("invalid-argument", e.message);
    }

    const userDoc = await getUserDoc(uid);

    // Create the voice_memo document immediately so the client can track status
    const memoRef = db.collection("voice_memos").doc();
    await memoRef.set({
      createdBy: uid,
      userRole: userDoc.role,
      companyId: userDoc.companyId || null,
      projectId: payload.projectId,
      siteId: payload.siteId,
      storagePath: payload.storagePath,
      transcriptStatus: "processing",
      processingStatus: "processing",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      // Extract items from audio (real Gemini or demo fallback)
      const extraction = await extractFromAudio(
        payload.storagePath,
        payload.mimeType
      );

      // Write all extracted items to Firestore
      const itemIds: string[] = [];
      const writeBatch = db.batch();

      for (const geminiItem of extraction.items) {
        // Determine who should receive this item
        const { recipientUserIds, recipientCompanyIds } =
          await determineRecipients(geminiItem, payload.projectId);

        const itemRef = db.collection("extracted_items").doc();
        writeBatch.set(itemRef, {
          memoId: memoRef.id,
          projectId: payload.projectId,
          siteId: payload.siteId,
          createdBy: uid,
          sourceText: geminiItem.source_text,
          normalizedSummary: geminiItem.normalized_summary,
          trade: geminiItem.trade,
          tier: geminiItem.tier,
          urgency: geminiItem.urgency,
          unitOrArea: geminiItem.unit_or_area || null,
          needsGcAttention: geminiItem.needs_gc_attention,
          needsTradeManagerAttention: geminiItem.needs_trade_manager_attention,
          downstreamTrades: geminiItem.downstream_trades,
          recommendedCompanyType: geminiItem.recommended_company_type,
          actionRequired: geminiItem.action_required,
          suggestedNextStep: geminiItem.suggested_next_step,
          recipientUserIds,
          recipientCompanyIds,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        itemIds.push(itemRef.id);

        // Send notifications (non-blocking — don't fail the whole function for FCM errors)
        if (geminiItem.tier !== "progress_update") {
          const { title, body, type } = buildNotificationContent(
            geminiItem.tier,
            geminiItem.trade,
            geminiItem.normalized_summary,
            geminiItem.urgency
          );

          // Store notification docs in Firestore
          createNotificationDocs(
            recipientUserIds,
            recipientCompanyIds,
            title,
            body,
            type,
            itemRef.id
          ).catch((err) =>
            console.error("[notifications] Failed to create docs:", err)
          );

          // Send FCM push notifications
          sendFcmNotifications(
            recipientUserIds,
            recipientCompanyIds,
            title,
            body,
            {
              type,
              extractedItemId: itemRef.id,
              projectId: payload.projectId,
            }
          ).catch((err) =>
            console.error("[FCM] Failed to send notifications:", err)
          );
        }
      }

      // Update voice_memo with success status
      writeBatch.update(memoRef, {
        transcriptStatus: "completed",
        processingStatus: "completed",
        overallSummary: extraction.overall_summary,
        detectedLanguage: extraction.language,
      });

      await writeBatch.commit();

      return {
        success: true,
        memoId: memoRef.id,
        itemCount: extraction.items.length,
      };
    } catch (err: any) {
      console.error("[submitVoiceMemo] Processing failed:", err);

      // Update voice_memo with failure status
      await memoRef.update({
        processingStatus: "failed",
        transcriptStatus: "failed",
        errorMessage: err.message || "Unknown processing error",
      });

      return {
        success: false,
        memoId: memoRef.id,
        error: err.message || "Processing failed",
      };
    }
  });

// ─── 2. assignTask ────────────────────────────────────────────────────────────
//
// Managers and GC can assign an extracted item to a specific worker.
// Creates a task_assignment doc and sends FCM to the assigned worker.
//

export const assignTask = functions.https.onCall(
  async (data, context): Promise<AssignTaskResponse> => {
    const assignerUid = requireAuth(context);
    const assigner = await getUserDoc(assignerUid);

    if (!["manager", "gc", "admin"].includes(assigner.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only managers and GC can assign tasks."
      );
    }

    let payload: {
      extractedItemId: string;
      assignedToUserId: string;
      dueDate?: string;
    };
    try {
      payload = validateAssignTaskPayload(data);
    } catch (e: any) {
      throw new functions.https.HttpsError("invalid-argument", e.message);
    }

    // Load the extracted item to get project/site context
    const itemSnap = await db
      .collection("extracted_items")
      .doc(payload.extractedItemId)
      .get();
    if (!itemSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Extracted item not found.");
    }
    const item = itemSnap.data()!;

    // Load the target worker
    const workerSnap = await db
      .collection("users")
      .doc(payload.assignedToUserId)
      .get();
    if (!workerSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Worker not found.");
    }
    const worker = workerSnap.data()!;

    // Create task assignment
    const taskRef = db.collection("task_assignments").doc();
    await taskRef.set({
      extractedItemId: payload.extractedItemId,
      assignedToUserId: payload.assignedToUserId,
      assignedByUserId: assignerUid,
      companyId: worker.companyId || null,
      projectId: item.projectId,
      siteId: item.siteId,
      status: "pending" as TaskStatus,
      dueDate: payload.dueDate
        ? admin.firestore.Timestamp.fromDate(new Date(payload.dueDate))
        : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify the assigned worker
    const notifRef = db.collection("notifications").doc();
    await notifRef.set({
      type: "task_assigned",
      userId: payload.assignedToUserId,
      extractedItemId: payload.extractedItemId,
      taskAssignmentId: taskRef.id,
      title: "New Task Assigned",
      body: item.normalizedSummary?.substring(0, 120) || "You have a new task.",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // FCM to worker
    if (worker.fcmTokens && worker.fcmTokens.length > 0) {
      sendFcmNotifications(
        [payload.assignedToUserId],
        [],
        "New Task Assigned",
        item.normalizedSummary?.substring(0, 120) || "You have a new task.",
        { type: "task_assigned", taskId: taskRef.id }
      ).catch(console.error);
    }

    return { success: true, taskId: taskRef.id };
  }
);

// ─── 3. updateTaskStatus ──────────────────────────────────────────────────────
//
// Workers update the status of their assigned task.
//

export const updateTaskStatus = functions.https.onCall(
  async (data, context): Promise<UpdateTaskStatusResponse> => {
    const uid = requireAuth(context);

    let payload: { taskId: string; status: TaskStatus };
    try {
      payload = validateUpdateTaskStatusPayload(data);
    } catch (e: any) {
      throw new functions.https.HttpsError("invalid-argument", e.message);
    }

    const taskSnap = await db
      .collection("task_assignments")
      .doc(payload.taskId)
      .get();
    if (!taskSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Task not found.");
    }
    const task = taskSnap.data()!;

    // Only the assigned worker, manager, GC, or admin can update
    const user = await getUserDoc(uid);
    const canUpdate =
      task.assignedToUserId === uid ||
      ["manager", "gc", "admin"].includes(user.role);

    if (!canUpdate) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not authorized to update this task."
      );
    }

    await db.collection("task_assignments").doc(payload.taskId).update({
      status: payload.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify the assigner if the task is completed
    if (payload.status === "done" && task.assignedByUserId) {
      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        type: "task_updated",
        userId: task.assignedByUserId,
        extractedItemId: task.extractedItemId,
        taskAssignmentId: payload.taskId,
        title: "Task Completed",
        body: "A task you assigned has been marked as done.",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { success: true };
  }
);

// ─── 4. generateDailyDigest ───────────────────────────────────────────────────
//
// Aggregates progress_update items from today into a digest document.
// Callable manually from the GC or Admin screen (no cron needed for MVP).
//

export const generateDailyDigest = functions.https.onCall(
  async (data, context): Promise<GenerateDailyDigestResponse> => {
    const uid = requireAuth(context);
    const user = await getUserDoc(uid);

    if (!["gc", "manager", "admin"].includes(user.role)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only GC, managers, and admins can generate digests."
      );
    }

    const projectId =
      typeof data === "object" && data !== null && typeof data.projectId === "string"
        ? data.projectId
        : null;
    if (!projectId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "projectId is required."
      );
    }

    const today = new Date();
    const dateKey =
      typeof data === "object" && data !== null && typeof data.dateKey === "string"
        ? data.dateKey
        : `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    // Query all items from today for this project
    const startOfDay = new Date(dateKey);
    const endOfDay = new Date(dateKey);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const itemsSnap = await db
      .collection("extracted_items")
      .where("projectId", "==", projectId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(endOfDay))
      .orderBy("createdAt", "asc")
      .get();

    if (itemsSnap.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        `No items found for project ${projectId} on ${dateKey}.`
      );
    }

    const includedItemIds: string[] = [];
    const lines: string[] = [];

    let blockerCount = 0;
    let progressCount = 0;
    let materialCount = 0;
    let scheduleCount = 0;

    itemsSnap.docs.forEach((doc) => {
      const item = doc.data();
      includedItemIds.push(doc.id);
      lines.push(`[${item.tier}] [${item.urgency}] ${item.normalizedSummary}`);
      switch (item.tier) {
        case "issue_or_blocker": blockerCount++; break;
        case "progress_update": progressCount++; break;
        case "material_request": materialCount++; break;
        case "schedule_change": scheduleCount++; break;
      }
    });

    const summary =
      `Daily Digest — ${dateKey}\n` +
      `Blockers: ${blockerCount} | Progress updates: ${progressCount} | ` +
      `Material requests: ${materialCount} | Schedule changes: ${scheduleCount}\n\n` +
      lines.join("\n");

    // Upsert the digest document
    const digestRef = db.collection("daily_digests").doc(
      `${projectId}_${dateKey}`
    );
    await digestRef.set({
      projectId,
      dateKey,
      summary,
      includedItemIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      digestId: digestRef.id,
      summary,
      itemCount: includedItemIds.length,
    };
  }
);

// ─── 5. seedDemoData ──────────────────────────────────────────────────────────
//
// Creates demo users, companies, projects, and sites.
// Only callable by admin role.
//

export const seedDemoDataFn = functions
  .runWith({ timeoutSeconds: 120 })
  .https.onCall(async (_, context) => {
    const uid = requireAuth(context);
    const user = await getUserDoc(uid).catch(() => null);

    // Allow seeding if: (a) user is admin, OR (b) user doc doesn't exist yet
    // This allows first-time seeding before any users exist.
    if (user && user.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can seed demo data."
      );
    }

    return seedDemoData();
  });

// ─── 6. seedDemoDataHttp ──────────────────────────────────────────────────────
//
// HTTP endpoint version of seedDemoData.
// Use this for FIRST-TIME seeding when no admin user exists yet.
// IMPORTANT: Disable or delete this function after seeding in production.
//
// Usage:
//   curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/seedDemoDataHttp \
//        -H "Content-Type: application/json" \
//        -d '{"secret":"BuildVoxSeed2024"}'
//

export const seedDemoDataHttp = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const secret = req.body?.secret;
  if (secret !== "BuildVoxSeed2024") {
    res.status(403).json({ error: "Invalid secret" });
    return;
  }

  try {
    const result = await seedDemoData();
    res.status(200).json(result);
  } catch (err: any) {
    console.error("[seedDemoDataHttp] Error:", err);
    res.status(500).json({ error: err.message });
  }
});
