---
name: theme-creation
description: Create new themes for PropertyWebBuilder. Use when creating custom themes, styling websites, or modifying theme templates. Handles theme registration, view templates, CSS, and asset configuration.
---

# Theme Creation for PropertyWebBuilder

## Theme System Overview

PropertyWebBuilder uses a multi-tenant theme system where each website can have its own theme. The system supports:
- **Theme inheritance** - Child themes extend parent themes
- **Color palettes** - Multiple pre-defined color schemes per theme
- **Page Part Library** - 20+ pre-built, customizable sections
- **CSS custom properties** - Native CSS variables for easy customization
- **Per-tenant customization** - Each website can override theme defaults
- **WCAG AA accessibility** - Built-in contrast checking utilities
- **Dark mode support** - Automatic or explicit dark mode colors

### Current Themes (January 2025)

| Theme | Parent | Status | Palettes | Description |
|-------|--------|--------|----------|-------------|
| `default` | None | Active | 6 | Base Tailwind/Flowbite theme |
| `brisbane` | default | Active | 6 | Luxury real estate (gold/navy) |
| `bologna` | default | Active | 4 | Traditional European style |
| `barcelona` | default | Disabled | 4 | Incomplete - needs work |
| `biarritz` | default | Disabled | 4 | Needs accessibility fixes |

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Theme Registry | `app/themes/config.json` | Theme definitions |
| Theme Model | `app/models/pwb/theme.rb` | ActiveJSON model with inheritance |
| Palette Loader | `app/services/pwb/palette_loader.rb` | Load palettes from JSON |
| Palette Validator | `app/services/pwb/palette_validator.rb` | Validate against schema |
| Color Utils | `app/services/pwb/color_utils.rb` | WCAG contrast, shade generation |
| Palette Compiler | `app/services/pwb/palette_compiler.rb` | Compile CSS for production |
| Website Styleable | `app/models/concerns/pwb/website_styleable.rb` | Per-website styles |
| CSS Templates | `app/views/pwb/custom_css/_*.css.erb` | Dynamic CSS generation |

### Theme Resolution Flow

1. Request comes in with subdomain (tenant identification)
2. `ApplicationController#set_theme_path` determines theme from:
   - URL parameter `?theme=name` (if whitelisted)
   - Website's `theme_name` field
   - Fallback to "default"
3. Theme view paths are prepended (child first, then parent)
4. Views render from theme directory, falling back through inheritance chain

## Creating a New Theme

### Step 1: Register the Theme in config.json

Add to `app/themes/config.json`:

```json
{
  "name": "mytheme",
  "friendly_name": "My Custom Theme",
  "id": "mytheme",
  "version": "1.0.0",
  "enabled": true,
  "parent_theme": "default",
  "description": "A custom theme for my agency",
  "author": "Your Name",
  "tags": ["modern", "clean"],
  "supports": {
    "page_parts": [
      "heroes/hero_centered",
      "heroes/hero_split",
      "features/feature_grid_3col",
      "testimonials/testimonial_carousel",
      "cta/cta_banner"
    ],
    "layouts": ["default", "landing", "full_width"],
    "color_schemes": ["light", "dark"],
    "features": {
      "sticky_header": true,
      "back_to_top": true,
      "animations": true
    }
  },
  "style_variables": {
    "colors": {
      "primary_color": {
        "type": "color",
        "default": "#your-brand-color",
        "label": "Primary Color"
      },
      "secondary_color": {
        "type": "color",
        "default": "#your-secondary-color",
        "label": "Secondary Color"
      }
    },
    "typography": {
      "font_primary": {
        "type": "font_select",
        "default": "Open Sans",
        "label": "Primary Font",
        "options": ["Open Sans", "Roboto", "Montserrat"]
      }
    }
  }
}
```

### Step 2: Create Directory Structure

```bash
mkdir -p app/themes/mytheme/views/layouts/pwb
mkdir -p app/themes/mytheme/views/pwb/welcome
mkdir -p app/themes/mytheme/views/pwb/components
mkdir -p app/themes/mytheme/views/pwb/sections
mkdir -p app/themes/mytheme/views/pwb/pages
mkdir -p app/themes/mytheme/views/pwb/props
mkdir -p app/themes/mytheme/views/pwb/search
mkdir -p app/themes/mytheme/views/pwb/shared
mkdir -p app/themes/mytheme/palettes  # For color palette JSON files
mkdir -p app/themes/mytheme/page_parts  # For custom page part templates
```

### Step 3: Create Default Palette

Create `app/themes/mytheme/palettes/default.json`:

```json
{
  "id": "default",
  "name": "Default",
  "description": "Default color scheme for mytheme",
  "is_default": true,
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
    "light_color": "#f8f9fa",
    "link_color": "#3498db",
    "action_color": "#3498db"
  }
}
```

### Step 4: Copy and Customize Layout

Copy from parent theme:
```bash
cp app/themes/default/views/layouts/pwb/application.html.erb app/themes/mytheme/views/layouts/pwb/
```

Edit `app/themes/mytheme/views/layouts/pwb/application.html.erb`:

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= yield(:page_title) || @current_website&.site_name %></title>
    <%= yield(:page_head) %>

    <%# Tailwind CSS for this theme %>
    <%= stylesheet_link_tag "tailwind-mytheme", "data-turbo-track": "reload" %>

    <%# Flowbite components %>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />

    <%# Material Symbols for icons %>
    <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0&display=swap" rel="stylesheet" />

    <%# Dynamic CSS variables %>
    <style>
      <%= custom_styles("mytheme") %>
    </style>

    <%= javascript_include_tag "pwb/application", async: false %>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js"></script>
    <%= csrf_meta_tags %>
  </head>
  <body class="tnt-body mytheme-theme <%= @current_website&.body_style %> bg-gray-50 text-gray-900">
    <div class="flex flex-col min-h-screen">
      <%= render partial: '/pwb/header', locals: { not_devise: true } %>
      <main class="flex-grow">
        <%= render 'devise/shared/messages' %>
        <%= yield %>
      </main>
      <%= render partial: '/pwb/footer', locals: {} %>
    </div>
    <%= yield(:page_script) %>
  </body>
</html>
```

### Step 5: Create Theme CSS Partial

Create `app/views/pwb/custom_css/_mytheme.css.erb`:

```erb
/* Theme: mytheme */
<%
  # Get palette colors merged with website overrides
  styles = @current_website&.style_variables || {}

  primary_color = styles["primary_color"] || "#3498db"
  secondary_color = styles["secondary_color"] || "#2c3e50"
  accent_color = styles["accent_color"] || "#e74c3c"
  background_color = styles["background_color"] || "#ffffff"
  text_color = styles["text_color"] || "#333333"
  header_bg = styles["header_background_color"] || "#ffffff"
  header_text = styles["header_text_color"] || "#333333"
  footer_bg = styles["footer_background_color"] || "#2c3e50"
  footer_text = styles["footer_text_color"] || "#ffffff"
  font_primary = styles["font_primary"] || "Open Sans"
  border_radius = styles["border_radius"] || "0.5rem"
%>

<%= render partial: 'pwb/custom_css/base_variables',
           locals: {
             primary_color: primary_color,
             secondary_color: secondary_color,
             accent_color: accent_color,
             background_color: background_color,
             text_color: text_color,
             font_primary: font_primary,
             border_radius: border_radius
           } %>

:root {
  --header-bg: <%= header_bg %>;
  --header-text: <%= header_text %>;
  --footer-bg: <%= footer_bg %>;
  --footer-text: <%= footer_text %>;
}

/* Theme-specific overrides */
.mytheme-theme header {
  background-color: var(--header-bg);
  color: var(--header-text);
}

.mytheme-theme footer {
  background-color: var(--footer-bg);
  color: var(--footer-text);
}

/* Custom raw CSS from admin */
<%= @current_website&.raw_css %>
```

### Step 6: Create Tailwind Input File

Create `app/assets/stylesheets/tailwind-mytheme.css`:

```css
@import "tailwindcss";

/* Font imports */
@font-face {
  font-family: 'Open Sans';
  font-weight: 400;
  src: url('https://cdn.jsdelivr.net/npm/@fontsource/open-sans@5.2.5/files/open-sans-latin-400-normal.woff2');
}

/* Theme configuration */
@theme {
  --color-primary: var(--primary-color, #3498db);
  --color-secondary: var(--secondary-color, #2c3e50);
  --color-accent: var(--accent-color, #e74c3c);
  --font-family-sans: 'Open Sans', var(--font-primary, system-ui, sans-serif);
  --radius: var(--border-radius, 0.375rem);
}

/* PWB utility classes */
@layer utilities {
  .bg-pwb-primary { background-color: var(--pwb-primary); }
  .bg-pwb-secondary { background-color: var(--pwb-secondary); }
  .text-pwb-primary { color: var(--pwb-primary); }
  .text-pwb-secondary { color: var(--pwb-secondary); }
  .border-pwb-primary { border-color: var(--pwb-primary); }
}
```

### Step 7: Add Build Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "tailwind:mytheme": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-mytheme.css -o ./app/assets/builds/tailwind-mytheme.css --watch",
    "tailwind:mytheme:prod": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-mytheme.css -o ./app/assets/builds/tailwind-mytheme.css --minify"
  }
}
```

### Step 8: Test the Theme

```ruby
# Via Rails console
theme = Pwb::Theme.find_by(name: 'mytheme')
theme.view_paths           # Verify path resolution
theme.palettes             # Check palettes loaded
theme.default_palette_id   # Verify default palette

# Update a website to use the theme
website = Pwb::Website.first
website.update(theme_name: 'mytheme')
```

```bash
# Build Tailwind CSS
npm run tailwind:mytheme:prod

# Via URL parameter (if enabled)
http://localhost:3000/?theme=mytheme
```

## Creating Color Palettes

### Palette File Structure

Palettes are stored in `app/themes/[theme]/palettes/*.json`:

```json
{
  "id": "my_palette",
  "name": "My Palette",
  "description": "A beautiful color palette",
  "is_default": false,
  "preview_colors": ["#primary", "#secondary", "#accent"],
  "colors": {
    "primary_color": "#e91b23",
    "secondary_color": "#2c3e50",
    "accent_color": "#3498db",
    "background_color": "#ffffff",
    "text_color": "#333333",
    "header_background_color": "#ffffff",
    "header_text_color": "#333333",
    "footer_background_color": "#2c3e50",
    "footer_text_color": "#ffffff",
    "light_color": "#f8f9fa",
    "link_color": "#e91b23",
    "action_color": "#e91b23"
  }
}
```

### Required Colors (9 mandatory)

| Key | Purpose |
|-----|---------|
| `primary_color` | Main brand color for CTAs and links |
| `secondary_color` | Supporting color for secondary elements |
| `accent_color` | Highlight color for special elements |
| `background_color` | Main page background |
| `text_color` | Primary text color |
| `header_background_color` | Header/nav background |
| `header_text_color` | Header/nav text |
| `footer_background_color` | Footer background |
| `footer_text_color` | Footer text |

### Dark Mode Support

For explicit dark mode colors, use the `modes` structure:

```json
{
  "id": "modern_dark",
  "name": "Modern with Dark Mode",
  "modes": {
    "light": {
      "primary_color": "#3498db",
      "background_color": "#ffffff",
      "text_color": "#333333"
    },
    "dark": {
      "primary_color": "#5dade2",
      "background_color": "#121212",
      "text_color": "#e8e8e8"
    }
  }
}
```

If you only provide `colors`, dark mode is auto-generated using `ColorUtils.generate_dark_mode_colors()`.

### Validation & Tools

```bash
# Validate all palettes
rake palettes:validate

# List available palettes for a theme
rake palettes:list[mytheme]

# Check WCAG contrast compliance
rake palettes:contrast[mytheme,my_palette]

# Generate shade scale for a color
rake palettes:shades[#3498db]
```

```ruby
# In Rails console
loader = Pwb::PaletteLoader.new
palettes = loader.load_theme_palettes("mytheme")
light = loader.get_light_colors("mytheme", "my_palette")
dark = loader.get_dark_colors("mytheme", "my_palette")

# Validate a palette
validator = Pwb::PaletteValidator.new
result = validator.validate(palette_hash)
result.valid?   # => true/false
result.errors   # => ["Missing required color: primary_color"]
```

## Search Page Layout Requirements

**IMPORTANT: Search pages MUST follow responsive layout requirements.**

### Desktop Layout (>=1024px)

Filters MUST be displayed BESIDE results (side-by-side), NOT above them:

```
+--------------------------------------------------+
|  +------------+  +----------------------------+  |
|  | Filters    |  | Search Results             |  |
|  | (1/4)      |  | (3/4 width)                |  |
|  +------------+  +----------------------------+  |
+--------------------------------------------------+
```

### Required HTML Structure

```erb
<div class="flex flex-wrap -mx-4">
  <!-- Sidebar Filters (1/4 on desktop, full on mobile) -->
  <div class="w-full lg:w-1/4 px-4 mb-6 lg:mb-0">
    <button class="lg:hidden w-full ..."
            data-controller="search-form"
            data-action="click->search-form#toggleFilters">
      Filter Properties
    </button>
    <div id="sidebar-filters" class="hidden lg:block">
      <%= render 'pwb/searches/search_form_for_sale' %>
    </div>
  </div>

  <!-- Search Results (3/4 on desktop, full on mobile) -->
  <div class="w-full lg:w-3/4 px-4">
    <div id="inmo-search-results">
      <%= render 'search_results' %>
    </div>
  </div>
</div>
```

## PWB CSS Class Naming

Use semantic PWB classes for consistency:

```css
/* Colors */
.bg-pwb-primary { background-color: var(--pwb-primary); }
.bg-pwb-secondary { background-color: var(--pwb-secondary); }
.text-pwb-primary { color: var(--pwb-primary); }

/* Buttons */
.pwb-btn--primary { background-color: var(--pwb-primary); }
.pwb-btn--secondary { background-color: var(--pwb-secondary); }
.pwb-btn--outline { border: 2px solid var(--pwb-primary); }

/* Cards */
.pwb-card { border-radius: var(--pwb-border-radius); }

/* Grid */
.pwb-grid--2col { grid-template-columns: repeat(2, 1fr); }
.pwb-grid--3col { grid-template-columns: repeat(3, 1fr); }
.pwb-grid--4col { grid-template-columns: repeat(4, 1fr); }
```

## WCAG Accessibility Requirements

### Contrast Ratios (WCAG 2.1 AA)

| Text Type | Minimum Ratio |
|-----------|---------------|
| Normal text (<18px) | 4.5:1 |
| Large text (>=18px bold or >=24px) | 3:1 |
| UI components & graphics | 3:1 |

### Check Contrast in Ruby

```ruby
# Check if colors meet WCAG AA
Pwb::ColorUtils.wcag_aa_compliant?('#ffffff', '#333333')
# => true (14.0:1 ratio)

# Get exact contrast ratio
Pwb::ColorUtils.contrast_ratio('#ffffff', '#9ca3af')
# => 2.9 (fails AA - needs 4.5:1)

# Get suggested text color for a background
Pwb::ColorUtils.suggest_text_color('#1a2744')
# => '#ffffff' (white for dark backgrounds)
```

## Theme Inheritance

### How It Works

Child themes inherit from parent themes:

```ruby
theme = Pwb::Theme.find_by(name: 'brisbane')
theme.parent_theme        # => "default"
theme.parent              # => <Pwb::Theme name="default">
theme.inheritance_chain   # => [brisbane, default]
theme.view_paths          # => [brisbane/views, default/views, app/views]
```

### View Resolution Order

1. Check child theme: `app/themes/brisbane/views/`
2. Check parent theme: `app/themes/default/views/`
3. Check application: `app/views/`

## Troubleshooting

### Theme Not Loading

1. Check entry exists in `app/themes/config.json`
2. Verify `"enabled": true` is set
3. Verify JSON syntax is valid
4. Restart Rails server after config changes
5. Check: `Pwb::Theme.find_by(name: 'mytheme')`

### Styles Not Applying

1. Verify CSS partial exists: `app/views/pwb/custom_css/_mytheme.css.erb`
2. Verify Tailwind CSS is built: `app/assets/builds/tailwind-mytheme.css`
3. Check body class matches theme name (`.mytheme-theme`)
4. Clear Rails cache: `Rails.cache.clear`

### Palette Not Found

1. Check file exists: `app/themes/mytheme/palettes/default.json`
2. Validate JSON syntax
3. Run: `rake palettes:validate`
4. Check: `Pwb::PaletteLoader.new.load_theme_palettes('mytheme')`

## Documentation Reference

- `docs/theming/README.md` - Documentation index
- `docs/theming/THEME_AND_COLOR_SYSTEM.md` - Complete architecture
- `docs/theming/color-palettes/COLOR_PALETTES_ARCHITECTURE.md` - Palette system
- `docs/theming/THEME_CREATION_CHECKLIST.md` - Step-by-step checklist
- `app/themes/shared/color_schema.json` - Palette JSON schema
