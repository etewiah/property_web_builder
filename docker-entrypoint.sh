#!/bin/bash
# docker-entrypoint.sh - Production entrypoint for PropertyWebBuilder
# Handles database setup and graceful startup

set -e

# =============================================================================
# Database Connection Check
# =============================================================================
wait_for_database() {
    echo "Checking database connection..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" 2>/dev/null; then
            echo "Database connection established."
            return 0
        fi

        echo "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "ERROR: Could not connect to database after $max_attempts attempts"
    exit 1
}

# =============================================================================
# Database Migrations
# =============================================================================
run_migrations() {
    if [ "${SKIP_MIGRATIONS:-false}" = "true" ]; then
        echo "Skipping database migrations (SKIP_MIGRATIONS=true)"
        return 0
    fi

    echo "Running database migrations..."
    bundle exec rake db:migrate
    echo "Migrations completed successfully."
}

# =============================================================================
# Database Seeding (optional, for new deployments)
# =============================================================================
run_seeds() {
    if [ "${RUN_SEEDS:-false}" = "true" ]; then
        echo "Running database seeds..."
        bundle exec rake db:seed
        echo "Seeds completed successfully."
    fi
}

# =============================================================================
# Cleanup old PID files (from container restarts)
# =============================================================================
cleanup_pids() {
    if [ -f tmp/pids/server.pid ]; then
        echo "Removing stale PID file..."
        rm -f tmp/pids/server.pid
    fi

    if [ -f tmp/pids/puma.pid ]; then
        rm -f tmp/pids/puma.pid
    fi
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo "=== PropertyWebBuilder Container Starting ==="
    echo "RAILS_ENV: ${RAILS_ENV:-production}"
    echo "Ruby version: $(ruby -v)"

    # Only run setup tasks for web/worker processes, not for one-off commands
    case "$1" in
        bundle)
            case "$2" in
                exec)
                    case "$3" in
                        puma|bin/jobs)
                            # Web server or worker - run full setup
                            wait_for_database
                            run_migrations
                            run_seeds
                            cleanup_pids
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac

    echo "Executing: $@"
    exec "$@"
}

main "$@"
