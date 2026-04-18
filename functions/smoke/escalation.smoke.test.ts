import { describe, expect, it, vi } from "vitest";
import * as supabaseAdmin from "../src/supabaseAdmin";
import { createNotificationDocs } from "../src/routing";
import { createSmokeMockSupabase } from "./mockSupabase";
import {
  COMPANY_IDS,
  PROJECT_ID,
  USER_IDS,
  companyRows,
  projectRow,
} from "./fixtures";

vi.mock("../src/supabaseAdmin", () => ({
  getSupabase: vi.fn(),
}));

describe("Scenario 8: escalation notification routing (GC + trade manager)", () => {
  it("createNotificationDocs notifies GC users and managers for the worker company", async () => {
    const mock = createSmokeMockSupabase({
      projects: [projectRow],
      companies: companyRows,
      appUsers: [],
    });
    vi.mocked(supabaseAdmin.getSupabase).mockReturnValue(mock.client);

    await createNotificationDocs(
      [USER_IDS.gc],
      [COMPANY_IDS.voltElectric],
      "Task escalated",
      "Reason: delay — need materials",
      "task_escalated",
      "00000000-0000-4000-8000-000000000099"
    );

    const userIds = mock.notifications.map(
      (n) => (n as { user_id: string }).user_id
    );
    expect(userIds).toContain(USER_IDS.gc);
    expect(userIds).toContain(USER_IDS.manager);
  });
});
