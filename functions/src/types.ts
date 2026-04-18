// ─── Enums / Union Types ─────────────────────────────────────────────────────

export type UserRole = "worker" | "gc" | "manager" | "admin";

export type TradeType =
  | "electrical"
  | "plumbing"
  | "framing"
  | "drywall"
  | "paint"
  | "general"
  | "inspection"
  | "other";

export type TierType =
  | "issue_or_blocker"
  | "material_request"
  | "progress_update"
  | "schedule_change";

export type UrgencyLevel = "low" | "medium" | "high" | "critical";

export type TaskStatus =
  | "pending"
  | "acknowledged"
  | "in_progress"
  | "done"
  | "cancelled";

export type ProcessingStatus =
  | "pending"
  | "processing"
  | "completed"
  | "failed";

export type NotificationType =
  | "new_blocker"
  | "new_schedule_change"
  | "task_assigned"
  | "material_request"
  | "task_updated"
  | "task_escalated";

// ─── Firestore Document Shapes ────────────────────────────────────────────────

export interface UserDoc {
  uid: string;
  name: string;
  email: string;
  role: UserRole;
  trade?: TradeType;
  companyId?: string;
  assignedProjectIds: string[];
  assignedSiteIds: string[];
  fcmTokens: string[];
  createdAt?: string;
}

export interface CompanyDoc {
  id: string;
  name: string;
  tradeType: TradeType;
  managerUserIds: string[];
  activeProjectIds: string[];
}

export interface ProjectDoc {
  id: string;
  name: string;
  gcUserIds: string[];
  companyIds: string[];
  jobSiteIds: string[];
  // Ordered trade sequence for schedule-change downstream routing
  tradeSequence: TradeType[];
  createdAt?: string;
}

export interface JobSiteDoc {
  id: string;
  projectId: string;
  name: string;
  address: string;
  activeTrades: TradeType[];
  createdAt?: string;
}

export interface VoiceMemoDoc {
  id: string;
  createdBy: string;         // userId
  userRole: UserRole;
  companyId?: string;
  projectId: string;
  siteId: string;
  storagePath?: string;      // optional Supabase object path
  audioUrl?: string;         // Supabase public/signed URL
  transcriptStatus: ProcessingStatus;
  processingStatus: ProcessingStatus;
  overallSummary?: string;
  rawTranscript?: string;
  detectedLanguage?: string;
  createdAt?: string;
  errorMessage?: string;
}

export interface ExtractedItemDoc {
  id: string;
  memoId: string;
  projectId: string;
  siteId: string;
  createdBy: string;
  sourceText: string;
  normalizedSummary: string;
  trade: TradeType;
  tier: TierType;
  urgency: UrgencyLevel;
  unitOrArea?: string;
  needsGcAttention: boolean;
  needsTradeManagerAttention: boolean;
  downstreamTrades: TradeType[];
  recommendedCompanyType: TradeType;
  actionRequired: boolean;
  suggestedNextStep: string;
  recipientUserIds: string[];
  recipientCompanyIds: string[];
  status: TaskStatus;
  createdAt?: string;
}

export interface TaskAssignmentDoc {
  id: string;
  extractedItemId: string;
  assignedToUserId: string;
  assignedByUserId: string;
  companyId: string;
  projectId: string;
  siteId: string;
  status: TaskStatus;
  dueDate?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface NotificationDoc {
  id: string;
  type: NotificationType;
  userId: string;
  extractedItemId?: string;
  taskAssignmentId?: string;
  title: string;
  body: string;
  read: boolean;
  createdAt?: string;
}

export interface DailyDigestDoc {
  id: string;
  projectId: string;
  dateKey: string;           // e.g. "2024-01-15"
  summary: string;
  includedItemIds: string[];
  createdAt?: string;
}

// ─── Gemini Response Shape ────────────────────────────────────────────────────

export interface GeminiExtractedItem {
  source_text: string;
  normalized_summary: string;
  trade: TradeType;
  tier: TierType;
  urgency: UrgencyLevel;
  project_ref: string | null;
  job_site_ref: string | null;
  unit_or_area: string | null;
  needs_gc_attention: boolean;
  needs_trade_manager_attention: boolean;
  downstream_trades: TradeType[];
  recommended_company_type: TradeType;
  action_required: boolean;
  suggested_next_step: string;
}

export interface GeminiExtractionResult {
  overall_summary: string;
  language: string;
  items: GeminiExtractedItem[];
}

// ─── Callable Function Payloads ───────────────────────────────────────────────

export interface SubmitVoiceMemoRequest {
  audioUrl: string;         // Supabase public/signed URL
  storagePath?: string;     // optional object path for metadata/debugging
  projectId: string;
  siteId: string;
  mimeType?: string;        // defaults to "audio/mp4"
}

export interface SubmitVoiceMemoResponse {
  success: boolean;
  memoId: string;
  itemCount?: number;
  overallSummary?: string;
  error?: string;
}

export interface AssignTaskRequest {
  extractedItemId: string;
  assignedToUserId: string;
  dueDate?: string;         // ISO date string
}

export interface AssignTaskResponse {
  success: boolean;
  taskId: string;
}

export interface UpdateTaskStatusRequest {
  taskId: string;
  status: TaskStatus;
}

export interface UpdateTaskStatusResponse {
  success: boolean;
}

export interface GenerateDailyDigestRequest {
  projectId: string;
  dateKey?: string;         // defaults to today (YYYY-MM-DD)
}

export interface GenerateDailyDigestResponse {
  success: boolean;
  digestId: string;
  summary: string;
  itemCount: number;
}

export interface StartVoiceMemoProcessingRequest extends SubmitVoiceMemoRequest {
  photoUrls?: string[];
}

export interface StartVoiceMemoProcessingResponse {
  success: boolean;
  requestId: string;
  status: ProcessingStatus;
  error?: string;
}

export interface PollVoiceMemoProcessingRequest {
  requestId: string;
}

export interface PollVoiceMemoProcessingResponse {
  success: boolean;
  requestId: string;
  status: ProcessingStatus;
  items?: Record<string, unknown>[];
  error?: string;
}

export interface SubmitReviewedItemsRequest {
  requestId: string;
  projectId: string;
  siteId: string;
  items: Record<string, unknown>[];
}

export interface SubmitReviewedItemsResponse {
  success: boolean;
  itemCount: number;
}
