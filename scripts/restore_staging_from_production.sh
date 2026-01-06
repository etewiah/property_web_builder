#!/usr/bin/env bash
set -euo pipefail

# Copies the production database (via Dokku) into the local staging database
# and then boots the Rails server on port 4444.
#
# Required environment variables:
#   PRODUCTION_SSH_HOST     - e.g. root@example.com
#   DOKKU_POSTGRES_SERVICE  - Dokku Postgres service name to export
#
# Optional environment variables:
#   SSH_COMMAND             - command used for ssh/rsync (default: ssh)
#   RSYNC_RSH               - overrides ssh command just for rsync (default: SSH_COMMAND)
#   REMOTE_DUMP_PATH        - remote path for the dump (default: /tmp/<service>.dump)
#   BACKUP_DIR              - local directory for timestamped dumps (default: db_imports)
#   LOCAL_STAGING_DB        - local database name (default: pwb_staging)
#   LOCAL_DB_HOST           - local database host (default: localhost)
#   LOCAL_DB_PORT           - local database port (default: 5432)
#   LOCAL_DB_USER           - database user (default: current user / libpq default)
#   LOCAL_DB_SUPERUSER      - superuser for role creation (default: current user)
#   LOCAL_DB_SUPERUSER_DB   - database to connect to when ensuring roles (default: postgres)
#   STAGING_SECRET_KEY_BASE - secret key base for staging Rails server (optional)
#   RAILS_PORT              - port for Rails server (default: 4444)
#
# Usage:
#   ./scripts/restore_staging_from_production.sh            # import + run server
#   ./scripts/restore_staging_from_production.sh --import-only
#   ./scripts/restore_staging_from_production.sh --server-only
#   ./scripts/restore_staging_from_production.sh --skip-import --skip-server
#
# Flags:
#   --import-only   Only refresh the database, do not start the server
#   --server-only   Only start the server using the existing database
#   --skip-import   Skip the import step (same as --server-only)
#   --skip-server   Skip starting the server (same as --import-only)
#   -h|--help       Show this help and exit

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${PRODUCTION_SSH_HOST:?Set PRODUCTION_SSH_HOST (e.g. root@example.com)}"
: "${DOKKU_POSTGRES_SERVICE:?Set DOKKU_POSTGRES_SERVICE (dokku postgres:export service name)}"

SSH_COMMAND="${SSH_COMMAND:-ssh}"
RSYNC_RSH="${RSYNC_RSH:-$SSH_COMMAND}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/db_imports}"
if [[ "$BACKUP_DIR" != /* ]]; then
  BACKUP_DIR="$ROOT_DIR/${BACKUP_DIR#./}"
fi
LOCAL_DB_NAME="${LOCAL_STAGING_DB:-pwb_staging}"
LOCAL_DB_HOST="${LOCAL_DB_HOST:-localhost}"
LOCAL_DB_PORT="${LOCAL_DB_PORT:-5432}"
LOCAL_DB_USER="${LOCAL_DB_USER:-}"
LOCAL_DB_SUPERUSER="${LOCAL_DB_SUPERUSER:-}"
LOCAL_DB_SUPERUSER_DB="${LOCAL_DB_SUPERUSER_DB:-postgres}"
RAILS_PORT="${RAILS_PORT:-4444}"

ACTION_IMPORT=true
ACTION_SERVER=true

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Usage: restore_staging_from_production.sh [options]

Options:
  --import-only    Run database import only (skip server)
  --server-only    Run server only (skip import)
  --skip-import    Alias for --server-only
  --skip-server    Alias for --import-only
  -h, --help       Show this help and exit
EOF
}

ensure_role_exists() {
  local role="$1"
  [[ -z "$role" ]] && return
  log "Ensuring role $role exists"
  local psql_cmd=(psql --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" --tuples-only --quiet --no-align --dbname "$LOCAL_DB_SUPERUSER_DB")
  if [[ -n "$LOCAL_DB_SUPERUSER" ]]; then
    psql_cmd+=(--username "$LOCAL_DB_SUPERUSER")
  fi
  "${psql_cmd[@]}" <<SQL || true
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${role}') THEN
    EXECUTE 'CREATE ROLE ${role} LOGIN';
  END IF;
END
\$\$;
SQL
}

ensure_database_exists() {
  local database="$1"
  [[ -z "$database" ]] && return
  log "Ensuring database $database exists"
  local psql_cmd=(psql --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" --tuples-only --quiet --no-align --dbname "$LOCAL_DB_SUPERUSER_DB")
  if [[ -n "$LOCAL_DB_SUPERUSER" ]]; then
    psql_cmd+=(--username "$LOCAL_DB_SUPERUSER")
  fi
  local exists
  exists=$("${psql_cmd[@]}" <<SQL || true
SELECT 1 FROM pg_database WHERE datname = '${database}' LIMIT 1;
SQL
)
  exists="$(echo "$exists" | tr -d '[:space:]')"
  if [[ "$exists" != "1" ]]; then
    log "Creating database $database"
    local createdb_cmd=(createdb --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" "$database")
    if [[ -n "$LOCAL_DB_SUPERUSER" ]]; then
      createdb_cmd+=(--username "$LOCAL_DB_SUPERUSER")
    fi
    if [[ -n "$LOCAL_DB_USER" ]]; then
      createdb_cmd+=(--owner "$LOCAL_DB_USER")
    fi
    "${createdb_cmd[@]}" || true
  fi
}

perform_import() {
  : "${PRODUCTION_SSH_HOST:?Set PRODUCTION_SSH_HOST (e.g. root@example.com)}"
  : "${DOKKU_POSTGRES_SERVICE:?Set DOKKU_POSTGRES_SERVICE (dokku postgres:export service name)}"

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local remote_dump_path
  remote_dump_path="${REMOTE_DUMP_PATH:-/tmp/${DOKKU_POSTGRES_SERVICE}.dump}"
  local local_dump_file
  local_dump_file="${BACKUP_DIR}/${timestamp}-${DOKKU_POSTGRES_SERVICE}.dump"

  log "Exporting $DOKKU_POSTGRES_SERVICE from $PRODUCTION_SSH_HOST"
  $SSH_COMMAND "$PRODUCTION_SSH_HOST" "dokku postgres:export $DOKKU_POSTGRES_SERVICE > $remote_dump_path"

  log "Downloading dump to $local_dump_file"
  RSYNC_CMD=(rsync -az)
  if [[ -n "${RSYNC_RSH:-}" ]]; then
    RSYNC_CMD+=("-e" "$RSYNC_RSH")
  fi
  "${RSYNC_CMD[@]}" "$PRODUCTION_SSH_HOST:$remote_dump_path" "$local_dump_file"

  log "Removing remote dump"
  $SSH_COMMAND "$PRODUCTION_SSH_HOST" "rm -f $remote_dump_path"

  ensure_role_exists "$LOCAL_DB_USER"
  ensure_database_exists "$LOCAL_DB_NAME"

  log "Restoring into local database $LOCAL_DB_NAME"
  PG_RESTORE_CMD=(pg_restore --clean --no-owner --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" --dbname "$LOCAL_DB_NAME")
  if [[ -n "$LOCAL_DB_USER" ]]; then
    PG_RESTORE_CMD+=(--username "$LOCAL_DB_USER")
  fi
  "${PG_RESTORE_CMD[@]}" "$local_dump_file"
}

start_server() {
  if [[ -z "${SECRET_KEY_BASE:-}" ]]; then
    if [[ -n "${STAGING_SECRET_KEY_BASE:-}" ]]; then
      export SECRET_KEY_BASE="$STAGING_SECRET_KEY_BASE"
    else
      log "Generating temporary secret_key_base for staging"
      export SECRET_KEY_BASE="$(bundle exec rails secret)"
    fi
  fi

  log "Starting Rails server on port $RAILS_PORT (Ctrl+C to stop)"
  RAILS_ENV=staging bundle exec rails server -p "$RAILS_PORT"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --import-only|--skip-server)
      ACTION_SERVER=false
      ;;
    --server-only|--skip-import)
      ACTION_IMPORT=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift

done

if [[ "$ACTION_IMPORT" != true && "$ACTION_SERVER" != true ]]; then
  log "Nothing to do (import and server both skipped)"
  exit 1
fi

if [[ "$ACTION_IMPORT" == true ]]; then
  perform_import
else
  log "Skipping database import"
fi

if [[ "$ACTION_SERVER" == true ]]; then
  start_server
else
  log "Skipping Rails server startup"
fi
