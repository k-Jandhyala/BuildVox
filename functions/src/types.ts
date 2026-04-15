import * as admin from "firebase-admin";

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
  | "task_updated";

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
  createdAt: admin.firestore.Timestamp;
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
  createdAt: admin.firestore.Timestamp;
}

export interface JobSiteDoc {
  id: string;
  projectId: string;
  name: string;
  address: string;
  activeTrades: TradeType[];
  createdAt: admin.firestore.Timestamp;
}

export interface VoiceMemoDoc {
  id: string;
  createdBy: string;         // userId
  userRole: UserRole;
  companyId?: string;
  projectId: string;
  siteId: string;
  storagePath: string;       // Firebase Storage path
  audioUrl?: string;         // download URL (optional, set after upload)
  transcriptStatus: ProcessingStatus;
  processingStatus: ProcessingStatus;
  overallSummary?: string;
  rawTranscript?: string;
  detectedLanguage?: string;
  createdAt: admin.firestore.Timestamp;
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
  createdAt: admin.firestore.Timestamp;
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
  dueDate?: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
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
  createdAt: admin.firestore.Timestamp;
}

export interface DailyDigestDoc {
  id: string;
  projectId: string;
  dateKey: string;           // e.g. "2024-01-15"
  summary: string;
  includedItemIds: string[];
  createdAt: admin.firestore.Timestamp;
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
  storagePath: string;      // e.g. "audio/uid/filename.m4a"
  projectId: string;
  siteId: string;
  mimeType?: string;        // defaults to "audio/mp4"
}

export interface SubmitVoiceMemoResponse {
  success: boolean;
  memoId: string;
  itemCount?: number;
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
