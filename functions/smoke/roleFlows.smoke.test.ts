import { describe, expect, it } from "vitest";
import { computeRecipientRouting } from "../src/routing";
import type { CompanyDoc, GeminiExtractedItem, ProjectDoc } from "../src/types";
import type { TradeType } from "../src/types";
import {
  COMPANY_IDS,
  PROJECT_ID,
  SITE_A,
  SITE_B,
  USER_IDS,
  companyRows,
  projectRow,
} from "./fixtures";
import {
  adminExtractedItemsForProject,
  assignedTasksForWorkerAtSite,
  gcHighSignalFeed,
  materialRequestsForCompanies,
  progressUpdatesForProject,
  type ExtractedItemRow,
  type TaskAssignmentRow,
} from "./feedQueries";
import {
  mockElectricianBlockerExtraction,
  mockMaterialRequestExtraction,
  mockPlumberScheduleImpactExtraction,
  mockRoutineProgressExtraction,
} from "./geminiStructuredMocks";

function toProjectDoc(): ProjectDoc {
  return {
    id: projectRow.id,
    name: projectRow.name,
    gcUserIds: projectRow.gc_user_ids,
    companyIds: projectRow.company_ids,
    jobSiteIds: projectRow.job_site_ids,
    tradeSequence: projectRow.trade_sequence as TradeType[],
  };
}

function toCompanyDocs(): CompanyDoc[] {
  return companyRows.map((c) => ({
    id: c.id,
    name: c.name,
    tradeType: c.trade_type as TradeType,
    managerUserIds: [...c.manager_user_ids],
    activeProjectIds: [...c.active_project_ids],
  }));
}

describe("role flows — Gemini → routing → feed semantics", () => {
  const project = toProjectDoc();
  const companies = toCompanyDocs();

  it("Scenario 1: electrician blocker is validated, routes to GC, appears on GC feed", () => {
    const extraction = mockElectricianBlockerExtraction();
    expect(extraction.items.length).toBeGreaterThanOrEqual(1);
    const item = extraction.items[0];
    expect(item.tier).toBe("issue_or_blocker");

    const { recipientUserIds, recipientCompanyIds } = computeRecipientRouting(
      item,
      project,
      companies
    );
    expect(recipientUserIds).toContain(USER_IDS.gc);
    expect(recipientCompanyIds).toContain(COMPANY_IDS.voltElectric);

    const row: ExtractedItemRow = {
      id: "e1",
      project_id: PROJECT_ID,
      site_id: SITE_A,
      tier: item.tier,
      normalized_summary: item.normalized_summary,
      trade: item.trade,
      recipient_user_ids: recipientUserIds,
      recipient_company_ids: recipientCompanyIds,
    };
    const feed = gcHighSignalFeed([row], { projectId: PROJECT_ID });
    expect(feed.some((r) => r.id === "e1")).toBe(true);
    const scoped = gcHighSignalFeed([row], { projectId: PROJECT_ID, siteId: SITE_A });
    expect(scoped.length).toBe(1);
    const wrongSite = gcHighSignalFeed([row], { projectId: PROJECT_ID, siteId: SITE_B });
    expect(wrongSite.length).toBe(0);
  });

  it("Scenario 2: plumber schedule-impact routes to GC + downstream companies; on GC feed", () => {
    const extraction = mockPlumberScheduleImpactExtraction();
    const item = extraction.items[0];
    expect(item.tier === "issue_or_blocker" || item.tier === "schedule_change").toBe(
      true
    );

    const { recipientUserIds, recipientCompanyIds } = computeRecipientRouting(
      item,
      project,
      companies
    );
    expect(recipientUserIds).toContain(USER_IDS.gc);
    expect(recipientCompanyIds.length).toBeGreaterThan(0);

    const row: ExtractedItemRow = {
      id: "p1",
      project_id: PROJECT_ID,
      site_id: SITE_B,
      tier: item.tier,
      normalized_summary: item.normalized_summary,
      trade: item.trade,
      recipient_user_ids: recipientUserIds,
      recipient_company_ids: recipientCompanyIds,
    };
    expect(gcHighSignalFeed([row], { projectId: PROJECT_ID }).length).toBe(1);
  });

  it("Scenario 5: material request routes to both manager path and GC", () => {
    const extraction = mockMaterialRequestExtraction();
    const item = extraction.items[0];
    expect(item.tier).toBe("material_request");

    const { recipientUserIds, recipientCompanyIds } = computeRecipientRouting(
      item,
      project,
      companies
    );
    expect(recipientUserIds).toContain(USER_IDS.gc);
    expect(recipientUserIds).toContain(USER_IDS.manager);
    expect(recipientCompanyIds).toContain(COMPANY_IDS.voltElectric);

    const row: ExtractedItemRow = {
      id: "m1",
      project_id: PROJECT_ID,
      site_id: SITE_A,
      tier: "material_request",
      normalized_summary: item.normalized_summary,
      trade: "electrical",
      recipient_company_ids: recipientCompanyIds,
    };
    const mgrQueue = materialRequestsForCompanies([row], {
      projectId: PROJECT_ID,
      companyId: COMPANY_IDS.voltElectric,
    });
    expect(mgrQueue.length).toBe(1);
    const gcFeed = gcHighSignalFeed([row], { projectId: PROJECT_ID });
    expect(gcFeed.length).toBe(0);
  });

  it("Scenario 6: routine progress is stored but not in GC high-signal feed", () => {
    const extraction = mockRoutineProgressExtraction();
    const item = extraction.items[0];
    expect(item.tier).toBe("progress_update");

    const row: ExtractedItemRow = {
      id: "pr1",
      project_id: PROJECT_ID,
      site_id: SITE_A,
      tier: "progress_update",
      normalized_summary: item.normalized_summary,
      trade: "electrical",
    };
    expect(gcHighSignalFeed([row], { projectId: PROJECT_ID }).length).toBe(0);
    expect(progressUpdatesForProject([row], PROJECT_ID).length).toBe(1);
  });

  it("Scenario 7: jobsite scoping for tasks (worker A ≠ site B)", () => {
    const tasks: TaskAssignmentRow[] = [
      {
        id: "t1",
        project_id: PROJECT_ID,
        site_id: SITE_A,
        assigned_to_user_id: USER_IDS.electrician,
        assigned_by_user_id: USER_IDS.gc,
        company_id: COMPANY_IDS.voltElectric,
        extracted_item_id: "00000000-0000-4000-8000-000000000001",
        status: "pending",
      },
      {
        id: "t2",
        project_id: PROJECT_ID,
        site_id: SITE_B,
        assigned_to_user_id: USER_IDS.plumber,
        assigned_by_user_id: USER_IDS.gc,
        company_id: COMPANY_IDS.aquaPlumbing,
        extracted_item_id: "00000000-0000-4000-8000-000000000002",
        status: "pending",
      },
    ];
    expect(assignedTasksForWorkerAtSite(tasks, USER_IDS.electrician, SITE_A).length).toBe(
      1
    );
    expect(assignedTasksForWorkerAtSite(tasks, USER_IDS.electrician, SITE_B).length).toBe(
      0
    );
    expect(assignedTasksForWorkerAtSite(tasks, USER_IDS.plumber, SITE_B).length).toBe(1);
    expect(assignedTasksForWorkerAtSite(tasks, USER_IDS.plumber, SITE_A).length).toBe(0);
  });

  it("Scenario 9: admin oversight includes all item types for the project", () => {
    const rows: ExtractedItemRow[] = [
      {
        id: "a1",
        project_id: PROJECT_ID,
        site_id: SITE_A,
        tier: "issue_or_blocker",
        normalized_summary: "x",
        trade: "electrical",
      },
      {
        id: "a2",
        project_id: PROJECT_ID,
        site_id: SITE_B,
        tier: "progress_update",
        normalized_summary: "y",
        trade: "plumbing",
      },
    ];
    const all = adminExtractedItemsForProject(rows, PROJECT_ID);
    expect(all.length).toBe(2);
  });
});

describe("role flows — synthetic Gemini items for routing edges", () => {
  const project = toProjectDoc();
  const companies = toCompanyDocs();

  it("Scenario 3 & 4: GC-assigned task rows are retrievable per assignee + site (electrician / plumber)", () => {
    const synthetic: GeminiExtractedItem = {
      source_text: "GC assigned follow-up",
      normalized_summary: "Install temporary power",
      trade: "electrical",
      tier: "issue_or_blocker",
      urgency: "medium",
      project_ref: null,
      job_site_ref: null,
      unit_or_area: null,
      needs_gc_attention: true,
      needs_trade_manager_attention: false,
      downstream_trades: [],
      recommended_company_type: "electrical",
      action_required: true,
      suggested_next_step: "Complete install",
    };
    const r = computeRecipientRouting(synthetic, project, companies);
    expect(r.recipientUserIds).toContain(USER_IDS.gc);
    const task: TaskAssignmentRow = {
      id: "syn-e",
      project_id: PROJECT_ID,
      site_id: SITE_A,
      assigned_to_user_id: USER_IDS.electrician,
      assigned_by_user_id: USER_IDS.gc,
      company_id: COMPANY_IDS.voltElectric,
      extracted_item_id: "00000000-0000-4000-8000-000000000010",
      status: "pending",
    };
    expect(assignedTasksForWorkerAtSite([task], USER_IDS.electrician, SITE_A)).toEqual([
      task,
    ]);
  });
});
