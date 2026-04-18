import { randomUUID } from "crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  determineRecipients,
  sendFcmNotifications,
  createNotificationDocs,
  buildNotificationContent,
} from "./routing";
import type { GeminiExtractedItem, TaskStatus } from "./types";

/** Tiers that should appear on the worker Tasks tab (task_assignments). */
const SELF_TASK_TIERS = new Set<string>([
  "issue_or_blocker",
  "material_request",
  "schedule_change",
]);

/**
 * Creates a self-assigned task row so the submitting worker sees blockers / materials /
 * schedule items on the Tasks tab and can mark them done (updateTaskStatus).
 * GC-assigned tasks use the same extracted_item_id; assignTask updates this row if present.
 */
export async function ensureSelfTaskForExtractedItem(params: {
  supabase: SupabaseClient;
  extractedItemId: string;
  workerUserId: string;
  projectId: string;
  siteId: string;
  tier: string;
}): Promise<void> {
  const { supabase, extractedItemId, workerUserId, projectId, siteId, tier } =
    params;
  if (!SELF_TASK_TIERS.has(tier)) return;

  const { data: profile, error: pErr } = await supabase
    .from("app_users")
    .select("role, company_id")
    .eq("id", workerUserId)
    .maybeSingle();

  if (pErr || !profile) {
    console.warn("[ensureSelfTaskForExtractedItem] app_users lookup failed:", pErr);
    return;
  }
  if ((profile as { role?: string }).role !== "worker") return;

  const companyId = (profile as { company_id?: string | null }).company_id ?? null;

  const taskId = randomUUID();
  const { error } = await supabase.from("task_assignments").insert({
    id: taskId,
    extracted_item_id: extractedItemId,
    assigned_to_user_id: workerUserId,
    assigned_by_user_id: workerUserId,
    company_id: companyId,
    project_id: projectId,
    site_id: siteId,
    status: "pending" as TaskStatus,
  });

  if (error) {
    console.error("[ensureSelfTaskForExtractedItem] task_assignments insert failed:", error);
  }
}

/**
 * Inserts extracted_items rows from Gemini-structured items and sends notifications.
 * Shared by submitVoiceMemo, startVoiceMemoProcessing, and submitReviewedItems (typed flow).
 */
export async function persistGeminiExtractedItems(params: {
  supabase: SupabaseClient;
  items: GeminiExtractedItem[];
  memoId: string;
  projectId: string;
  siteId: string;
  createdBy: string;
}): Promise<number> {
  const { supabase, items, memoId, projectId, siteId, createdBy } = params;
  let inserted = 0;

  for (const geminiItem of items) {
    const { recipientUserIds, recipientCompanyIds } = await determineRecipients(
      geminiItem,
      projectId
    );

    const itemId = randomUUID();
    const { error: itemErr } = await supabase.from("extracted_items").insert({
      id: itemId,
      memo_id: memoId,
      project_id: projectId,
      site_id: siteId,
      created_by: createdBy,
      source_text: geminiItem.source_text,
      normalized_summary: geminiItem.normalized_summary,
      trade: geminiItem.trade,
      tier: geminiItem.tier,
      urgency: geminiItem.urgency,
      unit_or_area: geminiItem.unit_or_area || null,
      needs_gc_attention: geminiItem.needs_gc_attention,
      needs_trade_manager_attention: geminiItem.needs_trade_manager_attention,
      downstream_trades: geminiItem.downstream_trades,
      recommended_company_type: geminiItem.recommended_company_type,
      action_required: geminiItem.action_required,
      suggested_next_step: geminiItem.suggested_next_step,
      recipient_user_ids: recipientUserIds,
      recipient_company_ids: recipientCompanyIds,
      status: "pending",
    });

    if (itemErr) {
      console.error("[persistGeminiExtractedItems] insert failed:", itemErr);
      continue;
    }

    inserted++;

    await ensureSelfTaskForExtractedItem({
      supabase,
      extractedItemId: itemId,
      workerUserId: createdBy,
      projectId,
      siteId,
      tier: geminiItem.tier,
    });

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
        console.error("[persistGeminiExtractedItems] notification docs:", err)
      );

      sendFcmNotifications(
        recipientUserIds,
        recipientCompanyIds,
        title,
        body,
        {
          type,
          extractedItemId: itemId,
          projectId,
        }
      ).catch((err) =>
        console.error("[persistGeminiExtractedItems] FCM:", err)
      );
    }
  }

  return inserted;
}
