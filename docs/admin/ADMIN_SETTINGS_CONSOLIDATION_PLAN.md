# Admin Settings Consolidation Plan

**Date:** December 2024
**Status:** Proposed

## Problem Summary

The site_admin interface has confusing duplicate inputs where the same information can be set in multiple places. This causes:

1. **User confusion** - Admins don't know which field to edit
2. **Silent failures** - Changes made in one place may be overridden by values in another
3. **Inconsistent behavior** - Different themes use different precedence logic

---

## Issue #1: Company Display Name (CRITICAL)

### Current State

| Location | Field | Model | Help Text |
|----------|-------|-------|-----------|
| Website Settings > General | `company_display_name` | Pwb::Website | "The name displayed on your website" |
| Agency Profile | `display_name` | Pwb::Agency | "The name shown to visitors on your website" |
| Agency Profile | `company_name` | Pwb::Agency | "Used in legal documents and invoices" |

**Problem:** Both fields have nearly identical descriptions but `website.company_display_name` takes precedence when set.

### Current Precedence Logic (Inconsistent!)

```
Brisbane theme: website.company_display_name.presence || agency.display_name
Barcelona theme: website.company_display_name || "Property" (IGNORES AGENCY!)
Default theme:   website.company_display_name.presence || agency.company_name
Bologna theme:   website.company_display_name || "Real Estate" (IGNORES AGENCY!)
```

### Recommended Solution

**Option A: Consolidate to Agency Profile (Recommended)**

1. Remove `company_display_name` from Website Settings > General tab
2. Add deprecation warning if `website.company_display_name` is set
3. Create a migration helper method:
   ```ruby
   def company_display_name
     @current_website.company_display_name.presence ||
       @current_agency&.display_name.presence ||
       @current_agency&.company_name
   end
   ```
4. Use this helper consistently in ALL themes
5. Update Agency Profile to clarify:
   - `display_name` - "Company name shown to visitors (header, footer, emails)"
   - `company_name` - "Legal name for invoices and contracts"

**Benefits:**
- Single source of truth in Agency Profile
- Clear distinction between display name and legal name
- Agency Profile already has all contact info, so it's the natural home

**Migration Path:**
1. Phase 1: Add helper method, update themes to use it
2. Phase 2: Add warning to Website Settings if field is populated
3. Phase 3: Hide field from Website Settings, auto-migrate values to Agency
4. Phase 4: Remove database column (after data verification)

---

## Issue #2: Unused Database Fields (MEDIUM)

### Fields That Exist But Are Never Used

| Model | Column | Status |
|-------|--------|--------|
| Pwb::Website | `main_logo_url` | Unused - logos come from ContentPhoto |
| Pwb::Website | `email_for_general_contact_form` | Unused - views use Agency email |
| Pwb::Website | `email_for_property_contact_form` | Unused - views use Agency email |
| Pwb::Website | `owner_email` | Unclear usage |

### Recommended Solution

1. **Immediate:** Document in code which columns are deprecated
2. **Short-term:** Add migration to remove unused columns
3. **Update:** Ensure all email functionality uses Agency model

---

## Issue #3: Logo Configuration (LOW)

### Current State

- `website.main_logo_url` column exists but is NEVER used
- Actual logo comes from `ContentPhoto.find_by_block_key("logo")`
- Logo is managed via Page Parts / Content system, not Website Settings

### Recommended Solution

1. Remove `main_logo_url` column (unused)
2. Add "Logo" section to Website Settings > Appearance tab that links to the content management
3. OR move logo upload to a more prominent location

---

## Issue #4: Theme Inconsistency (MEDIUM)

### Current State

Different themes have different fallback patterns for company name, causing inconsistent behavior:

- Barcelona: Shows "Property" or "Real Estate" if website name is empty (ignores agency)
- Brisbane: Falls back to agency.display_name
- Default: Falls back to agency.company_name

### Recommended Solution

1. Create `ApplicationHelper#company_display_name` method
2. Update ALL themes to use this helper instead of inline logic
3. Standardize the fallback chain:
   ```
   website.company_display_name (if present)
   → agency.display_name (if present)
   → agency.company_name (if present)
   → "Real Estate" (default)
   ```

---

## Implementation Phases

### Phase 1: Quick Wins (1-2 hours)

1. **Add clarifying help text** to both forms:
   - Website Settings: "Note: This overrides the Agency Profile display name if set"
   - Agency Profile: "Note: Website Settings > General may override this value"

2. **Create `company_display_name` helper** in ApplicationHelper

3. **Update all themes** to use the helper consistently

### Phase 2: Consolidation (2-4 hours)

1. **Add validation warning** in Website Settings if both are set
2. **Add "Sync" button** to copy website value to agency and clear website field
3. **Update documentation** with clear data model explanation

### Phase 3: Migration (1-2 hours)

1. **Create migration** to move data from Website to Agency
2. **Remove field** from Website Settings > General tab
3. **Add redirect/deprecation notice** for any API usage

### Phase 4: Cleanup (30 min)

1. **Remove unused columns** via migration
2. **Update tests** to reflect new structure
3. **Document** the consolidated approach

---

## Files to Modify

### Phase 1 Files

| File | Change |
|------|--------|
| `app/helpers/application_helper.rb` | Add `company_display_name` helper |
| `app/themes/*/views/pwb/_header.html.erb` | Use helper instead of inline logic |
| `app/themes/*/views/pwb/_footer.html.erb` | Use helper instead of inline logic |
| `app/views/site_admin/website/settings/_general_tab.html.erb` | Add warning text |
| `app/views/site_admin/agency/edit.html.erb` | Add warning text |

### Phase 2-3 Files

| File | Change |
|------|--------|
| `app/controllers/site_admin/website/settings_controller.rb` | Add validation |
| `db/migrate/xxx_consolidate_company_name.rb` | Data migration |

---

## Success Criteria

1. Single, clear location to set company display name
2. No silent override of values
3. All themes behave consistently
4. Clear documentation for admins

---

## Alternative: Keep Both, Add Explicit Precedence UI

Instead of consolidating, we could:

1. Keep both fields
2. Add clear visual indicator showing which value is currently being used
3. Add explicit "source" selector: "Use Website name" / "Use Agency name"

This is more complex but preserves flexibility for multi-agency scenarios.

---

## Decision Needed

**Recommended:** Phase 1 (quick fixes) + Phase 2 (consolidation to Agency Profile)

This provides the cleanest user experience and matches the existing pattern where Agency Profile holds all contact/company information.
