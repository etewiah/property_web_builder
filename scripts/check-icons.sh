#!/bin/bash
#
# Pre-commit hook to prevent forbidden icon class patterns
#
# Install:
#   cp scripts/check-icons.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or add to existing pre-commit hook:
#   scripts/check-icons.sh || exit 1
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking for forbidden icon patterns..."

# Get staged files
FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(erb|html|liquid|rb|yml|yaml)$' || true)

if [ -z "$FILES" ]; then
  echo -e "${GREEN}No relevant files staged.${NC}"
  exit 0
fi

ERRORS=0

# Patterns to check
declare -A PATTERNS
PATTERNS["Font Awesome (fa fa-*)"]="fa fa-"
PATTERNS["Font Awesome Solid (fas fa-*)"]="fas fa-"
PATTERNS["Font Awesome Brands (fab fa-*)"]="fab fa-"
PATTERNS["Phosphor Icons (ph ph-*)"]="ph ph-"
PATTERNS["Glyphicons"]="glyphicon-"

for pattern_name in "${!PATTERNS[@]}"; do
  pattern="${PATTERNS[$pattern_name]}"

  MATCHES=$(echo "$FILES" | xargs grep -l "$pattern" 2>/dev/null || true)

  if [ -n "$MATCHES" ]; then
    echo ""
    echo -e "${RED}ERROR: $pattern_name found in:${NC}"
    echo "$MATCHES" | while read -r file; do
      echo -e "  ${YELLOW}$file${NC}"
      grep -n "$pattern" "$file" | head -3 | while read -r line; do
        echo "    $line"
      done
    done
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}COMMIT BLOCKED: Forbidden icons found${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  echo "Use the icon(:name) helper instead of inline icon classes:"
  echo ""
  echo "  # Instead of:"
  echo "  <i class=\"fa fa-home\"></i>"
  echo ""
  echo "  # Use:"
  echo "  <%= icon(:home) %>"
  echo ""
  echo "  # For brand icons:"
  echo "  <%= brand_icon(:facebook) %>"
  echo ""
  echo "See: docs/architecture/MATERIAL_ICONS_MIGRATION_PLAN.md"
  echo ""
  exit 1
fi

echo -e "${GREEN}No forbidden icon patterns found.${NC}"
exit 0
