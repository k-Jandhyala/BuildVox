import * as dotenv from "dotenv";
dotenv.config();

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import { extractFromAudio, extractFromText } from "./gemini";
import {
  persistGeminiExtractedItems,
  ensureSelfTaskForExtractedItem,
} from "./persistItems";
import {
  determineRecipients,
  loadProject,
  sendFcmNotifications,
  createNotificationDocs,
  buildNotificationContent,
} from "./routing";
import {
  validateSubmitMemoPayload,
  validateAssignTaskPayload,
  validateUpdateTaskStatusPayload,
  validatePollVoiceMemoPayload,
  validateSubmitReviewedItemsPayload,
  validateEscalateTaskPayload,
} from "./validators";
import { seedDemoData } from "./seed";
import { getSupabase } from "./supabaseAdmin";
import { getUserDoc } from "./db";
import {
  getSupabaseUserIdFromBearer,
  readJsonBody,
  setCors,
} from "./authHttp";
import {
  SubmitVoiceMemoResponse,
  AssignTaskResponse,
  UpdateTaskStatusResponse,
  GenerateDailyDigestResponse,
  TaskStatus,
} from "./types";
import {
  buildGeminiLikeItem,
  isUuidV4,
} from "./reviewPayload";

admin.initializeApp();

function jsonErr(res: functions.Response, status: number, message: string) {
  setCors(res);
  res.status(status).json({ error: message });
}

function jsonOk(res: functions.Response, data: unknown) {
  setCors(res);
  res.status(200).json(data);
}

/** Inserts extracted_items from client JSON (AI review screen or manual fallback). */
async function persistClientPayloadItems(params: {
  supabase: ReturnType<typeof getSupabase>;
  items: Record<string, unknown>[];
  memoId: string;
  projectId: string;
  siteId: string;
  uid: string;
  userTrade: string;
}): Promise<number> {
  const { supabase, items, memoId, projectId, siteId, uid, userTrade } =
    params;
  let insertedCount = 0;
  for (const raw of items) {
    const normalizedSummary = String(raw.summary || "").trim();
    if (!normalizedSummary) continue;

    const geminiLike = buildGeminiLikeItem(raw, userTrade || "other");
    const { recipientUserIds, recipientCompanyIds } = await determineRecipients(
      geminiLike,
      projectId
    );

    const itemId = randomUUID();
    const { error: itemErr } = await supabase.from("extracted_items").insert({
      id: itemId,
      memo_id: memoId,
      project_id: projectId,
      site_id: siteId,
      created_by: uid,
      source_text: geminiLike.source_text,
      normalized_summary: geminiLike.normalized_summary,
      trade: geminiLike.trade,
      tier: geminiLike.tier,
      urgency: geminiLike.urgency,
      unit_or_area: geminiLike.unit_or_area || null,
      needs_gc_attention: geminiLike.needs_gc_attention,
      needs_trade_manager_attention: geminiLike.needs_trade_manager_attention,
      downstream_trades: geminiLike.downstream_trades,
      recommended_company_type: geminiLike.recommended_company_type,
      action_required: geminiLike.action_required,
      suggested_next_step: geminiLike.suggested_next_step,
      recipient_user_ids: recipientUserIds,
      recipient_company_ids: recipientCompanyIds,
      status: "pending",
    });
    if (itemErr) {
      console.error("[persistClientPayloadItems] insert failed", itemErr);
      continue;
    }

    insertedCount++;

    await ensureSelfTaskForExtractedItem({
      supabase,
      extractedItemId: itemId,
      workerUserId: uid,
      projectId,
      siteId,
      tier: geminiLike.tier,
    });

    if (geminiLike.tier !== "progress_update") {
      const { title, body, type } = buildNotificationContent(
        geminiLike.tier,
        geminiLike.trade,
        geminiLike.normalized_summary,
        geminiLike.urgency
      );
      createNotificationDocs(
        recipientUserIds,
        recipientCompanyIds,
        title,
        body,
        type,
        itemId
      ).catch((err) =>
        console.error("[persistClientPayloadItems] notification docs failed:", err)
      );
      sendFcmNotifications(recipientUserIds, recipientCompanyIds, title, body, {
        type,
        extractedItemId: itemId,
        projectId,
      }).catch((err) =>
        console.error("[persistClientPayloadItems] FCM failed:", err)
      );
    }
  }
  return insertedCount;
}

export const submitVoiceMemo = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    let payload: {
      audioUrl: string;
      storagePath?: string;
      projectId: string;
      siteId: string;
      mimeType: string;
    };
    try {
      payload = validateSubmitMemoPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    let userDoc;
    try {
      userDoc = await getUserDoc(uid);
    } catch {
      jsonErr(res, 404, "User profile not found");
      return;
    }

    const supabase = getSupabase();

    const { data: memoRow, error: memoErr } = await supabase
      .from("voice_memos")
      .insert({
        created_by: uid,
        user_role: userDoc.role,
        company_id: userDoc.companyId ?? null,
        project_id: payload.projectId,
        site_id: payload.siteId,
        storage_path: payload.storagePath ?? null,
        audio_url: payload.audioUrl,
        transcript_status: "processing",
        processing_status: "processing",
      })
      .select()
      .single();

    if (memoErr || !memoRow) {
      jsonErr(res, 500, memoErr?.message || "Failed to create voice memo");
      return;
    }

    const memoId = memoRow.id as string;

    try {
      const extraction = await extractFromAudio(
        payload.audioUrl,
        payload.mimeType
      );

      await persistGeminiExtractedItems({
        supabase,
        items: extraction.items,
        memoId,
        projectId: payload.projectId,
        siteId: payload.siteId,
        createdBy: uid,
      });

      await supabase
        .from("voice_memos")
        .update({
          transcript_status: "completed",
          processing_status: "completed",
          overall_summary: extraction.overall_summary,
          detected_language: extraction.language,
        })
        .eq("id", memoId);

      const out: SubmitVoiceMemoResponse = {
        success: true,
        memoId,
        itemCount: extraction.items.length,
        overallSummary: extraction.overall_summary,
      };
      jsonOk(res, out);
    } catch (err: any) {
      console.error("[submitVoiceMemo] Processing failed:", err);

      await supabase
        .from("voice_memos")
        .update({
          processing_status: "failed",
          transcript_status: "failed",
          error_message: err.message || "Unknown processing error",
        })
        .eq("id", memoId);

      const out: SubmitVoiceMemoResponse = {
        success: false,
        memoId,
        error: err.message || "Processing failed",
      };
      jsonOk(res, out);
    }
  });

export const startVoiceMemoProcessing = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    let payload: {
      audioUrl: string;
      storagePath?: string;
      projectId: string;
      siteId: string;
      mimeType: string;
    };
    try {
      payload = validateSubmitMemoPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    let userDoc;
    try {
      userDoc = await getUserDoc(uid);
    } catch {
      jsonErr(res, 404, "User profile not found");
      return;
    }

    const supabase = getSupabase();
    const { data: memoRow, error: memoErr } = await supabase
      .from("voice_memos")
      .insert({
        created_by: uid,
        user_role: userDoc.role,
        company_id: userDoc.companyId ?? null,
        project_id: payload.projectId,
        site_id: payload.siteId,
        storage_path: payload.storagePath ?? null,
        audio_url: payload.audioUrl,
        transcript_status: "processing",
        processing_status: "processing",
      })
      .select()
      .single();

    if (memoErr || !memoRow) {
      jsonErr(res, 500, memoErr?.message || "Failed to create voice memo");
      return;
    }

    const memoId = memoRow.id as string;
    const requestId = randomUUID();
    const { error: reqInsertErr } = await supabase.from("ai_review_requests").insert({
      id: requestId,
      memo_id: memoId,
      created_by: uid,
      project_id: payload.projectId,
      site_id: payload.siteId,
      status: "processing",
      items_json: [],
    });
    if (reqInsertErr) {
      jsonErr(res, 500, reqInsertErr.message || "Failed to start AI review request");
      return;
    }

    try {
      const extraction = await extractFromAudio(payload.audioUrl, payload.mimeType);
      const items = extraction.items.map((it, idx) => ({
        id: randomUUID(),
        transcriptSegment: it.source_text || "",
        summary: it.normalized_summary || "",
        category:
          it.tier === "issue_or_blocker"
            ? "blocker"
            : it.tier === "material_request"
              ? "materialRequest"
              : it.tier === "schedule_change"
                ? "scheduleIssue"
                : "taskUpdate",
        priority: it.urgency || "medium",
        location: it.unit_or_area || "",
        relatedTrade: it.trade || "other",
        dueDate: null,
        notes: it.suggested_next_step || "",
        isBlocker: it.tier === "issue_or_blocker",
        isMaterialRequest: it.tier === "material_request",
        attachedPhotos: [],
        routePreview: null,
        order: idx,
      }));

      await supabase
        .from("ai_review_requests")
        .update({
          status: "completed",
          items_json: items,
          updated_at: new Date().toISOString(),
        })
        .eq("id", requestId);

      await supabase
        .from("voice_memos")
        .update({
          transcript_status: "completed",
          processing_status: "completed",
          overall_summary: extraction.overall_summary,
          detected_language: extraction.language,
        })
        .eq("id", memoId);
    } catch (err: any) {
      await supabase
        .from("ai_review_requests")
        .update({
          status: "failed",
          error_message: err.message || "AI processing failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", requestId);

      await supabase
        .from("voice_memos")
        .update({
          processing_status: "failed",
          transcript_status: "failed",
          error_message: err.message || "AI processing failed",
        })
        .eq("id", memoId);
    }

    jsonOk(res, {
      success: true,
      requestId,
      status: "processing",
    });
  });

export const pollVoiceMemoProcessing = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    jsonErr(res, 405, "Method not allowed");
    return;
  }
  let uid: string;
  try {
    uid = await getSupabaseUserIdFromBearer(req);
  } catch (e: any) {
    jsonErr(res, 401, e.message || "Unauthorized");
    return;
  }
  let payload: { requestId: string };
  try {
    payload = validatePollVoiceMemoPayload(readJsonBody(req));
  } catch (e: any) {
    jsonErr(res, 400, e.message);
    return;
  }
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("ai_review_requests")
    .select("*")
    .eq("id", payload.requestId)
    .eq("created_by", uid)
    .maybeSingle();

  if (error || !data) {
    jsonErr(res, 404, "AI review request not found");
    return;
  }
  const row = data as Record<string, unknown>;
  jsonOk(res, {
    success: true,
    requestId: row.id,
    status: row.status,
    items: (row.items_json as unknown[]) || [],
    error: row.error_message || null,
  });
});

export const submitReviewedItems = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }
    let payload: {
      requestId: string;
      projectId: string;
      siteId: string;
      items: Record<string, unknown>[];
    };
    try {
      payload = validateSubmitReviewedItemsPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    let userDoc;
    try {
      userDoc = await getUserDoc(uid);
    } catch {
      jsonErr(res, 404, "User profile not found");
      return;
    }

    const supabase = getSupabase();
    const userTrade = userDoc.trade || "other";
    const fromAiReview = isUuidV4(payload.requestId);

    console.log(
      `[submitReviewedItems] requestId=${payload.requestId} | aiReview=${fromAiReview} | items=${payload.items.length} | user=${uid}`
    );

    let memoId: string;
    let shouldMarkAiReviewSubmitted = false;

    if (fromAiReview) {
      const { data: reqRow, error: reqErr } = await supabase
        .from("ai_review_requests")
        .select("*")
        .eq("id", payload.requestId)
        .eq("created_by", uid)
        .maybeSingle();

      if (reqErr || !reqRow) {
        jsonErr(res, 404, "AI review request not found");
        return;
      }
      memoId = String((reqRow as Record<string, unknown>).memo_id);
      shouldMarkAiReviewSubmitted = true;
    } else {
      const typedFieldNote = payload.requestId.startsWith("field_note");

      const { data: memoRow, error: memoErr } = await supabase
        .from("voice_memos")
        .insert({
          created_by: uid,
          user_role: userDoc.role,
          company_id: userDoc.companyId ?? null,
          project_id: payload.projectId,
          site_id: payload.siteId,
          storage_path: null,
          audio_url: null,
          transcript_status: typedFieldNote ? "processing" : "completed",
          processing_status: typedFieldNote ? "processing" : "completed",
          overall_summary: typedFieldNote
            ? null
            : `Submission: ${payload.items.length} item(s)`,
          detected_language: "en",
        })
        .select()
        .single();

      if (memoErr || !memoRow) {
        jsonErr(res, 500, memoErr?.message || "Failed to create memo record");
        return;
      }
      memoId = memoRow.id as string;

      if (typedFieldNote) {
        const rawText = payload.items
          .map((i) => String(i.transcriptSegment || "").trim())
          .filter(Boolean)
          .join("\n\n");
        if (!rawText) {
          jsonErr(res, 400, "typed text (transcriptSegment) is required");
          return;
        }

        try {
          const extraction = await extractFromText(rawText);
          await supabase
            .from("voice_memos")
            .update({
              transcript_status: "completed",
              processing_status: "completed",
              overall_summary: extraction.overall_summary,
              raw_transcript: rawText,
              detected_language: extraction.language,
            })
            .eq("id", memoId);

          const insertedCount = await persistGeminiExtractedItems({
            supabase,
            items: extraction.items,
            memoId,
            projectId: payload.projectId,
            siteId: payload.siteId,
            createdBy: uid,
          });

          jsonOk(res, {
            success: true,
            itemCount: insertedCount,
            overallSummary: extraction.overall_summary,
          });
          return;
        } catch (err: any) {
          console.error(
            "[submitReviewedItems] Gemini text failed; falling back to client items",
            err
          );
          await supabase
            .from("voice_memos")
            .update({
              transcript_status: "completed",
              processing_status: "completed",
              overall_summary: `Typed submission (AI fallback): ${payload.items.length} item(s)`,
              raw_transcript: rawText,
              error_message: String(err?.message || "Gemini error").substring(
                0,
                500
              ),
            })
            .eq("id", memoId);
        }
      }
    }

    const insertedCount = await persistClientPayloadItems({
      supabase,
      items: payload.items,
      memoId,
      projectId: payload.projectId,
      siteId: payload.siteId,
      uid,
      userTrade,
    });

    if (shouldMarkAiReviewSubmitted) {
      await supabase
        .from("ai_review_requests")
        .update({
          status: "submitted",
          updated_at: new Date().toISOString(),
        })
        .eq("id", payload.requestId);
    }

    jsonOk(res, { success: true, itemCount: insertedCount });
  });

export const assignTask = functions.https.onRequest(
  async (req, res): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let assignerUid: string;
    try {
      assignerUid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    const assigner = await getUserDoc(assignerUid);

    if (!["manager", "gc", "admin"].includes(assigner.role)) {
      jsonErr(res, 403, "Only managers and GC can assign tasks.");
      return;
    }

    let payload: {
      extractedItemId: string;
      assignedToUserId: string;
      dueDate?: string;
    };
    try {
      payload = validateAssignTaskPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    const supabase = getSupabase();

    const { data: itemRow, error: itemErr } = await supabase
      .from("extracted_items")
      .select("*")
      .eq("id", payload.extractedItemId)
      .maybeSingle();

    if (itemErr || !itemRow) {
      jsonErr(res, 404, "Extracted item not found.");
      return;
    }

    const item = itemRow as Record<string, unknown>;

    const { data: workerRow, error: wErr } = await supabase
      .from("app_users")
      .select("*")
      .eq("id", payload.assignedToUserId)
      .maybeSingle();

    if (wErr || !workerRow) {
      jsonErr(res, 404, "Worker not found.");
      return;
    }

    const worker = workerRow as Record<string, unknown>;

    const { data: existingRows, error: exErr } = await supabase
      .from("task_assignments")
      .select("id")
      .eq("extracted_item_id", payload.extractedItemId)
      .limit(1);

    if (exErr) {
      jsonErr(res, 500, exErr.message);
      return;
    }

    const existingId =
      existingRows && existingRows.length > 0
        ? (existingRows[0] as { id: string }).id
        : null;

    let taskId: string;

    if (existingId) {
      taskId = existingId;
      const { error: upErr } = await supabase
        .from("task_assignments")
        .update({
          assigned_to_user_id: payload.assignedToUserId,
          assigned_by_user_id: assignerUid,
          company_id: worker.company_id,
          due_date: payload.dueDate
            ? new Date(payload.dueDate).toISOString()
            : null,
          status: "pending" as TaskStatus,
          updated_at: new Date().toISOString(),
        })
        .eq("id", taskId);

      if (upErr) {
        jsonErr(res, 500, upErr.message);
        return;
      }
    } else {
      taskId = randomUUID();
      const { error: tErr } = await supabase.from("task_assignments").insert({
        id: taskId,
        extracted_item_id: payload.extractedItemId,
        assigned_to_user_id: payload.assignedToUserId,
        assigned_by_user_id: assignerUid,
        company_id: worker.company_id,
        project_id: item.project_id,
        site_id: item.site_id,
        status: "pending" as TaskStatus,
        due_date: payload.dueDate
          ? new Date(payload.dueDate).toISOString()
          : null,
      });

      if (tErr) {
        jsonErr(res, 500, tErr.message);
        return;
      }
    }

    await supabase
      .from("extracted_items")
      .update({ status: "acknowledged" })
      .eq("id", payload.extractedItemId);

    await supabase.from("notifications").insert({
      type: "task_assigned",
      user_id: payload.assignedToUserId,
      extracted_item_id: payload.extractedItemId,
      task_assignment_id: taskId,
      title: "New Task Assigned",
      body:
        String(item.normalized_summary || "").substring(0, 120) ||
        "You have a new task.",
      read: false,
    });

    const tokens = (worker.fcm_tokens as string[]) || [];
    if (tokens.length > 0) {
      sendFcmNotifications(
        [payload.assignedToUserId],
        [],
        "New Task Assigned",
        String(item.normalized_summary || "").substring(0, 120) ||
          "You have a new task.",
        { type: "task_assigned", taskId }
      ).catch(console.error);
    }

    const out: AssignTaskResponse = { success: true, taskId };
    jsonOk(res, out);
  }
);

/** Worker escalates an assigned task; GC + trade managers are notified (matches Flutter escalateTask). */
export const escalateTask = functions.https.onRequest(
  async (req, res): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    let payload: { taskId: string; reason: string; details: string };
    try {
      payload = validateEscalateTaskPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    const user = await getUserDoc(uid);
    const supabase = getSupabase();

    const { data: taskRow, error: taskErr } = await supabase
      .from("task_assignments")
      .select("*")
      .eq("id", payload.taskId)
      .maybeSingle();

    if (taskErr || !taskRow) {
      jsonErr(res, 404, "Task not found.");
      return;
    }

    const task = taskRow as Record<string, unknown>;
    const assignedTo = task.assigned_to_user_id as string;
    const canEscalate = assignedTo === uid || user.role === "admin";
    if (!canEscalate) {
      jsonErr(res, 403, "Only the assignee can escalate this task.");
      return;
    }

    const projectId = task.project_id as string;
    const siteId = task.site_id as string;
    const extractedItemId = task.extracted_item_id as string;

    const escalationId = randomUUID();
    const { error: insErr } = await supabase.from("task_escalations").insert({
      id: escalationId,
      task_id: payload.taskId,
      escalated_by: uid,
      reason: payload.reason,
      details: payload.details,
      project_id: projectId,
      site_id: siteId,
    });

    if (insErr) {
      jsonErr(res, 500, insErr.message);
      return;
    }

    const project = await loadProject(projectId);
    const gcUserIds = project?.gcUserIds ?? [];

    const workerCompanyId = (task.company_id as string) || "";
    const recipientCompanyIds: string[] = [];
    if (workerCompanyId) {
      recipientCompanyIds.push(workerCompanyId);
    }

    const title = "Task escalated";
    const body =
      `${payload.reason}: ${payload.details}`.substring(0, 200) ||
      "A worker escalated a task.";

    await createNotificationDocs(
      gcUserIds,
      recipientCompanyIds,
      title,
      body,
      "task_escalated",
      extractedItemId
    );

    sendFcmNotifications(
      gcUserIds,
      recipientCompanyIds,
      title,
      body,
      {
        type: "task_escalated",
        taskId: payload.taskId,
        escalationId,
        projectId,
      }
    ).catch(console.error);

    jsonOk(res, { success: true, escalationId });
  }
);

export const updateTaskStatus = functions.https.onRequest(
  async (req, res): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    let payload: { taskId: string; status: TaskStatus };
    try {
      payload = validateUpdateTaskStatusPayload(readJsonBody(req));
    } catch (e: any) {
      jsonErr(res, 400, e.message);
      return;
    }

    const supabase = getSupabase();

    const { data: taskRow, error: taskErr } = await supabase
      .from("task_assignments")
      .select("*")
      .eq("id", payload.taskId)
      .maybeSingle();

    if (taskErr || !taskRow) {
      jsonErr(res, 404, "Task not found.");
      return;
    }

    const task = taskRow as Record<string, unknown>;
    const user = await getUserDoc(uid);

    const canUpdate =
      task.assigned_to_user_id === uid ||
      ["manager", "gc", "admin"].includes(user.role);

    if (!canUpdate) {
      jsonErr(res, 403, "You are not authorized to update this task.");
      return;
    }

    await supabase
      .from("task_assignments")
      .update({
        status: payload.status,
        updated_at: new Date().toISOString(),
      })
      .eq("id", payload.taskId);

    const extractedItemId = task.extracted_item_id as string;
    if (extractedItemId) {
      await supabase
        .from("extracted_items")
        .update({ status: payload.status })
        .eq("id", extractedItemId);
    }

    if (payload.status === "done" && task.assigned_by_user_id) {
      await supabase.from("notifications").insert({
        type: "task_updated",
        user_id: task.assigned_by_user_id as string,
        extracted_item_id: extractedItemId,
        task_assignment_id: payload.taskId,
        title: "Task Completed",
        body: "A task you assigned has been marked as done.",
        read: false,
      });
    }

    const out: UpdateTaskStatusResponse = { success: true };
    jsonOk(res, out);
  }
);

export const generateDailyDigest = functions.https.onRequest(
  async (req, res): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    const user = await getUserDoc(uid);

    if (!["gc", "manager", "admin"].includes(user.role)) {
      jsonErr(res, 403, "Only GC, managers, and admins can generate digests.");
      return;
    }

    const data = readJsonBody(req) as Record<string, unknown>;

    const projectId =
      typeof data?.projectId === "string" ? data.projectId : null;
    if (!projectId) {
      jsonErr(res, 400, "projectId is required.");
      return;
    }

    const today = new Date();
    const dateKey =
      typeof data === "object" && data !== null && typeof data.dateKey === "string"
        ? data.dateKey
        : `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    const startOfDay = new Date(`${dateKey}T00:00:00.000Z`);
    const endExclusive = new Date(startOfDay);
    endExclusive.setUTCDate(endExclusive.getUTCDate() + 1);

    const supabase = getSupabase();

    const { data: rows, error: qErr } = await supabase
      .from("extracted_items")
      .select("*")
      .eq("project_id", projectId)
      .gte("created_at", startOfDay.toISOString())
      .lt("created_at", endExclusive.toISOString())
      .order("created_at", { ascending: true });

    if (qErr) {
      jsonErr(res, 500, qErr.message);
      return;
    }

    if (!rows || rows.length === 0) {
      jsonErr(
        res,
        404,
        `No items found for project ${projectId} on ${dateKey}.`
      );
      return;
    }

    const includedItemIds: string[] = [];
    const lines: string[] = [];

    let blockerCount = 0;
    let progressCount = 0;
    let materialCount = 0;
    let scheduleCount = 0;

    rows.forEach((doc) => {
      const item = doc as Record<string, unknown>;
      const id = item.id as string;
      includedItemIds.push(id);
      lines.push(
        `[${item.tier}] [${item.urgency}] ${item.normalized_summary}`
      );
      switch (item.tier) {
        case "issue_or_blocker":
          blockerCount++;
          break;
        case "progress_update":
          progressCount++;
          break;
        case "material_request":
          materialCount++;
          break;
        case "schedule_change":
          scheduleCount++;
          break;
      }
    });

    const summary =
      `Daily Digest — ${dateKey}\n` +
      `Blockers: ${blockerCount} | Progress updates: ${progressCount} | ` +
      `Material requests: ${materialCount} | Schedule changes: ${scheduleCount}\n\n` +
      lines.join("\n");

    const digestId = `${projectId}_${dateKey}`;

    await supabase.from("daily_digests").upsert({
      id: digestId,
      project_id: projectId,
      date_key: dateKey,
      summary,
      included_item_ids: includedItemIds,
    });

    const out: GenerateDailyDigestResponse = {
      success: true,
      digestId,
      summary,
      itemCount: includedItemIds.length,
    };
    jsonOk(res, out);
  }
);

export const seedDemoDataFn = functions
  .runWith({ timeoutSeconds: 120 })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonErr(res, 405, "Method not allowed");
      return;
    }
    let uid: string;
    try {
      uid = await getSupabaseUserIdFromBearer(req);
    } catch (e: any) {
      jsonErr(res, 401, e.message || "Unauthorized");
      return;
    }

    let user: Awaited<ReturnType<typeof getUserDoc>> | null = null;
    try {
      user = await getUserDoc(uid);
    } catch {
      user = null;
    }

    if (user && user.role !== "admin") {
      jsonErr(res, 403, "Only admins can seed demo data.");
      return;
    }

    try {
      const result = await seedDemoData();
      jsonOk(res, result);
    } catch (err: any) {
      console.error("[seedDemoDataFn]", err);
      jsonErr(res, 500, err.message || "Seed failed");
    }
  });

export const seedDemoDataHttp = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
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
