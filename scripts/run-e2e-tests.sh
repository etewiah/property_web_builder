#!/bin/bash
#
# E2E Test Runner for PropertyWebBuilder
#
# This script sets up the e2e environment and runs Playwright tests.
# It handles database setup, server startup, and test execution.
#
# Usage:
#   ./scripts/run-e2e-tests.sh [playwright-args]
#
# Examples:
#   ./scripts/run-e2e-tests.sh                    # Run all tests
#   ./scripts/run-e2e-tests.sh --ui               # Run with Playwright UI
#   ./scripts/run-e2e-tests.sh tests/e2e/public/  # Run specific tests
#   ./scripts/run-e2e-tests.sh --headed           # Run with browser visible
#
# Options:
#   --reset       Force reset the e2e database before running tests
#   --no-server   Don't start the server (assume it's already running)
#   --bypass-auth Start server with admin auth bypass enabled
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
E2E_PORT=3001
E2E_HOST="tenant-a.e2e.localhost"
E2E_URL="http://${E2E_HOST}:${E2E_PORT}"
SERVER_PID_FILE="/tmp/pwb-e2e-server.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse our custom arguments
FORCE_RESET=false
NO_SERVER=false
BYPASS_AUTH=false
PLAYWRIGHT_ARGS=()

for arg in "$@"; do
  case $arg in
    --reset)
      FORCE_RESET=true
      ;;
    --no-server)
      NO_SERVER=true
      ;;
    --bypass-auth)
      BYPASS_AUTH=true
      ;;
    *)
      PLAYWRIGHT_ARGS+=("$arg")
      ;;
  esac
done

cd "$PROJECT_ROOT"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}PropertyWebBuilder E2E Test Runner${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to check if server is running (returns "up" or "down")
check_server() {
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$E2E_URL" 2>/dev/null)
  if [ $? -eq 0 ] && [ "$status" != "000" ] && [ -n "$status" ]; then
    echo "up"
  else
    echo "down"
  fi
}

# Function to wait for server to be ready
wait_for_server() {
  echo -e "${YELLOW}Waiting for server to be ready...${NC}"
  local max_attempts=60
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    local status=$(check_server)
    if [ "$status" = "up" ]; then
      echo -e "${GREEN}Server is ready!${NC}"
      return 0
    fi
    echo -n "."
    sleep 1
    attempt=$((attempt + 1))
  done

  echo ""
  echo -e "${RED}Server failed to start within ${max_attempts} seconds${NC}"
  return 1
}

# Function to stop server
stop_server() {
  if [ -f "$SERVER_PID_FILE" ]; then
    local pid=$(cat "$SERVER_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "${YELLOW}Stopping e2e server (PID: $pid)...${NC}"
      kill "$pid" 2>/dev/null || true
      sleep 2
      # Force kill if still running
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$SERVER_PID_FILE"
  fi
}

# Function to start server
start_server() {
  echo -e "${YELLOW}Starting e2e server on port ${E2E_PORT}...${NC}"

  # Stop any existing server
  stop_server

  # Also kill any process on the port
  lsof -ti:${E2E_PORT} | xargs kill -9 2>/dev/null || true

  # Start the server in background
  if [ "$BYPASS_AUTH" = true ]; then
    echo -e "${YELLOW}Starting with BYPASS_ADMIN_AUTH=true${NC}"
    RAILS_ENV=e2e BYPASS_ADMIN_AUTH=true bundle exec rails server -p ${E2E_PORT} -d -P "$SERVER_PID_FILE" 2>/dev/null
  else
    RAILS_ENV=e2e bundle exec rails server -p ${E2E_PORT} -d -P "$SERVER_PID_FILE" 2>/dev/null
  fi

  # Wait a moment for the PID file to be created
  sleep 2

  if [ -f "$SERVER_PID_FILE" ]; then
    echo -e "${GREEN}Server started (PID: $(cat $SERVER_PID_FILE))${NC}"
  fi
}

# Function to check e2e database
check_database() {
  echo -e "${YELLOW}Checking e2e database...${NC}"

  local result=$(RAILS_ENV=e2e bundle exec rails runner "puts Pwb::Website.where(subdomain: 'tenant-a').exists?" 2>/dev/null || echo "error")

  if [ "$result" = "true" ]; then
    echo -e "${GREEN}E2E database is ready${NC}"
    return 0
  else
    echo -e "${YELLOW}E2E database needs setup${NC}"
    return 1
  fi
}

# Function to setup database
setup_database() {
  echo -e "${YELLOW}Setting up e2e database...${NC}"
  echo -e "${YELLOW}Running: RAILS_ENV=e2e bin/rails playwright:reset${NC}"

  RAILS_ENV=e2e bundle exec rails playwright:reset

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database setup complete${NC}"
  else
    echo -e "${RED}Database setup failed${NC}"
    exit 1
  fi
}

# Cleanup function
cleanup() {
  echo ""
  echo -e "${YELLOW}Cleaning up...${NC}"
  stop_server
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Main execution
echo -e "${BLUE}Step 1: Database Setup${NC}"
echo "------------------------"

if [ "$FORCE_RESET" = true ]; then
  echo -e "${YELLOW}Force reset requested${NC}"
  setup_database
elif ! check_database; then
  setup_database
fi

echo ""
echo -e "${BLUE}Step 2: Server Setup${NC}"
echo "------------------------"

if [ "$NO_SERVER" = true ]; then
  echo -e "${YELLOW}Skipping server start (--no-server)${NC}"
  echo -e "${YELLOW}Assuming server is already running at ${E2E_URL}${NC}"

  # Verify server is running
  if [ "$(check_server)" = "down" ]; then
    echo -e "${RED}Error: Server is not running at ${E2E_URL}${NC}"
    echo -e "${YELLOW}Start the server manually:${NC}"
    echo "  RAILS_ENV=e2e bin/rails playwright:server"
    exit 1
  fi
else
  # Check if server is already running
  if [ "$(check_server)" = "up" ]; then
    echo -e "${YELLOW}Server already running at ${E2E_URL}${NC}"
  else
    start_server
    wait_for_server || exit 1
  fi
fi

echo ""
echo -e "${BLUE}Step 3: Running Playwright Tests${NC}"
echo "------------------------"

echo -e "${YELLOW}Running: npx playwright test ${PLAYWRIGHT_ARGS[*]}${NC}"
echo ""

# Run playwright tests
npx playwright test "${PLAYWRIGHT_ARGS[@]}"
TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}======================================${NC}"
  echo -e "${GREEN}All tests passed!${NC}"
  echo -e "${GREEN}======================================${NC}"
else
  echo -e "${RED}======================================${NC}"
  echo -e "${RED}Some tests failed (exit code: $TEST_EXIT_CODE)${NC}"
  echo -e "${RED}======================================${NC}"
  echo ""
  echo -e "${YELLOW}View the report: npx playwright show-report${NC}"
fi

exit $TEST_EXIT_CODE
