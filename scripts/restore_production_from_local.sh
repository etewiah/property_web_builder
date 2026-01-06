#!/usr/bin/env bash
set -euo pipefail

# Uploads a local db_imports/*.dump file to a Dokku host and restores it into the
# specified Dokku Postgres service (production).
#
# Required environment variables:
#   PRODUCTION_SSH_HOST     - e.g. root@example.com
#   DOKKU_POSTGRES_SERVICE  - Dokku Postgres service name to restore (e.g., pwb-database)
#   LOCAL_DUMP_FILE         - Path to local dump file (default: latest in db_imports/)
#
# Optional environment variables:
#   SSH_COMMAND             - command used for ssh/scp (default: ssh)
#   RSYNC_RSH               - overrides ssh command just for rsync/scp (default: SSH_COMMAND)
#   REMOTE_DUMP_PATH        - path on remote server (default: /tmp/<service>.restore.dump)
#   BACKUP_DIR              - directory containing dumps (default: db_imports)
#
# Usage:
#   ./scripts/restore_production_from_local.sh
#   LOCAL_DUMP_FILE=db_imports/20260106-120000-pwb-2025-db.dump ./scripts/restore_production_from_local.sh
#
# WARNING: This will overwrite the Dokku Postgres database.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${PRODUCTION_SSH_HOST:?Set PRODUCTION_SSH_HOST (e.g. root@example.com)}"
: "${DOKKU_POSTGRES_SERVICE:?Set DOKKU_POSTGRES_SERVICE (dokku postgres service name)}"

SSH_COMMAND="${SSH_COMMAND:-ssh}"
RSYNC_RSH="${RSYNC_RSH:-$SSH_COMMAND}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/db_imports}"
REMOTE_DUMP_PATH="${REMOTE_DUMP_PATH:-/tmp/${DOKKU_POSTGRES_SERVICE}.restore.dump}"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

if [[ ! -d "$BACKUP_DIR" ]]; then
  log "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

LOCAL_DUMP_FILE="${LOCAL_DUMP_FILE:-}"
if [[ -z "$LOCAL_DUMP_FILE" ]]; then
  LOCAL_DUMP_FILE="$(ls -1t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$LOCAL_DUMP_FILE" || ! -f "$LOCAL_DUMP_FILE" ]]; then
  log "No dump file found. Set LOCAL_DUMP_FILE or add dumps to $BACKUP_DIR"
  exit 1
fi

echo "⚠️  WARNING: This will overwrite the production database on $PRODUCTION_SSH_HOST"
echo "    Service : $DOKKU_POSTGRES_SERVICE"
echo "    Dump    : $LOCAL_DUMP_FILE"
echo "    Remote  : $REMOTE_DUMP_PATH"
read -p "Type RESTORE to continue: " -r CONFIRM_ONE
if [[ "$CONFIRM_ONE" != "RESTORE" ]]; then
  log "Confirmation failed. Aborting."
  exit 1
fi

read -p "This is destructive. Type the service name ($DOKKU_POSTGRES_SERVICE) to confirm: " -r CONFIRM_TWO
if [[ "$CONFIRM_TWO" != "$DOKKU_POSTGRES_SERVICE" ]]; then
  log "Service confirmation mismatch. Aborting."
  exit 1
fi

read -p "Proceed with uploading and restoring? (yes/no): " -r CONFIRM_THREE
if [[ "$CONFIRM_THREE" != "yes" ]]; then
  log "User cancelled operation."
  exit 1
fi

log "Uploading $LOCAL_DUMP_FILE to $PRODUCTION_SSH_HOST:$REMOTE_DUMP_PATH"
RSYNC_CMD=(rsync -az)
if [[ -n "${RSYNC_RSH:-}" ]]; then
  RSYNC_CMD+=("-e" "$RSYNC_RSH")
fi
"${RSYNC_CMD[@]}" "$LOCAL_DUMP_FILE" "$PRODUCTION_SSH_HOST:$REMOTE_DUMP_PATH"

log "Restoring dump into dokku postgres service: $DOKKU_POSTGRES_SERVICE"
$SSH_COMMAND "$PRODUCTION_SSH_HOST" "dokku postgres:import $DOKKU_POSTGRES_SERVICE < $REMOTE_DUMP_PATH"

log "Cleaning up remote dump"
$SSH_COMMAND "$PRODUCTION_SSH_HOST" "rm -f $REMOTE_DUMP_PATH"

log "Production database restore complete"
