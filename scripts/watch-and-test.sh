#!/bin/bash
#
# Background test watcher - monitors git commits and runs tests
#
# Usage:
#   ./scripts/watch-and-test.sh              # Run in foreground
#   ./scripts/watch-and-test.sh &            # Run in background
#   nohup ./scripts/watch-and-test.sh &      # Run and persist after terminal close
#
# Stop with: pkill -f watch-and-test.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

NTFY_TOPIC="${NTFY_TOPIC:-}"  # Set to your ntfy.sh topic for push notifications
LAST_COMMIT=""

notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"

    echo "[$title] $message"

    # Desktop notification (macOS)
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\""
    fi

    # NTFY push notification
    if [ -n "$NTFY_TOPIC" ]; then
        curl -s -d "$message" -H "Title: $title" -H "Priority: $priority" \
            "https://ntfy.sh/$NTFY_TOPIC" > /dev/null
    fi
}

run_tests() {
    local commit="$1"
    local commit_msg=$(git log -1 --format="%s" "$commit" 2>/dev/null)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Testing commit: $commit"
    echo "   Message: $commit_msg"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Run RSpec tests
    echo "Running RSpec tests..."
    if bundle exec rspec --fail-fast 2>&1 | tail -20; then
        notify "✅ Tests Passed" "$commit_msg"
    else
        notify "❌ Tests Failed" "$commit_msg" "high"
    fi
}

echo "👀 Watching for new commits..."
echo "   Press Ctrl+C to stop"
echo ""

while true; do
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)

    if [ "$CURRENT_COMMIT" != "$LAST_COMMIT" ] && [ -n "$LAST_COMMIT" ]; then
        run_tests "$CURRENT_COMMIT"
    fi

    LAST_COMMIT="$CURRENT_COMMIT"
    sleep 5
done
