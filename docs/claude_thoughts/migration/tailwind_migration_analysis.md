# Tailwind CDN to Compiled CSS Migration Analysis

## Executive Summary

PropertyWebBuilder currently uses Tailwind CSS via CDN with runtime CSS variables for per-tenant customization. Migrating to compiled Tailwind will require:

1. **Converting Tailwind CDN configuration to a build-time compiled setup**
2. **Replacing runtime CSS variables with Tailwind's arbitrary value syntax**
3. **Preserving per-tenant color/style customization through CSS variables**
4. **Handling theme-specific Tailwind extensions (colors, fonts, shadows)**

### Current Status
- **Tailwind Setup**: CDN-based with inline `tailwind.config` in each layout
- **Node Version**: Tailwind CSS 4.1.17, CLI 4.1.17
- **Theme Count**: 3 themes (bologna, brisbane, default)
- **Customization Method**: Per-tenant CSS variables via `@current_website.style_variables`

---

## Part 1: Theme Layout Files Analysis

### Three Theme Layout Files Location
All layouts inject Tailwind CDN and inline configuration:

```
app/themes/bologna/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/default/views/layouts/pwb/application.html.erb
```

### Layout Structure Commonalities

All three layouts follow this pattern:
```erb
<script src="https://cdn.tailwindcss.com"></script>
<script>
  tailwind.config = {
    theme: {
      container: { ... },
      extend: {
        colors: { ... },
        fontFamily: { ... },
        // other customizations
      }
    }
  }
</script>
```

### TODO Comments Found

All three layouts have identical TODO comments:
```erb
<%# TODO: Migrate to compiled Tailwind by using arbitrary value syntax: bg-[var(--primary-color)] %>
```

This indicates the migration path was already planned.

---

## Part 2: CSS Variables Used by Each Theme

### Default Theme CSS Variables

**Source**: `app/themes/default/views/layouts/pwb/application.html.erb`

```javascript
--primary-color: defaults to #3b82f6 (blue)
--secondary-color: defaults to #1e40af (darker blue)
--services-bg-color: defaults to #f9fafb (light gray)
--services-card-bg: defaults to #ffffff (white)
--services-text-color: defaults to #1f2937 (dark gray)
--font-primary: defaults to "Open Sans"
--font-secondary: defaults to "Vollkorn"
--border-radius: defaults to 0.5rem
--container-padding: defaults to 1rem
```

**Used in Tailwind config**:
```javascript
colors: {
  primary: 'var(--primary-color)',
  secondary: 'var(--secondary-color)',
  'services-bg': 'var(--services-bg-color)',
  'services-card': 'var(--services-card-bg)',
  'services-text': 'var(--services-text-color)',
},
fontFamily: {
  sans: ['var(--font-primary)', 'sans-serif'],
  serif: ['var(--font-secondary)', 'serif'],
},
borderRadius: {
  DEFAULT: 'var(--border-radius)',
  'lg': 'var(--border-radius)',
}
```

### Bologna Theme CSS Variables

**Source**: `app/themes/bologna/views/layouts/pwb/application.html.erb`

Uses hardcoded color palettes (not CSS variables in Tailwind config):
```javascript
colors: {
  'terra': { 50: '#fdf8f6', 100: '#f9ece6', ... 900: '#642d22' },
  'olive': { 50: '#f6f7f4', 100: '#e8ebe3', ... 900: '#2b3028' },
  'sand': { 50: '#fdfcfa', 100: '#f9f6f0', ... 900: '#5f422e' },
  'warm-gray': { 50: '#faf9f7', 100: '#f5f3f0', ... 900: '#3d3d3d' },
  primary: '#c45d3e',
  secondary: '#5c6b4d',
  accent: '#d4a574',
}
```

**Custom ERB-generated CSS variables** (in `_bologna.css.erb`):
```css
--bologna-terra: <%= @current_website.style_variables["primary_color"] || "#c45d3e" %>
--bologna-olive: <%= @current_website.style_variables["secondary_color"] || "#5c6b4d" %>
--bologna-sand: <%= @current_website.style_variables["accent_color"] || "#d4a574" %>
--bologna-warm-gray: <%= @current_website.style_variables["text_color"] || "#3d3d3d" %>
--bologna-light: <%= @current_website.style_variables["light_color"] || "#faf9f7" %>
--footer-bg-color: <%= @current_website.style_variables["footer_bg_color"] || "#3d3d3d" %>
--footer-text-color: <%= @current_website.style_variables["footer_main_text_color"] || "#d5d0c8" %>
--action-color: <%= @current_website.style_variables["action_color"] || "#c45d3e" %>
```

### Brisbane Theme CSS Variables

**Source**: `app/themes/brisbane/views/layouts/pwb/application.html.erb`

Uses hardcoded luxury color palette:
```javascript
colors: {
  'luxury-navy': '#1a2744',
  'luxury-gold': '#c9a962',
  'luxury-cream': '#faf8f5',
  'luxury-charcoal': '#2d2d2d',
  'luxury-pearl': '#f5f3f0',
  primary: '#1a2744',
  secondary: '#c9a962',
}
```

**Custom ERB-generated CSS variables** (in `_brisbane.css.erb`):
```css
--brisbane-navy: <%= @current_website.style_variables["primary_color"] || "#1a2744" %>
--brisbane-gold: <%= @current_website.style_variables["secondary_color"] || "#c9a962" %>
--brisbane-cream: <%= @current_website.style_variables["cream_color"] || "#faf8f5" %>
--brisbane-charcoal: <%= @current_website.style_variables["charcoal_color"] || "#2d2d2d" %>
--brisbane-pearl: <%= @current_website.style_variables["pearl_color"] || "#f5f3f0" %>
--footer-bg-color: <%= @current_website.style_variables["footer_bg_color"] || "#1a2744" %>
--footer-text-color: <%= @current_website.style_variables["footer_main_text_color"] || "#faf8f5" %>
--action-color: <%= @current_website.style_variables["action_color"] || "#c9a962" %>
```

---

## Part 3: CSS Variable Definition System

### Custom Styles Helper

**Location**: `app/helpers/pwb/css_helper.rb`

```ruby
def custom_styles(theme_name)
  @bg_style_vars = ["primary-color-light", "primary-color-dark",
                    "primary-color",
                    "accent-color", "divider-color",
                    "primary-background-dark"]
  @text_color_style_vars = ["primary-color-text",
                            "primary-text-color", "secondary-text-color"]
  render partial: "pwb/custom_css/#{theme_name}", locals: {}, formats: :css
end
```

**Called in layouts**:
```erb
<style>
  <%= custom_styles "bologna" %>
</style>
```

### CSS Variable Definitions by Theme

**Base Variables** (`app/views/pwb/custom_css/_base_variables.css.erb`)

Comprehensive CSS variables system for all themes:
- **Color System**: `--pwb-primary`, `--pwb-secondary`, `--pwb-accent` with light/dark variants
- **Status Colors**: `--pwb-success`, `--pwb-warning`, `--pwb-danger`, `--pwb-info`
- **Background Colors**: `--pwb-bg-light`, `--pwb-bg-dark`, `--pwb-bg-body`, `--pwb-bg-surface`, `--pwb-bg-muted`
- **Text Colors**: Multiple shades for primary, secondary, muted, light
- **Typography**: Font families, sizes (xs to 5xl), line heights, font weights
- **Spacing**: Calculated using `--pwb-spacing-unit` with xs through 3xl variants
- **Layout**: Container padding, max-width, narrow, wide variants
- **Border Radius**: `--pwb-radius-sm`, `--pwb-radius`, `--pwb-radius-lg`, `--pwb-radius-full`
- **Shadows**: Small, medium, large, inner
- **Transitions**: Fast (150ms), normal (300ms), slow (500ms)
- **Z-Index Scale**: dropdown, sticky, fixed, modal, popover, tooltip

**Bologna Theme CSS** (`app/views/pwb/custom_css/_bologna.css.erb`)

Specific variables:
```css
--bologna-terra: (primary color - configurable)
--bologna-olive: (secondary color - configurable)
--bologna-sand: (accent color - configurable)
--bologna-warm-gray: (text color - configurable)
--bologna-light: (light background - configurable)
--font-display: (Outfit - configurable)
--font-body: (DM Sans - configurable)
--border-radius-soft: (16px - configurable)
--border-radius-softer: (20px)
--border-radius-pill: (9999px)
--shadow-soft, --shadow-medium, --shadow-elevated, --shadow-glow
```

**Brisbane Theme CSS** (`app/views/pwb/custom_css/_brisbane.css.erb`)

Specific variables:
```css
--brisbane-navy: (primary color - configurable)
--brisbane-gold: (secondary color - configurable)
--brisbane-cream: (background - configurable)
--brisbane-charcoal: (text color - configurable)
--brisbane-pearl: (light background - configurable)
--font-primary: (Cormorant Garamond - serif - configurable)
--font-secondary: (Montserrat - sans - configurable)
--border-radius: (0 - no border radius - configurable)
--container-padding: (2rem - configurable)
--shadow-elegant, --shadow-hover, --shadow-card
```

**Default Theme CSS** (`app/views/pwb/custom_css/_default.css.erb`)

Simpler set of variables:
```css
--primary-color: (configurable)
--secondary-color: (configurable)
--services-bg-color: (configurable)
--services-card-bg: (configurable)
--services-text-color: (configurable)
--font-primary: (configurable)
--font-secondary: (configurable)
--border-radius: (configurable)
--container-padding: (configurable)
```

---

## Part 4: Per-Tenant Customization System

### Website Model Style Variables

**Location**: `app/models/pwb/website.rb`

Key method:
```ruby
def style_variables
  default_style_variables = {
    "primary_color" => "#e91b23",      # red
    "secondary_color" => "#3498db",    # blue
    "action_color" => "green",
    "body_style" => "siteLayout.wide",
    "theme" => "light",
    "font_primary" => "Open Sans",
    "font_secondary" => "Vollkorn",
    "border_radius" => "0.5rem",
    "container_padding" => "1rem",
  }
  style_variables_for_theme["default"] || default_style_variables
end
```

### Per-Tenant Variables Used

The Website model exposes these customizable style variables accessed via `@current_website.style_variables`:

**Color Variables**:
- `primary_color` - Main brand color
- `secondary_color` - Secondary brand color
- `accent_color` / `action_color` - Accent color
- `text_color` - Primary text color
- `light_color` - Light background
- `footer_bg_color` - Footer background
- `footer_main_text_color` - Footer text
- `footer_sec_text_color` - Footer secondary text
- `services_bg_color` - Services section background
- `services_card_bg` - Services card background
- `services_text_color` - Services text
- `cream_color`, `charcoal_color`, `pearl_color` - Brisbane theme specific

**Typography Variables**:
- `font_primary` - Primary font family
- `font_secondary` - Secondary font family

**Layout Variables**:
- `border_radius` - Default border radius
- `container_padding` - Container padding

**Layout Mode**:
- `body_style` - "siteLayout.wide" or "siteLayout.boxed"

### How Variables Flow

1. **Admin Interface** → Sets `website.style_variables_for_theme["default"]`
2. **Theme Layout** → Calls `custom_styles("theme_name")`
3. **CSS Helper** → Renders partial `_theme.css.erb`
4. **CSS Partial** → Accesses `@current_website.style_variables` during rendering
5. **Output** → Inline CSS with `:root { --variable: value; }` containing per-tenant values

---

## Part 5: Current Compiled Tailwind Setup

### Package.json Dependencies

```json
"@tailwindcss/cli": "^4.1.17",
"tailwindcss": "^4.1.17",
"flowbite": "^4.0.1",
```

**Status**: Tailwind 4.1.17 is already installed but NOT being used in themes (only CDN).

### Existing Theme Stylesheets

Static compiled stylesheets already exist for Bologna and Brisbane:

```
app/assets/stylesheets/bologna_theme.css
app/assets/stylesheets/brisbane_theme.css
app/assets/stylesheets/pwb/themes/default.css
```

These are NOT Tailwind-compiled; they're handwritten CSS containing:
- Typography rules
- Component styles (buttons, cards, forms)
- Layout styles
- Animations
- Utility classes

### No tailwind.config.js File

There is NO `tailwind.config.js` in the project root. Current setup uses inline Tailwind config in layouts.

---

## Part 6: Theme-Specific Tailwind Extensions

### Bologna Theme Extensions

```javascript
theme: {
  container: { center: true, padding: { ... } },
  extend: {
    colors: {
      terra: { 50-900 palette },
      olive: { 50-900 palette },
      sand: { 50-900 palette },
      warm-gray: { 50-900 palette },
      primary: '#c45d3e',
      secondary: '#5c6b4d',
      accent: '#d4a574',
    },
    fontFamily: {
      sans: ['DM Sans', ...],
      display: ['Outfit', ...],
    },
    borderRadius: {
      soft: '16px',
      softer: '20px',
      pill: '9999px',
    },
    boxShadow: {
      soft: '0 4px 24px -4px rgba(...)',
      medium: '0 8px 32px -8px rgba(...)',
      elevated: '0 16px 48px -12px rgba(...)',
      glow: '0 0 40px rgba(196, 93, 62, 0.15)',
    },
    spacing: { 18: '4.5rem', 22: '5.5rem' },
    animation: {
      'fade-up': 'fadeUp 0.6s ease-out forwards',
      'scale-in': 'scaleIn 0.5s ease-out forwards',
      'slide-in': 'slideIn 0.4s ease-out forwards',
    },
    keyframes: { fadeUp, scaleIn, slideIn }
  }
}
```

### Brisbane Theme Extensions

```javascript
theme: {
  container: { center: true, padding: '2rem' },
  extend: {
    colors: {
      'luxury-navy': '#1a2744',
      'luxury-gold': '#c9a962',
      'luxury-cream': '#faf8f5',
      'luxury-charcoal': '#2d2d2d',
      'luxury-pearl': '#f5f3f0',
      primary: '#1a2744',
      secondary: '#c9a962',
    },
    fontFamily: {
      serif: ['Cormorant Garamond', ...],
      sans: ['Montserrat', ...],
    },
    borderRadius: { DEFAULT: '0', none: '0' },
    boxShadow: {
      elegant: '0 4px 20px rgba(26, 39, 68, 0.08)',
      hover: '0 8px 30px rgba(26, 39, 68, 0.12)',
    },
    letterSpacing: {
      luxury: '0.15em',
      'wide-luxury': '0.25em',
    }
  }
}
```

### Default Theme Extensions

```javascript
theme: {
  container: { center: true, padding: 'var(--container-padding)' },
  extend: {
    colors: {
      primary: 'var(--primary-color)',
      secondary: 'var(--secondary-color)',
      'services-bg': 'var(--services-bg-color)',
      'services-card': 'var(--services-card-bg)',
      'services-text': 'var(--services-text-color)',
    },
    fontFamily: {
      sans: ['var(--font-primary)', 'sans-serif'],
      serif: ['var(--font-secondary)', 'serif'],
    },
    borderRadius: {
      DEFAULT: 'var(--border-radius)',
      lg: 'var(--border-radius)',
    }
  }
}
```

---

## Part 7: CSS Variable Usage Summary

### Total CSS Variables Across All Themes

**Shared/Base Variables** (~75 variables):
- Color system (primary, secondary, accent with variants)
- Status colors (success, warning, danger, info)
- Background colors (light, dark, body, surface, muted)
- Text colors (multiple shades)
- Border colors
- Footer colors
- Typography (fonts, sizes, weights, line heights)
- Spacing (xs through 3xl)
- Layout (container variants)
- Border radius (sm, default, lg, full)
- Shadows (sm, default, lg, inner)
- Transitions (fast, normal, slow)
- Z-index scale

**Bologna-Specific** (~20 variables):
- Extended terra palette (50-600 variants)
- Extended olive palette (50-600 variants)
- Footer colors
- Font customization
- Border radius variants
- Shadow variants

**Brisbane-Specific** (~15 variables):
- Navy/Gold/Cream/Charcoal/Pearl colors
- Accent colors
- Footer colors
- Font customization
- Shadow variants (elegant, hover, card)

**Default-Specific** (~10 variables):
- Simple primary/secondary
- Services colors
- Font customization
- Border radius and container padding

**Per-Tenant Customizable** (~20 variables):
- primary_color
- secondary_color
- accent_color / action_color
- text_color
- light_color
- footer_bg_color
- footer_main_text_color
- footer_sec_text_color
- services_bg_color
- services_card_bg
- services_text_color
- font_primary
- font_secondary
- border_radius
- container_padding
- (Plus theme-specific: cream_color, charcoal_color, pearl_color)

---

## Part 8: Migration Path & Strategy

### Current Flow (CDN)

```
1. Request → Theme Layout
2. Layout loads Tailwind CDN
3. Layout includes inline tailwind.config { ... }
4. Layout renders custom_styles partial
5. Partial outputs ERB-generated CSS variables
6. Browser downloads CDN, applies inline config, applies CSS variables
7. Styles render with per-tenant customization
```

### Proposed Flow (Compiled)

```
1. Create tailwind.config.js with theme-specific configs
2. For each theme, use arbitrary value syntax for variables:
   - bg-[var(--primary-color)]
   - text-[var(--secondary-color)]
   - font-[var(--font-primary)]
3. Keep CSS variable definitions in ERB partials (for per-tenant values)
4. Compile Tailwind with: npx tailwindcss -i input.css -o output.css
5. Include compiled CSS in Rails asset pipeline
6. Keep custom_styles helper for per-tenant CSS variables only
```

### Key Challenges

1. **Per-Tenant Customization**: Cannot pre-compile arbitrary colors at build time
   - **Solution**: Use CSS variables in arbitrary values: `bg-[var(--primary-color)]`
   
2. **Theme-Specific Configurations**: Each theme has different Tailwind config
   - **Solution**: Create separate compiled stylesheets per theme OR use CSS layer system
   
3. **Dynamic CSS Variables**: Generated per-tenant during page load
   - **Solution**: Keep current system of ERB partials generating `:root { ... }`

4. **Color Palettes**: Bologna and Brisbane have hardcoded palettes
   - **Solution**: Keep hardcoded palettes in compiled CSS, use CSS variables for overrides

### Feasible Approaches

#### Approach A: Hybrid (Recommended)
- Pre-compile theme-specific Tailwind configs into separate stylesheets
- Keep CSS variables in ERB partials for per-tenant overrides
- Use arbitrary values only for per-tenant customizable properties
- Compile cost: 3 separate Tailwind builds (one per theme)

#### Approach B: Single Build with Layers
- Compile single Tailwind with all themes as separate CSS layers
- Use `@layer` for theme-specific styles
- Keep CSS variables for per-tenant
- Challenge: Tailwind CLI doesn't easily support multi-theme single build

#### Approach C: No Migration
- Keep CDN approach (not recommended for production)
- Already slower than compiled

---

## Part 9: Variables to Replace with Arbitrary Syntax

### Default Theme (Easy Migration)

Already using CSS variables in Tailwind config:

```javascript
// Current (CDN)
colors: {
  primary: 'var(--primary-color)',
  ...
}

// After migration (identical, will work with arbitrary syntax)
// Usage: bg-primary (works)
// For full flexibility: bg-[var(--primary-color)] (also works)
```

### Bologna & Brisbane Themes

Hardcoded palettes will need migration to support customization:

```javascript
// Current (hardcoded)
colors: {
  terra: { 50: '#fdf8f6', ... },
  primary: '#c45d3e',
}

// After migration (support both hardcoded AND variable)
colors: {
  terra: { 50: '#fdf8f6', ... },  // Keep hardcoded palette
  primary: 'var(--bologna-terra)',  // Use variable for customization
}

// Usage: bg-primary or bg-[var(--bologna-terra)]
```

---

## Recommendations

### 1. **Immediate Priority: Document Current System**
   - Already done in this analysis
   - Understand per-tenant customization flow

### 2. **Phase 1: Create tailwind.config.js**
   - Extract inline configs from layouts
   - Preserve theme-specific configurations
   - Test with current CDN (no breaking changes)

### 3. **Phase 2: Setup Compilation Pipeline**
   - Configure Tailwind CLI (already installed)
   - Create separate builds for each theme
   - Integrate into Rails asset pipeline

### 4. **Phase 3: Convert Layouts to Compiled CSS**
   - Remove CDN script
   - Reference compiled stylesheets
   - Keep CSS variable generation in ERB partials

### 5. **Phase 4: Optional Optimizations**
   - Purge unused styles (add template paths to Tailwind config)
   - Minify compiled CSS
   - Consider CSS layer organization

### 6. **Migration Safeguards**
   - Keep CSS variable system intact
   - Test per-tenant customization thoroughly
   - A/B test layouts with old vs. new CSS
   - No breaking changes to style_variables API

---

## Appendix: File Locations Summary

### Theme Files
```
app/themes/bologna/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/default/views/layouts/pwb/application.html.erb
```

### CSS Variable Definitions
```
app/views/pwb/custom_css/_base_variables.css.erb
app/views/pwb/custom_css/_bologna.css.erb
app/views/pwb/custom_css/_brisbane.css.erb
app/views/pwb/custom_css/_default.css.erb
app/views/pwb/custom_css/_shared.css.erb
```

### Helper Code
```
app/helpers/pwb/css_helper.rb
```

### Model Code
```
app/models/pwb/website.rb (style_variables method)
```

### Compiled Theme Stylesheets
```
app/assets/stylesheets/bologna_theme.css
app/assets/stylesheets/brisbane_theme.css
app/assets/stylesheets/pwb/themes/default.css
```

### Package Configuration
```
package.json (Tailwind 4.1.17 already installed)
```

---

## Conclusion

PropertyWebBuilder has a well-structured system for per-tenant CSS customization using CSS variables. The migration from Tailwind CDN to compiled CSS is **technically feasible** and has already been partially planned (TODO comments in layouts). 

The key to successful migration is:
1. Preserving the CSS variable system for per-tenant customization
2. Pre-compiling theme-specific Tailwind configs separately
3. Using arbitrary value syntax sparingly (only for dynamic values)
4. Maintaining the `custom_styles` helper and `Website.style_variables` API

The migration will improve:
- Page load performance (no CDN + no inline config parsing)
- Asset size (tree-shaking unused utilities)
- Development experience (standard Tailwind CLI workflow)

Estimated effort: 2-3 days for a complete migration including testing.
