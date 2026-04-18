/**
 * Realistic IDs aligned with seedDemoData / seed.ts (Project Alpha, two jobsites).
 * Used by role-flow smoke tests — not a live DB.
 */

export const USER_IDS = {
  gc: "user_gc_alpha",
  electrician: "user_elec_site_a",
  plumber: "user_plumb_site_b",
  manager: "user_manager_volt",
  admin: "user_admin_global",
} as const;

export const COMPANY_IDS = {
  voltElectric: "company_volt_electric",
  aquaPlumbing: "company_aquaflow_plumbing",
} as const;

export const PROJECT_ID = "project_downtown_tower";
export const SITE_A = "site_floor_1_5";
export const SITE_B = "site_floor_6_10";

export const projectRow = {
  id: PROJECT_ID,
  name: "Downtown Mixed-Use Tower",
  gc_user_ids: [USER_IDS.gc],
  company_ids: [COMPANY_IDS.voltElectric, COMPANY_IDS.aquaPlumbing],
  job_site_ids: [SITE_A, SITE_B],
  trade_sequence: ["framing", "electrical", "plumbing", "drywall", "paint"],
};

export const companyRows = [
  {
    id: COMPANY_IDS.voltElectric,
    name: "Volt Electric Inc.",
    trade_type: "electrical",
    manager_user_ids: [USER_IDS.manager],
    active_project_ids: [PROJECT_ID],
  },
  {
    id: COMPANY_IDS.aquaPlumbing,
    name: "AquaFlow Plumbing LLC",
    trade_type: "plumbing",
    manager_user_ids: [] as string[],
    active_project_ids: [PROJECT_ID],
  },
];

export const appUserRows = [
  {
    id: USER_IDS.gc,
    role: "gc",
    email: "gc@demo.com",
    fcm_tokens: [] as string[],
  },
  {
    id: USER_IDS.manager,
    role: "manager",
    email: "manager@demo.com",
    fcm_tokens: [] as string[],
  },
  {
    id: USER_IDS.electrician,
    role: "worker",
    trade: "electrical",
    company_id: COMPANY_IDS.voltElectric,
    assigned_project_ids: [PROJECT_ID],
    assigned_site_ids: [SITE_A],
    fcm_tokens: [] as string[],
  },
  {
    id: USER_IDS.plumber,
    role: "worker",
    trade: "plumbing",
    company_id: COMPANY_IDS.aquaPlumbing,
    assigned_project_ids: [PROJECT_ID],
    assigned_site_ids: [SITE_B],
    fcm_tokens: [] as string[],
  },
  {
    id: USER_IDS.admin,
    role: "admin",
    email: "admin@demo.com",
    fcm_tokens: [] as string[],
  },
];
