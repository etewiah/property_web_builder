# Recommended Theming Architecture

This document describes the ideal, most effective and flexible theming solution for PropertyWebBuilder.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Theme System                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Palettes   │  │    Fonts     │  │    Icons     │      │
│  │              │  │              │  │              │      │
│  │ • JSON files │  │ • Dynamic    │  │ • Material   │      │
│  │ • Validated  │  │   loading    │  │   Symbols    │      │
│  │ • Light/Dark │  │ • Self-host  │  │ • Fallback   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │  CSS Generator │                        │
│                    │                │                        │
│                    │ • Variables    │                        │
│                    │ • Utilities    │                        │
│                    │ • Components   │                        │
│                    └───────┬────────┘                        │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │  Output Modes  │                        │
│                    │                │                        │
│                    │ • Dynamic CSS  │                        │
│                    │ • Compiled CSS │                        │
│                    │ • Inline CSS   │                        │
│                    └────────────────┘                        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Color Palette System

### File Structure

```
app/themes/
├── shared/
│   ├── color_schema.json          # JSON Schema for validation
│   └── palette_defaults.json      # Smart defaults
├── default/
│   └── palettes/
│       ├── classic_red.json
│       ├── modern_blue.json
│       └── elegant_gray.json
└── barcelona/
    └── palettes/
        ├── catalan_classic.json
        └── mediterranean.json
```

### Palette JSON Structure (Recommended)

```json
{
  "id": "ocean_professional",
  "name": "Ocean Professional",
  "description": "Calm, trustworthy, and professional",
  "category": "business",
  "preview_colors": ["#0077be", "#2c3e50", "#16a085"],
  "is_default": false,
  "author": "PropertyWebBuilder Team",
  "version": "1.0.0",
  
  "colors": {
    "primary_color": "#0077be",
    "secondary_color": "#2c3e50",
    "accent_color": "#16a085",
    
    "background_color": "#ffffff",
    "text_color": "#1a202c",
    "muted_text_color": "#718096",
    
    "header_background_color": "#ffffff",
    "header_text_color": "#1a202c",
    "footer_background_color": "#2c3e50",
    "footer_text_color": "#ffffff",
    
    "card_background_color": "#ffffff",
    "card_text_color": "#1a202c",
    "card_border_color": "#e2e8f0",
    
    "surface_color": "#f7fafc",
    "surface_alt_color": "#edf2f7",
    "border_color": "#e2e8f0",
    
    "link_color": "#0077be",
    "link_hover_color": "#005a8f",
    
    "button_primary_background": "#0077be",
    "button_primary_text": "#ffffff",
    "button_primary_hover": "#005a8f",
    "button_secondary_background": "#edf2f7",
    "button_secondary_text": "#2c3e50",
    "button_secondary_hover": "#e2e8f0",
    
    "input_background_color": "#ffffff",
    "input_border_color": "#cbd5e0",
    "input_focus_color": "#0077be",
    "input_text_color": "#1a202c",
    
    "success_color": "#22c55e",
    "warning_color": "#f59e0b",
    "error_color": "#ef4444",
    "info_color": "#3b82f6"
  },
  
  "modes": {
    "dark": {
      "background_color": "#121212",
      "text_color": "#e8e8e8",
      "primary_color": "#4da6ff",
      "card_background_color": "#1e1e1e",
      "surface_color": "#1e1e1e",
      "border_color": "#3d3d3d"
    }
  },
  
  "accessibility": {
    "contrast_ratios": {
      "text_on_background": 7.2,
      "primary_on_white": 4.8,
      "button_primary": 5.1
    },
    "wcag_level": "AA"
  }
}
```

### Palette Loader (Enhanced)

```ruby
module Pwb
  class PaletteLoader
    def initialize(theme_name)
      @theme_name = theme_name
      @cache = {}
    end
    
    # Load all palettes for a theme
    def palettes
      @cache[:palettes] ||= load_palettes_from_files
    end
    
    # Get a specific palette by ID
    def palette(palette_id)
      palettes.find { |p| p["id"] == palette_id }
    end
    
    # Generate CSS for a palette
    def palette_css(palette_id, mode: :light)
      palette = palette(palette_id)
      return "" unless palette
      
      colors = palette_colors(palette, mode)
      Pwb::ColorUtils.generate_palette_css_variables(colors)
    end
    
    # Generate compiled CSS with all utilities
    def compile_palette_css(palette_id)
      palette = palette(palette_id)
      return "" unless palette
      
      Pwb::PaletteCompiler.new(palette).compile
    end
    
    private
    
    def load_palettes_from_files
      palette_dir = Rails.root.join("app/themes/#{@theme_name}/palettes")
      return [] unless Dir.exist?(palette_dir)
      
      Dir.glob(palette_dir.join("*.json")).map do |file|
        palette = JSON.parse(File.read(file))
        
        # Validate
        validator = Pwb::PaletteValidator.new(palette)
        unless validator.valid?
          Rails.logger.error("Invalid palette: #{file}")
          next
        end
        
        # Apply smart defaults
        apply_defaults(palette)
      end.compact
    end
    
    def apply_defaults(palette)
      defaults = Pwb::PaletteDefaults.for_palette(palette["colors"])
      palette["colors"] = defaults.merge(palette["colors"])
      palette
    end
    
    def palette_colors(palette, mode)
      if mode == :dark && palette["modes"]&.key?("dark")
        palette["modes"]["dark"]
      else
        palette["colors"]
      end
    end
  end
end
```

---

## 2. Font System

### Font Configuration

```json
{
  "fonts": {
    "Inter": {
      "provider": "fontsource",
      "package": "@fontsource-variable/inter",
      "type": "variable",
      "weights": [400, 500, 600, 700],
      "category": "sans-serif",
      "fallback": "system-ui, -apple-system, sans-serif",
      "features": ["tabular-nums", "slashed-zero"]
    },
    "Merriweather": {
      "provider": "fontsource",
      "package": "@fontsource/merriweather",
      "type": "static",
      "weights": [400, 700],
      "styles": ["normal", "italic"],
      "category": "serif",
      "fallback": "Georgia, serif"
    },
    "Roboto": {
      "provider": "google",
      "weights": [400, 500, 700],
      "category": "sans-serif",
      "fallback": "system-ui, sans-serif",
      "subset": "latin"
    }
  },
  
  "pairings": [
    {
      "name": "Modern Professional",
      "primary": "Inter",
      "heading": "Inter",
      "description": "Clean and contemporary"
    },
    {
      "name": "Editorial Classic",
      "primary": "Inter",
      "heading": "Merriweather",
      "description": "Readable body with elegant headings"
    }
  ]
}
```

### Font Loader Service

```ruby
module Pwb
  class FontLoader
    def initialize(theme)
      @theme = theme
      @font_config = load_font_config
    end
    
    # Generate CSS imports for theme fonts
    def generate_font_css
      fonts = selected_fonts
      
      css = fonts.map do |font_name|
        font_data = @font_config["fonts"][font_name]
        next unless font_data
        
        case font_data["provider"]
        when "fontsource"
          generate_fontsource_import(font_data)
        when "google"
          generate_google_import(font_name, font_data)
        end
      end.compact
      
      css << generate_font_face_declarations(fonts)
      css.join("\n\n")
    end
    
    # Generate preconnect tags for external fonts
    def preconnect_tags
      return [] unless uses_google_fonts?
      
      [
        tag.link(rel: "preconnect", href: "https://fonts.googleapis.com"),
        tag.link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: true)
      ]
    end
    
    # Generate font-family CSS variables
    def font_variables
      primary = @theme.font_primary || "Inter"
      heading = @theme.font_heading || primary
      
      primary_data = @font_config["fonts"][primary]
      heading_data = @font_config["fonts"][heading]
      
      {
        "--pwb-font-primary" => font_stack(primary, primary_data),
        "--pwb-font-heading" => font_stack(heading, heading_data),
        "--pwb-font-size-base" => @theme.font_size_base || "16px"
      }
    end
    
    private
    
    def selected_fonts
      [@theme.font_primary, @theme.font_heading].compact.uniq
    end
    
    def generate_fontsource_import(font_data)
      if font_data["type"] == "variable"
        "@import '#{font_data["package"]}';"
      else
        weights = font_data["weights"] || [400]
        styles = font_data["styles"] || ["normal"]
        
        weights.flat_map do |weight|
          styles.map do |style|
            suffix = style == "italic" ? "-italic" : ""
            "@import '#{font_data["package"]}/#{weight}#{suffix}.css';"
          end
        end.join("\n")
      end
    end
    
    def generate_google_import(name, font_data)
      family = name.gsub(" ", "+")
      weights = (font_data["weights"] || [400]).join(";")
      subset = font_data["subset"] || "latin"
      
      "@import url('https://fonts.googleapis.com/css2?" \
      "family=#{family}:wght@#{weights}&" \
      "subset=#{subset}&display=swap');"
    end
    
    def font_stack(name, data)
      return "system-ui, sans-serif" unless data
      "'#{name}', #{data["fallback"]}"
    end
  end
end
```

---

## 3. Icon System (Already Good!)

The current icon system is well-designed. Only minor improvements needed:

### Enhanced Icon Helper

```ruby
def icon(name, options = {})
  original_name = name
  name = normalize_icon_name(name)
  
  unless ALLOWED_ICONS.include?(name)
    Rails.logger.warn("Unknown icon: #{original_name} (normalized: #{name})")
    
    # Render fallback icon
    name = "help_outline"
    options[:class] = [options[:class], "icon-fallback"].compact.join(" ")
    options[:title] ||= "Icon not found: #{original_name}"
    options[:data] ||= {}
    options[:data][:original_icon] = original_name
  end
  
  # ... rest of method
end
```

---

## 4. CSS Generation Strategy

### Dynamic Mode (Development)

Generate CSS variables on-the-fly:

```css
:root {
  --pwb-primary-color: #0077be;
  --pwb-primary-50: #e6f4fb;
  --pwb-primary-100: #cce9f7;
  /* ... all shades */
  
  --pwb-font-primary: 'Inter', system-ui, sans-serif;
  --pwb-font-heading: 'Inter', system-ui, sans-serif;
}
```

### Compiled Mode (Production)

Pre-generate all utilities:

```css
.bg-primary { background-color: var(--pwb-primary-color); }
.text-primary { color: var(--pwb-primary-color); }
.border-primary { border-color: var(--pwb-primary-color); }

.bg-primary-50 { background-color: var(--pwb-primary-50); }
/* ... all shades and utilities */
```

---

## 5. Usage in Templates

### Using Colors

```erb
<!-- Via utility classes -->
<div class="bg-primary text-white">...</div>
<div class="bg-surface border border-color">...</div>

<!-- Via CSS variables -->
<div style="background-color: var(--pwb-primary-color)">...</div>
```

### Using Fonts

```erb
<h1 class="font-heading">Property Title</h1>
<p class="font-primary">Description text</p>
```

### Using Icons

```erb
<%= icon(:home) %>
<%= icon(:bed, size: :lg) %>
<%= icon_button(:close, aria: { label: "Close" }) %>
```

---

## Benefits of This Architecture

1. **Flexibility:** Easy to add new palettes, fonts, icons
2. **Performance:** Compiled mode for production, dynamic for dev
3. **Maintainability:** Single source of truth, validated
4. **Accessibility:** Built-in contrast checking, ARIA support
5. **Developer Experience:** Clear APIs, good documentation
6. **Extensibility:** Easy to add new themes without touching core code

This is the recommended target architecture for PropertyWebBuilder's theming system.

