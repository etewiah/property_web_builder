# Page Parts Implementation - Investigation Documents

This folder contains a complete investigation of how page parts work in PropertyWebBuilder and the color system issues discovered.

## Documents Overview

### 1. PAGE_PARTS_INVESTIGATION.md (COMPREHENSIVE)
**File:** `/docs/PAGE_PARTS_INVESTIGATION.md`

The complete, detailed technical investigation covering:
- PagePart model structure and architecture
- Template loading priority and rendering pipeline
- CSS color system implementation
- Detailed issue descriptions with line numbers
- Architecture strengths and weaknesses
- Complete file reference guide
- Actionable next steps

**Read this if:** You want the full technical details and architecture context.

**Key Sections:**
- Section 1-3: How page parts work
- Section 4-5: Color system details and critical issues
- Section 6-7: Issues, recommendations, and insights
- Section 8-10: File references and action items

---

### 2. PAGE_PARTS_COLOR_ISSUES_SUMMARY.md (QUICK REFERENCE)
**File:** `/docs/PAGE_PARTS_COLOR_ISSUES_SUMMARY.md`

Executive summary focused on the critical color system problems:
- What's broken and why
- Side-by-side comparisons of bad vs good patterns
- Impact on website theming
- Quick fix examples
- List of files to fix prioritized by urgency

**Read this if:** You want to quickly understand the problem and its impact.

**Key Sections:**
- Critical Issues (2 main seed files, plus stylesheet)
- How page parts should handle colors (4 patterns)
- Color system architecture
- Files to fix (prioritized)
- Testing guidance

---

### 3. PAGE_PARTS_COLOR_FIX_EXAMPLES.md (IMPLEMENTATION GUIDE)
**File:** `/docs/PAGE_PARTS_COLOR_FIX_EXAMPLES.md`

Detailed code examples showing exactly how to fix each issue:
- Before/after code for seed file #1 (CTA banner)
- Before/after code for seed file #2 (Feature grid)
- Before/after code for stylesheet hardcoded colors
- Two fix options for each issue (choose best fit)
- Testing strategy and validation checklist

**Read this if:** You're going to fix the issues and need specific code examples.

**Key Sections:**
- Issue 1: home__cta_cta_banner.yml (2 fix options)
- Issue 2: home__features_feature_grid_3col.yml (2 fix options)
- Issue 3: Stylesheet hardcoded colors
- Testing the fixes
- Validation checklist

---

## Quick Summary

### The Problem
Some page parts use hardcoded colors instead of CSS variables, causing them to **ignore website theme/palette settings**. This breaks the theming system for certain sections.

### Critical Files with Issues
1. **`db/yml_seeds/page_parts/home__cta_cta_banner.yml`** - Uses hardcoded Tailwind colors
2. **`db/yml_seeds/page_parts/home__features_feature_grid_3col.yml`** - Uses hardcoded amber/gray scheme
3. **`app/views/pwb/custom_css/_component_styles.css.erb`** - Has hardcoded hex values on lines 139, 151, 156, 184, 237, 261, 338, 361, 409+

### The Solution
Replace hardcoded colors with:
- CSS custom properties: `var(--pwb-primary)`, `var(--pwb-bg-light)`, etc.
- CSS class patterns: `.pwb-btn--primary`, `.pwb-icon-card__icon--primary`, etc.
- Follow existing good examples in codebase

### Expected Impact
After fixes, website owners will be able to:
- Change primary/secondary/accent colors and see ALL page sections update
- Use dark mode and have all components respect it
- Ensure visual consistency across entire website

---

## Key Findings

### Good Patterns (Already in Use)
```liquid
<!-- Pattern 1: CSS Class Names (BEST) -->
<section class="pwb-cta pwb-cta--primary">
  <a class="pwb-btn pwb-btn--primary">Click</a>
</section>

<!-- Pattern 2: CSS Variables (ACCEPTABLE) -->
<div style="color: var(--pwb-primary);">Text</div>
```

### Bad Patterns (Need to Fix)
```liquid
<!-- Pattern 3: Hardcoded Tailwind Classes (BAD) -->
<section class="bg-primary text-white">
  <a class="bg-white text-gray-900">Click</a>
</section>

<!-- Pattern 4: Hardcoded Hex Values (WORST) -->
<style>.btn { background: #ffffff; color: #fbbf24; }</style>
```

---

## Color System Architecture

```
Website style_variables (DB)
    ↓
_base_variables.css.erb (generates CSS custom properties)
    ↓
:root { --pwb-primary: #...; --pwb-secondary: #...; ... }
    ↓
_component_styles.css.erb (uses CSS variables)
    ↓
.pwb-btn { background: var(--pwb-primary); }
    ↓
Page parts use CSS classes or variables
    ↓
✓ ALL COLORS THEMEABLE (when done right)
```

---

## File Organization

### Models
- `app/models/pwb/page_part.rb` - Main model
- `app/models/pwb_tenant/page_part.rb` - Tenant-scoped variant

### Libraries
- `app/lib/pwb/page_part_registry.rb` - Registry of definitions
- `app/lib/pwb/page_part_library.rb` - Metadata and categories
- `app/lib/pwb/liquid_tags/page_part_tag.rb` - Liquid rendering

### Templates
- `app/views/pwb/page_parts/` - Default templates (21 files)
- `app/views/pwb/page_parts/heroes/` - Hero components
- `app/views/pwb/page_parts/cta/` - Call-to-action components
- `app/views/pwb/page_parts/features/` - Feature display components
- And more categories...

### Styling (COLOR SYSTEM)
- `app/views/pwb/custom_css/_base_variables.css.erb` - CSS variable definitions
- `app/views/pwb/custom_css/_component_styles.css.erb` - Component styling
- `app/views/pwb/custom_css/_shared.css.erb` - Shared utilities
- `app/views/pwb/custom_css/_barcelona.css.erb` - Barcelona theme
- `app/views/pwb/custom_css/_biarritz.css.erb` - Biarritz theme
- `app/views/pwb/custom_css/_bologna.css.erb` - Bologna theme
- `app/views/pwb/custom_css/_brisbane.css.erb` - Brisbane theme
- `app/views/pwb/custom_css/_default.css.erb` - Default theme

### Seed Data (HAS ISSUES)
- `db/yml_seeds/page_parts/home__cta_cta_banner.yml` - ❌ HARDCODED COLORS
- `db/yml_seeds/page_parts/home__features_feature_grid_3col.yml` - ❌ HARDCODED COLORS
- `db/yml_seeds/page_parts/` - 20+ other seed files (mostly OK)

---

## Statistics

### Page Parts Registered
- **Modern Components:** 12 (heroes, features, testimonials, cta, stats, teams, galleries, pricing, faqs)
- **Legacy Components:** 8 (our_agency, content_html, form_and_map, search, footer content, etc.)
- **Total:** 20+ components

### Available Themes
- barcelona
- biarritz
- bologna
- brisbane
- default

### Color Issues Found
- **Seed files with hardcoded colors:** 2 (CTA banner, Feature grid)
- **Stylesheet lines with hardcoded hex:** 15+
- **Files needing fixes:** 3 (2 seeds + 1 stylesheet)
- **Severity:** HIGH (breaks theming system)

---

## How to Use These Documents

### For Project Managers / Product Owners
1. Read PAGE_PARTS_COLOR_ISSUES_SUMMARY.md section "Critical Issues Found"
2. Review the "Testing the Issue" section to understand impact
3. Check "Files to Fix" priority list

### For Developers Fixing Issues
1. Start with PAGE_PARTS_COLOR_FIX_EXAMPLES.md
2. Copy the fixed code examples
3. Use the validation checklist before committing
4. Reference PAGE_PARTS_INVESTIGATION.md section 3 for color system details

### For Architecture Review
1. Read PAGE_PARTS_INVESTIGATION.md sections 1-3
2. Review sections 7 (Architecture Insights)
3. Check section 4-5 for issue analysis
4. Reference section 9 (Summary Table)

### For Preventing Future Issues
1. Review "Good Patterns" section in PAGE_PARTS_COLOR_ISSUES_SUMMARY.md
2. Read PAGE_PARTS_COLOR_FIX_EXAMPLES.md "Validation Checklist"
3. Share PAGE_PARTS_INVESTIGATION.md sections 1-3 with new developers

---

## Related Documentation

Page parts interact with several systems. For context:

### Theme System
- See: `docs/THEME_IMPLEMENTATION.md` (if exists)
- Related: `app/models/pwb/theme.rb`

### Website Styling
- Website model stores `style_variables` hash
- Model: `app/models/pwb/website.rb`
- Concern: `app/models/concerns/website/styleable.rb`

### Liquid Template System
- Custom tags in `app/lib/pwb/liquid_tags/`
- Filters in `app/lib/pwb/liquid_filters/`
- Configuration in `config/initializers/liquid.rb`

### Component Registry
- PagePartLibrary provides metadata
- Used by page editor UI
- Extensible for new components

---

## Next Actions

### Immediate (Do First)
- [ ] Review PAGE_PARTS_COLOR_ISSUES_SUMMARY.md
- [ ] Verify issue by testing with custom palette
- [ ] Create ticket to fix seed files

### This Sprint
- [ ] Implement fixes from PAGE_PARTS_COLOR_FIX_EXAMPLES.md
- [ ] Run validation checklist
- [ ] Test with multiple color palettes
- [ ] Test dark mode support

### Future
- [ ] Audit remaining seed files
- [ ] Add CI linting for hardcoded colors
- [ ] Create component style guide for developers
- [ ] Build theme preview UI

---

## Questions?

If something isn't clear:

1. **Quick question about an issue?** → PAGE_PARTS_COLOR_ISSUES_SUMMARY.md
2. **Need specific code fix?** → PAGE_PARTS_COLOR_FIX_EXAMPLES.md
3. **Want full technical details?** → PAGE_PARTS_INVESTIGATION.md
4. **Looking for architecture understanding?** → PAGE_PARTS_INVESTIGATION.md sections 1-7

All documents cross-reference each other with line numbers and file paths.
