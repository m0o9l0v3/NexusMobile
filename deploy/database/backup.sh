#!/usr/bin/env bash
set -euo pipefail
umask 077
[[ $# == 1 ]] || { echo 'Usage: nexus-backup full|diff|check|export' >&2; exit 2; }
case "$1" in full|diff|check|export) ;; *) echo 'Unknown backup operation' >&2; exit 2 ;; esac
[[ $(id -u) != 0 ]] || { echo 'Run as the postgres user' >&2; exit 1; }
# All scheduled/manual backups and exports use this entry point, serializing expiry too.
exec 9>/var/lib/pgbackrest/backup-cycle.lock
flock --exclusive 9
case "$1" in
  full|diff) pgbackrest --stanza=nexus --type="$1" backup ;;
  check) pgbackrest --stanza=nexus check ;;
  export)
    # Keep stdout strictly binary. Archive files and metadata remain encrypted.
    pgbackrest --stanza=nexus --type=full backup >&2
    exec 8>/var/lib/pgbackrest/repository-copy.lock
    flock --exclusive 8
    # Active archive-push has finished; later WAL remains in pg_wal until the copy ends.
    # Locks are released on success, failure, or broken SSH pipe.
    tar --directory=/backup --create --file=- archive backup
    ;;
esac
