---
name: theme-creation
description: Create new themes for PropertyWebBuilder. Use when creating custom themes, styling websites, or modifying theme templates. Handles theme registration, view templates, CSS, and asset configuration.
---

# Theme Creation for PropertyWebBuilder

## Theme System Overview

PropertyWebBuilder uses a multi-tenant theme system where each website can have its own theme. The system supports:
- **Theme inheritance** - Child themes extend parent themes
- **Page Part Library** - 20+ pre-built, customizable sections
- **CSS custom properties** - Native CSS variables for easy customization
- **Per-tenant customization** - Each website can override theme defaults
- **Custom Liquid tags** - Dynamic content rendering in templates

### Available Themes (as of Dec 2025)

| Theme | Parent | Status | Description |
|-------|--------|--------|-------------|
| `default` | None | Active | Base Tailwind/Flowbite theme |
| `brisbane` | default | Active | Luxury real estate theme with navy/gold palette |

### Key Components

1. **Theme Registry**: `app/themes/config.json` - JSON array defining all themes with full configuration
2. **Theme Model**: `app/models/pwb/theme.rb` - ActiveJSON model with inheritance support
3. **Page Part Library**: `app/lib/pwb/page_part_library.rb` - Registry of available page parts
4. **Theme Settings Schema**: `app/lib/pwb/theme_settings_schema.rb` - UI schema for customization
5. **CSS Variables**: `app/views/pwb/custom_css/_base_variables.css.erb` - Core CSS custom properties
6. **Custom Liquid Tags**: `app/lib/pwb/liquid_tags/` - Property cards, featured properties, etc.
7. **Theme Directories**: `app/themes/[theme_name]/views/` - View templates per theme

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
  },
  "page_parts_config": {
    "heroes": {
      "default_variant": "hero_centered",
      "available_variants": ["hero_centered", "hero_split"]
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
mkdir -p app/themes/mytheme/page_parts  # For custom page part templates
```

## Search Page Layout Requirements

**IMPORTANT: Search pages MUST follow the responsive layout requirements below.**

### Desktop Layout (≥1024px / lg breakpoint)

On large screens, search filters MUST be displayed BESIDE search results (side-by-side), NOT above them taking full page width.

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
<!-- Container with flex-wrap -->
<div class="flex flex-wrap -mx-4">

  <!-- Sidebar Filters (1/4 on desktop, full on mobile) -->
  <div class="w-full lg:w-1/4 px-4 mb-6 lg:mb-0">
    <!-- Mobile toggle button (only visible on mobile) -->
    <button class="lg:hidden w-full ..."
            data-controller="search-form"
            data-action="click->search-form#toggleFilters">
      Filter Properties
    </button>

    <!-- Filter form (hidden on mobile, visible on desktop) -->
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

### Critical Tailwind Classes

| Element | Classes | Purpose |
|---------|---------|---------|
| Container | `flex flex-wrap` | Enables side-by-side layout |
| Sidebar | `w-full lg:w-1/4` | 100% mobile, 25% desktop |
| Results | `w-full lg:w-3/4` | 100% mobile, 75% desktop |
| Filter toggle | `lg:hidden` | Only visible on mobile |
| Filter form | `hidden lg:block` | Hidden mobile, visible desktop |

### Verification Checklist

When creating search pages (buy.html.erb, rent.html.erb):

- [ ] Container uses `flex flex-wrap`
- [ ] Sidebar div has `w-full lg:w-1/4`
- [ ] Results div has `w-full lg:w-3/4`
- [ ] Test at 1024px width - filters beside results
- [ ] Test at 768px width - filters collapse

**Reference:** See `docs/ui/SEARCH_UI_SPECIFICATION.md` and `docs/ui/SEARCH_LAYOUT_PLAN.md` for complete specifications.

### Step 3: Copy Files from Parent Theme

Since your theme extends default:
```bash
# Only copy files you want to override
cp app/themes/default/views/layouts/pwb/application.html.erb app/themes/mytheme/views/layouts/pwb/
cp app/themes/default/views/pwb/_header.html.erb app/themes/mytheme/views/pwb/
cp app/themes/default/views/pwb/_footer.html.erb app/themes/mytheme/views/pwb/
```

### Step 4: Create Custom CSS Partial

Create `app/views/pwb/custom_css/_mytheme.css.erb`:

```erb
/* Theme: mytheme */
/* Uses CSS custom properties from the base variables system */

<%
  # Get theme defaults merged with website overrides
  theme = Pwb::Theme.find_by(name: 'mytheme')
  defaults = theme&.default_style_variables || {}
  styles = defaults.merge(@current_website&.style_variables || {})

  primary_color = styles["primary_color"] || "#e91b23"
  secondary_color = styles["secondary_color"] || "#3498db"
  accent_color = styles["accent_color"] || "#27ae60"
  font_primary = styles["font_primary"] || "Open Sans"
  font_heading = styles["font_heading"] || "Montserrat"
%>

<%= render partial: 'pwb/custom_css/base_variables',
           locals: {
             primary_color: primary_color,
             secondary_color: secondary_color,
             accent_color: accent_color,
             font_primary: font_primary,
             font_heading: font_heading,
             background_color: styles["background_color"] || "#ffffff",
             text_color: styles["text_color"] || "#333333",
             border_radius: styles["border_radius"] || "8px",
             container_width: styles["container_width"] || "1200px"
           } %>

<%= render partial: 'pwb/custom_css/component_styles' %>

/* Theme-specific overrides */
.mytheme-theme {
  /* Add custom styles here */
}

.mytheme-theme .hero-section {
  /* Custom hero styling */
}
```

### Step 5: Update the Layout

Edit `app/themes/mytheme/views/layouts/pwb/application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= yield(:page_title) %></title>
    <%= yield(:page_head) %>

    <%# Tailwind CSS %>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
      tailwind.config = {
        theme: {
          container: { center: true, padding: 'var(--pwb-container-padding)' },
          extend: {
            colors: {
              primary: 'var(--pwb-primary)',
              secondary: 'var(--pwb-secondary)',
              accent: 'var(--pwb-accent)',
            },
            fontFamily: {
              sans: ['var(--pwb-font-primary)', 'sans-serif'],
              heading: ['var(--pwb-font-heading)', 'serif'],
            },
            borderRadius: {
              DEFAULT: 'var(--pwb-border-radius)',
            }
          }
        }
      }
    </script>

    <%# Flowbite for UI components %>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />

    <%# Theme styles with CSS variables %>
    <style>
      <%= custom_styles "mytheme" %>
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

### Step 6: Test the Theme

```ruby
# Via Rails console
theme = Pwb::Theme.find_by(name: 'mytheme')
theme.view_paths           # Verify path resolution
theme.available_page_parts # Check supported page parts
theme.as_api_json         # Full theme info

# Update a website to use the theme
website = Pwb::Website.first
website.update(theme_name: 'mytheme')
```

```bash
# Via URL parameter (if enabled)
http://localhost:3000/?theme=mytheme
```

## Page Part Library

### Available Categories

| Category | Description | Page Parts |
|----------|-------------|------------|
| `heroes` | Hero sections | hero_centered, hero_split, hero_search |
| `features` | Feature showcases | feature_grid_3col, feature_cards_icons |
| `testimonials` | Customer reviews | testimonial_carousel, testimonial_grid |
| `cta` | Call to action | cta_banner, cta_split_image |
| `stats` | Statistics | stats_counter |
| `teams` | Team profiles | team_grid |
| `galleries` | Image galleries | image_gallery |
| `faqs` | FAQ sections | faq_accordion |
| `pricing` | Pricing tables | pricing_table |

### Using Page Parts in Templates

```liquid
{% page_part "heroes/hero_centered" %}
{% page_part "features/feature_grid_3col" %}
{% page_part "cta/cta_banner", style: "primary" %}
```

### Creating Custom Page Part Templates

Create theme-specific page part variants in `app/themes/mytheme/page_parts/`:

```liquid
<!-- app/themes/mytheme/page_parts/heroes/hero_custom.liquid -->
<section class="mytheme-hero pwb-hero">
  <div class="pwb-container">
    <h1 class="pwb-hero__title">{{ page_part.title.content }}</h1>
    <p class="pwb-hero__subtitle">{{ page_part.subtitle.content }}</p>
    {% if page_part.cta_text.content %}
      <a href="{{ page_part.cta_link.content }}" class="pwb-btn--primary">
        {{ page_part.cta_text.content }}
      </a>
    {% endif %}
  </div>
</section>
```

## Custom Liquid Tags

### Available Tags

```liquid
<!-- Render a property card -->
{% property_card 123 %}
{% property_card property_id, style: "compact" %}

<!-- Render featured properties -->
{% featured_properties %}
{% featured_properties limit: 6, type: "sale" %}
{% featured_properties limit: 4, style: "card", columns: 4 %}

<!-- Render a contact form -->
{% contact_form %}
{% contact_form style: "compact" %}
{% contact_form style: "inline", property_id: 123 %}

<!-- Embed another page part -->
{% page_part "heroes/hero_centered" %}
{% page_part "cta/cta_banner" %}
```

## CSS Custom Properties System

### Base Variables (`_base_variables.css.erb`)

```css
:root {
  /* Colors */
  --pwb-primary: <%= primary_color %>;
  --pwb-primary-light: color-mix(in srgb, <%= primary_color %> 70%, white);
  --pwb-primary-dark: color-mix(in srgb, <%= primary_color %> 70%, black);
  --pwb-secondary: <%= secondary_color %>;
  --pwb-accent: <%= accent_color %>;

  /* Typography */
  --pwb-font-primary: <%= font_primary %>;
  --pwb-font-heading: <%= font_heading %>;
  --pwb-font-size-base: <%= font_size_base %>;

  /* Layout */
  --pwb-container-width: <%= container_width %>;
  --pwb-border-radius: <%= border_radius %>;

  /* Spacing */
  --pwb-space-xs: 0.25rem;
  --pwb-space-sm: 0.5rem;
  --pwb-space-md: 1rem;
  --pwb-space-lg: 1.5rem;
  --pwb-space-xl: 2rem;
}
```

### Component CSS Classes

The system provides ready-to-use component classes:

```css
/* Grid system */
.pwb-grid--2col { grid-template-columns: repeat(2, 1fr); }
.pwb-grid--3col { grid-template-columns: repeat(3, 1fr); }
.pwb-grid--4col { grid-template-columns: repeat(4, 1fr); }

/* Buttons */
.pwb-btn--primary { background-color: var(--pwb-primary); }
.pwb-btn--secondary { background-color: var(--pwb-secondary); }
.pwb-btn--outline { border: 2px solid var(--pwb-primary); }

/* Cards */
.pwb-card { border-radius: var(--pwb-border-radius); box-shadow: var(--pwb-shadow-md); }

/* Heroes */
.pwb-hero { font-family: var(--pwb-font-heading); }
.pwb-hero__title { font-size: 3rem; }
```

## Theme Inheritance

### How It Works

Child themes automatically inherit from parent themes:

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

### Page Part Resolution

1. Check theme's custom page part template
2. Check parent theme's template
3. Check database-stored PagePart
4. Fall back to PagePartLibrary default template

## Per-Tenant Customization

### Website Style Variables

Each website can override theme defaults:

```ruby
website = Pwb::Website.first
website.style_variables
# => { "primary_color" => "#ff0000", "font_primary" => "Roboto" }

# Update style variables
website.update(style_variables: {
  "primary_color" => "#00ff00",
  "secondary_color" => "#333333",
  "font_primary" => "Montserrat"
})
```

### Merging with Theme Defaults

```ruby
theme = Pwb::Theme.find_by(name: website.theme_name)
defaults = theme.default_style_variables
effective_styles = defaults.merge(website.style_variables || {})
```

## Theme Settings Schema

### Available Field Types

| Type | Description | Properties |
|------|-------------|------------|
| `:color` | Color picker | `default`, `css_variable` |
| `:font_select` | Font dropdown | `options`, `default` |
| `:select` | Generic dropdown | `options`, `default` |
| `:range` | Slider | `min`, `max`, `step`, `unit` |
| `:toggle` | Boolean switch | `default` |

### Schema Sections

- `colors` - Primary, secondary, accent, background, text colors
- `typography` - Font families, sizes, line heights
- `layout` - Container width, padding, spacing
- `header` - Header style, colors
- `footer` - Footer style, colors, columns
- `buttons` - Button styles, sizes
- `appearance` - Border radius, shadows, color scheme

## Troubleshooting

### Theme Not Loading

1. Check entry exists in `app/themes/config.json`
2. Verify JSON syntax is valid
3. Restart Rails server after config changes
4. Check: `Pwb::Theme.find_by(name: 'mytheme')`

### Styles Not Applying

1. Verify CSS variables are defined in `:root`
2. Check body class matches theme name (`.mytheme-theme`)
3. Ensure `custom_styles` helper is called with correct theme name
4. Clear Rails cache: `Rails.cache.clear`

### Page Part Not Rendering

1. Check template exists: `Pwb::PagePartLibrary.template_exists?(key)`
2. Verify Liquid syntax in template
3. Check `block_contents` has data for current locale
4. Verify page part key is in theme's `supports.page_parts`

### Inheritance Not Working

1. Verify `parent_theme` is set correctly in config.json
2. Check parent theme exists
3. Test: `theme.parent.present?`
4. Verify view paths: `theme.view_paths`

## Examples

**Create a luxury theme extending default:**
1. Add to config.json with `"parent_theme": "default"`
2. Copy only files you need to customize
3. Create custom CSS with gold/navy palette
4. Set custom font families (Playfair Display, Cormorant Garamond)

**Add a new page part variant:**
1. Create template in `app/themes/mytheme/page_parts/heroes/hero_video.liquid`
2. Add to theme's `supports.page_parts` in config.json
3. Update `page_parts_config` with new variant

**Override a specific component:**
1. Copy file from parent theme to your theme's views directory
2. Modify as needed
3. Child theme file automatically takes precedence

## Creating Color Palettes

### Palette File Location
Palettes are stored in separate JSON files per theme:
```
app/themes/[theme_name]/palettes/
├── classic_red.json
├── ocean_blue.json
├── forest_green.json
└── sunset_orange.json
```

### Palette JSON Structure
Create a new palette file with this structure:

```json
{
  "id": "my_palette",
  "name": "My Palette",
  "description": "A custom color palette",
  "preview_colors": ["#primary", "#secondary", "#accent"],
  "is_default": false,
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

### Dark Mode Support
For explicit dark mode, use the `modes` structure instead of `colors`:

```json
{
  "id": "modern_dark",
  "name": "Modern with Dark Mode",
  "supports_dark_mode": true,
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

# List available palettes
rake palettes:list

# Generate CSS with dark mode
rake palettes:css_dark[mytheme,my_palette]

# Check accessibility contrast
rake palettes:contrast[mytheme,my_palette]

# Generate shade scale for a color
rake palettes:shades[#3498db]
```

### Using Palettes in Ruby
```ruby
loader = Pwb::PaletteLoader.new
light = loader.get_light_colors("mytheme", "my_palette")
dark = loader.get_dark_colors("mytheme", "my_palette")
css = loader.generate_full_css("mytheme", "my_palette")  # Includes dark mode
```

## Brisbane Theme Reference (Luxury Theme Pattern)

### Color Palette
```css
--luxury-navy: #1a2744;
--luxury-gold: #c9a962;
--luxury-cream: #faf8f5;
```

### Typography
- Headings: Playfair Display (serif)
- Body: Cormorant Garamond (serif)
- Letter spacing: 0.02em for headings

### Key Design Elements
1. Sharp corners (no border-radius)
2. Gold accents on icons and dividers
3. Subtle shadows with navy tint
4. Hover lift effects
5. Decorative gold dividers

### Files
```
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/pwb/_header.html.erb
app/themes/brisbane/views/pwb/_footer.html.erb
app/themes/brisbane/views/pwb/welcome/index.html.erb
```

## Documentation Reference

For complete documentation, see:
- `docs/architecture/COLOR_PALETTES_ARCHITECTURE.md` - Color palette system
- `docs/11_Theming_System.md` - Full theming system documentation
- `docs/08_PagePart_System.md` - Page part system details
- `app/lib/pwb/page_part_library.rb` - Page part definitions
- `app/lib/pwb/theme_settings_schema.rb` - Settings schema
- `app/themes/shared/color_schema.json` - Palette JSON schema
- `app/services/pwb/palette_loader.rb` - Palette loading service
- `app/services/pwb/color_utils.rb` - Color utilities
