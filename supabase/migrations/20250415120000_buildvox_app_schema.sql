-- BuildVox application data (Postgres). Firebase Auth UIDs are stored as app_users.id.
-- Apply in Supabase: SQL Editor → New query → paste → Run.
-- RLS below is permissive for anon (dev/demo). Lock down before production.

CREATE TABLE IF NOT EXISTS app_users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'worker',
  trade TEXT,
  company_id TEXT,
  assigned_project_ids TEXT[] NOT NULL DEFAULT '{}',
  assigned_site_ids TEXT[] NOT NULL DEFAULT '{}',
  fcm_tokens TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  trade_type TEXT NOT NULL,
  manager_user_ids TEXT[] NOT NULL DEFAULT '{}',
  active_project_ids TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  gc_user_ids TEXT[] NOT NULL DEFAULT '{}',
  company_ids TEXT[] NOT NULL DEFAULT '{}',
  job_site_ids TEXT[] NOT NULL DEFAULT '{}',
  trade_sequence TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS job_sites (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  name TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  active_trades TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS voice_memos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by TEXT NOT NULL,
  user_role TEXT NOT NULL,
  company_id TEXT,
  project_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  storage_path TEXT,
  audio_url TEXT,
  transcript_status TEXT NOT NULL DEFAULT 'processing',
  processing_status TEXT NOT NULL DEFAULT 'processing',
  overall_summary TEXT,
  raw_transcript TEXT,
  detected_language TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_review_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id UUID NOT NULL,
  created_by TEXT NOT NULL,
  project_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'processing',
  items_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS extracted_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id UUID NOT NULL,
  project_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  created_by TEXT NOT NULL,
  source_text TEXT NOT NULL DEFAULT '',
  normalized_summary TEXT NOT NULL DEFAULT '',
  trade TEXT NOT NULL,
  tier TEXT NOT NULL,
  urgency TEXT NOT NULL,
  unit_or_area TEXT,
  needs_gc_attention BOOLEAN NOT NULL DEFAULT false,
  needs_trade_manager_attention BOOLEAN NOT NULL DEFAULT false,
  downstream_trades TEXT[] NOT NULL DEFAULT '{}',
  recommended_company_type TEXT NOT NULL,
  action_required BOOLEAN NOT NULL DEFAULT false,
  suggested_next_step TEXT NOT NULL DEFAULT '',
  recipient_user_ids TEXT[] NOT NULL DEFAULT '{}',
  recipient_company_ids TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  extracted_item_id UUID NOT NULL,
  assigned_to_user_id TEXT NOT NULL,
  assigned_by_user_id TEXT NOT NULL,
  company_id TEXT,
  project_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  user_id TEXT NOT NULL,
  extracted_item_id UUID,
  task_assignment_id UUID,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_digests (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  date_key TEXT NOT NULL,
  summary TEXT NOT NULL,
  included_item_ids TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_extracted_items_project ON extracted_items(project_id);
CREATE INDEX IF NOT EXISTS idx_extracted_items_created ON extracted_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned ON task_assignments(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_company ON task_assignments(company_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_review_requests_created_by ON ai_review_requests(created_by);

-- Realtime (Flutter .stream()): ignore errors if already added.
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE app_users;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE companies;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE projects;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE job_sites;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE extracted_items;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE task_assignments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE voice_memos;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE ai_review_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE app_users REPLICA IDENTITY FULL;
ALTER TABLE extracted_items REPLICA IDENTITY FULL;
ALTER TABLE task_assignments REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER TABLE projects REPLICA IDENTITY FULL;
ALTER TABLE job_sites REPLICA IDENTITY FULL;
ALTER TABLE companies REPLICA IDENTITY FULL;

-- Dev/demo: allow Flutter client to read/write (tighten for production).
-- Must include BOTH `anon` (no session) and `authenticated` (signed-in JWT).
-- Logged-in requests use `authenticated`; without it, SELECT returns 0 rows (looks like "missing profile").
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_memos ENABLE ROW LEVEL SECURITY;
ALTER TABLE extracted_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_digests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all" ON app_users;
CREATE POLICY "anon_all" ON app_users FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON companies;
CREATE POLICY "anon_all" ON companies FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON ai_review_requests;
CREATE POLICY "anon_all" ON ai_review_requests FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON projects;
CREATE POLICY "anon_all" ON projects FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON job_sites;
CREATE POLICY "anon_all" ON job_sites FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON voice_memos;
CREATE POLICY "anon_all" ON voice_memos FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON extracted_items;
CREATE POLICY "anon_all" ON extracted_items FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON task_assignments;
CREATE POLICY "anon_all" ON task_assignments FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON notifications;
CREATE POLICY "anon_all" ON notifications FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "anon_all" ON daily_digests;
CREATE POLICY "anon_all" ON daily_digests FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_all" ON app_users;
CREATE POLICY "authenticated_all" ON app_users FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON companies;
CREATE POLICY "authenticated_all" ON companies FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON ai_review_requests;
CREATE POLICY "authenticated_all" ON ai_review_requests FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON projects;
CREATE POLICY "authenticated_all" ON projects FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON job_sites;
CREATE POLICY "authenticated_all" ON job_sites FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON voice_memos;
CREATE POLICY "authenticated_all" ON voice_memos FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON extracted_items;
CREATE POLICY "authenticated_all" ON extracted_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON task_assignments;
CREATE POLICY "authenticated_all" ON task_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON notifications;
CREATE POLICY "authenticated_all" ON notifications FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated_all" ON daily_digests;
CREATE POLICY "authenticated_all" ON daily_digests FOR ALL TO authenticated USING (true) WITH CHECK (true);
