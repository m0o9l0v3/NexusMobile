#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p /etc/pgbackrest /var/log/pgbackrest /var/lib/pgbackrest /var/run/postgresql "$PGDATA"
chmod 755 /etc/pgbackrest
chown postgres:postgres /var/log/pgbackrest /var/lib/pgbackrest /var/run/postgresql "$(dirname "$PGDATA")" "$PGDATA"
chmod 700 "$PGDATA"
secret() {
  local value
  value=$(cat "/run/secrets/$1")
  [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || { echo "Invalid secret: $1" >&2; exit 1; }
  printf '%s' "$value"
}
{
  printf '[global]\nrepo1-cipher-type=aes-256-cbc\nrepo1-cipher-pass=%s\n' "$(secret backup_cipher)"
  printf 'repo1-retention-full=5\nstart-fast=y\nlog-level-console=info\nlog-path=/var/log/pgbackrest\nspool-path=/var/lib/pgbackrest\n'
  if [[ ${NEXUS_BACKUP_REPO_TYPE:-s3} == posix ]]; then
    [[ ${NEXUS_DB_DISPOSABLE:-} == 1 ]] || { echo 'Local backup repository is verification-only' >&2; exit 1; }
    mkdir -p /backup
    chown postgres:postgres /backup
    printf 'repo1-type=posix\nrepo1-path=/backup\n'
  else
    : "${NEXUS_BACKUP_S3_BUCKET:?Set the backup bucket}"
    printf 'repo1-type=s3\nrepo1-path=/nexus\nrepo1-s3-region=ap-northeast-1\nrepo1-s3-endpoint=s3.ap-northeast-1.amazonaws.com\n'
    printf 'repo1-s3-bucket=%s\nrepo1-s3-key=%s\nrepo1-s3-key-secret=%s\n' "$NEXUS_BACKUP_S3_BUCKET" "$(secret backup_s3_key)" "$(secret backup_s3_secret)"
  fi
  printf '\n[nexus]\npg1-path=%s\npg1-port=5432\npg1-socket-path=/var/run/postgresql\n' "$PGDATA"
} > /etc/pgbackrest/pgbackrest.conf
chown postgres:postgres /etc/pgbackrest/pgbackrest.conf
if [[ ${1:-} == restore ]]; then
  shift
  [[ -z $(ls -A "$PGDATA") ]] || { echo 'Restore requires an empty, separate data volume' >&2; exit 1; }
  exec gosu postgres pgbackrest --stanza=nexus "$@" restore
fi
if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
  # Read bind-mounted secrets as root before the official entrypoint drops privileges.
  export NEXUS_ADMIN_PASSWORD NEXUS_PUBLIC_PASSWORD NEXUS_MIGRATOR_PASSWORD
  NEXUS_ADMIN_PASSWORD=$(secret admin_password)
  NEXUS_PUBLIC_PASSWORD=$(secret public_password)
  NEXUS_MIGRATOR_PASSWORD=$(secret migrator_password)
fi
exec docker-entrypoint.sh "$@"
