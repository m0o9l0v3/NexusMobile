-- Run as nexus_owner after applying the reviewed schema. Intentionally no default grants.
BEGIN;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM nexus_admin_app, nexus_public;
ALTER DEFAULT PRIVILEGES FOR ROLE nexus_owner IN SCHEMA public REVOKE ALL ON TABLES FROM nexus_admin_app, nexus_public;
GRANT SELECT ON "__EFMigrationsHistory" TO nexus_admin_app, nexus_public;
GRANT SELECT, INSERT, UPDATE, DELETE ON departments, events, exhibits, issued_tokens,
    map_datasets, oc_days, one_time_login_codes, open_campus_timeslots, qr_issues,
    revoked_jti, spots, timeslot_exhibits, visit_logs TO nexus_admin_app;
GRANT SELECT ON spots, events TO nexus_public;
GRANT SELECT (chain_id, created_at, hash), INSERT ON visit_logs TO nexus_public;
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexus_public_visible ON spots;
DROP POLICY IF EXISTS nexus_admin_all ON spots;
DROP POLICY IF EXISTS nexus_public_visible ON events;
DROP POLICY IF EXISTS nexus_admin_all ON events;
CREATE POLICY nexus_public_visible ON spots FOR SELECT TO nexus_public USING (is_published);
CREATE POLICY nexus_admin_all ON spots FOR ALL TO nexus_admin_app USING (true) WITH CHECK (true);
CREATE POLICY nexus_public_visible ON events FOR SELECT TO nexus_public USING (is_published);
CREATE POLICY nexus_admin_all ON events FOR ALL TO nexus_admin_app USING (true) WITH CHECK (true);
COMMIT;
