import type { SupabaseClient } from "@supabase/supabase-js";

type Row = Record<string, unknown>;

/**
 * Minimal chainable mock for routing + persist + createNotificationDocs + sendFcmNotifications.
 */
export function createSmokeMockSupabase(seed: {
  projects: Row[];
  companies: Row[];
  appUsers?: Row[];
}) {
  const extracted_items: Row[] = [];
  const notifications: Row[] = [];
  const task_assignments: Row[] = [];

  function from(table: string) {
    return {
      select: (_cols?: string) => ({
        eq: (col: string, val: unknown) => ({
          limit: (n: number) => {
            if (table === "task_assignments" && col === "extracted_item_id") {
              const found = task_assignments.filter((t) => t.extracted_item_id === val).slice(0, n);
              return Promise.resolve({ data: found, error: null });
            }
            return Promise.resolve({ data: [], error: null });
          },
          maybeSingle: async () => {
            if (table === "projects") {
              const row = seed.projects.find((p) => p.id === val);
              return { data: row ?? null, error: null };
            }
            if (table === "companies") {
              const row = seed.companies.find((c) => c.id === val);
              return { data: row ?? null, error: null };
            }
            if (table === "app_users") {
              const row = seed.appUsers?.find((u) => u.id === val);
              return { data: row ?? null, error: null };
            }
            if (table === "task_assignments") {
              const row = (seed as { taskAssignments?: Row[] }).taskAssignments?.find(
                (t) => t.id === val
              );
              return { data: row ?? null, error: null };
            }
            return { data: null, error: null };
          },
        }),
        filter: (col: string, _op: string, pattern: string) => {
          const projectId = pattern.replace(/[{}]/g, "");
          if (table === "companies") {
            const data = seed.companies.filter((c) => {
              const ids = c.active_project_ids as string[] | undefined;
              return Array.isArray(ids) && ids.includes(projectId);
            });
            return Promise.resolve({ data, error: null });
          }
          return Promise.resolve({ data: [], error: null });
        },
        in: (col: string, vals: string[]) => {
          const users = (seed.appUsers ?? []).filter((u) =>
            vals.includes(u.id as string)
          );
          return Promise.resolve({ data: users, error: null });
        },
      }),
      insert: async (row: Row | Row[]) => {
        const rows = Array.isArray(row) ? row : [row];
        for (const r of rows) {
          if (table === "extracted_items") extracted_items.push({ ...r });
          if (table === "notifications") notifications.push({ ...r });
          if (table === "task_assignments") task_assignments.push({ ...r });
        }
        return { error: null };
      },
      update: async (_patch: Row) => ({ error: null }),
    };
  }

  const client = { from } as unknown as SupabaseClient;

  return {
    client,
    get extracted_items() {
      return extracted_items;
    },
    get notifications() {
      return notifications;
    },
    get task_assignments() {
      return task_assignments;
    },
  };
}
