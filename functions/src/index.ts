import * as dotenv from "dotenv";
dotenv.config();

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
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
  validatePollVoiceMemoPayload,
  validateSubmitReviewedItemsPayload,
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
  GeminiExtractedItem,
  TaskStatus,
} from "./types";

admin.initializeApp();

function jsonErr(res: functions.Response, status: number, message: string) {
  setCors(res);
  res.status(status).json({ error: message });
}

function jsonOk(res: functions.Response, data: unknown) {
  setCors(res);
  res.status(200).json(data);
}

function mapCategoryToTier(category: string): string {
  switch ((category || "").toLowerCase()) {
    case "blocker":
      return "issue_or_blocker";
    case "materialrequest":
    case "material_request":
    case "material request":
      return "material_request";
    case "scheduleissue":
    case "schedule_issue":
    case "schedule issue":
      return "schedule_change";
    default:
      return "progress_update";
  }
}

function mapPriorityToUrgency(priority: string): string {
  switch ((priority || "").toLowerCase()) {
    case "critical":
      return "critical";
    case "high":
      return "high";
    case "low":
      return "low";
    default:
      return "medium";
  }
}

function buildGeminiLikeItem(
  raw: Record<string, unknown>,
  fallbackTrade: string
): GeminiExtractedItem {
  const category = String(raw.category || "taskUpdate");
  const isBlocker = Boolean(raw.isBlocker);
  const isMaterialRequest = Boolean(raw.isMaterialRequest);
  const tier = isBlocker
    ? "issue_or_blocker"
    : isMaterialRequest
      ? "material_request"
      : mapCategoryToTier(category);
  const trade = String(raw.relatedTrade || fallbackTrade || "other");
  const urgency = mapPriorityToUrgency(String(raw.priority || "medium"));
  const summary = String(raw.summary || "").trim();

  return {
    source_text: String(raw.transcriptSegment || ""),
    normalized_summary: summary,
    trade: trade as any,
    tier: tier as any,
    urgency: urgency as any,
    project_ref: null,
    job_site_ref: null,
    unit_or_area: String(raw.location || "") || null,
    needs_gc_attention: isBlocker || tier === "schedule_change",
    needs_trade_manager_attention: isMaterialRequest || tier === "material_request",
    downstream_trades: [],
    recommended_company_type: trade as any,
    action_required: true,
    suggested_next_step: String(raw.notes || "Review and route."),
  };
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

      for (const geminiItem of extraction.items) {
        const { recipientUserIds, recipientCompanyIds } =
          await determineRecipients(geminiItem, payload.projectId);

        const itemId = randomUUID();
        const { error: itemErr } = await supabase.from("extracted_items").insert({
          id: itemId,
          memo_id: memoId,
          project_id: payload.projectId,
          site_id: payload.siteId,
          created_by: uid,
          source_text: geminiItem.source_text,
          normalized_summary: geminiItem.normalized_summary,
          trade: geminiItem.trade,
          tier: geminiItem.tier,
          urgency: geminiItem.urgency,
          unit_or_area: geminiItem.unit_or_area || null,
          needs_gc_attention: geminiItem.needs_gc_attention,
          needs_trade_manager_attention:
            geminiItem.needs_trade_manager_attention,
          downstream_trades: geminiItem.downstream_trades,
          recommended_company_type: geminiItem.recommended_company_type,
          action_required: geminiItem.action_required,
          suggested_next_step: geminiItem.suggested_next_step,
          recipient_user_ids: recipientUserIds,
          recipient_company_ids: recipientCompanyIds,
          status: "pending",
        });

        if (itemErr) {
          console.error("[submitVoiceMemo] item insert failed:", itemErr);
          continue;
        }

        if (geminiItem.tier !== "progress_update") {
          const { title, body, type } = buildNotificationContent(
            geminiItem.tier,
            geminiItem.trade,
            geminiItem.normalized_summary,
            geminiItem.urgency
          );

          createNotificationDocs(
            recipientUserIds,
            recipientCompanyIds,
            title,
            body,
            type,
            itemId
          ).catch((err) =>
            console.error("[notifications] Failed to create docs:", err)
          );

          sendFcmNotifications(
            recipientUserIds,
            recipientCompanyIds,
            title,
            body,
            {
              type,
              extractedItemId: itemId,
              projectId: payload.projectId,
            }
          ).catch((err) =>
            console.error("[FCM] Failed to send notifications:", err)
          );
        }
      }

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
  .runWith({ timeoutSeconds: 180, memory: "512MB" })
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
    const request = reqRow as Record<string, unknown>;
    const memoId = String(request.memo_id);

    let insertedCount = 0;
    for (const raw of payload.items) {
      const normalizedSummary = String(raw.summary || "").trim();
      if (!normalizedSummary) continue;

      const geminiLike = buildGeminiLikeItem(raw, userDoc.trade || "other");
      const { recipientUserIds, recipientCompanyIds } = await determineRecipients(
        geminiLike,
        payload.projectId
      );

      const itemId = randomUUID();
      const { error: itemErr } = await supabase.from("extracted_items").insert({
        id: itemId,
        memo_id: memoId,
        project_id: payload.projectId,
        site_id: payload.siteId,
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
        console.error("[submitReviewedItems] item insert failed", itemErr);
        continue;
      }

      insertedCount++;
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
          console.error("[submitReviewedItems] notification docs failed:", err)
        );
        sendFcmNotifications(recipientUserIds, recipientCompanyIds, title, body, {
          type,
          extractedItemId: itemId,
          projectId: payload.projectId,
        }).catch((err) =>
          console.error("[submitReviewedItems] FCM failed:", err)
        );
      }
    }

    await supabase
      .from("ai_review_requests")
      .update({
        status: "submitted",
        updated_at: new Date().toISOString(),
      })
      .eq("id", payload.requestId);

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

    const taskId = randomUUID();
    const { error: tErr } = await supabase.from("task_assignments").insert({
      id: taskId,
      extracted_item_id: payload.extractedItemId,
      assigned_to_user_id: payload.assignedToUserId,
      assigned_by_user_id: assignerUid,
      company_id: worker.company_id,
      project_id: item.project_id,
      site_id: item.site_id,
      status: "pending" as TaskStatus,
      due_date: payload.dueDate ? new Date(payload.dueDate).toISOString() : null,
    });

    if (tErr) {
      jsonErr(res, 500, tErr.message);
      return;
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
