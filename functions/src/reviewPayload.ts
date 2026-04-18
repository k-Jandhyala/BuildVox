import type { GeminiExtractedItem } from "./types";

export function mapCategoryToTier(category: string): string {
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
    case "workorder":
    case "work_order":
      return "progress_update";
    default:
      return "progress_update";
  }
}

export function mapPriorityToUrgency(priority: string): string {
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

/** Maps client AI-review / field-note JSON to Gemini-shaped item for routing + DB. */
export function buildGeminiLikeItem(
  raw: Record<string, unknown>,
  fallbackTrade: string
): GeminiExtractedItem {
  const category = String(raw.category || "taskUpdate");
  const catLower = category.toLowerCase();
  const isBlocker = Boolean(raw.isBlocker);
  const isMaterialRequest = Boolean(raw.isMaterialRequest);
  const isWorkOrder =
    catLower === "workorder" ||
    catLower === "work_order" ||
    catLower.includes("workorder");
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
    trade: trade as GeminiExtractedItem["trade"],
    tier: tier as GeminiExtractedItem["tier"],
    urgency: urgency as GeminiExtractedItem["urgency"],
    project_ref: null,
    job_site_ref: null,
    unit_or_area: String(raw.location || "") || null,
    needs_gc_attention: isBlocker || tier === "schedule_change",
    needs_trade_manager_attention:
      isMaterialRequest || tier === "material_request" || isWorkOrder,
    downstream_trades: [],
    recommended_company_type:
      trade as GeminiExtractedItem["recommended_company_type"],
    action_required: true,
    suggested_next_step: String(raw.notes || "Review and route."),
  };
}

/** Standard UUID v4 (matches ai_review_requests.id from voice flow). */
export function isUuidV4(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    id.trim()
  );
}
