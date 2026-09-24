#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || { echo 'Usage: nexus-backup-host full|diff|check|export|daily' >&2; exit 2; }
case "$1" in full|diff|check|export|daily) ;; *) exit 2 ;; esac
# Install this script and the settings file as root-owned files on the VPS.
set -a
source /etc/nexus/database.env
set +a
: "${NEXUS_REPO_DIR:?Set the deployed repository path}"
operation=$1
if [[ "$operation" == daily ]]; then
  operation=diff
  [[ $(TZ=Asia/Tokyo date +%u) != 7 ]] || operation=full
fi
exec bash "$NEXUS_REPO_DIR/deploy/database/compose-production.sh" \
  exec -T --user postgres postgres nexus-backup "$operation"
