import { randomUUID } from "crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";
import * as supabaseAdmin from "../src/supabaseAdmin";
import { persistGeminiExtractedItems } from "../src/persistItems";
import { createSmokeMockSupabase } from "./mockSupabase";
import {
  COMPANY_IDS,
  PROJECT_ID,
  SITE_A,
  USER_IDS,
  companyRows,
  projectRow,
  appUserRows,
} from "./fixtures";
import {
  mockElectricianBlockerExtraction,
  mockMaterialRequestExtraction,
} from "./geminiStructuredMocks";

vi.mock("../src/supabaseAdmin", () => ({
  getSupabase: vi.fn(),
}));

describe("persist pipeline — routing + extracted_items + notifications (mock DB)", () => {
  beforeEach(() => {
    const mock = createSmokeMockSupabase({
      projects: [projectRow],
      companies: companyRows,
      appUsers: appUserRows,
    });
    vi.mocked(supabaseAdmin.getSupabase).mockReturnValue(mock.client);
  });

  it("persists electrician blocker with GC recipients and company; notifies GC + manager", async () => {
    const mock = createSmokeMockSupabase({
      projects: [projectRow],
      companies: companyRows,
      appUsers: appUserRows,
    });
    vi.mocked(supabaseAdmin.getSupabase).mockReturnValue(mock.client);

    const extraction = mockElectricianBlockerExtraction();
    const memoId = randomUUID();
    const inserted = await persistGeminiExtractedItems({
      supabase: mock.client,
      items: extraction.items,
      memoId,
      projectId: PROJECT_ID,
      siteId: SITE_A,
      createdBy: USER_IDS.electrician,
    });

    expect(inserted).toBe(1);
    expect(mock.extracted_items.length).toBe(1);
    expect(mock.task_assignments.length).toBe(1);
    expect(
      (mock.task_assignments[0] as { assigned_to_user_id?: string })
        .assigned_to_user_id
    ).toBe(USER_IDS.electrician);
    const row = mock.extracted_items[0] as Record<string, unknown>;
    expect(row.project_id).toBe(PROJECT_ID);
    expect(row.site_id).toBe(SITE_A);
    expect(row.tier).toBe("issue_or_blocker");
    expect((row.recipient_user_ids as string[]).includes(USER_IDS.gc)).toBe(true);
    expect((row.recipient_company_ids as string[]).includes(COMPANY_IDS.voltElectric)).toBe(
      true
    );

    expect(mock.notifications.length).toBeGreaterThanOrEqual(1);
    const gcNote = mock.notifications.find(
      (n) => (n as { user_id?: string }).user_id === USER_IDS.gc
    );
    expect(gcNote).toBeDefined();
    const mgrNote = mock.notifications.find(
      (n) => (n as { user_id?: string }).user_id === USER_IDS.manager
    );
    expect(mgrNote).toBeDefined();
  });

  it("material request: no GC user recipients; manager notification via company", async () => {
    const mock = createSmokeMockSupabase({
      projects: [projectRow],
      companies: companyRows,
      appUsers: appUserRows,
    });
    vi.mocked(supabaseAdmin.getSupabase).mockReturnValue(mock.client);

    const extraction = mockMaterialRequestExtraction();
    const memoId = randomUUID();
    await persistGeminiExtractedItems({
      supabase: mock.client,
      items: extraction.items,
      memoId,
      projectId: PROJECT_ID,
      siteId: SITE_A,
      createdBy: USER_IDS.electrician,
    });

    const row = mock.extracted_items[0] as Record<string, unknown>;
    expect(row.tier).toBe("material_request");
    expect((row.recipient_user_ids as string[]).length).toBe(0);
    expect(mock.notifications.some((n) => (n as { user_id?: string }).user_id === USER_IDS.gc)).toBe(
      false
    );
    expect(
      mock.notifications.some((n) => (n as { user_id?: string }).user_id === USER_IDS.manager)
    ).toBe(true);
    expect(mock.task_assignments.length).toBe(1);
  });
});
