import {
  GeminiExtractionResult,
  GeminiExtractedItem,
  TradeType,
  TierType,
  UrgencyLevel,
  TaskStatus,
} from "./types";

// ─── Valid enum sets ──────────────────────────────────────────────────────────

const VALID_TRADES = new Set<string>([
  "electrical", "plumbing", "framing", "drywall",
  "paint", "general", "inspection", "other",
]);

const VALID_TIERS = new Set<string>([
  "issue_or_blocker", "material_request",
  "progress_update", "schedule_change",
]);

const VALID_URGENCY = new Set<string>([
  "low", "medium", "high", "critical",
]);

const VALID_TASK_STATUS = new Set<string>([
  "pending", "acknowledged", "in_progress", "done", "cancelled",
]);

// ─── Individual field validators ─────────────────────────────────────────────

function isString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

function isBoolean(v: unknown): v is boolean {
  return typeof v === "boolean";
}

function isStringArray(v: unknown): v is string[] {
  return Array.isArray(v) && v.every((i) => typeof i === "string");
}

// ─── Gemini response validation ───────────────────────────────────────────────

/**
 * Validates and normalises the raw JSON returned by Gemini.
 * Returns a clean GeminiExtractionResult or throws with a descriptive message.
 */
export function validateGeminiResponse(raw: unknown): GeminiExtractionResult {
  if (typeof raw !== "object" || raw === null) {
    throw new Error("Gemini response is not an object");
  }

  const obj = raw as Record<string, unknown>;

  if (!isString(obj.overall_summary)) {
    throw new Error("Missing or empty overall_summary");
  }
  if (!isString(obj.language)) {
    throw new Error("Missing or empty language");
  }
  if (!Array.isArray(obj.items)) {
    throw new Error("Missing items array");
  }
  if (obj.items.length === 0) {
    throw new Error("Gemini returned an empty items array");
  }

  const items: GeminiExtractedItem[] = obj.items.map(
    (item: unknown, idx: number) => validateGeminiItem(item, idx)
  );

  return {
    overall_summary: obj.overall_summary.trim(),
    language: obj.language.trim(),
    items,
  };
}

function validateGeminiItem(raw: unknown, idx: number): GeminiExtractedItem {
  if (typeof raw !== "object" || raw === null) {
    throw new Error(`Item[${idx}] is not an object`);
  }

  const item = raw as Record<string, unknown>;
  const ctx = `Item[${idx}]`;

  if (!isString(item.source_text)) {
    throw new Error(`${ctx}: missing source_text`);
  }
  if (!isString(item.normalized_summary)) {
    throw new Error(`${ctx}: missing normalized_summary`);
  }
  if (!isString(item.trade) || !VALID_TRADES.has(item.trade)) {
    // Coerce unknown trades to "other" rather than failing
    item.trade = "other";
  }
  if (!isString(item.tier) || !VALID_TIERS.has(item.tier)) {
    throw new Error(`${ctx}: invalid tier '${String(item.tier)}'`);
  }
  if (!isString(item.urgency) || !VALID_URGENCY.has(item.urgency)) {
    item.urgency = "medium"; // safe default
  }
  if (!isBoolean(item.needs_gc_attention)) {
    item.needs_gc_attention = false;
  }
  if (!isBoolean(item.needs_trade_manager_attention)) {
    item.needs_trade_manager_attention = false;
  }
  if (!isBoolean(item.action_required)) {
    item.action_required = false;
  }
  if (!isStringArray(item.downstream_trades)) {
    item.downstream_trades = [];
  }
  if (!isString(item.recommended_company_type) || !VALID_TRADES.has(item.recommended_company_type)) {
    item.recommended_company_type = item.trade;
  }
  if (!isString(item.suggested_next_step)) {
    item.suggested_next_step = "Review and take appropriate action.";
  }

  return {
    source_text: (item.source_text as string).trim(),
    normalized_summary: (item.normalized_summary as string).trim(),
    trade: item.trade as TradeType,
    tier: item.tier as TierType,
    urgency: item.urgency as UrgencyLevel,
    project_ref: typeof item.project_ref === "string" ? item.project_ref : null,
    job_site_ref: typeof item.job_site_ref === "string" ? item.job_site_ref : null,
    unit_or_area: typeof item.unit_or_area === "string" ? item.unit_or_area : null,
    needs_gc_attention: item.needs_gc_attention as boolean,
    needs_trade_manager_attention: item.needs_trade_manager_attention as boolean,
    downstream_trades: (item.downstream_trades as string[]).filter(
      (t) => VALID_TRADES.has(t)
    ) as TradeType[],
    recommended_company_type: item.recommended_company_type as TradeType,
    action_required: item.action_required as boolean,
    suggested_next_step: (item.suggested_next_step as string).trim(),
  };
}

// ─── Callable function payload validators ─────────────────────────────────────

export function validateSubmitMemoPayload(
  data: unknown
): {
  audioUrl: string;
  storagePath?: string;
  projectId: string;
  siteId: string;
  mimeType: string;
} {
  if (typeof data !== "object" || data === null) {
    throw new Error("Invalid request payload");
  }
  const d = data as Record<string, unknown>;

  if (!isString(d.audioUrl)) throw new Error("audioUrl is required");
  if (!isString(d.projectId)) throw new Error("projectId is required");
  if (!isString(d.siteId)) throw new Error("siteId is required");

  return {
    audioUrl: d.audioUrl,
    storagePath: isString(d.storagePath) ? d.storagePath : undefined,
    projectId: d.projectId,
    siteId: d.siteId,
    mimeType: isString(d.mimeType) ? d.mimeType : "audio/mp4",
  };
}

export function validateAssignTaskPayload(
  data: unknown
): { extractedItemId: string; assignedToUserId: string; dueDate?: string } {
  if (typeof data !== "object" || data === null) {
    throw new Error("Invalid request payload");
  }
  const d = data as Record<string, unknown>;

  if (!isString(d.extractedItemId)) throw new Error("extractedItemId is required");
  if (!isString(d.assignedToUserId)) throw new Error("assignedToUserId is required");

  return {
    extractedItemId: d.extractedItemId,
    assignedToUserId: d.assignedToUserId,
    dueDate: isString(d.dueDate) ? d.dueDate : undefined,
  };
}

export function validateUpdateTaskStatusPayload(
  data: unknown
): { taskId: string; status: TaskStatus } {
  if (typeof data !== "object" || data === null) {
    throw new Error("Invalid request payload");
  }
  const d = data as Record<string, unknown>;

  if (!isString(d.taskId)) throw new Error("taskId is required");
  if (!isString(d.status) || !VALID_TASK_STATUS.has(d.status)) {
    throw new Error(`Invalid status '${String(d.status)}'`);
  }

  return { taskId: d.taskId, status: d.status as TaskStatus };
}

export function validatePollVoiceMemoPayload(
  data: unknown
): { requestId: string } {
  if (typeof data !== "object" || data === null) {
    throw new Error("Invalid request payload");
  }
  const d = data as Record<string, unknown>;
  if (!isString(d.requestId)) throw new Error("requestId is required");
  return { requestId: d.requestId };
}

export function validateSubmitReviewedItemsPayload(
  data: unknown
): {
  requestId: string;
  projectId: string;
  siteId: string;
  items: Record<string, unknown>[];
} {
  if (typeof data !== "object" || data === null) {
    throw new Error("Invalid request payload");
  }
  const d = data as Record<string, unknown>;
  if (!isString(d.requestId)) throw new Error("requestId is required");
  if (!isString(d.projectId)) throw new Error("projectId is required");
  if (!isString(d.siteId)) throw new Error("siteId is required");
  if (!Array.isArray(d.items)) throw new Error("items array is required");

  return {
    requestId: d.requestId,
    projectId: d.projectId,
    siteId: d.siteId,
    items: d.items.map((x) => (typeof x === "object" && x !== null ? x : {})) as Record<
      string,
      unknown
    >[],
  };
}
