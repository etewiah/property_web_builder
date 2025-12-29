# Theme and Color Palette System Architecture

## Overview

PropertyWebBuilder uses a sophisticated multi-tenant theme system where each website can have a unique visual appearance. The system separates structural themes from color palettes, allowing both to be independently selected and customized.

**Key Components:**
- **Themes** - Provide page templates, layouts, and structure (in `app/themes/`)
- **Color Palettes** - Define color schemes within themes (in `app/themes/{theme}/palettes/`)
- **CSS Variables** - Dynamic style values applied per-tenant (generated via ERB partials)
- **Tailwind CSS** - Pre-built theme stylesheets for each theme
- **Style Variables** - Customizable theme settings stored per-website

## 1. Theme Structure

### Directory Layout

```
app/themes/
├── config.json                          # Master theme configuration
├── shared/
│   └── color_schema.json               # JSON Schema for palette validation
├── default/
│   ├── palettes/
│   │   ├── classic_red.json
│   │   ├── ocean_blue.json
│   │   ├── forest_green.json
│   │   └── sunset_orange.json
│   └── views/
│       ├── pwb/components/
│       ├── pwb/sections/
│       ├── pwb/search/
│       └── pwb/props/
├── brisbane/
│   ├── palettes/
│   │   ├── gold_navy.json              # Default palette
│   │   ├── rose_gold.json
│   │   ├── platinum.json
│   │   ├── emerald_luxury.json
│   │   └── azure_prestige.json
│   └── views/
│       ├── pwb/components/
│       ├── pwb/sections/
│       └── pwb/props/
├── bologna/
│   ├── palettes/
│   │   ├── terracotta_classic.json     # Default palette
│   │   ├── sage_stone.json
│   │   ├── coastal_warmth.json
│   │   └── modern_slate.json
│   └── views/
├── barcelona/                           # Disabled theme (enabled: false)
│   ├── palettes/
│   └── views/
└── biarritz/                            # Disabled theme (enabled: false)
    ├── palettes/
    └── views/
```

### Theme Inheritance

Themes can inherit from parent themes to reduce duplication:

```json
{
  "name": "brisbane",
  "friendly_name": "Brisbane Luxury Theme",
  "parent_theme": "default",
  "version": "2.0.0"
}
```

When a theme has a parent:
1. View paths are checked in order: theme → parent → default Rails views
2. Style variables are merged with parent defaults
3. Page part configurations cascade down

## 2. Color Palette System

### Palette Structure

Palettes are stored as individual JSON files in `app/themes/{theme}/palettes/`:

```json
{
  "id": "ocean_blue",
  "name": "Ocean Blue",
  "description": "Professional and trustworthy",
  "is_default": false,
  "preview_colors": ["#3498db", "#2c3e50", "#e74c3c"],
  "colors": {
    "primary_color": "#3498db",
    "secondary_color": "#2c3e50",
    "accent_color": "#e74c3c",
    "background_color": "#ffffff",
    "text_color": "#333333",
    "header_background_color": "#ffffff",
    "header_text_color": "#333333",
    "footer_background_color": "#2c3e50",
    "footer_text_color": "#ffffff",
    "light_color": "#f0f7fc",
    "link_color": "#3498db",
    "action_color": "#3498db"
  }
}
```

### Multi-Mode Palettes (Light/Dark)

Palettes support explicit dark mode colors using a `modes` structure:

```json
{
  "id": "modern_split",
  "name": "Modern Split",
  "modes": {
    "light": {
      "primary_color": "#3b82f6",
      "secondary_color": "#64748b",
      "background_color": "#ffffff",
      "text_color": "#1f2937"
    },
    "dark": {
      "primary_color": "#60a5fa",
      "secondary_color": "#cbd5e1",
      "background_color": "#0f172a",
      "text_color": "#f1f5f9"
    }
  }
}
```

When dark mode is explicit, it takes precedence. Otherwise, dark mode is auto-generated via `ColorUtils.generate_dark_mode_colors()`.

### Required Color Keys

Every palette must include these 9 required colors:
- `primary_color` - Main brand color for CTAs and links
- `secondary_color` - Supporting color for secondary elements
- `accent_color` - Highlight color for special elements
- `background_color` - Main page background
- `text_color` - Primary text color
- `header_background_color` - Header/nav background
- `header_text_color` - Header/nav text
- `footer_background_color` - Footer background
- `footer_text_color` - Footer text

Optional colors (auto-inherit fallbacks if not provided):
- `card_background_color`, `border_color`, `surface_color`, `success_color`, `error_color`, `link_hover_color`, etc.

### Palette Loading and Caching

The `PaletteLoader` service loads palettes with intelligent caching:

```ruby
loader = Pwb::PaletteLoader.new
palettes = loader.load_theme_palettes("brisbane")
# => { "gold_navy" => {...}, "rose_gold" => {...}, ... }

palette = loader.get_palette("brisbane", "gold_navy")
default = loader.get_default_palette("brisbane")
light_colors = loader.get_light_colors("brisbane", "gold_navy")
dark_colors = loader.get_dark_colors("brisbane", "gold_navy")
```

**Fallback Strategy:**
1. Check `app/themes/{theme}/palettes/*.json` files
2. If directory doesn't exist, load from `config.json` (legacy)
3. All palettes are validated against the JSON schema

## 3. Website Style Configuration

### Database Storage

The `Pwb::Website` model stores style configuration:

```ruby
class Website < ApplicationRecord
  # Key attributes:
  theme_name: String              # "default", "brisbane", "bologna", etc.
  selected_palette: String        # "gold_navy", "rose_gold", etc.
  style_variables_for_theme: JSON # { "default" => { vars... } }
  dark_mode_setting: String       # "light_only" | "auto" | "dark"
  raw_css: Text                   # User-provided custom CSS
end
```

### Style Variables Access

The `Pwb::WebsiteStyleable` concern provides methods to access and manage styles:

```ruby
website.style_variables
# => Merges palette colors with customized variables

website.current_theme
# => Returns Pwb::Theme object for website.theme_name

website.apply_palette!("rose_gold")
# => Updates selected_palette and refreshes cached styles

website.effective_palette_id
# => Returns selected_palette or theme default

website.palette_options_for_select
# => Array of [name, id] pairs for form selects
```

### Default Style Variables

Every website starts with these defaults:

```ruby
DEFAULT_STYLE_VARIABLES = {
  "primary_color" => "#e91b23",
  "secondary_color" => "#3498db",
  "action_color" => "green",
  "body_style" => "siteLayout.wide",
  "theme" => "light",
  "font_primary" => "Open Sans",
  "font_secondary" => "Vollkorn",
  "border_radius" => "0.5rem",
  "container_padding" => "1rem"
}
```

## 4. CSS Variable Generation

### Dynamic CSS Variables

CSS variables are generated per-website using ERB templates in `app/views/pwb/custom_css/`:

#### `_base_variables.css.erb`

Generates `:root` CSS custom properties from `website.style_variables`:

```css
:root {
  /* Color System */
  --pwb-primary: #e91b23;
  --pwb-primary-light: color-mix(in srgb, #e91b23 70%, white);
  --pwb-primary-dark: color-mix(in srgb, #e91b23 70%, black);
  --pwb-primary-rgb: 233, 27, 35;

  --pwb-secondary: #3498db;
  --pwb-accent: #27ae60;

  /* Status colors */
  --pwb-success: #28a745;
  --pwb-warning: #ffc107;
  --pwb-danger: #dc3545;

  /* Typography */
  --pwb-font-primary: Inter, system-ui, sans-serif;
  --pwb-font-secondary: Georgia, serif;
  --pwb-font-size-base: 16px;
  --pwb-line-height-base: 1.6;

  /* Layout */
  --pwb-container-max-width: 1200px;
  --pwb-radius: 0.5rem;

  /* Transitions */
  --pwb-transition-fast: 150ms;
  --pwb-transition-normal: 300ms;
}
```

#### `_default.css.erb` (Theme-Specific)

Theme-specific CSS that references variables:

```css
:root {
  --primary-color: <%= @current_website.style_variables['primary_color'] || '#3b82f6' %>;
  --secondary-color: <%= @current_website.style_variables['secondary_color'] || '#1e40af' %>;
  --services-bg-color: <%= @current_website.style_variables['services_bg_color'] || '#f9fafb' %>;
  --font-primary: <%= @current_website.style_variables['font_primary'] || 'Open Sans' %>;
  --border-radius: <%= @current_website.style_variables['border_radius'] || '0.5rem' %>;
}

.service-card {
  background: var(--services-card-bg);
  border-radius: var(--border-radius);
  color: var(--services-text-color);
}
```

#### `_shared.css.erb`

Legacy CSS with direct variable access:

```css
footer .col h5 {
  color: <%= @current_website.style_variables["footer_sec_text_color"] || "#ccc" %>;  
}

.services-section .single-service .icon-service {
  color: <%= @current_website.style_variables["primary_color"] %>;
}

<%= @current_website.raw_css %>
```

### Dark Mode Support

Dark mode is controlled by `website.dark_mode_setting`:

- **`"light_only"`** (default) - No dark mode CSS generated
- **`"auto"`** - CSS respects system preference via `@media (prefers-color-scheme: dark)`
- **`"dark"`** - Applies dark mode class to HTML element

Dark mode CSS generated in `_base_variables.css.erb`:

```css
@media (prefers-color-scheme: dark) {
  :root.pwb-auto-dark {
    --pwb-primary: #f3111a;
    --pwb-text-primary: #e8e8e8;
    --pwb-bg-body: #121212;
    /* ... */
  }
}

.pwb-dark,
html.pwb-dark {
  --pwb-primary: #f3111a;
  --pwb-text-primary: #e8e8e8;
  --pwb-bg-body: #121212;
}
```

## 5. Tailwind CSS Compilation

### Build Process

Tailwind CSS is compiled per-theme to separate CSS files using the CLI:

**`package.json` Scripts:**

```json
{
  "scripts": {
    "tailwind:default": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-input.css -o ./app/assets/builds/tailwind-default.css",
    "tailwind:brisbane": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-brisbane.css -o ./app/assets/builds/tailwind-brisbane.css",
    "tailwind:bologna": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-bologna.css -o ./app/assets/builds/tailwind-bologna.css",
    "tailwind:build": "npm run tailwind:default && npm run tailwind:brisbane && npm run tailwind:bologna",
    "tailwind:build:prod": "npm run tailwind:default:prod && npm run tailwind:brisbane:prod && npm run tailwind:bologna:prod"
  }
}
```

### Theme Input Files

Each theme has a corresponding input file:

- `app/assets/stylesheets/tailwind-input.css` → `tailwind-default.css`
- `app/assets/stylesheets/tailwind-brisbane.css` → `tailwind-brisbane.css`
- `app/assets/stylesheets/tailwind-bologna.css` → `tailwind-bologna.css`

**Example: `tailwind-input.css`**

```css
@import "tailwindcss";

@font-face {
  font-family: 'Open Sans';
  font-weight: 400;
  src: url('https://cdn.jsdelivr.net/npm/@fontsource/open-sans@5.2.5/files/open-sans-latin-400-normal.woff2');
}

@theme {
  --color-primary: var(--primary-color, #3b82f6);
  --color-secondary: var(--secondary-color, #64748b);
  --font-family-sans: 'Open Sans', var(--font-primary, system-ui, sans-serif);
  --radius: var(--border-radius, 0.375rem);
}

/* Custom responsive rules for layouts */
@media (min-width: 1024px) {
  .search-layout .search-sidebar {
    width: 25%;
  }
  .search-layout .search-results {
    width: 75%;
  }
}
```

### CSS Generation Strategy

**Hardcoded Tailwind Colors vs. CSS Variables:**

1. **Hardcoded Colors** (in Tailwind classes like `bg-blue-500`)
   - Come from Tailwind's default palette
   - Compiled into stylesheet at build time
   - Cannot be changed per-tenant

2. **CSS Variables** (like `bg-[var(--primary-color)]`)
   - Defined in `_base_variables.css.erb`
   - Changed dynamically per website
   - Allow full color customization

**Current Implementation:**
- Most Tailwind utilities use default colors (hardcoded)
- Per-tenant colors use CSS variables approach
- Examples: `--pwb-primary`, `--pwb-secondary`, `--primary-color`

### Pre-compiled Stylesheets

The build pipeline generates pre-compiled CSS:

```
app/assets/builds/
├── tailwind-default.css        # Pre-built, includes all Tailwind utilities
├── tailwind-brisbane.css       # Pre-built, includes all Tailwind utilities
├── tailwind-bologna.css        # Pre-built, includes all Tailwind utilities
├── tailwind-barcelona.css
├── tailwind-biarritz.css
├── critical-default.css        # (Optional) Above-the-fold CSS for LCP
├── critical-brisbane.css       # Extracted via: npm run critical:extract
├── brisbane_theme.css          # Additional theme-specific CSS
└── fontawesome-subset.css      # Optimized Font Awesome icons
```

## 6. Theme Selection and Serving

### Theme Resolution

When rendering a page, themes are resolved in this order:

```ruby
# app/controllers/pwb/application_controller.rb
def set_view_paths_for_theme
  theme_name = current_website&.theme_name
  theme_name = params[:theme] if params[:theme].present?
  theme_name = theme_name.present? ? theme_name : "default"
  
  prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"
end
```

This allows:
1. Website to have a selected theme
2. Preview of different themes via `?theme=brisbane` param
3. Fallback to "default" theme

### Stylesheet Inclusion

In layouts (e.g., `app/views/layouts/pwb/page_part.html.erb`):

```erb
<%
  theme_name = @current_website&.theme_name || 'default'
  tailwind_file = "tailwind-#{theme_name}"
%>

<%= stylesheet_link_tag tailwind_file, "data-turbo-track": "reload" %>
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" />

<% case theme_name %>
<% when 'brisbane' %>
  <%= stylesheet_link_tag "brisbane_theme", media: "all" %>
<% else %>
  <%= stylesheet_link_tag "pwb/themes/default", media: "all" %>
<% end %>

<style>
  <%= custom_styles(theme_name) %>
</style>
```

**What loads:**
1. Pre-compiled Tailwind CSS: `tailwind-{theme_name}.css`
2. Flowbite component library
3. Theme-specific CSS file
4. Dynamic CSS variables from ERB template

### CSS Helper

The `Pwb::CssHelper` renders dynamic CSS:

```ruby
def custom_styles(theme_name)
  render partial: "pwb/custom_css/#{theme_name}", locals: {}, formats: :css
end
```

This renders one of:
- `app/views/pwb/custom_css/_default.css.erb`
- `app/views/pwb/custom_css/_brisbane.css.erb`
- `app/views/pwb/custom_css/_bologna.css.erb`
- etc.

## 7. Color Palette UI Configuration

### Model: Pwb::Theme

`app/models/pwb/theme.rb` provides theme metadata (uses ActiveJSON from config.json):

```ruby
theme = Pwb::Theme.find_by(name: "brisbane")

theme.palettes
# => { "gold_navy" => {...}, "rose_gold" => {...}, ... }

theme.default_palette_id
# => "gold_navy"

theme.palette_colors("gold_navy")
# => { "primary_color" => "#c9a962", "secondary_color" => "#1a1a2e", ... }

theme.palette_options
# => [["Gold & Navy", "gold_navy"], ["Rose Gold", "rose_gold"], ...]

theme.style_variables
# => { "primary_color" => {...}, "secondary_color" => {...}, ... }
```

### Theme Configuration UI

The theme configuration system is exposed in admin UI:

1. **Theme Selection** - Choose base theme (default, brisbane, bologna, barcelona, biarritz)
2. **Palette Selection** - Choose color palette within theme
3. **Style Variables** - Customize individual style settings
4. **Dark Mode** - Toggle dark mode support (light_only, auto, dark)
5. **Custom CSS** - Add raw CSS for additional customization

### Services: PaletteValidator

`app/services/pwb/palette_validator.rb` validates palette JSON against schema:

```ruby
validator = Pwb::PaletteValidator.new
result = validator.validate(palette_hash)

result.valid?       # => true/false
result.errors       # => ["Missing required color: primary_color"]
result.warnings     # => ["Migrated legacy key 'footer_bg_color' to 'footer_background_color'"]
result.normalized_palette  # => Cleaned up palette with legacy key mappings
```

Performs validation:
- Checks required keys (id, name)
- Validates hex color format
- Enforces 9 required colors
- Checks for either `colors` or `modes.light` structure
- Normalizes legacy key names

## 8. Current Limitations and Design Decisions

### Hardcoded vs. Dynamic Colors

**Currently Hardcoded (from Tailwind defaults):**
- Utility classes like `bg-blue-500`, `text-red-600`
- These are compiled at build time and cannot change per-tenant
- Workaround: Use `bg-[var(--primary-color)]` syntax instead

**Dynamic per Tenant:**
- `--pwb-primary`, `--pwb-secondary`, `--pwb-accent`
- Header/footer colors
- Custom typography sizes
- Spacing and border radius

**Implication:** To change button colors per-theme, use `class="bg-[var(--pwb-primary)]"` instead of `class="bg-primary"`.

### Multiple Stylesheet Approach

The system uses separate pre-built CSS files per theme rather than single stylesheet:

**Advantages:**
- Each website loads only its theme's CSS
- Pre-built files serve faster than dynamic generation
- Can be CDN-cached per theme

**Disadvantages:**
- Build pipeline is complex (5+ npm scripts)
- Theme changes require rebuild
- Larger total CSS footprint (each theme has full Tailwind)

### Palette Storage Strategy

Palettes stored as separate JSON files rather than database records:

**Advantages:**
- Version controlled with codebase
- No database migrations needed
- Fallback to config.json for legacy compatibility
- Easy to template/copy across themes

**Disadvantages:**
- Cannot create new palettes in UI (must add to repo)
- Palette changes require code deployment
- No multi-tenancy for palette editing

## 9. Data Flow Diagram

```
Website Tenant
    ↓
website.theme_name ("brisbane")
website.selected_palette ("gold_navy")
website.style_variables_for_theme
website.dark_mode_setting
    ↓
[Controller: set_view_paths_for_theme]
    ↓
Prepend view path: app/themes/brisbane/views/
    ↓
[Layout renders stylesheet_link_tag]
    ↓
Load: app/assets/builds/tailwind-brisbane.css (pre-compiled)
Load: brisbane_theme.css (static)
Render inline: app/views/pwb/custom_css/_brisbane.css.erb
    ↓
[ERB renders with @current_website]
    ↓
CSS variables generated from:
  - website.selected_palette → palette colors
  - website.style_variables → customized variables
  - website.dark_mode_setting → dark mode CSS
    ↓
All styles applied to rendered HTML
```

## 10. Key Files Reference

| File | Purpose |
|------|---------|
| `app/themes/config.json` | Master theme config with style_variables schema |
| `app/themes/{theme}/palettes/*.json` | Color palette definitions |
| `app/themes/shared/color_schema.json` | JSON Schema for palette validation |
| `app/models/pwb/website.rb` | Tenant website model |
| `app/models/pwb/theme.rb` | Theme metadata loader (ActiveJSON) |
| `app/models/concerns/pwb/website_styleable.rb` | Style management concern |
| `app/services/pwb/palette_loader.rb` | Loads and caches palettes from disk |
| `app/services/pwb/palette_validator.rb` | Validates palette JSON structure |
| `app/helpers/pwb/css_helper.rb` | Renders dynamic CSS templates |
| `app/views/pwb/custom_css/_*.css.erb` | Per-theme dynamic CSS |
| `app/assets/stylesheets/tailwind-input.css` | Tailwind base input |
| `app/assets/stylesheets/tailwind-{theme}.css` | Theme-specific Tailwind input |
| `app/assets/builds/tailwind-{theme}.css` | Pre-compiled theme CSS |
| `package.json` | npm build scripts for Tailwind compilation |

## 11. Extending the System

### Adding a New Theme

1. Create theme directory: `app/themes/new_theme/`
2. Create views: `app/themes/new_theme/views/pwb/...`
3. Create default palette: `app/themes/new_theme/palettes/default.json`
4. Add to `config.json`:
   ```json
   {
     "name": "new_theme",
     "friendly_name": "New Theme",
     "id": "new_theme",
     "parent_theme": "default"
   }
   ```
5. Create Tailwind input: `app/assets/stylesheets/tailwind-new_theme.css`
6. Add npm scripts:
   ```json
   "tailwind:new_theme": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-new_theme.css -o ./app/assets/builds/tailwind-new_theme.css"
   ```
7. Run build: `npm run tailwind:new_theme`

### Adding a New Palette to Existing Theme

1. Create JSON file: `app/themes/{theme}/palettes/new_palette.json`
2. Validate against schema
3. No rebuild needed - loaded dynamically at runtime

### Customizing Colors Per-Website

Use the `apply_palette!` method or update `selected_palette`:

```ruby
website = Pwb::Website.find(1)
website.apply_palette!("gold_navy")
```

This updates `selected_palette` and the colors are immediately available via `website.style_variables`.

---

**Last Updated:** 2025-12-29
**Author:** Research conducted by Claude Code
