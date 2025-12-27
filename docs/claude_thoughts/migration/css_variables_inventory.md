# CSS Variables Inventory - Quick Reference

## CSS Variables by Theme

### Default Theme Variables (10 core variables)

| Variable | Default Value | Purpose | Customizable |
|----------|---------------|---------|--------------|
| `--primary-color` | #3b82f6 | Primary brand color | ✅ Yes |
| `--secondary-color` | #1e40af | Secondary brand color | ✅ Yes |
| `--services-bg-color` | #f9fafb | Services section background | ✅ Yes |
| `--services-card-bg` | #ffffff | Services card background | ✅ Yes |
| `--services-text-color` | #1f2937 | Services section text | ✅ Yes |
| `--font-primary` | Open Sans | Primary font family | ✅ Yes |
| `--font-secondary` | Vollkorn | Secondary font family | ✅ Yes |
| `--border-radius` | 0.5rem | Default border radius | ✅ Yes |
| `--container-padding` | 1rem | Container padding | ✅ Yes |

**File**: `app/views/pwb/custom_css/_default.css.erb`

---

### Bologna Theme Variables (20+ variables)

#### Primary Colors (Customizable)
| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `--bologna-terra` | #c45d3e | Primary color (terracotta) |
| `--bologna-olive` | #5c6b4d | Secondary color (olive) |
| `--bologna-sand` | #d4a574 | Accent color (sand) |
| `--bologna-warm-gray` | #3d3d3d | Text color |
| `--bologna-light` | #faf9f7 | Light background |

#### Extended Terra Palette (Hardcoded)
| Shade | Value |
|-------|-------|
| terra-50 | #fdf8f6 |
| terra-100 | #f9ece6 |
| terra-200 | #f2d5c9 |
| terra-300 | #e7b5a0 |
| terra-400 | #d98e6e |
| terra-500 | #c45d3e (primary) |
| terra-600 | #b14a2e |

#### Extended Olive Palette (Hardcoded)
| Shade | Value |
|-------|-------|
| olive-50 | #f6f7f4 |
| olive-100 | #e8ebe3 |
| olive-200 | #d3d9c9 |
| olive-300 | #b4bfa4 |
| olive-400 | #95a37f |
| olive-500 | #5c6b4d (secondary) |
| olive-600 | #4a5640 |

#### Footer & Typography (Customizable)
| Variable | Default Value |
|----------|---------------|
| `--footer-bg-color` | #3d3d3d |
| `--footer-text-color` | #d5d0c8 |
| `--action-color` | #c45d3e |
| `--font-display` | Outfit |
| `--font-body` | DM Sans |

#### Border & Shadows
| Variable | Value |
|----------|-------|
| `--border-radius-soft` | 16px |
| `--border-radius-softer` | 20px |
| `--border-radius-pill` | 9999px |
| `--shadow-soft` | 0 4px 24px -4px rgba(61, 61, 61, 0.08) |
| `--shadow-medium` | 0 8px 32px -8px rgba(61, 61, 61, 0.12) |
| `--shadow-elevated` | 0 16px 48px -12px rgba(61, 61, 61, 0.16) |
| `--shadow-glow` | 0 0 40px rgba(196, 93, 62, 0.15) |

**File**: `app/views/pwb/custom_css/_bologna.css.erb`

---

### Brisbane Theme Variables (15+ variables)

#### Primary Colors (Customizable)
| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `--brisbane-navy` | #1a2744 | Primary color (navy) |
| `--brisbane-gold` | #c9a962 | Secondary color (champagne gold) |
| `--brisbane-cream` | #faf8f5 | Background color |
| `--brisbane-charcoal` | #2d2d2d | Text color |
| `--brisbane-pearl` | #f5f3f0 | Light background |

#### Accent Colors (Hardcoded)
| Variable | Value |
|----------|-------|
| `--brisbane-gold-light` | #d4b978 |
| `--brisbane-gold-dark` | #a88a4a |
| `--brisbane-navy-light` | #2a3a5c |
| `--brisbane-navy-dark` | #0f1a2e |

#### Footer & Typography (Customizable)
| Variable | Default Value |
|----------|---------------|
| `--footer-bg-color` | #1a2744 |
| `--footer-text-color` | #faf8f5 |
| `--action-color` | #c9a962 |
| `--font-primary` | Cormorant Garamond |
| `--font-secondary` | Montserrat |

#### Layout & Shadows
| Variable | Value |
|----------|-------|
| `--border-radius` | 0 (no rounding) |
| `--container-padding` | 2rem |
| `--shadow-elegant` | 0 4px 20px rgba(26, 39, 68, 0.08) |
| `--shadow-hover` | 0 8px 30px rgba(26, 39, 68, 0.12) |
| `--shadow-card` | 0 2px 15px rgba(0, 0, 0, 0.05) |

**File**: `app/views/pwb/custom_css/_brisbane.css.erb`

---

### Base Variables (All Themes) - ~75 variables

**File**: `app/views/pwb/custom_css/_base_variables.css.erb`

#### Color System
```css
--pwb-primary: (calculated from primary_color)
--pwb-primary-light: color-mix variant
--pwb-primary-dark: color-mix variant
--pwb-primary-rgb: RGB decomposition

--pwb-secondary: (from secondary_color)
--pwb-secondary-light: color-mix variant
--pwb-secondary-dark: color-mix variant

--pwb-accent: (from accent_color)
--pwb-accent-light: color-mix variant
--pwb-accent-dark: color-mix variant

--pwb-success: #28a745
--pwb-warning: #ffc107
--pwb-danger: #dc3545
--pwb-info: #17a2b8
```

#### Background Colors
```css
--pwb-bg-light: (configurable)
--pwb-bg-dark: (configurable)
--pwb-bg-body: #ffffff
--pwb-bg-surface: #ffffff
--pwb-bg-muted: #f1f3f4
```

#### Text Colors
```css
--pwb-text-primary: (from style_variables)
--pwb-text-secondary: (from style_variables)
--pwb-text-muted: #9ca3af
--pwb-text-light: (from style_variables)
--pwb-text-on-primary: #ffffff
--pwb-text-on-secondary: #ffffff
```

#### Typography (8 size variants)
```css
--pwb-font-primary: (configurable)
--pwb-font-secondary: (configurable)
--pwb-font-mono: ui-monospace, monospace

--pwb-font-size-xs: 0.75rem
--pwb-font-size-sm: 0.875rem
--pwb-font-size-base: 16px (configurable)
--pwb-font-size-lg: 1.125rem
--pwb-font-size-xl: 1.25rem
--pwb-font-size-2xl: 1.5rem
--pwb-font-size-3xl: 1.875rem
--pwb-font-size-4xl: 2.25rem
--pwb-font-size-5xl: 3rem

--pwb-line-height-tight: 1.25
--pwb-line-height-base: (configurable)
--pwb-line-height-relaxed: 1.75

--pwb-font-weight-normal: 400
--pwb-font-weight-medium: 500
--pwb-font-weight-semibold: 600
--pwb-font-weight-bold: 700
```

#### Spacing System (7 variants)
```css
--pwb-spacing-unit: (configurable, default 1rem)
--pwb-spacing-xs: calc(var(--pwb-spacing-unit) * 0.25)
--pwb-spacing-sm: calc(var(--pwb-spacing-unit) * 0.5)
--pwb-spacing-md: var(--pwb-spacing-unit)
--pwb-spacing-lg: calc(var(--pwb-spacing-unit) * 1.5)
--pwb-spacing-xl: calc(var(--pwb-spacing-unit) * 2)
--pwb-spacing-2xl: calc(var(--pwb-spacing-unit) * 3)
--pwb-spacing-3xl: calc(var(--pwb-spacing-unit) * 4)
```

#### Layout
```css
--pwb-container-padding: (configurable)
--pwb-container-max-width: (configurable)
--pwb-container-narrow: 800px
--pwb-container-wide: 1400px
```

#### Border Radius (4 variants)
```css
--pwb-radius-sm: (configurable)
--pwb-radius: (configurable)
--pwb-radius-lg: (configurable)
--pwb-radius-full: (configurable)
```

#### Shadows (4 types)
```css
--pwb-shadow-sm: 0 1px 2px rgba(0,0,0,0.05)
--pwb-shadow: 0 4px 6px rgba(0,0,0,0.1)
--pwb-shadow-lg: 0 10px 25px rgba(0,0,0,0.15)
--pwb-shadow-inner: inset 0 2px 4px rgba(0,0,0,0.06)
```

#### Transitions (3 speeds)
```css
--pwb-transition-fast: 150ms
--pwb-transition-normal: 300ms
--pwb-transition-slow: 500ms
--pwb-transition-timing: cubic-bezier(0.4, 0, 0.2, 1)
```

#### Z-Index Scale (7 levels)
```css
--pwb-z-dropdown: 1000
--pwb-z-sticky: 1020
--pwb-z-fixed: 1030
--pwb-z-modal-backdrop: 1040
--pwb-z-modal: 1050
--pwb-z-popover: 1060
--pwb-z-tooltip: 1070
```

---

## Per-Tenant Customization Variables

These are the variables stored in `Website.style_variables` and accessible across all themes:

### Core Customizable Variables (20 total)

#### Colors (13 variables)
```ruby
@current_website.style_variables['primary_color']        # Main brand color
@current_website.style_variables['secondary_color']      # Secondary brand
@current_website.style_variables['accent_color']         # Accent color
@current_website.style_variables['action_color']         # Action/CTA color
@current_website.style_variables['text_color']           # Primary text
@current_website.style_variables['light_color']          # Light background
@current_website.style_variables['footer_bg_color']      # Footer background
@current_website.style_variables['footer_main_text_color'] # Footer text
@current_website.style_variables['footer_sec_text_color']  # Footer secondary
@current_website.style_variables['services_bg_color']    # Services section BG
@current_website.style_variables['services_card_bg']     # Services card BG
@current_website.style_variables['services_text_color']  # Services text

# Brisbane theme only:
@current_website.style_variables['cream_color']
@current_website.style_variables['charcoal_color']
@current_website.style_variables['pearl_color']
```

#### Typography (2 variables)
```ruby
@current_website.style_variables['font_primary']         # Primary font
@current_website.style_variables['font_secondary']       # Secondary font
```

#### Layout (4 variables)
```ruby
@current_website.style_variables['border_radius']        # Border radius
@current_website.style_variables['container_padding']    # Container padding
@current_website.style_variables['body_style']           # Layout mode (wide/boxed)
@current_website.style_variables['theme']                # Theme mode (light/dark)
```

#### Raw CSS Override
```ruby
@current_website.style_variables['raw_css']              # Custom CSS injection
```

**Note**: Additional theme-specific variables can be added by extending `style_variables_for_theme["default"]` hash in the Website model.

---

## How CSS Variables Are Rendered

### Flow Diagram

```
┌─────────────────────────────────────┐
│  Theme Layout (application.html.erb) │
│  <%= custom_styles "bologna" %>     │
└──────────┬──────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│ CSS Helper (pwb/css_helper.rb)        │
│ render partial: custom_css/bologna    │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│ Custom CSS Partial (_bologna.css.erb)  │
│ Accesses: @current_website.style_*    │
│ ERB processing at request time        │
└──────────┬─────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Output: Inline CSS with :root { }       │
│ --bologna-terra: #c45d3e (per tenant)  │
│ --footer-bg-color: #3d3d3d (per tenant)│
└─────────────────────────────────────────┘
```

### Example Output (Default Theme)

```css
/* From _default.css.erb rendering */
:root {
  --primary-color: #e91b23;          /* from @current_website.style_variables */
  --secondary-color: #3498db;
  --services-bg-color: #f9fafb;
  --services-card-bg: #ffffff;
  --services-text-color: #1f2937;
  --font-primary: Open Sans;
  --font-secondary: Vollkorn;
  --border-radius: 0.5rem;
  --container-padding: 1rem;
}
```

---

## Usage in CSS and HTML

### In CSS Files
```css
/* Using CSS variables */
.button {
  background-color: var(--primary-color);
  color: var(--pwb-text-on-primary);
  padding: var(--pwb-spacing-md);
  border-radius: var(--pwb-radius);
}

/* Using Tailwind classes with CSS variables (after migration) */
.button {
  @apply bg-[var(--primary-color)] text-[var(--pwb-text-on-primary)] 
         px-4 py-2 rounded;
}
```

### In HTML/ERB
```erb
<!-- Using Tailwind classes directly -->
<button class="bg-primary text-white px-4 py-2 rounded">
  Click me
</button>

<!-- Using theme-specific classes -->
<button class="bg-terra text-white px-4 py-2 rounded-pill">
  Bologna theme
</button>

<!-- Using CSS variables in arbitrary values (post-migration) -->
<button class="bg-[var(--primary-color)] text-[var(--pwb-text-light)] 
               px-4 py-2 rounded-[var(--pwb-radius)]">
  Dynamic colors
</button>
```

---

## CSS Variables Not Yet Used

These are defined in `_base_variables.css.erb` but may not be actively used in component classes:

```css
--pwb-primary-rgb        /* RGB decomposition */
--pwb-secondary-dark     /* Derived secondary */
--pwb-accent-light       /* Derived accent */
--pwb-accent-dark        /* Derived accent */
--pwb-border-color       /* Border color */
--pwb-border-color-dark  /* Dark border */
--pwb-footer-link        /* Footer link color */
--pwb-spacing-unit       /* Base spacing unit */
--pwb-container-narrow   /* Narrow container width */
--pwb-container-wide     /* Wide container width */
```

These are available for future use or custom styling.

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Base Variables** | ~75 |
| **Bologna Theme Variables** | ~20 |
| **Brisbane Theme Variables** | ~15 |
| **Default Theme Variables** | ~10 |
| **Per-Tenant Customizable** | ~20 |
| **Total Unique Variables** | 130+ |
| **Theme Files** | 3 |
| **CSS Partial Files** | 7 |
| **Themes Supported** | 3 |

---

## Migration Impact

### Variables That Will Change Behavior

With migration to compiled Tailwind:

1. **Hardcoded Palettes** (Bologna, Brisbane)
   - Before: Generated at request time with CDN parsing
   - After: Pre-compiled, loaded instantly
   - Impact: Faster page loads, smaller JS

2. **Custom Variables** (Default theme)
   - Before: Used in Tailwind config at request time
   - After: Used in Tailwind config at build time + arbitrary values at runtime
   - Impact: Preserved functionality, faster page loads

3. **Performance Improvements**
   - No CDN network latency
   - No inline Tailwind config parsing
   - No runtime CSS generation
   - Smaller CSS files with tree-shaking

### What Stays the Same

- Per-tenant customization mechanism (CSS variables in ERB partials)
- Website.style_variables API
- Admin customization interface
- Style inheritance and defaults

---

## Recommendations for Migration

### High Priority
- ✅ Keep `--pwb-primary`, `--pwb-secondary`, `--pwb-accent` patterns
- ✅ Preserve per-tenant customization via CSS variables
- ✅ Maintain backward compatibility with existing custom CSS

### Medium Priority
- 🔄 Consolidate theme-specific variables into base if possible
- 🔄 Document CSS variable naming conventions
- 🔄 Create CSS variable migration guide

### Low Priority
- ⚠️ Remove unused CSS variables from base
- ⚠️ Optimize color derivation (color-mix functions)
- ⚠️ Implement CSS layer organization

---

**Last Updated**: 2025-12-17
**Analysis Scope**: All 3 themes + base variables + per-tenant customization
**Status**: Ready for implementation
