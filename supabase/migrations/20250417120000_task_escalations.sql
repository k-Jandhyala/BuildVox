-- Task escalations from workers (matches Firebase escalateTask).

CREATE TABLE IF NOT EXISTS task_escalations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
  escalated_by TEXT NOT NULL,
  reason TEXT NOT NULL,
  details TEXT NOT NULL DEFAULT '',
  project_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_escalations_project ON task_escalations(project_id);
CREATE INDEX IF NOT EXISTS idx_task_escalations_task ON task_escalations(task_id);

ALTER TABLE task_escalations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all" ON task_escalations;
CREATE POLICY "anon_all" ON task_escalations FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_all" ON task_escalations;
CREATE POLICY "authenticated_all" ON task_escalations FOR ALL TO authenticated USING (true) WITH CHECK (true);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE task_escalations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
