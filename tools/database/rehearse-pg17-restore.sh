#!/usr/bin/env bash
# Disposable PostgreSQL 17 backup -> restore rehearsal for the Nexus `public` schema (E8-5, #71).
#
# Builds a throw-away "source" PG17 with the reviewed baseline (NexusInfra 01-roles.sql, the
# NexusMobile migration SQL, grant-runtime.sql), writes audit logs through the real public-api,
# backs it up exactly like NexusInfra scripts/backup-pg17-source.sh, then restores the copy into a
# NEW empty volume with NexusInfra compose.pg17-restore.yml and checks it (docs/backup-restore.md).
#
# Never point this at production: it only talks to the local Docker context named in
# DOCKER_CONTEXT (Unix socket), creates every container/volume/network itself under a random
# prefix, and removes only those at the end (KEEP=1 keeps them for inspection).
#
#   DOCKER_CONTEXT=colima-nexus-db-verify NEXUS_INFRA_DIR=../nexus-infra \
#   PUBLIC_API_IMAGE=<local or adopted image> bash tools/database/rehearse-pg17-restore.sh
set -euo pipefail
umask 077

: "${DOCKER_CONTEXT:?Set DOCKER_CONTEXT to a local verification engine}"
: "${NEXUS_INFRA_DIR:?Set NEXUS_INFRA_DIR to a NexusInfra checkout}"
: "${PUBLIC_API_IMAGE:?Set PUBLIC_API_IMAGE to the public-api image under test}"
PG17_IMAGE=${PG17_IMAGE:-postgres@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24}
INFRA_REF=${INFRA_REF:-origin/main}
COMPOSE=${COMPOSE:-docker-compose}
SDK_IMAGE=${SDK_IMAGE:-mcr.microsoft.com/dotnet/sdk:8.0}
export DOCKER_CONTEXT

endpoint=$(docker context inspect "$DOCKER_CONTEXT" --format '{{.Endpoints.docker.Host}}')
case "$endpoint" in unix://*) ;; *) echo 'Only a local Unix-socket Docker context is supported' >&2; exit 2 ;; esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
INFRA_DIR=$(cd "$NEXUS_INFRA_DIR" && pwd)
stamp=$(date -u +%Y%m%dT%H%M%SZ)
suffix=$(openssl rand -hex 4)
P="nexus-r71-$suffix"                     # prefix of everything this run creates
OUT=${REHEARSAL_DIR:-$ROOT/.local/restore-rehearsal/$stamp}
mkdir -p "$OUT"/{secrets,infra,backup,mac-copy,tool/apps,tool/tools}
chmod 700 "$OUT"
LOG="$OUT/rehearsal.log"
: > "$LOG"
SRC_NET="$P-src" SRC_VOL="$P-src-db" SRC_DB="$P-src-postgres" API="$P-api"
RESTORE_PROJECT="nexus-pg17-restore-$suffix" RESTORE_VOL="nexus-pg17-restore-$suffix"
RESTORE_NET="${RESTORE_PROJECT}_restore"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$LOG"; }
ok() { log "PASS: $*"; }
fail() { log "FAIL: $*"; exit 1; }
secs() { echo $(( $(date +%s) - $1 )); }

cleanup() {
    status=$?
    if [ "${KEEP:-0}" = 1 ]; then log "KEEP=1: leaving $P* and $RESTORE_PROJECT"; exit "$status"; fi
    docker rm -f "$API" "$API-restored" "$SRC_DB" >/dev/null 2>&1 || true
    RESTORE_ENV $COMPOSE -p "$RESTORE_PROJECT" -f "$OUT/infra/compose.pg17-restore.yml" down >/dev/null 2>&1 || true
    docker network rm "$SRC_NET" >/dev/null 2>&1 || true
    docker volume rm "$SRC_VOL" "$RESTORE_VOL" "$P-nuget" >/dev/null 2>&1 || true
    log "cleanup done (exit $status)"
    exit "$status"
}
RESTORE_ENV() {
    PG17_RESTORE_PROJECT="$RESTORE_PROJECT" PG17_RESTORE_IMAGE="$PG17_IMAGE" PG17_DB_NAME=nexus \
    PG17_RESTORE_VOLUME="$RESTORE_VOL" PG17_RESTORE_PASSWORD_FILE="$OUT/secrets/restore_password" "$@"
}
trap cleanup EXIT

rand() { openssl rand -hex 24; }
rand > "$OUT/secrets/source_password"
rand > "$OUT/secrets/restore_password"
rand > "$OUT/secrets/public_password"
rand > "$OUT/secrets/restored_public_password"
openssl rand -hex 32 > "$OUT/secrets/audit_key"
openssl rand -hex 32 > "$OUT/secrets/wrong_audit_key"
printf 'Host=db;Port=5432;Database=nexus;Username=nexus_public;Password=%s' "$(cat "$OUT/secrets/public_password")" > "$OUT/secrets/public_connection"
printf 'Host=postgres;Port=5432;Database=nexus;Username=nexus_public;Password=%s' "$(cat "$OUT/secrets/restored_public_password")" > "$OUT/secrets/restored_public_connection"
printf 'Host=postgres;Port=5432;Database=nexus;Username=postgres;Password=%s' "$(cat "$OUT/secrets/restore_password")" > "$OUT/secrets/restored_audit_connection"
chmod 644 "$OUT"/secrets/*   # disposable values; readable by the non-root public-api UID in the container
chmod 755 "$OUT/secrets"

# Inputs, pinned and hashed.
for f in compose.pg17-restore.yml scripts/preflight-rehearsal.py scripts/backup-pg17-source.sh sql/pg17-baseline/01-roles.sql; do
    git -C "$INFRA_DIR" show "$INFRA_REF:$f" > "$OUT/infra/$(basename "$f")"
done
# tools/database (.NET 8, same SDK image as the public-api build), published once with network access.
# It writes the migration SQL here and runs audit-verify later on the internal networks.
rsync -a --exclude bin --exclude obj "$ROOT/apps/nexus-data" "$ROOT/apps/public-api" "$OUT/tool/apps/"
rsync -a --exclude bin --exclude obj "$ROOT/tools/database" "$OUT/tool/tools/"
docker run --rm -v "$OUT/tool:/w" -v "$P-nuget:/root/.nuget" -w /w "$SDK_IMAGE" \
    dotnet publish tools/database/Nexus.Database.csproj -c Release -o /w/out -v q >/dev/null
docker run --rm -v "$OUT/tool:/w" -v "$OUT:/o" "$SDK_IMAGE" dotnet /w/out/Nexus.Database.dll script /o/migrate.sql >/dev/null
{
    echo "nexus-mobile $(git -C "$ROOT" rev-parse HEAD)"
    echo "nexus-infra $INFRA_REF $(git -C "$INFRA_DIR" rev-parse "$INFRA_REF")"
    echo "pg17_image $PG17_IMAGE"
    echo "public_api_image $PUBLIC_API_IMAGE $(docker image inspect --format '{{.Id}}' "$PUBLIC_API_IMAGE")"
    (cd "$OUT" && shasum -a 256 migrate.sql infra/01-roles.sql)
    (cd "$ROOT" && shasum -a 256 deploy/database/grant-runtime.sql deploy/database/restore-fingerprint.sql)
} > "$OUT/inputs.txt"
log "inputs: $(tr '\n' ';' < "$OUT/inputs.txt")"

audit_verify() { # network host connection_file key_file
    docker run --rm --network "$1" -v "$OUT/tool/out:/tool:ro" -v "$OUT/secrets:/s:ro" \
        -e NEXUS_AUDIT_CONNECTION_FILE="/s/$2" -e NEXUS_AUDIT_HASH_KEY_FILE="/s/$3" "$SDK_IMAGE" dotnet /tool/Nexus.Database.dll audit-verify
}

# 1. Source PG17 with the reviewed baseline.
t=$(date +%s)
docker network create --internal "$SRC_NET" >/dev/null
docker volume create "$SRC_VOL" >/dev/null
docker run -d --name "$SRC_DB" --network "$SRC_NET" --network-alias db -v "$SRC_VOL:/var/lib/postgresql/data" \
    -v "$OUT/secrets:/s:ro" -e POSTGRES_USER=nexus -e POSTGRES_DB=nexus -e POSTGRES_PASSWORD_FILE=/s/source_password \
    --health-cmd 'pg_isready -U nexus -d nexus' --health-interval 2s "$PG17_IMAGE" >/dev/null
for _ in $(seq 60); do [ "$(docker inspect -f '{{.State.Health.Status}}' "$SRC_DB")" = healthy ] && break; sleep 1; done
src_psql() { docker exec -i --user postgres "$SRC_DB" psql -X -q -v ON_ERROR_STOP=1 -U nexus -d nexus "$@"; }
docker exec -i --user postgres -e NEXUS_PUBLIC_PASSWORD="$(cat "$OUT/secrets/public_password")" "$SRC_DB" \
    psql -X -q -v ON_ERROR_STOP=1 -U nexus -d nexus < "$OUT/infra/01-roles.sql"
src_psql < "$OUT/migrate.sql" >/dev/null
{ printf 'SET ROLE nexus_owner;\n'; cat "$ROOT/deploy/database/grant-runtime.sql"; } | src_psql
ok "source PG17 baseline (01-roles, migrate.sql, grant-runtime) in $(secs "$t")s"

# 2. Representative data. Rows are synthetic; visit_logs are written by the real public-api.
src_psql <<'SQL'
SET ROLE nexus_owner;
INSERT INTO departments (id, name) VALUES ('d-info', 'Information'), ('d-design', 'Design');
INSERT INTO spots (id, code, name, description, is_published, updated_at)
SELECT gen_random_uuid(), 'R71-' || g, 'Spot ' || g, 'Rehearsal spot ' || g, g % 4 <> 0, now() FROM generate_series(1, 40) g;
INSERT INTO events (id, title, starts_at, ends_at, is_published)
SELECT gen_random_uuid(), 'Event ' || g, now() + g * interval '1 hour', now() + g * interval '1 hour' + interval '30 minutes', g % 3 <> 0 FROM generate_series(1, 12) g;
INSERT INTO map_datasets (id, version, status, payload, checksum, published_at)
SELECT gen_random_uuid(), v, CASE WHEN v = 3 THEN 'published' ELSE 'archived' END, p, encode(sha256(convert_to(p, 'UTF8')), 'hex'), now()
FROM (SELECT v, '{"type":"FeatureCollection","nexus":{"schema_version":"1.0.0","rev":' || v || '},"features":[]}' AS p FROM generate_series(1, 3) v) s;
SQL
api_run() { # name network connection_file
    docker rm -f "$1" >/dev/null 2>&1 || true
    docker run -d --name "$1" --network "$2" -v "$OUT/secrets:/run/secrets:ro" \
        -e ASPNETCORE_ENVIRONMENT=Production -e DatabaseProvider=postgresql \
        -e ConnectionStrings__PublicApiReadOnlyFile="/run/secrets/$3" -e AuditLog__HashKeyFile=/run/secrets/audit_key \
        -e Cors__AllowedOrigins__0=https://site.example.invalid "$PUBLIC_API_IMAGE" >/dev/null
    for _ in $(seq 60); do
        h=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1")
        [ "$h" = healthy ] && return 0
        [ "$(docker inspect -f '{{.State.Running}}' "$1")" = true ] || break
        sleep 2
    done
    docker logs "$1" 2>&1 | tail -n 20 >> "$LOG"; return 1
}
api_get() { docker exec "$1" curl -fsS "http://127.0.0.1:8080$2"; }
post_logs() { # container count tag
    body=$(python3 - "$2" "$3" <<'PY'
import json, sys
n, tag = int(sys.argv[1]), sys.argv[2]
print(json.dumps({"logs": [{"sessionId": f"{tag}-{i % 3}", "eventType": "spot_view", "spotCode": f"R71-{i % 40 + 1}"} for i in range(n)]}))
PY
)
    docker exec "$1" curl -fsS -o /dev/null -X POST -H 'Content-Type: application/json' -d "$body" http://127.0.0.1:8080/api/logs/batch
}
api_run "$API" "$SRC_NET" public_connection || fail 'public-api did not become healthy on the source'
post_logs "$API" 30 src; post_logs "$API" 20 src2; sleep 3
src_count=$(src_psql -At -c 'SELECT count(*) FROM visit_logs')
[ "$src_count" = 50 ] || fail "source visit_logs=$src_count (expected 50)"
src_public=$(api_get "$API" /api/spots/public | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d if isinstance(d, list) else d.get("items", d.get("spots", []))))')
printf 'Host=db;Port=5432;Database=nexus;Username=nexus;Password=%s' "$(cat "$OUT/secrets/source_password")" > "$OUT/secrets/source_audit_connection"
chmod 644 "$OUT/secrets/source_audit_connection"
# audit-verify prints PASS, or FAILED with the first broken row. The restore must reproduce the
# source result exactly; STRICT_AUDIT=1 additionally requires PASS (see docs/backup-restore.md §6).
# Matching a FAILED message alone says nothing about later rows: the audit_rows lines of
# restore-fingerprint.sql (step 5) compare every row in full.
src_audit=$(audit_verify "$SRC_NET" source_audit_connection audit_key 2>&1 | grep -E '^(PASS|FAILED)' || true)
log "source audit-verify: $src_audit"
case "$src_audit" in PASS*) ;; *) [ "${STRICT_AUDIT:-0}" = 1 ] && fail 'audit chain on source' ;; esac
ok "source data: visit_logs=$src_count via public-api, public spots via API=$src_public"

# 3. Backup, same commands as NexusInfra scripts/backup-pg17-source.sh (run here without root/host checks).
t=$(date +%s)
d="$OUT/backup/pg17-$stamp"; mkdir -m 700 "$d"
docker exec --user postgres "$SRC_DB" pg_dumpall -U nexus --globals-only --no-role-passwords > "$d/globals.sql"
docker exec --user postgres "$SRC_DB" pg_dumpall -U nexus --no-role-passwords > "$d/cluster.sql"
docker exec --user postgres "$SRC_DB" pg_dump -U nexus -d nexus --format=custom --no-owner --no-acl > "$d/nexus.dump"
docker exec -i --user postgres "$SRC_DB" pg_restore -l < "$d/nexus.dump" > /dev/null
(cd "$d" && shasum -a 256 globals.sql cluster.sql nexus.dump > SHA256SUMS)
src_psql -At -f - < "$ROOT/deploy/database/restore-fingerprint.sql" > "$OUT/fingerprint-source.txt"
ok "backup + source fingerprint in $(secs "$t")s, nexus.dump $(wc -c < "$d/nexus.dump") bytes"

# 4. Off-VPS copy (here: another local directory) and checksum.
cp -R "$d" "$OUT/mac-copy/"; copy="$OUT/mac-copy/$(basename "$d")"
(cd "$copy" && shasum -a 256 -c SHA256SUMS) >> "$LOG" || fail 'copy checksum'
ok 'copy SHA256SUMS'
# The source is now stopped: everything below uses only the copy and the separately kept secrets.
docker rm -f "$API" >/dev/null; docker stop "$SRC_DB" >/dev/null

# 5. Restore into a NEW empty volume with NexusInfra compose.pg17-restore.yml.
t=$(date +%s)
docker volume create "$RESTORE_VOL" >/dev/null
[ "$(docker run --rm -v "$RESTORE_VOL:/v" "$PG17_IMAGE" sh -c 'ls -A /v | wc -l')" = 0 ] || fail 'restore volume not empty'
RESTORE_ENV python3 "$OUT/infra/preflight-rehearsal.py" pg17 >> "$LOG" 2>&1 || fail 'NexusInfra preflight-rehearsal.py pg17'
RC() { RESTORE_ENV $COMPOSE -p "$RESTORE_PROJECT" -f "$OUT/infra/compose.pg17-restore.yml" "$@"; }
RC config --quiet
RC up -d --wait >/dev/null 2>&1
rst_psql() { RC exec -T postgres psql -X -q -v ON_ERROR_STOP=1 -U postgres "$@"; }
RC exec -T postgres postgres --version | tee -a "$LOG" | grep -q 'PostgreSQL) 17\.' || fail 'restore target is not PG17'

# 5a. As NexusInfra transition doc Phase 1 writes it today (no roles first) -> expected to fail
#     once the baseline exists, because the RLS policies name nexus_public / nexus_admin_app.
rst_psql -d postgres -c 'CREATE DATABASE as_written' >/dev/null
if RC exec -T postgres pg_restore -U postgres -d as_written --no-owner --no-acl --exit-on-error < "$copy/nexus.dump" >> "$LOG" 2>&1; then
    log 'NOTE: restore without roles succeeded'
    as_written=succeeded
else
    as_written=failed
    ok 'restore without roles first fails (as predicted; see docs/backup-restore.md §3)'
fi
rst_psql -d postgres -c 'DROP DATABASE as_written' >/dev/null

# 5b. Procedure of docs/backup-restore.md: roles first, restore as nexus_owner, then grants.
docker exec -i -e NEXUS_PUBLIC_PASSWORD="$(cat "$OUT/secrets/restored_public_password")" "${RESTORE_PROJECT}-postgres-1" \
    psql -X -q -v ON_ERROR_STOP=1 -U postgres -d nexus < "$OUT/infra/01-roles.sql"
RC exec -T postgres pg_restore -U postgres -d nexus --no-owner --no-acl --role=nexus_owner --exit-on-error < "$copy/nexus.dump"
{ printf 'SET ROLE nexus_owner;\n'; cat "$ROOT/deploy/database/grant-runtime.sql"; } | rst_psql -d nexus
restore_secs=$(secs "$t")
rst_psql -d nexus -At -f - < "$ROOT/deploy/database/restore-fingerprint.sql" > "$OUT/fingerprint-restored.txt"
if diff -u "$OUT/fingerprint-source.txt" "$OUT/fingerprint-restored.txt" > "$OUT/fingerprint.diff"; then
    ok "fingerprint identical ($(wc -l < "$OUT/fingerprint-source.txt") lines), restore took ${restore_secs}s"
else
    cat "$OUT/fingerprint.diff" >> "$LOG"; fail 'fingerprint differs'
fi
grep -q '^audit_rows|' "$OUT/fingerprint-source.txt" || fail 'fingerprint has no audit_rows line'

# 5c. The audit_rows digest covers the rows that audit-verify does not reach (it stops at the first
#     broken link). Change only session_id of the newest row in a throw-away copy of the restore:
#     audit_chain (count + last hash) stays the same, audit_rows must differ.
rst_psql -d postgres -c 'CREATE DATABASE tamper_check TEMPLATE nexus' >/dev/null
rst_psql -d tamper_check -c "UPDATE visit_logs SET session_id = session_id || '-x' WHERE id = (SELECT id FROM visit_logs ORDER BY created_at DESC, id DESC LIMIT 1)" >/dev/null
rst_psql -d tamper_check -At -f - < "$ROOT/deploy/database/restore-fingerprint.sql" > "$OUT/fingerprint-tamper.txt"
rst_psql -d postgres -c 'DROP DATABASE tamper_check' >/dev/null
[ "$(grep '^audit_chain|' "$OUT/fingerprint-tamper.txt")" = "$(grep '^audit_chain|' "$OUT/fingerprint-restored.txt")" ] \
    || fail 'tamper check: audit_chain changed (the check is not testing what it should)'
[ "$(grep '^audit_rows|' "$OUT/fingerprint-tamper.txt")" != "$(grep '^audit_rows|' "$OUT/fingerprint-restored.txt")" ] \
    || fail 'tamper check: audit_rows did not detect a changed session_id'
ok 'audit_rows detects a changed session_id in the newest row (audit_chain alone does not)'

# 6. Audit chain on the restored copy: right key passes, wrong key fails.
rst_audit=$(audit_verify "$RESTORE_NET" restored_audit_connection audit_key 2>&1 | grep -E '^(PASS|FAILED)' || true)
[ "$rst_audit" = "$src_audit" ] || fail "audit-verify differs: source '$src_audit' restore '$rst_audit'"
wrong=$(audit_verify "$RESTORE_NET" restored_audit_connection wrong_audit_key 2>&1 | grep -E '^(PASS|FAILED)' || true)
case "$wrong" in FAILED*) ;; *) fail "another audit key gave '$wrong'" ;; esac
ok "audit-verify on restore identical to source ('$rst_audit'); another key fails"

# 7. public-api on the restored DB: readiness, same public rows, the chain continues.
api_run "$API-restored" "$RESTORE_NET" restored_public_connection || fail 'public-api did not start on the restore'
rst_public=$(api_get "$API-restored" /api/spots/public | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d if isinstance(d, list) else d.get("items", d.get("spots", []))))')
[ "$rst_public" = "$src_public" ] || fail "public spots $rst_public != $src_public"
post_logs "$API-restored" 5 after; sleep 3
rst_count=$(rst_psql -d nexus -At -c 'SELECT count(*) FROM visit_logs')
[ "$rst_count" = $((src_count + 5)) ] || fail "restored visit_logs=$rst_count after 5 new logs"
linked=$(rst_psql -d nexus -At -c "SELECT count(*) FROM visit_logs n WHERE n.session_id LIKE 'after-%' AND n.prev_hash IN (SELECT hash FROM visit_logs)")
[ "$linked" = 5 ] || fail "new logs linked to existing hashes: $linked/5"
ok "public-api healthy on restore (readiness passed), public spots=$rst_public, 5 new logs appended and linked to the restored chain"

# 8. Original source volume untouched by the restore.
[ "$(docker inspect -f '{{range .Mounts}}{{.Name}}{{end}}' "$SRC_DB")" = "$SRC_VOL" ] || fail 'source mount changed'
ok "source volume $SRC_VOL still attached to the stopped source only"
log "RESULT: all checks passed (restore without roles first: $as_written)"
