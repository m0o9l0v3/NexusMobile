#!/usr/bin/env bash
set -euo pipefail
# Executed by the official entrypoint only for an empty cluster.
: "${NEXUS_ADMIN_PASSWORD:?Initial admin password required}"
: "${NEXUS_PUBLIC_PASSWORD:?Initial public password required}"
: "${NEXUS_MIGRATOR_PASSWORD:?Initial migrator password required}"
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=ON_ERROR_STOP=1 <<'SQL'
\getenv admin_password NEXUS_ADMIN_PASSWORD
\getenv public_password NEXUS_PUBLIC_PASSWORD
\getenv migrator_password NEXUS_MIGRATOR_PASSWORD
CREATE ROLE nexus_owner NOLOGIN;
CREATE ROLE nexus_migrator LOGIN NOINHERIT PASSWORD :'migrator_password';
CREATE ROLE nexus_admin_app LOGIN PASSWORD :'admin_password';
CREATE ROLE nexus_public LOGIN PASSWORD :'public_password';
GRANT nexus_owner TO nexus_migrator;
SELECT format('ALTER DATABASE %I OWNER TO nexus_owner', current_database()) \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO nexus_migrator, nexus_admin_app, nexus_public', current_database()) \gexec
ALTER SCHEMA public OWNER TO nexus_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO nexus_admin_app, nexus_public;
SQL
unset NEXUS_ADMIN_PASSWORD NEXUS_PUBLIC_PASSWORD NEXUS_MIGRATOR_PASSWORD
