#!/usr/bin/env bash
# Disposable PostgreSQL 17 rehearsal of the public-api deploy / rollback rules (E8-6, #73).
#
# Checks, against a throw-away PG17 with the reviewed baseline, how public-api images and the
# migration SQL behave in the orders described in docs/deploy-rollback.md:
#   D1 new image before the migration  -> refuses to start (startup readiness)
#   D2 migration SQL + grants, then image -> healthy, DB-backed GET works
#   D3 migration SQL again             -> no-op (idempotent), history unchanged
#   D4 image rollback / roll forward with the same history -> both start
#   D5 a newer migration applied       -> running process keeps serving, but no image of the
#                                         current history can (re)start: rollback = restore or forward-fix
#   D6 older migration SQL on a newer history -> rejected (no downgrade path)
#   D7 DB down while the API runs      -> /health stays 200, data endpoints fail
#
# Never point this at production: local Unix-socket Docker context only, random-prefixed
# resources created and removed by this run (KEEP=1 keeps them).
#
#   DOCKER_CONTEXT=colima-nexus-db-verify NEXUS_INFRA_DIR=../nexus-infra \
#   NEW_IMAGE=<public-api image> PREV_IMAGE=<previous public-api image> bash tools/database/rehearse-deploy.sh
set -euo pipefail
umask 077

: "${DOCKER_CONTEXT:?Set DOCKER_CONTEXT to a local verification engine}"
: "${NEXUS_INFRA_DIR:?Set NEXUS_INFRA_DIR to a NexusInfra checkout}"
: "${NEW_IMAGE:?Set NEW_IMAGE to the public-api image being deployed}"
: "${PREV_IMAGE:?Set PREV_IMAGE to the previous public-api image}"
PG17_IMAGE=${PG17_IMAGE:-postgres@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24}
INFRA_REF=${INFRA_REF:-origin/main}
SDK_IMAGE=${SDK_IMAGE:-mcr.microsoft.com/dotnet/sdk:8.0}
export DOCKER_CONTEXT

endpoint=$(docker context inspect "$DOCKER_CONTEXT" --format '{{.Endpoints.docker.Host}}')
case "$endpoint" in unix://*) ;; *) echo 'Only a local Unix-socket Docker context is supported' >&2; exit 2 ;; esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
INFRA_DIR=$(cd "$NEXUS_INFRA_DIR" && pwd)
stamp=$(date -u +%Y%m%dT%H%M%SZ)
P="nexus-r73-$(openssl rand -hex 4)"
OUT=${REHEARSAL_DIR:-$ROOT/.local/database-verification/deploy-rehearsal-$stamp}
mkdir -p "$OUT"/{secrets,infra,tool/apps,tool/tools}
chmod 700 "$OUT"
LOG="$OUT/rehearsal.log"; : > "$LOG"
NET="$P-net" VOL="$P-db" DB="$P-postgres" API="$P-api"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$LOG"; }
ok() { log "PASS: $*"; }
fail() { log "FAIL: $*"; exit 1; }
cleanup() {
    status=$?
    if [ "${KEEP:-0}" = 1 ]; then log "KEEP=1: leaving $P*"; exit "$status"; fi
    docker rm -f "$API" "$DB" >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
    docker volume rm "$VOL" "$P-nuget" >/dev/null 2>&1 || true
    log "cleanup done (exit $status)"; exit "$status"
}
trap cleanup EXIT

openssl rand -hex 24 > "$OUT/secrets/db_password"
openssl rand -hex 24 > "$OUT/secrets/public_password"
openssl rand -hex 32 > "$OUT/secrets/audit_key"
printf 'Host=db;Port=5432;Database=nexus;Username=nexus_public;Password=%s' "$(cat "$OUT/secrets/public_password")" > "$OUT/secrets/public_connection"
chmod 755 "$OUT/secrets"; chmod 644 "$OUT"/secrets/*   # disposable values for the non-root API UID

git -C "$INFRA_DIR" show "$INFRA_REF:sql/pg17-baseline/01-roles.sql" > "$OUT/infra/01-roles.sql"
rsync -a --exclude bin --exclude obj "$ROOT/apps/nexus-data" "$ROOT/apps/public-api" "$OUT/tool/apps/"
rsync -a --exclude bin --exclude obj "$ROOT/tools/database" "$OUT/tool/tools/"
docker run --rm -v "$OUT/tool:/w" -v "$P-nuget:/root/.nuget" -w /w "$SDK_IMAGE" \
    dotnet publish tools/database/Nexus.Database.csproj -c Release -o /w/out -v q >/dev/null
docker run --rm -v "$OUT/tool:/w" -v "$OUT:/o" "$SDK_IMAGE" dotnet /w/out/Nexus.Database.dll script /o/migrate.sql >/dev/null
{
    echo "nexus-mobile $(git -C "$ROOT" rev-parse HEAD)"
    echo "nexus-infra $INFRA_REF $(git -C "$INFRA_DIR" rev-parse "$INFRA_REF")"
    echo "pg17_image $PG17_IMAGE"
    echo "new_image $NEW_IMAGE $(docker image inspect --format '{{.Id}}' "$NEW_IMAGE")"
    echo "prev_image $PREV_IMAGE $(docker image inspect --format '{{.Id}}' "$PREV_IMAGE")"
    (cd "$OUT" && shasum -a 256 migrate.sql infra/01-roles.sql)
    (cd "$ROOT" && shasum -a 256 deploy/database/grant-runtime.sql)
} > "$OUT/inputs.txt"
log "inputs: $(tr '\n' ';' < "$OUT/inputs.txt")"

docker network create --internal "$NET" >/dev/null
docker volume create "$VOL" >/dev/null
docker run -d --name "$DB" --network "$NET" --network-alias db -v "$VOL:/var/lib/postgresql/data" -v "$OUT/secrets:/s:ro" \
    -e POSTGRES_USER=nexus -e POSTGRES_DB=nexus -e POSTGRES_PASSWORD_FILE=/s/db_password \
    --health-cmd 'pg_isready -U nexus -d nexus' --health-interval 2s "$PG17_IMAGE" >/dev/null
wait_db() { for _ in $(seq 60); do [ "$(docker inspect -f '{{.State.Health.Status}}' "$DB")" = healthy ] && return 0; sleep 1; done; return 1; }
wait_db || fail 'PG17 did not start'
psql_su() { docker exec -i --user postgres "$DB" psql -X -q -v ON_ERROR_STOP=1 -U nexus -d nexus "$@"; }
history() { psql_su -At -c "SELECT string_agg(\"MigrationId\", ',' ORDER BY \"MigrationId\") FROM \"__EFMigrationsHistory\""; }
docker exec -i --user postgres -e NEXUS_PUBLIC_PASSWORD="$(cat "$OUT/secrets/public_password")" "$DB" \
    psql -X -q -v ON_ERROR_STOP=1 -U nexus -d nexus < "$OUT/infra/01-roles.sql"

# start_api IMAGE -> 0 when healthy, 1 when the process exits; the last log lines go to the log file
start_api() {
    docker rm -f "$API" >/dev/null 2>&1 || true
    docker run -d --name "$API" --network "$NET" -v "$OUT/secrets:/run/secrets:ro" \
        -e ASPNETCORE_ENVIRONMENT=Production -e DatabaseProvider=postgresql \
        -e ConnectionStrings__PublicApiReadOnlyFile=/run/secrets/public_connection -e AuditLog__HashKeyFile=/run/secrets/audit_key \
        -e Cors__AllowedOrigins__0=https://site.example.invalid "$1" >/dev/null
    for _ in $(seq 60); do
        [ "$(docker inspect -f '{{.State.Running}}' "$API")" = true ] || { docker logs "$API" 2>&1 | grep -m1 -E 'InvalidOperationException|Exception:' >> "$LOG" || true; return 1; }
        [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$API")" = healthy ] && return 0
        sleep 2
    done
    return 1
}
code() { docker exec "$API" curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8080$1"; }
post_log() { docker exec "$API" curl -fsS -o /dev/null -X POST -H 'Content-Type: application/json' \
    -d "{\"sessionId\":\"$1\",\"eventType\":\"spot_view\",\"spotCode\":\"R73-1\"}" http://127.0.0.1:8080/api/logs; }

# D1
if start_api "$NEW_IMAGE"; then fail 'D1 new image started before the migration'; fi
ok "D1 new image before the migration exits at startup (history='$(psql_su -At -c "SELECT to_regclass('public.\"__EFMigrationsHistory\"')")')"

# D2
t=$(date +%s)
psql_su < "$OUT/migrate.sql" >/dev/null
{ printf 'SET ROLE nexus_owner;\n'; cat "$ROOT/deploy/database/grant-runtime.sql"; } | psql_su 2>/dev/null
psql_su -c "SET ROLE nexus_owner; INSERT INTO spots (id, code, name, description, is_published, updated_at) VALUES (gen_random_uuid(), 'R73-1', 'Spot 1', 'Rehearsal', true, now())"
migrate_secs=$(( $(date +%s) - t ))
start_api "$NEW_IMAGE" || fail 'D2 new image did not start after the migration'
[ "$(code /health)" = 200 ] && [ "$(code /api/spots/public)" = 200 ] || fail 'D2 HTTP checks'
post_log d2
ok "D2 migration SQL + grants (${migrate_secs}s), then new image: healthy, /health 200, /api/spots/public 200, log accepted (history=$(history))"

# D3
before=$(history)
psql_su < "$OUT/migrate.sql" >/dev/null
[ "$(history)" = "$before" ] || fail 'D3 history changed on re-run'
ok 'D3 migration SQL re-run is a no-op (history unchanged)'

# D4
start_api "$PREV_IMAGE" || fail 'D4 previous image did not start on the same history'
[ "$(code /api/spots/public)" = 200 ] || fail 'D4 previous image GET'
post_log d4-prev
start_api "$NEW_IMAGE" || fail 'D4 roll forward'
post_log d4-new; sleep 2
ok "D4 rollback to the previous image and forward again on the same history: both healthy (visit_logs=$(psql_su -At -c 'SELECT count(*) FROM visit_logs'))"

# D5: stands in for the next reviewed migration (only the history row, so that nothing else changes)
psql_su -c "SET ROLE nexus_owner; INSERT INTO \"__EFMigrationsHistory\" VALUES ('20991231000000_RehearsalNextMigration', '8.0.6')"
[ "$(code /api/spots/public)" = 200 ] || fail 'D5 running process stopped serving'
log 'D5 running process still serves /api/spots/public after the newer migration (readiness runs only at startup)'
docker restart "$API" >/dev/null; sleep 5
if [ "$(docker inspect -f '{{.State.Running}}' "$API")" = true ]; then fail 'D5 restart of the current image succeeded'; fi
docker logs "$API" 2>&1 | grep -m1 -E 'InvalidOperationException' >> "$LOG" || true
if start_api "$PREV_IMAGE"; then fail 'D5 previous image started on the newer history'; fi
ok 'D5 after a newer migration neither the current nor the previous image can (re)start: image rollback alone is impossible'

# D6
if psql_su < "$OUT/migrate.sql" >> "$LOG" 2>&1; then fail 'D6 older migration SQL accepted a newer history'; fi
ok 'D6 the current migration SQL refuses a database with an unknown (newer) migration'
psql_su -c "SET ROLE nexus_owner; DELETE FROM \"__EFMigrationsHistory\" WHERE \"MigrationId\" = '20991231000000_RehearsalNextMigration'"   # disposable DB only

# D7
start_api "$NEW_IMAGE" || fail 'D7 start'
docker stop "$DB" >/dev/null
h=$(code /health); s=$(code /api/spots/public)
[ "$h" = 200 ] && [ "$s" != 200 ] || fail "D7 health=$h spots=$s"
docker start "$DB" >/dev/null; wait_db
for _ in $(seq 15); do [ "$(code /api/spots/public)" = 200 ] && break; sleep 2; done
[ "$(code /api/spots/public)" = 200 ] || fail 'D7 did not recover after the DB came back'
ok "D7 with the DB stopped /health=$h but /api/spots/public=$s; after the DB returned the same process served 200 again"
log 'RESULT: all deploy/rollback checks passed'
