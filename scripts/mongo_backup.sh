#!/usr/bin/env bash
# Daily production backup: dump all databases, keep 7 days locally, upload an
# encrypted copy to Google Drive (rclone remote gdrive-crypt), verify it and
# keep 30 days there. Run from root's crontab on the database host; see
# README.md -> Automated Backups.
#
# No credentials here: mongodump runs inside the container with the root
# credentials the container already has (MONGO_INITDB_ROOT_*).

set -Eeuo pipefail

# === CONFIG ===
CONTAINER_NAME="mongodb"
BACKUP_DIR="/root/backups/mongodb"
LOG_DIR="/var/log/mongo-backup"
RETENTION_DAYS=7
REMOTE="gdrive-crypt:mongodb"
REMOTE_RETENTION_DAYS=30

# === RUNTIME ===
DATE="$(date +%F_%H-%M-%S)"
HOSTNAME_SHORT="$(hostname -s)"
BACKUP_FILE="${BACKUP_DIR}/mongo_${HOSTNAME_SHORT}_${DATE}.archive.gz"
LOG_FILE="${LOG_DIR}/backup_${DATE}.log"
LATEST_LINK="${BACKUP_DIR}/latest.archive.gz"

mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "${LOG_FILE}"
}

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "ERROR: backup failed with exit code ${exit_code}"
  fi
}
trap cleanup EXIT

log "=== Mongo backup started ==="

for cmd in docker rclone; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log "ERROR: ${cmd} command not found"
    exit 1
  fi
done

if ! docker ps --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  log "ERROR: container '${CONTAINER_NAME}' is not running"
  exit 1
fi

TMP_FILE="${BACKUP_FILE}.tmp"

log "Creating dump from container '${CONTAINER_NAME}'..."
if docker exec "${CONTAINER_NAME}" sh -c 'mongodump \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --archive \
  --gzip' > "${TMP_FILE}"; then
  mv "${TMP_FILE}" "${BACKUP_FILE}"
  ln -sfn "${BACKUP_FILE}" "${LATEST_LINK}"
  log "Backup created: ${BACKUP_FILE}"
else
  rm -f "${TMP_FILE}"
  log "ERROR: mongodump failed"
  exit 1
fi

log "Checking backup file size..."
if [[ ! -s "${BACKUP_FILE}" ]]; then
  log "ERROR: backup file is empty"
  exit 1
fi
log "Backup size: $(du -h "${BACKUP_FILE}" | awk '{print $1}')"

# === OFF-HOST COPY (Google Drive, encrypted by rclone crypt) ===
log "Uploading to ${REMOTE}..."
rclone copy "${BACKUP_FILE}" "${REMOTE}" --log-level ERROR

log "Verifying uploaded copy..."
rclone cryptcheck "${BACKUP_DIR}" "${REMOTE}" --one-way \
  --include "$(basename "${BACKUP_FILE}")" --log-level ERROR

log "Removing remote backups older than ${REMOTE_RETENTION_DAYS} days..."
rclone delete "${REMOTE}" --min-age "${REMOTE_RETENTION_DAYS}d" --log-level ERROR

log "Removing backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -type f -name "*.archive.gz" -mtime +"${RETENTION_DAYS}" -delete

log "=== Mongo backup finished successfully ==="
