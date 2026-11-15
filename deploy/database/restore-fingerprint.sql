-- Read-only fingerprint of a Nexus database, used to compare a backup source with its restore.
-- Run the same file against the source (right after the dump, in the same window) and against the
-- restored disposable DB, then diff the two outputs. See docs/backup-restore.md.
--
--   psql -X -At -v ON_ERROR_STOP=1 -U <superuser> -d <db> -f restore-fingerprint.sql > fingerprint.txt
--
-- The output holds no secrets or row contents: counts, migration IDs, checksums, SHA-256 of map
-- payloads, the last audit hash per chain, role/privilege flags and the server major version.
-- Optional Studio schemas (studio, delivery) are included only when they exist.
\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT 'server_major|' || current_setting('server_version_num')::int / 10000;
SELECT 'database|' || current_database();

-- 1. Migration histories (public is NexusMobile, studio is NexusStudio).
SELECT 'migration|public|' || "MigrationId" || '|' || "ProductVersion"
FROM public."__EFMigrationsHistory" ORDER BY "MigrationId";
SELECT format('SELECT ''migration|studio|'' || "MigrationId" || ''|'' || "ProductVersion" FROM studio."__EFMigrationsHistory" ORDER BY "MigrationId"')
WHERE to_regclass('studio."__EFMigrationsHistory"') IS NOT NULL \gexec

-- 2. Exact row count of every table in the Nexus schemas.
SELECT format('SELECT %L || count(*) FROM %I.%I', 'rows|' || n.nspname || '.' || c.relname || '|', n.nspname, c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND n.nspname IN ('public', 'studio', 'delivery')
ORDER BY n.nspname, c.relname \gexec

-- 3. Map datasets: the published bytes must survive unchanged.
SELECT 'map_dataset|' || version || '|' || status || '|' || checksum || '|' || encode(sha256(convert_to(payload, 'UTF8')), 'hex')
FROM public.map_datasets ORDER BY version;

-- 4. Audit chain: count and the hash at the end of each chain. audit-verify checks every link.
SELECT 'audit_chain|' || coalesce(chain_id, '<null>') || '|' || count(*) || '|' ||
       coalesce((array_agg(hash ORDER BY created_at DESC, id DESC))[1], '<null>')
FROM public.visit_logs GROUP BY chain_id ORDER BY chain_id;

-- 5. Participant bundle pointer (Studio delivery, when present).
SELECT format('SELECT ''current_bundle|'' || bundle_version FROM delivery.current_bundle')
WHERE to_regclass('delivery.current_bundle') IS NOT NULL \gexec

-- 6. Ownership, roles and the runtime contract (contract B). A restore that lost these is not usable.
SELECT 'role|' || r.rolname || '|login=' || r.rolcanlogin
FROM pg_roles r WHERE r.rolname IN ('nexus_owner', 'nexus_admin_app', 'nexus_public', 'nexus_studio_migrator', 'nexus_studio_app')
ORDER BY r.rolname;
SELECT 'owner|' || n.nspname || '.' || c.relname || '|' || pg_get_userbyid(c.relowner)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND n.nspname = 'public' ORDER BY c.relname;
SELECT 'rls|' || c.relname || '|' || c.relrowsecurity
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('spots', 'events') ORDER BY c.relname;
SELECT 'policy|' || tablename || '|' || policyname || '|' || array_to_string(roles, ',')
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
SELECT 'grant|nexus_public|' || c.relname || '|select=' || has_table_privilege('nexus_public', c.oid, 'SELECT')
       || '|insert=' || has_table_privilege('nexus_public', c.oid, 'INSERT')
       || '|update=' || has_table_privilege('nexus_public', c.oid, 'UPDATE')
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname = 'public' AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'nexus_public')
ORDER BY c.relname;

ROLLBACK;
