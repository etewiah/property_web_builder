# Page Parts Color System Issues - Quick Reference

## Overview

Page parts in PropertyWebBuilder have a critical color system problem: **Some page parts ignore the website's theme palette and use hardcoded colors instead.**

---

## Critical Issues Found

### 1. Seed Files with Hardcoded Colors

#### home__cta_cta_banner.yml
**Location:** `/db/yml_seeds/page_parts/home__cta_cta_banner.yml` (Lines 29-49)

**Problem:**
```liquid
<!-- WRONG: Hardcoded Tailwind classes -->
<section class="cta-banner py-16 bg-primary text-white">
  <a class="px-8 py-3 bg-white text-gray-900 ...">Button</a>
</section>
```

**What it should be:**
```liquid
<!-- CORRECT: Uses CSS variables or class-based theming -->
<section class="pwb-cta pwb-cta--primary">
  <a class="pwb-btn pwb-btn--white">Button</a>
</section>
```

**Impact:**
- All websites see the same button colors (white text on primary)
- Changing website palette colors doesn't affect this section
- Ignores theme customization

---

#### home__features_feature_grid_3col.yml
**Location:** `/db/yml_seeds/page_parts/home__features_feature_grid_3col.yml` (Lines 43-95)

**Problems:**
```liquid
<!-- WRONG: Uses hardcoded amber/gray/white colors -->
<section class="services-section-wrapper py-16 bg-gray-50">
  <p class="text-amber-700">Pretitle</p>
  <h2 class="text-gray-900">Title</h2>
  <div class="bg-white p-8">Card</div>
  <div class="text-amber-700">Icon color</div>
  <a class="text-amber-700">Link</a>
</section>
```

**Hardcoded Colors:**
- `bg-gray-50` - background
- `text-amber-700` - accent/icon color (3 places!)
- `text-gray-900` - heading text
- `text-gray-600` - paragraph text
- `bg-white` - card backgrounds

**What it should be:**
```liquid
<!-- CORRECT: Uses theme-aware CSS classes -->
<section class="pwb-section">
  <div class="pwb-icon-card">
    <div class="pwb-icon-card__icon pwb-icon-card__icon--primary">
      Icon
    </div>
  </div>
</section>
```

**Impact:**
- Feature section always has gray background
- Accent color always amber (not primary/secondary/accent)
- Breaking theming system completely

---

### 2. Hardcoded Colors in Stylesheet

**File:** `/app/views/pwb/custom_css/_component_styles.css.erb`

**Lines with Issues:**

```css
139:  background-color: #ffffff;      /* Button backgrounds */
151:  color: #ffffff;                 /* Outline button text */
156:  background-color: #ffffff;      /* Hover states */
184:  rgba(0,0,0,0.5), rgba(0,0,0,0.7) /* Hero overlay */
237:  rgba(255,255,255,0.95)          /* Search box background */
261:  background-color: #fff;         /* Input field background */
338:  background: #d4edda;            /* Success card - hardcoded! */
361:  color: #fbbf24;                 /* Star ratings - always amber */
409:  rgba(0,0,0,0.2)                 /* CTA overlay */
498:  background: linear-gradient(transparent, rgba(0,0,0,0.7))
511:  color: #fff;                    /* Social links */
686:  background: rgba(0,0,0,0.5);
690:  color: #fff;
```

**Problems:**
- Mix of hardcoded hex values (`#ffffff`, `#d4edda`, `#fbbf24`)
- Mix of hardcoded RGBA (`rgba(0,0,0,0.5)`)
- Some colors not themeable (rating stars always amber)
- Overlays use hardcoded transparency

**Should use:**
```css
/* Instead of #ffffff */
color: var(--pwb-text-light);
background-color: var(--pwb-bg-light);

/* Instead of #fbbf24 */
color: var(--pwb-warning);

/* Instead of #d4edda */
background: var(--pwb-success-light);
```

---

## How Page Parts Should Handle Colors

### Pattern 1: CSS Class Names (RECOMMENDED)
```liquid
<section class="pwb-cta pwb-cta--primary">
  <a class="pwb-btn pwb-btn--primary">Click me</a>
</section>
```

**Why:** Classes map to CSS variables, respects theme

**Example:** 
- `/app/views/pwb/page_parts/cta/cta_banner.liquid` ✓ CORRECT
- `/app/views/pwb/page_parts/heroes/hero_centered.liquid` ✓ CORRECT

---

### Pattern 2: Inline CSS Variables (ACCEPTABLE)
```liquid
<div style="color: var(--pwb-primary); background: var(--pwb-bg-surface);">
  Content
</div>
```

**Why:** Directly references theme colors

---

### Pattern 3: Hardcoded Tailwind Classes (BAD)
```liquid
<section class="bg-primary text-white">
  <a class="bg-white text-gray-900">Click me</a>
</section>
```

**Why:** Tailwind classes resolve to hardcoded values, ignores palette

**Current Examples:** ❌
- `home__cta_cta_banner.yml`
- `home__features_feature_grid_3col.yml`

---

### Pattern 4: Hardcoded Hex Values (WORST)
```css
.button { background-color: #ffffff; }
.icon { color: #fbbf24; }
```

**Why:** No theming at all, not customizable

**Current Examples:** ❌
- `_component_styles.css.erb` (lines 139, 151, 156, 184, etc.)

---

## Color System Architecture

### CSS Variables Generated Server-Side
```ruby
# From app/views/pwb/custom_css/_base_variables.css.erb
# Reads from: website.style_variables hash

:root {
  --pwb-primary: #e91b23          /* From DB */
  --pwb-secondary: #3498db        /* From DB */
  --pwb-accent: #27ae60           /* From DB */
  --pwb-text-primary: #212529     /* From DB */
  --pwb-bg-light: #f8f9fa         /* From DB */
  /* ... many more ... */
}
```

### What Gets Overridden by Hardcoded Colors
When page parts use hardcoded colors, they **ignore** these generated variables:
- Primary color customization ❌
- Secondary color customization ❌
- Accent color customization ❌
- Text colors ❌
- Background colors ❌
- Footer colors ❌
- Dark mode ❌

---

## How to Fix

### For Seed Files

**Change from:**
```yaml
template: |
  <section class="cta-banner py-16 bg-primary text-white">
    <a class="px-8 py-3 bg-white text-gray-900">Button</a>
  </section>
```

**Change to:**
```yaml
template: |
  <section class="pwb-cta pwb-cta--primary">
    <div class="pwb-cta__content">
      <a class="pwb-btn pwb-btn--white">Button</a>
    </div>
  </section>
```

### For Stylesheets

**Change from:**
```css
.pwb-btn--white {
  background-color: #ffffff;
  color: #000;
}

.pwb-icon-card__icon--success {
  background: #d4edda;
  color: #28a745;
}
```

**Change to:**
```css
.pwb-btn--white {
  background-color: var(--pwb-bg-light);
  color: var(--pwb-text-primary);
}

.pwb-icon-card__icon--success {
  background: var(--pwb-success-light);
  color: var(--pwb-success);
}
```

---

## Files to Fix (Priority Order)

### CRITICAL - Fix Immediately
1. **`db/yml_seeds/page_parts/home__cta_cta_banner.yml`**
   - Lines 29-49: Remove hardcoded colors
   - Impact: Affects CTA banner on all websites

2. **`db/yml_seeds/page_parts/home__features_feature_grid_3col.yml`**
   - Lines 43-95: Remove hardcoded amber/gray colors
   - Impact: Affects feature section on all websites

### HIGH - Fix This Sprint
3. **`app/views/pwb/custom_css/_component_styles.css.erb`**
   - Lines 139, 151, 156, 184, 237, 261, 338, 361, 409+
   - Impact: Multiple components not respecting theme

### MEDIUM - Fix Soon
4. **Audit all seed files in `db/yml_seeds/page_parts/`**
   - Check other files for hardcoded colors
   - Same pattern as above two files

---

## Testing the Issue

### Current Behavior (BROKEN)
1. Create website with custom palette: primary=#FF0000 (red)
2. Add CTA Banner page part
3. Result: Button is still white/gray ❌ (ignores red)
4. Feature section still uses amber accents ❌ (ignores red)

### Expected Behavior (CORRECT)
1. Create website with custom palette: primary=#FF0000 (red)
2. Add page parts
3. Result: All colors update to match red palette ✓

---

## Reference: CSS Variables Available

```css
--pwb-primary              /* Website primary color */
--pwb-secondary            /* Website secondary color */
--pwb-accent               /* Website accent color */
--pwb-success              /* Green - #28a745 */
--pwb-warning              /* Yellow - #ffc107 */
--pwb-danger               /* Red - #dc3545 */
--pwb-info                 /* Blue - #17a2b8 */

--pwb-text-primary         /* Main text color */
--pwb-text-secondary       /* Secondary text */
--pwb-text-light           /* Light/white text */
--pwb-text-on-primary      /* Text color on primary bg */

--pwb-bg-body              /* Page background */
--pwb-bg-surface           /* Card/container background */
--pwb-bg-light             /* Light background */
--pwb-bg-dark              /* Dark background */
--pwb-bg-muted             /* Muted/disabled background */

--pwb-footer-bg            /* Footer background */
--pwb-footer-text          /* Footer text */
--pwb-footer-link          /* Footer link color */

/* Typography, spacing, sizing, shadows, transitions also available */
```

---

## Key Insight

**The system is designed to be themeable, but some components break it by using hardcoded colors.**

This means:
- Website owners expect palette changes to affect all sections ❌ Not always true
- New page parts should follow the CSS variable pattern ✓ But old ones don't
- Theme customization is unpredictable depending on which components are used ❌

Fix: Replace hardcoded colors with CSS variables + follow the pattern shown in good examples.
