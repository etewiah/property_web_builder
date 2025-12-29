# Theme System - Implementation Patterns & Examples

## Pattern 1: Color Configuration in config.json

Each theme in `app/themes/config.json` includes:

```json
{
  "name": "brisbane",
  "friendly_name": "Brisbane Luxury Theme",
  "parent_theme": "default",
  "style_variables": {
    "colors": {
      "primary_color": {
        "type": "color",
        "default": "#c9a962",
        "label": "Primary Color",
        "description": "Luxurious gold accent color"
      },
      "secondary_color": {
        "type": "color",
        "default": "#1a1a2e",
        "label": "Secondary Color",
        "description": "Deep navy for elegant contrast"
      }
    },
    "typography": {
      "font_primary": {
        "type": "font_select",
        "default": "Cormorant Garamond",
        "label": "Primary Font",
        "options": ["Cormorant Garamond", "Libre Baskerville", "Playfair Display"]
      }
    },
    "layout": {
      "border_radius": {
        "type": "select",
        "default": "4px",
        "label": "Border Radius",
        "options": ["0px", "2px", "4px", "6px", "8px"]
      }
    }
  }
}
```

**Palettes nested in config.json (legacy):**

```json
{
  "palettes": {
    "gold_navy": {
      "id": "gold_navy",
      "name": "Gold & Navy",
      "is_default": true,
      "colors": {
        "primary_color": "#c9a962",
        "secondary_color": "#1a1a2e",
        "accent_color": "#16213e",
        "background_color": "#fafafa",
        "text_color": "#2d2d2d",
        "header_background_color": "#1a1a2e",
        "header_text_color": "#ffffff",
        "footer_background_color": "#1a1a2e",
        "footer_text_color": "#e8e8e8"
      }
    }
  }
}
```

**Modern approach (separate files):**
- `app/themes/brisbane/palettes/gold_navy.json`
- `app/themes/brisbane/palettes/rose_gold.json`
- etc.

## Pattern 2: Dynamic CSS Variables

### Generation in ERB Template

File: `app/views/pwb/custom_css/_base_variables.css.erb`

```erb
<%
  # Extract from website.style_variables with defaults
  primary_color = vars["primary_color"] || "#e91b23"
  secondary_color = vars["secondary_color"] || "#3498db"
  font_primary = vars["font_primary"] || "Inter, system-ui, sans-serif"
  border_radius = vars["border_radius"] || "0.5rem"
%>

:root {
  /* Colors */
  --pwb-primary: <%= primary_color %>;
  --pwb-primary-light: color-mix(in srgb, <%= primary_color %> 70%, white);
  --pwb-primary-dark: color-mix(in srgb, <%= primary_color %> 70%, black);
  
  --pwb-secondary: <%= secondary_color %>;
  
  /* Typography */
  --pwb-font-primary: <%= font_primary %>;
  --pwb-font-size-base: <%= vars["font_size_base"] || "16px" %>;
  
  /* Layout */
  --pwb-radius: <%= border_radius %>;
  --pwb-container-max-width: <%= vars["container_max_width"] || "1200px" %>;
}
```

### Usage in Component CSS

```css
.button {
  background-color: var(--pwb-primary);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: var(--pwb-radius);
  font-family: var(--pwb-font-primary);
  font-size: var(--pwb-font-size-base);
}

.button:hover {
  background-color: var(--pwb-primary-dark);
}
```

## Pattern 3: Palette JSON Structure

### Single Color Set (Most Common)

File: `app/themes/brisbane/palettes/gold_navy.json`

```json
{
  "id": "gold_navy",
  "name": "Gold & Navy",
  "description": "Classic luxury with timeless elegance",
  "is_default": true,
  "preview_colors": ["#c9a962", "#1a1a2e", "#16213e"],
  "colors": {
    "primary_color": "#c9a962",
    "secondary_color": "#1a1a2e",
    "accent_color": "#16213e",
    "background_color": "#fafafa",
    "text_color": "#2d2d2d",
    "light_color": "#fafafa",
    "link_color": "#c9a962",
    "header_background_color": "#1a1a2e",
    "header_text_color": "#ffffff",
    "footer_background_color": "#1a1a2e",
    "footer_text_color": "#e8e8e8",
    "action_color": "#c9a962",
    "card_background_color": "#ffffff",
    "border_color": "#d1d5db"
  }
}
```

### Explicit Dark Mode

File: `app/themes/example/palettes/modern_split.json`

```json
{
  "id": "modern_split",
  "name": "Modern Split",
  "description": "Different colors for light and dark modes",
  "supports_dark_mode": true,
  "preview_colors": ["#3b82f6", "#64748b", "#f3f4f6"],
  "modes": {
    "light": {
      "primary_color": "#3b82f6",
      "secondary_color": "#64748b",
      "accent_color": "#ec4899",
      "background_color": "#ffffff",
      "text_color": "#1f2937",
      "header_background_color": "#ffffff",
      "header_text_color": "#1f2937",
      "footer_background_color": "#1e293b",
      "footer_text_color": "#f1f5f9"
    },
    "dark": {
      "primary_color": "#60a5fa",
      "secondary_color": "#cbd5e1",
      "accent_color": "#ec4899",
      "background_color": "#0f172a",
      "text_color": "#f1f5f9",
      "header_background_color": "#0f172a",
      "header_text_color": "#f1f5f9",
      "footer_background_color": "#020617",
      "footer_text_color": "#e2e8f0"
    }
  }
}
```

## Pattern 4: Website Style Management

### Model Methods (Pwb::WebsiteStyleable)

```ruby
# Get style variables for rendering
@website.style_variables
# => Merged palette colors + custom variables

# Get current theme object
@website.current_theme
# => Pwb::Theme.find_by(name: @website.theme_name)

# Apply palette
@website.apply_palette!("rose_gold")
# => Updates selected_palette attribute

# Get effective palette ID
@website.effective_palette_id
# => selected_palette if valid, else theme default

# Access palette colors directly
@website.current_theme.palette_colors("gold_navy")
# => { "primary_color" => "#c9a962", ... }

# List available palettes
@website.available_palettes
# => { "gold_navy" => {...}, "rose_gold" => {...}, ... }

# Dark mode methods
@website.dark_mode_enabled?
# => true if setting is "auto" or "dark"

@website.force_dark_mode?
# => true if setting is "dark"

@website.dark_mode_html_class
# => "pwb-dark" if forced, nil otherwise
```

### Rendering CSS

```ruby
# In views/pwb/custom_css/_brisbane.css.erb
<%= render partial: '/pwb/custom_css/base_variables', locals: {} %>

:root {
  --primary-color: <%= @current_website.style_variables['primary_color'] || '#3b82f6' %>;
  --secondary-color: <%= @current_website.style_variables['secondary_color'] || '#1e40af' %>;
}

.button-primary {
  background-color: var(--primary-color);
}
```

## Pattern 5: Theme-Aware Views

### Template Inheritance

```erb
<!-- app/themes/brisbane/views/pwb/components/_hero.html.erb -->
<section class="hero hero-brisbane">
  <!-- Theme-specific layout for brisbane -->
</section>

<!-- Falls back to if not found: -->
<!-- app/themes/default/views/pwb/components/_hero.html.erb -->
<!-- Then: app/views/pwb/components/_hero.html.erb -->
```

### Conditional Styling

```erb
<!-- app/views/pwb/components/_search_box.html.erb -->
<div class="search-box 
  <%= case @current_website.theme_name
    when 'brisbane' then 'search-brisbane'
    when 'bologna' then 'search-bologna'
    else 'search-default'
  end %>">
  <!-- content -->
</div>
```

## Pattern 6: Tailwind CSS Per-Theme

### Input File Structure

File: `app/assets/stylesheets/tailwind-brisbane.css`

```css
@import "tailwindcss";

/* Self-hosted fonts for the theme */
@font-face {
  font-family: 'Playfair Display';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url('https://cdn.jsdelivr.net/npm/@fontsource/playfair-display@5.2.10/files/playfair-display-latin-700-normal.woff2');
}

/* Theme-specific color overrides in Tailwind */
@theme {
  --color-primary: var(--primary-color, #c9a962);
  --color-secondary: var(--secondary-color, #1a1a2e);
  --font-family-sans: 'Playfair Display', Georgia, serif;
  --radius: 0.25rem; /* Brisbane uses square edges */
}

/* Custom responsive rules */
@media (min-width: 1024px) {
  .luxury-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
  }
}

/* Per-theme component overrides */
.brisbane-card {
  border: 1px solid rgba(201, 169, 98, 0.2);
  box-shadow: 0 8px 24px rgba(26, 26, 46, 0.12);
}
```

### Build Process

```json
{
  "scripts": {
    "tailwind:brisbane": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-brisbane.css -o ./app/assets/builds/tailwind-brisbane.css",
    "tailwind:brisbane:prod": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-brisbane.css -o ./app/assets/builds/tailwind-brisbane.css --minify"
  }
}
```

## Pattern 7: Dark Mode CSS Generation

### Auto-Generated Dark Mode

If palette doesn't have explicit dark colors, they're auto-generated:

```ruby
# app/services/pwb/palette_loader.rb
def get_dark_colors(theme_name, palette_id)
  palette = get_palette(theme_name, palette_id)
  return {} unless palette

  if has_explicit_dark_mode?(palette)
    return palette.dig("modes", "dark").dup
  end

  # Auto-generate from light colors
  light_colors = extract_light_colors(palette)
  ColorUtils.generate_dark_mode_colors(light_colors)
end
```

### Dark Mode CSS Output

```css
/* Generated in _base_variables.css.erb */

/* Auto mode - respects system preference */
@media (prefers-color-scheme: dark) {
  :root.pwb-auto-dark {
    --pwb-primary: #f3111a;
    --pwb-primary-light: color-mix(in srgb, #f3111a 70%, white);
    --pwb-text-primary: #e8e8e8;
    --pwb-bg-body: #121212;
  }
}

/* Forced dark mode */
.pwb-dark,
html.pwb-dark {
  --pwb-primary: #f3111a;
  --pwb-primary-light: color-mix(in srgb, #f3111a 70%, white);
  --pwb-text-primary: #e8e8e8;
  --pwb-bg-body: #121212;
}
```

## Pattern 8: Service Layer

### PaletteLoader Service

```ruby
# Load all palettes for a theme
loader = Pwb::PaletteLoader.new
palettes = loader.load_theme_palettes("brisbane")
# Caches internally, loads from disk only once

# Get specific palette
palette = loader.get_palette("brisbane", "gold_navy")

# Generate CSS variables
css = loader.generate_css_variables("brisbane", "gold_navy")
css_with_dark = loader.generate_full_css("brisbane", "gold_navy")

# Validate
results = loader.validate_theme_palettes("brisbane")
```

### PaletteValidator Service

```ruby
validator = Pwb::PaletteValidator.new
result = validator.validate(palette_json)

if result.valid?
  palette = result.normalized_palette
  # Use palette
else
  errors = result.errors
  # ["Missing required color: primary_color", ...]
end

# Normalize legacy keys
validator.normalize_palette(palette, warnings = [])
# Converts footer_bg_color → footer_background_color, etc.
```

## Pattern 9: Layout Integration

### Page Rendering Flow

```erb
<!-- app/views/layouts/pwb/page_part.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <%
      theme_name = @current_website&.theme_name || 'default'
      tailwind_file = "tailwind-#{theme_name}"
    %>
    
    <!-- Load pre-compiled theme CSS -->
    <%= stylesheet_link_tag tailwind_file, "data-turbo-track": "reload" %>
    
    <!-- Load component library -->
    <link href="flowbite.min.css" rel="stylesheet" />
    
    <!-- Load theme-specific static CSS -->
    <% case theme_name %>
    <% when 'brisbane' %>
      <%= stylesheet_link_tag "brisbane_theme", media: "all" %>
    <% else %>
      <%= stylesheet_link_tag "pwb/themes/default", media: "all" %>
    <% end %>
    
    <!-- Inline dynamic CSS variables -->
    <style>
      <%= custom_styles(theme_name) %>
    </style>
  </head>
  
  <body class="<%= @current_website&.theme_name || 'default' %>-theme
              <%= @current_website&.dark_mode_html_class %>">
    <div class="page-part-container">
      <%= yield %>
    </div>
  </body>
</html>
```

## Pattern 10: Admin Form Integration

### Theme Selection UI

```erb
<!-- Theme selection dropdown -->
<select name="website[theme_name]">
  <% Pwb::Theme.enabled.each do |theme| %>
    <option value="<%= theme.name %>"
            <%= 'selected' if website.theme_name == theme.name %>>
      <%= theme.friendly_name %>
    </option>
  <% end %>
</select>

<!-- Palette selection dropdown -->
<select name="website[selected_palette]">
  <% @website.palette_options_for_select.each do |name, id| %>
    <option value="<%= id %>"
            <%= 'selected' if website.selected_palette == id %>>
      <%= name %>
    </option>
  <% end %>
</select>

<!-- Dark mode setting -->
<select name="website[dark_mode_setting]">
  <% Pwb::Website.dark_mode_setting_options.each do |label, value| %>
    <option value="<%= value %>"
            <%= 'selected' if website.dark_mode_setting == value %>>
      <%= label %>
    </option>
  <% end %>
</select>
```

## Best Practices

1. **Use CSS Variables** - Prefer `var(--pwb-primary)` over hardcoded colors
2. **Validate Palettes** - Always run validator on new palette files
3. **Test Dark Mode** - Test with all dark mode settings
4. **Document Defaults** - Keep default values in schema for clarity
5. **Cache Palettes** - PaletteLoader caches to disk; clear cache on updates
6. **Separate Concerns** - Keep theme views in `app/themes/`, not `app/views/`
7. **Preview with ?theme param** - Test different themes in development
8. **Rebuild Tailwind** - Don't forget `npm run tailwind:build` after changes

---

**Related Documentation:**
- [Theme and Color System Architecture](./THEME_AND_COLOR_SYSTEM.md)
- [Quick Reference Guide](./THEME_SYSTEM_QUICK_REFERENCE.md)
