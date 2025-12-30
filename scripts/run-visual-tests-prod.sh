#!/bin/bash
#
# Production Visual Regression Test Runner
#
# Runs Playwright visual regression tests against the production site
# at https://demo.propertywebbuilder.com
#
# Usage:
#   ./scripts/run-visual-tests-prod.sh              # Run all visual tests
#   ./scripts/run-visual-tests-prod.sh --update     # Update snapshots
#   ./scripts/run-visual-tests-prod.sh --ui         # Run with Playwright UI
#   ./scripts/run-visual-tests-prod.sh --headed     # Run with visible browser
#
# Options:
#   --update        Update baseline snapshots
#   --ui            Open Playwright UI for debugging
#   --headed        Run tests with visible browser
#   --project=NAME  Run specific project (chromium, firefox, webkit, mobile-chrome, mobile-safari)
#   --grep=PATTERN  Filter tests by pattern
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Production Visual Regression Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Target: https://demo.propertywebbuilder.com"
echo "        https://brisbane.propertywebbuilder.com"
echo "        https://bologna.propertywebbuilder.com"
echo ""

# Parse arguments
PLAYWRIGHT_ARGS=()
UPDATE_SNAPSHOTS=false

for arg in "$@"; do
  case $arg in
    --update)
      UPDATE_SNAPSHOTS=true
      PLAYWRIGHT_ARGS+=("--update-snapshots")
      ;;
    *)
      PLAYWRIGHT_ARGS+=("$arg")
      ;;
  esac
done

if [ "$UPDATE_SNAPSHOTS" = true ]; then
  echo -e "${YELLOW}Mode: Updating baseline snapshots${NC}"
else
  echo -e "${YELLOW}Mode: Comparing against baseline snapshots${NC}"
fi
echo ""

# Run the tests
echo -e "${BLUE}Running tests...${NC}"
echo ""

npx playwright test \
  --config=playwright.production.config.js \
  "${PLAYWRIGHT_ARGS[@]}"

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}All visual tests passed!${NC}"
  echo -e "${GREEN}========================================${NC}"
else
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}Some visual tests failed!${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  echo -e "${YELLOW}View the report:${NC}"
  echo "  npx playwright show-report playwright-report-production"
  echo ""
  echo -e "${YELLOW}To update snapshots after intentional changes:${NC}"
  echo "  ./scripts/run-visual-tests-prod.sh --update"
fi

exit $TEST_EXIT_CODE
