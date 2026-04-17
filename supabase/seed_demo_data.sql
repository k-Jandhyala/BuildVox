-- ═══════════════════════════════════════════════════════════════════════════════
-- OPTIONAL / LEGACY — Prefer seeding via Cloud Function `seedDemoData` or HTTP
-- `seedDemoDataHttp`: they create Supabase Auth users + `app_users` with matching UUIDs.
--
-- This file used fixed string IDs for a Firebase+SQL workflow. The app now uses
-- Supabase Auth only; `app_users.id` must equal `auth.users.id` (UUID).
-- Do not run this unless you understand the mismatch — use the function seed instead.
--
-- If you still want SQL-only companies/project/sites without users, trim this file
-- to only the companies / projects / job_sites sections.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Companies ───────────────────────────────────────────────────────────────
INSERT INTO companies (id, name, trade_type, manager_user_ids, active_project_ids)
VALUES
  (
    'company_volt_electric',
    'Volt Electric Inc.',
    'electrical',
    ARRAY['bv_demo_manager_001']::text[],
    ARRAY['project_downtown_tower']::text[]
  ),
  (
    'company_aquaflow_plumbing',
    'AquaFlow Plumbing LLC',
    'plumbing',
    ARRAY[]::text[],
    ARRAY['project_downtown_tower']::text[]
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  trade_type = EXCLUDED.trade_type,
  manager_user_ids = EXCLUDED.manager_user_ids,
  active_project_ids = EXCLUDED.active_project_ids;

-- ─── Project ───────────────────────────────────────────────────────────────────
INSERT INTO projects (
  id,
  name,
  gc_user_ids,
  company_ids,
  job_site_ids,
  trade_sequence
)
VALUES (
  'project_downtown_tower',
  'Downtown Mixed-Use Tower',
  ARRAY['bv_demo_gc_001']::text[],
  ARRAY['company_volt_electric', 'company_aquaflow_plumbing']::text[],
  ARRAY['site_floor_1_5', 'site_floor_6_10']::text[],
  ARRAY['framing', 'electrical', 'plumbing', 'drywall', 'paint']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  gc_user_ids = EXCLUDED.gc_user_ids,
  company_ids = EXCLUDED.company_ids,
  job_site_ids = EXCLUDED.job_site_ids,
  trade_sequence = EXCLUDED.trade_sequence;

-- ─── Job sites ────────────────────────────────────────────────────────────────
INSERT INTO job_sites (id, project_id, name, address, active_trades)
VALUES
  (
    'site_floor_1_5',
    'project_downtown_tower',
    'Floors 1–5',
    '123 Main St, Downtown — Floors 1–5',
    ARRAY['electrical', 'plumbing']::text[]
  ),
  (
    'site_floor_6_10',
    'project_downtown_tower',
    'Floors 6–10',
    '123 Main St, Downtown — Floors 6–10',
    ARRAY['framing']::text[]
  )
ON CONFLICT (id) DO UPDATE SET
  project_id = EXCLUDED.project_id,
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  active_trades = EXCLUDED.active_trades;

-- ─── App users (id = Firebase Auth uid) ───────────────────────────────────────
INSERT INTO app_users (
  id,
  name,
  email,
  role,
  trade,
  company_id,
  assigned_project_ids,
  assigned_site_ids,
  fcm_tokens
)
VALUES
  (
    'bv_demo_gc_001',
    'Alex Rivera',
    'gc@demo.com',
    'gc',
    NULL,
    NULL,
    ARRAY['project_downtown_tower']::text[],
    ARRAY['site_floor_1_5', 'site_floor_6_10']::text[],
    ARRAY[]::text[]
  ),
  (
    'bv_demo_electrician_001',
    'Jordan Lee',
    'electrician@demo.com',
    'worker',
    'electrical',
    'company_volt_electric',
    ARRAY['project_downtown_tower']::text[],
    ARRAY['site_floor_1_5']::text[],
    ARRAY[]::text[]
  ),
  (
    'bv_demo_plumber_001',
    'Sam Kowalski',
    'plumber@demo.com',
    'worker',
    'plumbing',
    'company_aquaflow_plumbing',
    ARRAY['project_downtown_tower']::text[],
    ARRAY['site_floor_1_5']::text[],
    ARRAY[]::text[]
  ),
  (
    'bv_demo_manager_001',
    'Morgan Blake',
    'manager@demo.com',
    'manager',
    'electrical',
    'company_volt_electric',
    ARRAY['project_downtown_tower']::text[],
    ARRAY['site_floor_1_5', 'site_floor_6_10']::text[],
    ARRAY[]::text[]
  ),
  (
    'bv_demo_admin_001',
    'Chris Admin',
    'admin@demo.com',
    'admin',
    NULL,
    NULL,
    ARRAY['project_downtown_tower']::text[],
    ARRAY['site_floor_1_5', 'site_floor_6_10']::text[],
    ARRAY[]::text[]
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role,
  trade = EXCLUDED.trade,
  company_id = EXCLUDED.company_id,
  assigned_project_ids = EXCLUDED.assigned_project_ids,
  assigned_site_ids = EXCLUDED.assigned_site_ids,
  fcm_tokens = EXCLUDED.fcm_tokens;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════════
-- Firebase: create users with matching UIDs (Node.js, Firebase Admin already init):
--
-- const pwd = 'BuildVox2024!';
-- const users = [
--   { uid: 'bv_demo_gc_001',          email: 'gc@demo.com',           name: 'Alex Rivera (GC)' },
--   { uid: 'bv_demo_electrician_001', email: 'electrician@demo.com', name: 'Jordan Lee (Electrician)' },
--   { uid: 'bv_demo_plumber_001',     email: 'plumber@demo.com',     name: 'Sam Kowalski (Plumber)' },
--   { uid: 'bv_demo_manager_001',     email: 'manager@demo.com',     name: 'Morgan Blake (Manager)' },
--   { uid: 'bv_demo_admin_001',       email: 'admin@demo.com',       name: 'Chris Admin' },
-- ];
-- for (const u of users) {
--   try { await admin.auth().createUser({ uid: u.uid, email: u.email, password: pwd, displayName: u.name, emailVerified: true }); }
--   catch (e) { if (e.code !== 'auth/uid-already-exists') throw e; }
-- }
-- ═══════════════════════════════════════════════════════════════════════════════
