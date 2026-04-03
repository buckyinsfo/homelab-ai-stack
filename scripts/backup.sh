#!/usr/bin/env bash
set -euo pipefail

# Backup script for homelab-ai-stack
# Backs up Docker named volumes and /srv bind mounts to /srv/backups/
# Run as root: sudo bash scripts/backup.sh

BACKUP_ROOT="/srv/backups"
TIMESTAMP=$(date +%F-%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
RETAIN_COUNT=7

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

mkdir -p "${BACKUP_DIR}/volumes"
mkdir -p "${BACKUP_DIR}/srv"

echo "==> Backup started: ${TIMESTAMP}"
echo "    Destination: ${BACKUP_DIR}"
echo

# ---------------------------------------------------------------------------
# Docker named volumes
# Uses a temporary Alpine container to tar each volume.
# ---------------------------------------------------------------------------
backup_volume() {
  local volume="$1"
  local dest="${BACKUP_DIR}/volumes/${volume}.tgz"
  if docker volume inspect "${volume}" >/dev/null 2>&1; then
    echo "  [volume] ${volume}"
    docker run --rm \
      -v "${volume}:/v:ro" \
      alpine sh -c "tar czf - -C /v ." > "${dest}"
  else
    echo "  [volume] ${volume} — not found, skipping"
  fi
}

echo "==> Backing up Docker named volumes"
backup_volume "monitoring_grafana-data"
backup_volume "monitoring_prometheus-data"
backup_volume "redis_redis-data"
backup_volume "qdrant_qdrant-data"
backup_volume "qdrant_qdrant-snapshots"
backup_volume "openwebui_openwebui-data"
backup_volume "portainer_data"
backup_volume "gila_mongodb_data"
echo

# ---------------------------------------------------------------------------
# PostgreSQL — use pg_dumpall for a clean, restorable SQL dump.
# Reads the superuser from the running container so no hardcoded credentials.
# ---------------------------------------------------------------------------
echo "==> Backing up PostgreSQL (pg_dump)"
if docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
  PG_USER=$(docker exec postgres printenv POSTGRES_USER)
  docker exec postgres pg_dumpall -U "${PG_USER}" \
    > "${BACKUP_DIR}/volumes/postgres_dumpall.sql"
  echo "  [postgres] pg_dumpall complete (user: ${PG_USER})"
else
  echo "  [postgres] container not running, skipping"
fi
echo

# ---------------------------------------------------------------------------
# /srv bind mounts
# ---------------------------------------------------------------------------
echo "==> Backing up /srv bind mounts"
for path in openclaw sandbox hermes certs traefik nextcloud onlyoffice; do
  src="/srv/${path}"
  dest="${BACKUP_DIR}/srv/${path}.tgz"
  if [[ -d "${src}" ]]; then
    echo "  [srv] /srv/${path}"
    tar czf "${dest}" -C "/srv" "${path}"
  else
    echo "  [srv] /srv/${path} — not found, skipping"
  fi
done
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "==> Backup complete"
echo "    Location: ${BACKUP_DIR}"
echo "    Size:     $(du -sh "${BACKUP_DIR}" | cut -f1)"
echo

# ---------------------------------------------------------------------------
# Retention — keep the last RETAIN_COUNT backups, purge the rest
# Only matches timestamped dirs (format: YYYY-MM-DD-HHMMSS)
# ---------------------------------------------------------------------------
echo "==> Pruning old backups (keeping last ${RETAIN_COUNT})"
OLDER=$(find "${BACKUP_ROOT}" -maxdepth 1 -type d -name "????-??-??-*" | sort | head -n -"${RETAIN_COUNT}")
if [[ -n "${OLDER}" ]]; then
  echo "${OLDER}" | xargs rm -rf
  echo "  Removed: $(echo "${OLDER}" | wc -l | tr -d ' ') old backup(s)"
else
  echo "  Nothing to prune"
fi
echo

echo "To restore, see docs/BACKUP_RESTORE.md"
