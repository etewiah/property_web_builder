# Page Parts Test Coverage - Quick Reference

## The Problem in 30 Seconds

**Error:** `"page_part with valid template not available"`

**Root Cause:** `rebuild_page_content()` checks only database field (`.template`), not the fallback chain

**Why Tests Failed:** `rebuild_page_content()` is never called in any test

## Files Affected

| File | Issue | Priority |
|------|-------|----------|
| `app/services/pwb/page_part_manager.rb:173` | Check only uses `.template`, should use `.template_content()` | P1 |
| `spec/services/pwb/page_part_manager_spec.rb` | Missing `rebuild_page_content()` tests | P2 |
| `spec/lib/pwb/seed_runner_spec.rb:13-14` | Mocks seeding instead of testing it | P3 |
| None | No YAML seed validator exists | P2 |

## The Fix (5 minutes)

**File:** `app/services/pwb/page_part_manager.rb` at line 173

**Change:**
```ruby
# From:
unless page_part && page_part.template
  raise "page_part with valid template not available"
end
l_template = Liquid::Template.parse(page_part.template)

# To:
template_content = page_part&.template_content
unless template_content.present?
  raise "page_part with valid template not available"
end
l_template = Liquid::Template.parse(template_content)
```

## Test Coverage by Component

| Component | Tested | Missing |
|-----------|--------|---------|
| `PagePart.template_content()` | ✓ 15 tests | - |
| `PagePartManager.find_or_create_content()` | ✓ 2 tests | - |
| `PagePartManager.seed_container_block_content()` | ✓ 2 tests | - |
| `PagePartManager.rebuild_page_content()` | ✗ 0 tests | **CRITICAL** |
| Theme-specific template loading | ✗ 0 tests | - |
| YAML seed validation | ✗ 0 tests | - |
| Real seeding end-to-end | ✗ Mocked | - |

## Why Tests Passed With Bug Present

1. **Factory creates templates:** All tests use factories with explicit `template:` field
2. **YAML has templates:** Seed files have `template:` field in database
3. **rebuild_page_content() untested:** No test ever calls this method directly
4. **SeedRunner mocked:** Real seeding never runs in tests (lines 13-14 stub it out)

## What Would Catch This

1. Test calling `rebuild_page_content()` with empty `.template` field ✗
2. Test running real seeding with theme missing template files ✗
3. YAML validator checking template presence ✗
4. Integration test verifying full seeding succeeds ✗

## Implementation Priorities

**Do First (1 hour):**
- Fix rebuild_page_content() logic

**Do Next (5 hours):**
- Add rebuild_page_content() tests
- Create YAML seed validator

**Do Soon (5 hours):**
- Add real seeding integration tests
- Add theme-specific template tests

**Total Time:** ~10 hours to prevent future issues

## Key Test Files

| File | Lines | Status |
|------|-------|--------|
| `spec/services/pwb/page_part_manager_spec.rb` | 74 | Incomplete |
| `spec/models/pwb/page_part_spec.rb` | 138 | Good but isolated |
| `spec/libraries/pwb/pages_seeder_spec.rb` | 76 | Real seeding but no validation |
| `spec/lib/pwb/seed_runner_spec.rb` | 282 | **Mocked - needs fix** |

## How Theme Seeding Works

```
1. New website created → theme_name = 'bristol'
2. ContentsSeeder.seed_page_content_translations!() runs
3. For each page_part:
   - Creates PagePartManager
   - Calls seed_container_block_content()
   - Which calls rebuild_page_content()
4. rebuild_page_content() checks: page_part.template
   - If nil → raises error
   - PagePart.template_content() exists but NOT USED
5. Error: "page_part with valid template not available"
```

## What Tests Should Verify

- [x] PagePart.template_content() with all fallback sources
- [ ] rebuild_page_content() successfully parses and renders
- [ ] rebuild_page_content() with missing database template
- [ ] rebuild_page_content() uses theme-specific file fallback
- [ ] YAML seed files have valid templates
- [ ] Real seeding completes without errors
- [ ] Each website gets its own theme templates
- [ ] Content seeding doesn't create empty content

## Quick Validation

```bash
# Test current code breaks with theme templates missing:
rails c < spec/support/test_missing_template.rb

# After fix, this should pass:
rspec spec/services/pwb/page_part_manager_spec.rb

# After adding tests, full suite should pass:
rspec spec/ --pattern "*page_part*"
```

## Historical Context

- **When introduced:** `rebuild_page_content()` added to PagePartManager
- **When broke:** Bristol theme added without template files
- **When caught:** During manual testing after deployment
- **Why not earlier:** Tests don't call `rebuild_page_content()` directly
- **Cost:** Several hours of debugging + deployment issue

## Related Issues

- Similar issues could occur with:
  - New themes without template files
  - YAML seed files with empty templates
  - Missing fallback template files
  - Stale cache with deleted templates

## Prevention Checklist

Before deploying new themes:
- [ ] All page part templates exist in theme directory
- [ ] All YAML seed files validated by spec
- [ ] Full seeding test runs successfully
- [ ] rebuild_page_content() test passes for all locales
- [ ] Theme-specific templates load correctly

## Documents

- **Analysis:** `/docs/claude_thoughts/PAGE_PART_TEST_COVERAGE_ANALYSIS.md`
- **Actionable:** `/docs/claude_thoughts/TEST_IMPROVEMENTS_ACTIONABLE.md`
- **This file:** `/docs/claude_thoughts/QUICK_REFERENCE.md`

## Next Steps

1. Read `PAGE_PART_TEST_COVERAGE_ANALYSIS.md` for detailed findings
2. Read `TEST_IMPROVEMENTS_ACTIONABLE.md` for implementation
3. Implement Priority 1 fix (5 min)
4. Add Priority 2 tests (3-5 hours)
5. Update CI/CD to validate seeds
6. Document in CONTRIBUTING.md

---

**TL;DR:** Method used database field instead of proper fallback chain. Fix takes 5 minutes. Preventing recurrence takes ~10 hours. Worth it.
