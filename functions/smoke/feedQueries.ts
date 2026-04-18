/**
 * Mirrors frontend/service query semantics for feeds (pure functions on row shapes).
 */

export type ExtractedItemRow = {
  id: string;
  project_id: string;
  site_id: string;
  tier: string;
  normalized_summary: string;
  trade: string;
  recipient_user_ids?: string[];
  recipient_company_ids?: string[];
  created_by?: string;
};

export type TaskAssignmentRow = {
  id: string;
  project_id: string;
  site_id: string;
  assigned_to_user_id: string;
  assigned_by_user_id: string;
  company_id: string | null;
  extracted_item_id: string;
  status: string;
};

/** GC “high signal” tab: blockers + schedule impacts (matches typical GC filters). */
export function gcHighSignalFeed(
  items: ExtractedItemRow[],
  opts: { projectId: string; siteId?: string }
): ExtractedItemRow[] {
  return items.filter((i) => {
    if (i.project_id !== opts.projectId) return false;
    if (opts.siteId && i.site_id !== opts.siteId) return false;
    return i.tier === "issue_or_blocker" || i.tier === "schedule_change";
  });
}

/** Material / company-side queue: not GC-user-direct; company recipients. */
export function materialRequestsForCompanies(
  items: ExtractedItemRow[],
  opts: { projectId: string; companyId: string }
): ExtractedItemRow[] {
  return items.filter(
    (i) =>
      i.project_id === opts.projectId &&
      i.tier === "material_request" &&
      (i.recipient_company_ids ?? []).includes(opts.companyId)
  );
}

/** Routine progress stored for history / digest — excluded from GC high-signal feed. */
export function progressUpdatesForProject(
  items: ExtractedItemRow[],
  projectId: string
): ExtractedItemRow[] {
  return items.filter(
    (i) => i.project_id === projectId && i.tier === "progress_update"
  );
}

/** Worker assigned-task list scoped by jobsite (and assignee). */
export function assignedTasksForWorkerAtSite(
  tasks: TaskAssignmentRow[],
  workerId: string,
  siteId: string
): TaskAssignmentRow[] {
  return tasks.filter(
    (t) =>
      t.assigned_to_user_id === workerId &&
      t.site_id === siteId
  );
}

/** Admin oversight: all items for a project (RLS would narrow in production). */
export function adminExtractedItemsForProject(
  items: ExtractedItemRow[],
  projectId: string
): ExtractedItemRow[] {
  return items.filter((i) => i.project_id === projectId);
}
