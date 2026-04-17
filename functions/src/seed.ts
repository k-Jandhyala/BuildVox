import { getDemoPassword } from "./config";
import { getSupabase } from "./supabaseAdmin";

/**
 * Seeds Supabase Auth users + app tables (idempotent).
 * No Firebase Auth — identities live in Supabase Auth only.
 */
export async function seedDemoData(): Promise<{
  message: string;
  created: string[];
}> {
  const created: string[] = [];
  const password = getDemoPassword();
  const supabase = getSupabase();

  const demoUsers = [
    { email: "gc@demo.com", displayName: "Alex Rivera (GC)", role: "gc" },
    {
      email: "electrician@demo.com",
      displayName: "Jordan Lee (Electrician)",
      role: "worker",
    },
    {
      email: "plumber@demo.com",
      displayName: "Sam Kowalski (Plumber)",
      role: "worker",
    },
    {
      email: "manager@demo.com",
      displayName: "Morgan Blake (Manager)",
      role: "manager",
    },
    { email: "admin@demo.com", displayName: "Chris Admin", role: "admin" },
  ];

  const userIds: Record<string, string> = {};

  async function findUserIdByEmail(email: string): Promise<string | null> {
    const { data, error } = await supabase.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    if (error) return null;
    const found = data.users.find((u) => u.email === email);
    return found?.id ?? null;
  }

  for (const u of demoUsers) {
    let uid = await findUserIdByEmail(u.email);
    if (uid) {
      userIds[u.email] = uid;
      console.log(`[seed] Auth user already exists: ${u.email}`);
      continue;
    }
    const { data, error } = await supabase.auth.admin.createUser({
      email: u.email,
      password,
      email_confirm: true,
      user_metadata: { full_name: u.displayName },
    });
    if (error) {
      uid = await findUserIdByEmail(u.email);
      if (uid) {
        userIds[u.email] = uid;
        console.log(`[seed] User exists after error, using: ${u.email}`);
        continue;
      }
      throw error;
    }
    if (!data.user) throw new Error(`createUser returned no user for ${u.email}`);
    userIds[u.email] = data.user.id;
    created.push(`auth:${u.email}`);
    console.log(`[seed] Created Supabase Auth user: ${u.email}`);
  }

  const voltId = "company_volt_electric";
  const aquaId = "company_aquaflow_plumbing";
  const projectId = "project_downtown_tower";

  const companyRows = [
    {
      id: voltId,
      name: "Volt Electric Inc.",
      trade_type: "electrical",
      manager_user_ids: [userIds["manager@demo.com"]],
      active_project_ids: [projectId],
    },
    {
      id: aquaId,
      name: "AquaFlow Plumbing LLC",
      trade_type: "plumbing",
      manager_user_ids: [] as string[],
      active_project_ids: [projectId],
    },
  ];

  const { error: cErr } = await supabase.from("companies").upsert(companyRows);
  if (cErr) throw cErr;
  created.push("company:volt_electric", "company:aquaflow_plumbing");

  const projectRow = {
    id: projectId,
    name: "Downtown Mixed-Use Tower",
    gc_user_ids: [userIds["gc@demo.com"]],
    company_ids: [voltId, aquaId],
    job_site_ids: ["site_floor_1_5", "site_floor_6_10"],
    trade_sequence: ["framing", "electrical", "plumbing", "drywall", "paint"],
  };

  const { error: pErr } = await supabase.from("projects").upsert(projectRow);
  if (pErr) throw pErr;
  created.push("project:downtown_tower");

  const siteRows = [
    {
      id: "site_floor_1_5",
      project_id: projectId,
      name: "Floors 1–5",
      address: "123 Main St, Downtown — Floors 1–5",
      active_trades: ["electrical", "plumbing"],
    },
    {
      id: "site_floor_6_10",
      project_id: projectId,
      name: "Floors 6–10",
      address: "123 Main St, Downtown — Floors 6–10",
      active_trades: ["framing"],
    },
  ];

  const { error: sErr } = await supabase.from("job_sites").upsert(siteRows);
  if (sErr) throw sErr;
  created.push("site:floors_1_5", "site:floors_6_10");

  const userRows = [
    {
      id: userIds["gc@demo.com"],
      name: "Alex Rivera",
      email: "gc@demo.com",
      role: "gc",
      company_id: null,
      assigned_project_ids: [projectId],
      assigned_site_ids: ["site_floor_1_5", "site_floor_6_10"],
      fcm_tokens: [] as string[],
    },
    {
      id: userIds["electrician@demo.com"],
      name: "Jordan Lee",
      email: "electrician@demo.com",
      role: "worker",
      trade: "electrical",
      company_id: voltId,
      assigned_project_ids: [projectId],
      assigned_site_ids: ["site_floor_1_5"],
      fcm_tokens: [] as string[],
    },
    {
      id: userIds["plumber@demo.com"],
      name: "Sam Kowalski",
      email: "plumber@demo.com",
      role: "worker",
      trade: "plumbing",
      company_id: aquaId,
      assigned_project_ids: [projectId],
      assigned_site_ids: ["site_floor_1_5"],
      fcm_tokens: [] as string[],
    },
    {
      id: userIds["manager@demo.com"],
      name: "Morgan Blake",
      email: "manager@demo.com",
      role: "manager",
      trade: "electrical",
      company_id: voltId,
      assigned_project_ids: [projectId],
      assigned_site_ids: ["site_floor_1_5", "site_floor_6_10"],
      fcm_tokens: [] as string[],
    },
    {
      id: userIds["admin@demo.com"],
      name: "Chris Admin",
      email: "admin@demo.com",
      role: "admin",
      company_id: null,
      assigned_project_ids: [projectId],
      assigned_site_ids: ["site_floor_1_5", "site_floor_6_10"],
      fcm_tokens: [] as string[],
    },
  ];

  const { error: uErr } = await supabase.from("app_users").upsert(userRows);
  if (uErr) throw uErr;
  created.push(
    "user:gc",
    "user:electrician",
    "user:plumber",
    "user:manager",
    "user:admin"
  );

  return {
    message: `Seed complete. ${created.length} resources created/updated.`,
    created,
  };
}
