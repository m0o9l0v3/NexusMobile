#!/usr/bin/env bash
set -euo pipefail
# Set these non-secret settings explicitly or source a protected server settings file first.
for key in NEXUS_POSTGRES_IMAGE NEXUS_ADMIN_IMAGE NEXUS_PUBLIC_IMAGE; do
  value=${!key:-}
  [[ "$value" =~ @sha256:[0-9a-f]{64}$ ]] || { echo "$key must specify an immutable registry digest" >&2; exit 1; }
done
: "${NEXUS_SECRET_DIR:?Set the private secrets directory}"
: "${NEXUS_DB_VOLUME:?Set the external production volume name}"
: "${NEXUS_BACKUP_VOLUME:?Set the local backup volume name}"
[[ "$NEXUS_DB_VOLUME" != "$NEXUS_BACKUP_VOLUME" ]] || { echo 'Database and backup volumes must differ' >&2; exit 1; }
directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec docker compose --project-name nexus-production --file "$directory/compose.production.yml" "$@"
