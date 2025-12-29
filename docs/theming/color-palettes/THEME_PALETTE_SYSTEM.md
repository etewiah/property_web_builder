# Theme Palette System Design

## Overview

Replace arbitrary color pickers with curated, theme-specific color palettes that ensure visual harmony and accessibility.

## Current State

- Each theme defines `style_variables.colors` with individual color pickers
- Users can pick any color, often resulting in clashing combinations
- PresetStyle model exists but is legacy (Material Design palettes, not theme-specific)
- Bologna theme CSS reads from `@current_website.style_variables["primary_color"]` etc.

## Proposed Architecture

### 1. Theme-Specific Palettes in config.json

Add a `palettes` section to each theme's config:

```json
{
  "name": "bologna",
  "palettes": {
    "terracotta_classic": {
      "id": "terracotta_classic",
      "name": "Terracotta Classic",
      "description": "Warm Mediterranean tones with earthy accents",
      "preview_colors": ["#c45d3e", "#5c6b4d", "#d4a574"],
      "is_default": true,
      "colors": {
        "primary_color": "#c45d3e",
        "secondary_color": "#5c6b4d",
        "accent_color": "#d4a574",
        "text_color": "#3d3d3d",
        "light_color": "#faf9f7",
        "footer_bg_color": "#3d3d3d",
        "footer_main_text_color": "#d5d0c8",
        "action_color": "#c45d3e"
      }
    },
    "sage_stone": {
      "id": "sage_stone",
      "name": "Sage & Stone",
      "description": "Natural greens with warm neutral tones",
      "preview_colors": ["#5c6b4d", "#8b9c7a", "#c4b5a0"],
      "colors": {
        "primary_color": "#5c6b4d",
        "secondary_color": "#8b9c7a",
        "accent_color": "#c4b5a0",
        "text_color": "#3d3d3d",
        "light_color": "#f8f7f4",
        "footer_bg_color": "#3d3d3d",
        "footer_main_text_color": "#d5d0c8",
        "action_color": "#5c6b4d"
      }
    },
    "coastal_warmth": {
      "id": "coastal_warmth",
      "name": "Coastal Warmth",
      "description": "Ocean blues with warm sand accents",
      "preview_colors": ["#2d5a7b", "#c45d3e", "#e8c9a9"],
      "colors": {
        "primary_color": "#2d5a7b",
        "secondary_color": "#c45d3e",
        "accent_color": "#e8c9a9",
        "text_color": "#2d3748",
        "light_color": "#fafbfc",
        "footer_bg_color": "#2d3748",
        "footer_main_text_color": "#e2e8f0",
        "action_color": "#2d5a7b"
      }
    },
    "modern_slate": {
      "id": "modern_slate",
      "name": "Modern Slate",
      "description": "Contemporary grays with warm terracotta accent",
      "preview_colors": ["#4a5568", "#718096", "#c45d3e"],
      "colors": {
        "primary_color": "#4a5568",
        "secondary_color": "#718096",
        "accent_color": "#c45d3e",
        "text_color": "#2d3748",
        "light_color": "#f7fafc",
        "footer_bg_color": "#2d3748",
        "footer_main_text_color": "#e2e8f0",
        "action_color": "#c45d3e"
      }
    }
  }
}
```

### 2. Database Changes

Add to `pwb_websites` table:

```ruby
# Migration
add_column :pwb_websites, :selected_palette, :string
```

### 3. Model Changes

**app/models/concerns/pwb/website_styleable.rb:**

```ruby
module Pwb
  module WebsiteStyleable
    # Get the current palette for this website
    def current_palette
      theme = Pwb::Theme.find_by(name: theme_name)
      return {} unless theme
      
      palette_id = selected_palette || theme.default_palette_id
      theme.palettes[palette_id] || theme.palettes.values.first || {}
    end
    
    # Get style variables (palette colors merged with any custom overrides)
    def style_variables
      palette_colors = current_palette["colors"] || {}
      custom_overrides = style_variables_for_theme["custom"] || {}
      
      palette_colors.merge(custom_overrides)
    end
    
    # Get available palettes for current theme
    def available_palettes
      theme = Pwb::Theme.find_by(name: theme_name)
      theme&.palettes || {}
    end
  end
end
```

**app/models/pwb/theme.rb:**

```ruby
class Theme < ActiveJSON::Base
  # Get all palettes for this theme
  def palettes
    attributes["palettes"] || {}
  end
  
  # Get the default palette ID
  def default_palette_id
    palettes.find { |_, p| p["is_default"] }&.first || palettes.keys.first
  end
  
  # Get a specific palette by ID
  def palette(palette_id)
    palettes[palette_id]
  end
end
```

### 4. Admin UI Changes

**app/views/site_admin/website/settings/_appearance.html.erb:**

```erb
<div class="palette-selector">
  <h3>Color Palette</h3>
  <p class="text-muted">Choose a curated color scheme for your website</p>
  
  <div class="palette-grid">
    <% @current_website.available_palettes.each do |id, palette| %>
      <label class="palette-option <%= 'selected' if @current_website.selected_palette == id %>">
        <input type="radio" 
               name="pwb_website[selected_palette]" 
               value="<%= id %>"
               <%= 'checked' if @current_website.selected_palette == id %>>
        
        <div class="palette-preview">
          <% palette["preview_colors"].each do |color| %>
            <span class="color-swatch" style="background-color: <%= color %>"></span>
          <% end %>
        </div>
        
        <div class="palette-info">
          <strong><%= palette["name"] %></strong>
          <small><%= palette["description"] %></small>
        </div>
      </label>
    <% end %>
  </div>
</div>
```

### 5. CSS Helper Changes

**app/helpers/pwb/css_helper.rb** (no changes needed - already reads from style_variables)

### 6. Suggested Palettes by Theme

#### Bologna Theme (Mediterranean Modern)
| Palette | Primary | Secondary | Accent | Character |
|---------|---------|-----------|--------|-----------|
| Terracotta Classic | #c45d3e | #5c6b4d | #d4a574 | Warm, earthy, traditional |
| Sage & Stone | #5c6b4d | #8b9c7a | #c4b5a0 | Natural, calming, organic |
| Coastal Warmth | #2d5a7b | #c45d3e | #e8c9a9 | Coastal, fresh, inviting |
| Modern Slate | #4a5568 | #718096 | #c45d3e | Contemporary, professional |

#### Brisbane Theme (Luxury)
| Palette | Primary | Secondary | Accent | Character |
|---------|---------|-----------|--------|-----------|
| Gold & Navy | #c9a962 | #1a1a2e | #16213e | Classic luxury |
| Rose Gold | #b76e79 | #2d2d2d | #e8d4d4 | Modern elegance |
| Platinum | #8c8c8c | #1a1a2e | #c9a962 | Sophisticated |
| Emerald Luxury | #2d6a4f | #1a1a2e | #c9a962 | Rich, exclusive |

#### Default Theme (Modern Clean)
| Palette | Primary | Secondary | Accent | Character |
|---------|---------|-----------|--------|-----------|
| Classic Red | #e91b23 | #2c3e50 | #3498db | Bold, energetic |
| Ocean Blue | #3498db | #2c3e50 | #e74c3c | Professional, trustworthy |
| Forest Green | #27ae60 | #2c3e50 | #f39c12 | Fresh, eco-friendly |
| Sunset Orange | #e67e22 | #2c3e50 | #9b59b6 | Warm, creative |

## Implementation Plan

### Phase 1: Data Structure (1-2 hours)
1. Add `palettes` to theme config.json for all themes
2. Add `selected_palette` column to websites table
3. Update WebsiteStyleable concern

### Phase 2: Admin UI (2-3 hours)
1. Create palette selector component
2. Add to appearance settings page
3. Style the palette preview cards

### Phase 3: Migration & Testing (1-2 hours)
1. Set default palette for existing websites
2. Test palette switching across themes
3. Verify CSS variable application

## Benefits

1. **Guaranteed Harmony** - All palettes are designer-curated
2. **Accessibility** - Palettes tested for contrast ratios
3. **Simpler UX** - 4-6 choices vs 8+ color pickers
4. **Theme Cohesion** - Palettes designed for each theme's aesthetic
5. **Future Extensibility** - Easy to add new palettes without code changes

## Optional: Advanced Mode

For power users, add a toggle to show individual color overrides:

```erb
<details>
  <summary>Advanced: Customize Individual Colors</summary>
  <div class="color-overrides">
    <!-- Individual color pickers that override palette defaults -->
  </div>
</details>
```
