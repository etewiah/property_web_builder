#!/usr/bin/env bash
set -euo pipefail

# Copies the production database(s) (via Dokku) into the local staging database(s)
# and then boots the Rails server on port 4444.
#
# This script supports multi-shard setups. It will import:
#   1. Primary database (required)
#   2. Demo shard database (optional, if DOKKU_DEMO_SHARD_SERVICE is set)
#   3. Tenant shard 1 database (optional, if DOKKU_TENANT_SHARD_1_SERVICE is set)
#
# Required environment variables:
#   PRODUCTION_SSH_HOST     - e.g. root@example.com
#   DOKKU_POSTGRES_SERVICE  - Dokku Postgres service name for primary database
#
# Optional environment variables (shards):
#   DOKKU_DEMO_SHARD_SERVICE      - Dokku Postgres service for demo shard
#   DOKKU_TENANT_SHARD_1_SERVICE  - Dokku Postgres service for tenant shard 1
#   LOCAL_DEMO_SHARD_DB           - local demo shard database (default: pwb_staging_demo_shard)
#   LOCAL_TENANT_SHARD_1_DB       - local tenant shard 1 database (default: pwb_staging_shard_1)
#
# Optional environment variables (general):
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
#   ./scripts/restore_staging_from_production.sh --primary-only  # skip shard imports
#
# Flags:
#   --import-only   Only refresh the database, do not start the server
#   --server-only   Only start the server using the existing database
#   --skip-import   Skip the import step (same as --server-only)
#   --skip-server   Skip starting the server (same as --import-only)
#   --primary-only  Only import primary database, skip shards
#   --shards-only   Only import shard databases, skip primary
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

# Primary database
LOCAL_DB_NAME="${LOCAL_STAGING_DB:-pwb_staging}"

# Shard databases
LOCAL_DEMO_SHARD_DB="${LOCAL_DEMO_SHARD_DB:-pwb_staging_demo_shard}"
LOCAL_TENANT_SHARD_1_DB="${LOCAL_TENANT_SHARD_1_DB:-pwb_staging_shard_1}"

LOCAL_DB_HOST="${LOCAL_DB_HOST:-localhost}"
LOCAL_DB_PORT="${LOCAL_DB_PORT:-5432}"
LOCAL_DB_USER="${LOCAL_DB_USER:-}"
LOCAL_DB_SUPERUSER="${LOCAL_DB_SUPERUSER:-}"
LOCAL_DB_SUPERUSER_DB="${LOCAL_DB_SUPERUSER_DB:-postgres}"
RAILS_PORT="${RAILS_PORT:-4444}"

ACTION_IMPORT=true
ACTION_SERVER=true
IMPORT_PRIMARY=true
IMPORT_SHARDS=true

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
  --primary-only   Only import primary database, skip shards
  --shards-only    Only import shard databases, skip primary
  -h, --help       Show this help and exit

Shard Environment Variables:
  DOKKU_DEMO_SHARD_SERVICE      Dokku service name for demo shard
  DOKKU_TENANT_SHARD_1_SERVICE  Dokku service name for tenant shard 1

Example with shards:
  DOKKU_DEMO_SHARD_SERVICE=pwb-demo-shard \
  DOKKU_TENANT_SHARD_1_SERVICE=pwb-shard-1 \
  ./scripts/restore_staging_from_production.sh
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

# Import a single database from Dokku
# Arguments: $1 = dokku service name, $2 = local database name, $3 = label (for logging)
import_database() {
  local dokku_service="$1"
  local local_db="$2"
  local label="${3:-$dokku_service}"

  log "=== Importing $label ==="

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local remote_dump_path="/tmp/${dokku_service}.dump"
  local local_dump_file="${BACKUP_DIR}/${timestamp}-${dokku_service}.dump"

  log "Exporting $dokku_service from $PRODUCTION_SSH_HOST"
  if ! $SSH_COMMAND "$PRODUCTION_SSH_HOST" "dokku postgres:export $dokku_service > $remote_dump_path" 2>/dev/null; then
    log "WARNING: Failed to export $dokku_service - service may not exist"
    return 1
  fi

  log "Downloading dump to $local_dump_file"
  RSYNC_CMD=(rsync -az)
  if [[ -n "${RSYNC_RSH:-}" ]]; then
    RSYNC_CMD+=("-e" "$RSYNC_RSH")
  fi
  "${RSYNC_CMD[@]}" "$PRODUCTION_SSH_HOST:$remote_dump_path" "$local_dump_file"

  log "Removing remote dump"
  $SSH_COMMAND "$PRODUCTION_SSH_HOST" "rm -f $remote_dump_path"

  ensure_role_exists "$LOCAL_DB_USER"
  ensure_database_exists "$local_db"

  log "Restoring into local database $local_db"
  PG_RESTORE_CMD=(pg_restore --clean --no-owner --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" --dbname "$local_db")
  if [[ -n "$LOCAL_DB_USER" ]]; then
    PG_RESTORE_CMD+=(--username "$LOCAL_DB_USER")
  fi
  # Use --if-exists to avoid errors on first restore when tables don't exist
  "${PG_RESTORE_CMD[@]}" --if-exists "$local_dump_file" || {
    log "WARNING: pg_restore had some errors (this is often normal for --clean on first run)"
  }

  log "Successfully imported $label into $local_db"
  return 0
}

perform_import() {
  local imported_primary=false
  local imported_shards=0

  # Import primary database
  if [[ "$IMPORT_PRIMARY" == true ]]; then
    if import_database "$DOKKU_POSTGRES_SERVICE" "$LOCAL_DB_NAME" "primary database"; then
      imported_primary=true
    fi
  else
    log "Skipping primary database import"
  fi

  # Import shard databases
  if [[ "$IMPORT_SHARDS" == true ]]; then
    # Demo shard
    if [[ -n "${DOKKU_DEMO_SHARD_SERVICE:-}" ]]; then
      if import_database "$DOKKU_DEMO_SHARD_SERVICE" "$LOCAL_DEMO_SHARD_DB" "demo shard"; then
        ((imported_shards++)) || true
      fi
    else
      log "Skipping demo shard (DOKKU_DEMO_SHARD_SERVICE not set)"
    fi

    # Tenant shard 1
    if [[ -n "${DOKKU_TENANT_SHARD_1_SERVICE:-}" ]]; then
      if import_database "$DOKKU_TENANT_SHARD_1_SERVICE" "$LOCAL_TENANT_SHARD_1_DB" "tenant shard 1"; then
        ((imported_shards++)) || true
      fi
    else
      log "Skipping tenant shard 1 (DOKKU_TENANT_SHARD_1_SERVICE not set)"
    fi
  else
    log "Skipping shard imports"
  fi

  log "=== Import Summary ==="
  log "Primary database: $([ "$imported_primary" == true ] && echo "imported" || echo "skipped")"
  log "Shards imported: $imported_shards"
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

  # Set up shard database URLs for staging environment
  # These match the database names used in config/database.yml for staging
  if [[ -n "${DOKKU_DEMO_SHARD_SERVICE:-}" ]] || [[ -f "$BACKUP_DIR"/*-"${DOKKU_DEMO_SHARD_SERVICE:-demo}"*.dump ]] 2>/dev/null; then
    export PWB_STAGING_DEMO_SHARD_DATABASE_URL="postgresql://${LOCAL_DB_USER:-}@${LOCAL_DB_HOST}:${LOCAL_DB_PORT}/${LOCAL_DEMO_SHARD_DB}"
    log "Demo shard URL: $PWB_STAGING_DEMO_SHARD_DATABASE_URL"
  fi

  if [[ -n "${DOKKU_TENANT_SHARD_1_SERVICE:-}" ]] || [[ -f "$BACKUP_DIR"/*-"${DOKKU_TENANT_SHARD_1_SERVICE:-shard}"*.dump ]] 2>/dev/null; then
    export PWB_STAGING_TENANT_SHARD_1_DATABASE_URL="postgresql://${LOCAL_DB_USER:-}@${LOCAL_DB_HOST}:${LOCAL_DB_PORT}/${LOCAL_TENANT_SHARD_1_DB}"
    log "Tenant shard 1 URL: $PWB_STAGING_TENANT_SHARD_1_DATABASE_URL"
  fi

  log "Starting Rails server on port $RAILS_PORT (Ctrl+C to stop)"
  log "Shard environment variables set for staging"
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
    --primary-only)
      IMPORT_SHARDS=false
      ;;
    --shards-only)
      IMPORT_PRIMARY=false
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
