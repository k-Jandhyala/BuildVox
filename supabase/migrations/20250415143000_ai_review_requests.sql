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

CREATE INDEX IF NOT EXISTS idx_ai_review_requests_created_by ON ai_review_requests(created_by);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE ai_review_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE ai_review_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all" ON ai_review_requests;
CREATE POLICY "anon_all" ON ai_review_requests FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_all" ON ai_review_requests;
CREATE POLICY "authenticated_all" ON ai_review_requests FOR ALL TO authenticated USING (true) WITH CHECK (true);
