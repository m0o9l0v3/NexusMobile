ARG POSTGRES_IMAGE=postgres:18.6-trixie@sha256:10037cee1d5ebfc057cd71b3365466cf27ce8d4bd0c4f409e426fcb2b3fb12e7
FROM ${POSTGRES_IMAGE}
ARG PGBACKREST_VERSION=2.59.1-1.pgdg13+1
RUN apt-get update && apt-get install -y --no-install-recommends pgbackrest=${PGBACKREST_VERSION} jq util-linux \
    && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /usr/local/bin/nexus-postgres
COPY init-roles.sh /docker-entrypoint-initdb.d/10-nexus-roles.sh
COPY backup.sh /usr/local/bin/nexus-backup
RUN chmod 755 /usr/local/bin/nexus-postgres /usr/local/bin/nexus-backup /docker-entrypoint-initdb.d/10-nexus-roles.sh
ENTRYPOINT ["nexus-postgres"]
CMD ["postgres", "-c", "archive_mode=on", "-c", "archive_command=flock --shared /var/lib/pgbackrest/repository-copy.lock pgbackrest --stanza=nexus archive-push %p", "-c", "archive_timeout=300", "-c", "timezone=UTC"]
