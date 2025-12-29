# Page Parts Implementation Investigation Report

## Executive Summary

This investigation examines how page parts work in the PropertyWebBuilder Rails codebase, specifically focusing on how they interact with the theme and color palette system. The analysis reveals a **critical color system issue**: page parts use a mix of theme-aware CSS variables and hardcoded Tailwind colors, creating inconsistency where some components respect theme palettes while others override them with hardcoded values.

---

## 1. PagePart Architecture Overview

### 1.1 Model Structure

**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/page_part.rb` (non-tenant scoped)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/page_part.rb` (tenant-scoped)

**Key Features:**
- PagePart is a database model with liquid template content stored in `pwb_page_parts` table
- Schema includes:
  - `page_part_key`: Unique identifier (e.g., "cta/cta_banner")
  - `template`: Optional database override for Liquid template
  - `block_contents`: JSON data for liquid variables
  - `editor_setup`: Configuration for the page editor UI
  - `page_slug`: Associated page (e.g., "home", "about-us")
  - `website_id`: Tenant scoping
  - `theme_name`: Optional theme override

**Template Loading Priority:**
1. Database override (`self[:template]`)
2. Theme-specific file: `app/themes/{theme_name}/page_parts/{page_part_key}.liquid`
3. Default file: `app/views/pwb/page_parts/{page_part_key}.liquid`

### 1.2 Page Part Registry and Library

**Files:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/page_part_registry.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/page_part_library.rb`

**Purpose:**
- Centralizes metadata about all available page parts
- Defines categories (Heroes, Features, CTAs, Stats, etc.)
- Maps page_part_key to field definitions and descriptions
- Provides introspection for the page editor UI

**Available Page Parts:** 20+ including:
- Heroes (centered, split, search)
- Features (grid, icon cards)
- Testimonials (carousel, grid)
- CTAs (banner, split image)
- Stats counter
- Teams grid
- Pricing table
- FAQ accordion
- Image gallery
- Legacy components (our_agency, content_html, form_and_map, etc.)

---

## 2. Rendering Pipeline

### 2.1 Liquid Tag Rendering

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/liquid_tags/page_part_tag.rb`

**Process:**
```
{% page_part "heroes/hero_centered" %}
    ↓
PagePartTag.render() executes:
    1. Finds PagePart record from database
    2. Gets template_content (via priority loading)
    3. Parses Liquid template
    4. Renders with block_contents as variables
    5. Passes context registers (view, website, locale)
```

**Context Registers Available to Templates:**
- `:view` - Rails view context (for helpers)
- `:website` - Current website object
- `:locale` - Current locale

### 2.2 ERB Template Rendering

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/pages/show_page_part.html.erb`

```erb
<% if @is_rails_part %>
  <%= render partial: "pwb/components/#{@page_part_key}", locals: {} rescue nil %>
<% else %>
  <%== @content_html %>
<% end %>
```

**Generic Page Part Components:**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/{theme}/views/pwb/components/_generic_page_part.html.erb`
- All themes use simple prose wrapper: `<div class="prose prose-lg max-w-none"><%== content %></div>`

---

## 3. Color System Implementation

### 3.1 CSS Custom Properties (CSS Variables)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_base_variables.css.erb`

This ERB template generates CSS custom properties from `website.style_variables`:

**Core Color Variables:**
```css
:root {
  /* Primary, Secondary, Accent */
  --pwb-primary: 
  --pwb-primary-light: 
  --pwb-primary-dark:
  --pwb-secondary:
  --pwb-accent:
  
  /* Status Colors */
  --pwb-success:
  --pwb-warning:
  --pwb-danger:
  --pwb-info:
  
  /* Background Colors */
  --pwb-bg-light:
  --pwb-bg-dark:
  --pwb-bg-body:
  --pwb-bg-surface:
  --pwb-bg-muted:
  
  /* Text Colors */
  --pwb-text-primary:
  --pwb-text-secondary:
  --pwb-text-light:
  --pwb-text-on-primary:
  
  /* Typography, Spacing, Sizing */
  --pwb-font-primary:
  --pwb-font-secondary:
  --pwb-line-height-base:
  --pwb-spacing-*: (xs, sm, md, lg, xl, 2xl, 3xl)
  --pwb-radius-*: (sm, base, lg, full)
  --pwb-shadow-*: (sm, base, lg)
  --pwb-transition-*: (fast, normal, slow)
}
```

**Dark Mode Support:**
- Media query: `@media (prefers-color-scheme: dark)` with class `.pwb-auto-dark`
- Class-based: `.pwb-dark` for forced dark mode
- Uses `color-mix()` for derived colors (lighter/darker variants)

### 3.2 Component Styles Using Variables

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_component_styles.css.erb`

**Good Examples (using variables):**
- `.pwb-btn--primary`: `background-color: var(--pwb-primary)`
- `.pwb-icon-card__icon--primary`: `background: var(--pwb-primary-light); color: var(--pwb-primary)`
- `.pwb-cta--primary`: `background: var(--pwb-primary-dark)`
- `.pwb-stat__value`: `color: var(--pwb-primary)`

---

## 4. CRITICAL ISSUE: Hardcoded Colors in Page Parts

### 4.1 Database-Stored Templates with Hardcoded Colors

**Files with Issues:**
- `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/page_parts/home__cta_cta_banner.yml`
- `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/page_parts/home__features_feature_grid_3col.yml`

#### Issue 1: CTA Banner (home__cta_cta_banner.yml)

**Location:** Lines 29-49 in seed file

```liquid
<section class="cta-banner py-16 bg-primary text-white">
  <!-- Uses Tailwind bg-primary which is hardcoded -->
  <a href="..." class="px-8 py-3 bg-white text-gray-900 ...">
    <!-- Hardcoded: bg-white, text-gray-900 -->
  </a>
  <a href="..." class="px-8 py-3 border-2 border-white ...">
    <!-- Hardcoded: border-white -->
  </a>
</section>
```

**Problems:**
1. Uses Tailwind color classes (`bg-primary`, `text-white`, `text-gray-900`) instead of CSS variables
2. `bg-primary` resolves to hardcoded Tailwind value, not dynamic theme color
3. Button colors are hardcoded (`bg-white`, `text-gray-900`)
4. Does not respect website palette changes

#### Issue 2: Feature Grid (home__features_feature_grid_3col.yml)

**Location:** Lines 43-95 in seed file

```liquid
<section class="services-section-wrapper py-16 bg-gray-50" id="home-services">
  <!-- Hardcoded: bg-gray-50 -->
  <p class="text-sm uppercase tracking-widest text-amber-700 mb-2">
    <!-- Hardcoded: text-amber-700 -->
  </p>
  <h2 class="text-3xl font-bold text-gray-900 mb-4">
    <!-- Hardcoded: text-gray-900 -->
  </h2>
  <div class="service-card bg-white p-8 rounded-lg shadow-md ...">
    <!-- Hardcoded: bg-white -->
  </div>
  <div class="service-icon-wrapper text-4xl text-amber-700 mb-4">
    <!-- Hardcoded: text-amber-700 (not theme-aware!) -->
  </div>
  <a href="..." class="inline-block mt-4 text-amber-700 hover:underline">
    <!-- Hardcoded: text-amber-700 -->
  </a>
</section>
```

**Problems:**
1. Hardcoded color scheme (amber for accents, gray for backgrounds, white for cards)
2. All text colors hardcoded (`text-gray-900`, `text-gray-600`, `text-amber-700`)
3. Background colors hardcoded (`bg-gray-50`, `bg-white`)
4. Ignores website palette entirely

### 4.2 Hardcoded Colors in Stylesheet

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_component_styles.css.erb`

**Lines with Issues:**

| Line | Issue | Current Value | Should Be |
|------|-------|---------------|-----------|
| 139 | Button text hardcoded | `#ffffff` | `var(--pwb-text-light)` |
| 141 | Button border hardcoded | `#ffffff` | `var(--pwb-btn-border)` |
| 151 | Outline button text hardcoded | `#ffffff` | `var(--pwb-text-light)` |
| 156 | Button hover bg hardcoded | `#ffffff` | `var(--pwb-bg-light)` |
| 184 | Hero overlay gradient hardcoded | `rgba(0,0,0,0.5/0.7)` | Should use CSS var or pattern |
| 237 | Search box bg hardcoded | `rgba(255,255,255,0.95)` | Could use CSS var |
| 261 | Input field bg hardcoded | `#fff` | Should reference theme |
| 338 | Success card bg | `#d4edda` | Not theme-aware (amber-tinted) |
| 361 | Rating color hardcoded | `#fbbf24` | Should use `--pwb-warning` or theme color |
| 409 | CTA gradient overlay | `rgba(0,0,0,0.2)` | Could use CSS var |
| 498, 511, 686, 690 | Various blacks/whites | Hardcoded | Should use theme vars |

### 4.3 Mixed Approach in Liquid Templates

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/cta/cta_banner.liquid`

```liquid
<section class="pwb-cta pwb-cta--{{ page_part.style.content | default: 'primary' }}">
```

**Good:** Uses dynamic style class names that map to theme colors in CSS

**Problem:** Seed data doesn't follow this pattern - it uses hardcoded Tailwind classes instead.

---

## 5. Detailed Findings

### 5.1 How Page Parts Reference Colors

#### Pattern 1: CSS Class Names (Best Practice)
```liquid
<a class="pwb-btn pwb-btn--primary">Click me</a>
```
- Classes map to CSS variables in stylesheet
- Respects theme colors
- **Example:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_centered.liquid`

#### Pattern 2: Inline CSS Variables (Good)
```liquid
<div style="color: var(--pwb-primary);">Content</div>
```
- References CSS custom properties directly
- Works with theme system
- **Less common in current codebase**

#### Pattern 3: Hardcoded Tailwind Classes (Problem)
```liquid
<section class="bg-primary text-white">
  <a class="bg-white text-gray-900">Button</a>
</section>
```
- Uses static Tailwind color classes
- Ignores website palette
- **Example:** Seed files (home__cta_cta_banner.yml, home__features_feature_grid_3col.yml)

#### Pattern 4: Hardcoded Hex Values (Worst)
```css
.button { background-color: #ffffff; }
.icon { color: #fbbf24; }
```
- Not themeable at all
- **Location:** _component_styles.css.erb lines 139, 151, 156, 184, 237, 261, 338, 361, 409, etc.

### 5.2 Theme and Palette System

**Website Model:**
- `style_variables` Hash field contains palette colors:
  - `primary_color`, `secondary_color`, `accent_color`
  - `text_primary`, `text_secondary`, `text_light`
  - `footer_bg_color`, `footer_main_text_color`, `footer_link_color`
  - `bg_light`, `bg_dark`
  - And 10+ other customizable values

**Dark Mode Support:**
- Optional per-website: `dark_mode_enabled?`
- `dark_mode_colors` Hash with dark variants
- Uses CSS media queries and classes

**CSS Variable Generation:**
- Server-side rendering in ERB template
- Converts style_variables to CSS custom properties
- Generated per-request (not cached in CSS file)

### 5.3 Page Part Interaction with Themes

**Theme Detection:**
```ruby
# In PagePart.load_template_content
theme_name = website&.theme_name || 'default'

# Theme-specific templates checked first
theme_path = Rails.root.join("app/themes/#{theme_name}/page_parts/#{page_part_key}.liquid")
```

**Available Themes:**
- barcelona
- biarritz
- bologna
- brisbane
- default

**Theme-Specific Components:**
- All themes have `_generic_page_part.html.erb` wrapper
- Some themes might override individual page_part templates
- Currently NO theme-specific page_part overrides in file system

---

## 6. Issues and Recommendations

### Issue 1: Database Seed Files Have Hardcoded Colors

**Severity:** HIGH

**Files:**
- `db/yml_seeds/page_parts/home__cta_cta_banner.yml` (lines 29-49)
- `db/yml_seeds/page_parts/home__features_feature_grid_3col.yml` (lines 43-95)

**Impact:**
- Page parts ignore website color palette
- All websites see same colors (amber/gray/white scheme)
- Customized themes don't affect these sections
- When palette is changed, these sections don't update

**Root Cause:**
Database-stored templates use hardcoded Tailwind color classes instead of referencing CSS variables or using CSS class-based patterns.

**Solution:**
Replace hardcoded Tailwind classes with:
1. CSS custom property references: `style="color: var(--pwb-primary)"`
2. Or use class-based approach: `class="pwb-btn pwb-btn--primary"`
3. Or move templates out of database into versioned .liquid files

**Recommendation Priority:** Fix immediately before any palette changes are made

---

### Issue 2: Component Styles Have Hardcoded Colors

**Severity:** MEDIUM

**File:** `app/views/pwb/custom_css/_component_styles.css.erb`

**Hardcoded Values:**
```css
Line 139:   background-color: #ffffff;      /* Button text fallback */
Line 151:   color: #ffffff;                 /* Outline button text */
Line 156:   background-color: #ffffff;      /* Hover state */
Line 184:   rgba(0,0,0,0.5), rgba(0,0,0,0.7)  /* Hero overlay */
Line 237:   rgba(255,255,255,0.95)          /* Search box */
Line 261:   background-color: #fff;         /* Input fields */
Line 338:   background: #d4edda;            /* Success card (amber-tinted!) */
Line 361:   color: #fbbf24;                 /* Star rating (amber) */
Line 409:   rgba(0,0,0,0.2)                 /* CTA overlay fallback */
```

**Impact:**
- Some overlays and utility colors ignore theme
- Success color uses amber instead of theme's success color
- Rating stars always amber regardless of palette
- Input fields always white

**Solution:**
- Create CSS variables for these: `--pwb-overlay-dark`, `--pwb-overlay-light`, `--pwb-search-box-bg`, etc.
- Or use `color-mix()` for overlay opacity
- Update stylesheet to reference variables instead of hardcoded values

**Recommendation Priority:** Medium - address as part of color system improvement

---

### Issue 3: Mix of Template Styles

**Severity:** LOW-MEDIUM

**Description:**
Three different approaches to handling colors in page part templates:

1. **Modern approach (good):** `/app/views/pwb/page_parts/cta/cta_banner.liquid`
   - Uses `pwb-cta--{{ style }}` class pattern
   - Maps to CSS variables in stylesheet
   - Respects theme

2. **Legacy approach (needs update):** Seed files with hardcoded Tailwind
   - All custom websites get same amber/gray scheme
   - Not themeable

3. **New component approach (good):** Feature card icon component
   - Uses `pwb-icon-card__icon--{{ color }}` pattern
   - Respects theme colors

**Impact:**
- Inconsistent styling across page parts
- New developers might follow wrong pattern
- Makes theme customization unpredictable

**Solution:**
- Document the modern approach clearly
- Migrate seed files to new pattern
- Add validation/examples for new page parts

---

## 7. Architecture Insights

### 7.1 Strengths

1. **Flexible Template Loading:**
   - Database > Theme-specific file > Default file
   - Allows customization at multiple levels

2. **CSS Variable System:**
   - Comprehensive palette support
   - Dark mode built-in
   - Responsive to website settings

3. **Modular Page Parts:**
   - Reusable components with clear interfaces
   - Registry pattern for introspection
   - Easy to add new sections

4. **Liquid Template Language:**
   - Safe server-side rendering
   - No security concerns
   - Good separation of concerns

### 7.2 Weaknesses

1. **Hardcoded Colors in Seeds:**
   - Breaks theming system
   - Makes database an implementation detail
   - Difficult to change globally

2. **Mixed Color Patterns:**
   - No clear migration path for old components
   - Inconsistent developer experience
   - Hard to enforce standards

3. **No Validation:**
   - No checks that page parts use themeable colors
   - No CI/linting for hardcoded hex values
   - Regressions possible when adding new parts

4. **Limited Theme Specificity:**
   - No theme-specific page part templates in filesystem
   - All customization via CSS
   - Can't adjust structure per theme

---

## 8. Files Reference

### Core Models
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/page_part.rb` - Main model
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/page_part.rb` - Tenant-scoped

### Library and Registry
- `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/page_part_registry.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/page_part_library.rb`

### Rendering
- `/Users/etewiah/dev/sites-older/property_web_builder/app/lib/pwb/liquid_tags/page_part_tag.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/pages/show_page_part.html.erb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/layouts/pwb/page_part.html.erb`

### Styling (COLOR ISSUES)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_base_variables.css.erb` - CSS var definitions
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_component_styles.css.erb` - Component styles (has hardcoded colors)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_shared.css.erb` - Shared utilities
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/custom_css/_*.css.erb` - Theme overrides

### Seed Data (CRITICAL ISSUES)
- `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/page_parts/home__cta_cta_banner.yml` - Hardcoded colors
- `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/page_parts/home__features_feature_grid_3col.yml` - Hardcoded colors
- `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/page_parts/` - All seed data (20+ files)

### Page Part Templates (mostly good)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/` - Default templates
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/heroes/hero_centered.liquid` - Good example
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/cta/cta_banner.liquid` - Good example
- `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/page_parts/features/feature_cards_icons.liquid` - Good example

### Themes
- `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/*/views/pwb/components/_generic_page_part.html.erb` - 5 themes

---

## 9. Summary Table

| Aspect | Status | Details |
|--------|--------|---------|
| **Page Part Model** | Good | Well-structured, tenant-scoped variant available |
| **Template Loading** | Good | Smart fallback priority (DB > theme > default) |
| **Liquid Rendering** | Good | Clean tag implementation, proper context passing |
| **CSS Variables** | Good | Comprehensive palette system, dark mode support |
| **Component Styles** | Mostly Good | Some hardcoded colors in utility/overlay styles |
| **File-based Templates** | Good | Most use theme-aware CSS classes |
| **Seed Data** | CRITICAL ISSUE | Hardcoded Tailwind colors override theme palette |
| **Color Consistency** | ISSUE | Mixed patterns: CSS vars, classes, and hardcoded values |
| **Theming Support** | PARTIAL | System designed for theming but some parts break it |
| **Dark Mode** | Good | Built into CSS variable system |

---

## 10. Actionable Next Steps

### Immediate (Do First)
1. Document issue with seed file colors
2. Create test to verify page parts use themeable colors
3. Identify all pages currently using hardcoded-color page parts

### Short Term (This Sprint)
1. Update `home__cta_cta_banner.yml` to use CSS variables or class-based approach
2. Update `home__features_feature_grid_3col.yml` to use theme colors
3. Add linting rule to catch hardcoded hex values in templates

### Medium Term (Next Sprint)
1. Audit all seed files for hardcoded colors
2. Remove hardcoded colors from `_component_styles.css.erb`
3. Create CSS variables for remaining utility colors
4. Document best practices for new page parts

### Long Term
1. Consider moving seed data to .liquid files with version control
2. Build theme preview UI showing color impacts
3. Add automated validation in CI for color compliance
4. Create page part style guide for developers

