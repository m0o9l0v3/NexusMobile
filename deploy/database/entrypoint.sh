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
  [[ ${NEXUS_BACKUP_REPO_TYPE:-posix} == posix ]] || { echo 'Only local encrypted backups are configured' >&2; exit 1; }
  mkdir -p /backup
  chown postgres:postgres /backup
  printf 'repo1-type=posix\nrepo1-path=/backup\n'
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
