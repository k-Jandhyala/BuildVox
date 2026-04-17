-- Signed-in Flutter clients use PostgREST role `authenticated`, not `anon`.
-- If only `anon` policies exist, every query with a JWT returns zero rows — login then
-- fails with "User profile not found" even when `app_users` has a matching row.
-- Run this in SQL Editor if you already applied the schema before `authenticated_all` was added.

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
