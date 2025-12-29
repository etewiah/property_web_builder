# Theming System Implementation Roadmap

This document outlines the step-by-step plan to fix and improve the PropertyWebBuilder theming system.

---

## Phase 1: Color Palette Consolidation (Week 1)

### Goal
Eliminate duplicate palette definitions and standardize color keys.

### Tasks

#### 1.1 Create Palette Migration Rake Task
**File:** `lib/tasks/pwb/migrate_palettes.rake`

```ruby
namespace :pwb do
  namespace :themes do
    desc "Migrate palettes from config.json to separate files"
    task migrate_palettes: :environment do
      config = JSON.parse(File.read(Rails.root.join("app/themes/config.json")))
      
      config["themes"].each do |theme|
        theme_name = theme["name"]
        palettes = theme["palettes"] || {}
        
        palettes.each do |palette_id, palette_data|
          # Create palette directory if needed
          palette_dir = Rails.root.join("app/themes/#{theme_name}/palettes")
          FileUtils.mkdir_p(palette_dir)
          
          # Standardize keys
          standardized = standardize_palette_keys(palette_data)
          
          # Write to file
          File.write(
            palette_dir.join("#{palette_id}.json"),
            JSON.pretty_generate(standardized)
          )
        end
      end
      
      puts "✅ Palettes migrated successfully"
    end
    
    def standardize_palette_keys(palette)
      # Map legacy keys to standard keys
      key_mapping = {
        "header_bg_color" => "header_background_color",
        "footer_bg_color" => "footer_background_color",
        "footer_main_text_color" => "footer_text_color"
      }
      
      colors = palette["colors"] || {}
      standardized_colors = {}
      
      colors.each do |key, value|
        new_key = key_mapping[key] || key
        standardized_colors[new_key] = value unless ["light_color", "action_color"].include?(key)
      end
      
      {
        "id" => palette["id"],
        "name" => palette["name"],
        "description" => palette["description"] || "",
        "preview_colors" => palette["preview_colors"] || [],
        "is_default" => palette["is_default"] || false,
        "colors" => standardized_colors
      }
    end
  end
end
```

**Run:**
```bash
rails pwb:themes:migrate_palettes
```

#### 1.2 Remove Palettes from config.json

**File:** `app/themes/config.json`

Remove the `palettes` key from each theme definition. Keep only:
- `name`
- `parent_theme`
- `style_variables`
- `view_paths`

#### 1.3 Update PaletteLoader

**File:** `app/services/pwb/palette_loader.rb`

Add deprecation warning to `fallback_to_config`:

```ruby
def fallback_to_config(theme_name)
  Rails.logger.warn(
    "DEPRECATED: Loading palettes from config.json for theme '#{theme_name}'. " \
    "Please migrate to separate palette JSON files. " \
    "Run: rails pwb:themes:migrate_palettes"
  )
  
  # ... existing fallback code
end
```

#### 1.4 Add Palette Validation Task

**File:** `lib/tasks/pwb/validate_palettes.rake`

```ruby
namespace :pwb do
  namespace :themes do
    desc "Validate all theme palettes"
    task validate_palettes: :environment do
      errors = []
      
      Dir.glob(Rails.root.join("app/themes/*/palettes/*.json")).each do |file|
        validator = Pwb::PaletteValidator.new(file)
        result = validator.validate
        
        unless result[:valid]
          errors << {
            file: file,
            errors: result[:errors]
          }
        end
      end
      
      if errors.empty?
        puts "✅ All palettes valid"
      else
        puts "❌ Validation errors found:"
        errors.each do |error|
          puts "\n#{error[:file]}:"
          error[:errors].each { |e| puts "  - #{e}" }
        end
        exit 1
      end
    end
  end
end
```

---

## Phase 2: Complete Palette Definitions (Week 2)

### Goal
Ensure all palettes have complete color definitions.

### Tasks

#### 2.1 Update Color Schema

**File:** `app/themes/shared/color_schema.json`

Make these colors required (move from `optional_colors` to `required_colors`):
- `card_background_color`
- `card_text_color`
- `border_color`
- `success_color`
- `warning_color`
- `error_color`

#### 2.2 Add Smart Defaults to Validator

**File:** `app/services/pwb/palette_validator.rb`

```ruby
def apply_smart_defaults(colors)
  defaults = {
    "card_background_color" => colors["background_color"],
    "card_text_color" => colors["text_color"],
    "border_color" => lighten(colors["text_color"], 70),
    "surface_color" => lighten(colors["background_color"], 3),
    "surface_alt_color" => lighten(colors["background_color"], 5),
    "success_color" => "#22c55e",
    "warning_color" => "#f59e0b",
    "error_color" => "#ef4444",
    "muted_text_color" => lighten(colors["text_color"], 30),
    "link_color" => colors["primary_color"],
    "link_hover_color" => darken(colors["primary_color"], 10)
  }
  
  defaults.merge(colors)
end
```

#### 2.3 Update All Existing Palettes

Run through each palette file and add missing colors using smart defaults.

---

## Phase 3: Font Loading Implementation (Week 3-4)

### Goal
Implement dynamic font loading based on theme configuration.

### Tasks

#### 3.1 Create Font Configuration

**File:** `app/themes/shared/fonts.json`

```json
{
  "fonts": {
    "Inter": {
      "provider": "fontsource",
      "package": "@fontsource-variable/inter",
      "weights": [400, 500, 600, 700],
      "category": "sans-serif",
      "fallback": "system-ui, sans-serif"
    },
    "Open Sans": {
      "provider": "google",
      "weights": [400, 600, 700],
      "category": "sans-serif",
      "fallback": "system-ui, sans-serif"
    }
    // ... more fonts
  }
}
```

#### 3.2 Create FontLoader Service

**File:** `app/services/pwb/font_loader.rb`

```ruby
module Pwb
  class FontLoader
    def initialize(theme)
      @theme = theme
      @font_config = load_font_config
    end
    
    def generate_font_css
      fonts = [@theme.font_primary, @theme.font_heading].compact.uniq
      
      fonts.map do |font_name|
        font_data = @font_config["fonts"][font_name]
        next unless font_data
        
        case font_data["provider"]
        when "fontsource"
          "@import '#{font_data["package"]}';"
        when "google"
          google_fonts_import(font_name, font_data["weights"])
        end
      end.compact.join("\n")
    end
    
    def preconnect_tags
      # Generate <link rel="preconnect"> for Google Fonts
    end
    
    private
    
    def load_font_config
      JSON.parse(File.read(Rails.root.join("app/themes/shared/fonts.json")))
    end
    
    def google_fonts_import(name, weights)
      family = name.gsub(" ", "+")
      weight_str = weights.join(";")
      "@import url('https://fonts.googleapis.com/css2?family=#{family}:wght@#{weight_str}&display=swap');"
    end
  end
end
```

#### 3.3 Update Layout Template

**File:** `app/themes/default/views/layouts/pwb/application.html.erb`

```erb
<head>
  <!-- Font preconnect -->
  <%= font_preconnect_tags if respond_to?(:font_preconnect_tags) %>
  
  <!-- Inline font CSS -->
  <% if @current_website&.theme %>
    <style>
      <%= Pwb::FontLoader.new(@current_website.theme).generate_font_css %>
    </style>
  <% end %>
  
  <!-- Rest of head -->
</head>
```

---

## Phase 4: Icon System Improvements (Week 5)

### Goal
Add fallback rendering and improve icon reliability.

### Tasks

#### 4.1 Add Icon Fallback

**File:** `app/helpers/pwb/icon_helper.rb`

Update `icon` method to render fallback for unknown icons (see audit document).

#### 4.2 Create Icon Audit Task

**File:** `lib/tasks/pwb/audit_icons.rake`

```ruby
namespace :pwb do
  namespace :icons do
    desc "Audit icon usage across templates"
    task audit: :environment do
      # Scan all ERB/Liquid files for icon usage
      # Report unknown icons
      # Report unused icons in ALLOWED_ICONS
    end
  end
end
```

---

## Phase 5: Testing & Documentation (Week 6)

### Goal
Ensure system reliability and developer experience.

### Tasks

#### 5.1 Add RSpec Tests

**File:** `spec/services/pwb/palette_loader_spec.rb`
**File:** `spec/services/pwb/font_loader_spec.rb`
**File:** `spec/helpers/pwb/icon_helper_spec.rb`

#### 5.2 Create Theme Development Guide

Already created: `docs/theming/QUICK_START_GUIDE.md`

#### 5.3 Add Theme Preview UI

Create admin interface for:
- Live palette preview
- Color contrast checker
- Font preview
- Icon browser

---

## Success Metrics

### Before
- ❌ Palettes in 2 locations (config.json + separate files)
- ❌ Inconsistent color keys (3 different naming conventions)
- ❌ Missing 8+ required colors in palettes
- ❌ Fonts not actually loaded
- ❌ No icon fallback handling

### After
- ✅ Single source of truth for palettes
- ✅ Standardized color keys
- ✅ Complete palette definitions with smart defaults
- ✅ Dynamic font loading working
- ✅ Graceful icon fallback
- ✅ Comprehensive tests
- ✅ Developer documentation

---

## Timeline Summary

| Phase | Duration | Effort | Priority |
|-------|----------|--------|----------|
| 1. Palette Consolidation | 1 week | Medium | High |
| 2. Complete Palettes | 1 week | Low | High |
| 3. Font Loading | 2 weeks | High | Medium |
| 4. Icon Improvements | 1 week | Low | Low |
| 5. Testing & Docs | 1 week | Medium | Medium |

**Total:** 6 weeks

---

## Risk Mitigation

### Risk: Breaking existing themes
**Mitigation:** 
- Keep fallback logic during migration
- Add deprecation warnings
- Test each theme individually

### Risk: Performance regression
**Mitigation:**
- Benchmark before/after
- Use compiled CSS mode for production
- Optimize font loading

### Risk: Incomplete migration
**Mitigation:**
- Automated validation tasks
- CI/CD integration
- Rollback plan

---

## Next Steps

1. Review this roadmap with team
2. Prioritize phases based on business needs
3. Create GitHub issues for each task
4. Assign owners and start Phase 1

For questions or clarifications, refer to `THEMING_SYSTEM_AUDIT.md`.

