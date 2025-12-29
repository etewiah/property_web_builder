# Theme & Color Palette System Documentation

Welcome! This directory contains comprehensive documentation about PropertyWebBuilder's theme and color palette system.

## Documents Overview

### 1. **THEME_AND_COLOR_SYSTEM.md** - Complete Architecture Guide
The most comprehensive document covering:
- Full system architecture and design
- Theme structure and inheritance
- Color palette system (single and multi-mode)
- CSS variable generation
- Tailwind CSS compilation process
- Theme selection and serving mechanisms
- Data flow diagrams
- How to extend the system

**Start here if:** You need to understand the entire system deeply or plan to make architectural changes.

### 2. **THEME_SYSTEM_QUICK_REFERENCE.md** - Quick Lookup Guide
Fast reference for common questions:
- Key concepts at a glance
- Typical user flows
- File locations map
- Color application methods
- Common tasks and code snippets
- Performance characteristics
- Troubleshooting guide

**Start here if:** You need quick answers or are looking up specific functionality.

### 3. **THEME_IMPLEMENTATION_PATTERNS.md** - Code Examples
Practical patterns and real code examples:
- Color configuration in config.json
- Dynamic CSS variable generation
- Palette JSON structures (single and multi-mode)
- Website style management
- Theme-aware views
- Tailwind CSS per-theme setup
- Dark mode CSS generation
- Service layer (PaletteLoader, PaletteValidator)
- Layout integration
- Admin UI form patterns

**Start here if:** You're implementing features or need concrete code examples.

## Quick Navigation by Task

### I want to...

**Understand how it all works**
→ Read: [THEME_AND_COLOR_SYSTEM.md](./THEME_AND_COLOR_SYSTEM.md)

**Find a specific file or method**
→ Check: [THEME_SYSTEM_QUICK_REFERENCE.md](./THEME_SYSTEM_QUICK_REFERENCE.md#file-locations-quick-map)

**See actual code examples**
→ Look: [THEME_IMPLEMENTATION_PATTERNS.md](./THEME_IMPLEMENTATION_PATTERNS.md)

**Add a new theme**
→ See: [THEME_AND_COLOR_SYSTEM.md](./THEME_AND_COLOR_SYSTEM.md#11-extending-the-system) → "Adding a New Theme"

**Add a palette to existing theme**
→ See: [THEME_AND_COLOR_SYSTEM.md](./THEME_AND_COLOR_SYSTEM.md#11-extending-the-system) → "Adding a New Palette to Existing Theme"

**Use colors dynamically in views**
→ See: [THEME_IMPLEMENTATION_PATTERNS.md](./THEME_IMPLEMENTATION_PATTERNS.md#pattern-9-layout-integration)

**Style a component per-theme**
→ See: [THEME_IMPLEMENTATION_PATTERNS.md](./THEME_IMPLEMENTATION_PATTERNS.md#pattern-5-theme-aware-views)

**Add dark mode support**
→ See: [THEME_IMPLEMENTATION_PATTERNS.md](./THEME_IMPLEMENTATION_PATTERNS.md#pattern-7-dark-mode-css-generation)

**Debug theme/color issues**
→ See: [THEME_SYSTEM_QUICK_REFERENCE.md](./THEME_SYSTEM_QUICK_REFERENCE.md#troubleshooting)

## System Overview Diagram

```
Website Tenant (Pwb::Website)
├── theme_name: "brisbane"
├── selected_palette: "gold_navy"
├── style_variables_for_theme: {...}
└── dark_mode_setting: "auto"
    ↓
┌─────────────────────────────┐
│ Theme Resolution & Loading  │
├─────────────────────────────┤
│ 1. Load Pwb::Theme          │
│    └─ palette_loader        │
│       └─ loads JSON files   │
│ 2. Apply palette colors     │
│ 3. Merge custom variables   │
│ 4. Generate CSS variables   │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ View Rendering              │
├─────────────────────────────┤
│ Prepend: app/themes/bris... │
│ Layout loads CSS:           │
│ - tailwind-brisbane.css     │
│ - brisbane_theme.css        │
│ - _brisbane.css.erb (inline)│
└─────────────────────────────┘
    ↓
HTML with themed styles and colors
```

## Key Concepts

### Theme
A complete visual package with templates, layouts, and color palettes. Examples: "default", "brisbane", "bologna"

### Palette
A JSON file with a complete set of colors (9+ required colors + optional extras). Each theme has 3-6 palettes.

### CSS Variables
Dynamic color values that change per-website. Generated from palette + customizations. Example: `--pwb-primary`

### Style Variables
Customizable theme settings (colors, fonts, spacing, etc.) defined in config.json and stored per-website.

## System Features

- Multi-tenant theme support (each website can have different theme + palette)
- Palette inheritance and fallback system
- Dynamic CSS variable generation per-website
- Dark mode support (auto-detect or forced)
- Tailwind CSS pre-compilation per-theme
- Theme view path precedence (theme → parent → default)
- Palette validation against JSON schema
- Color generation utilities (dark mode auto-generation)
- Legacy key mapping for backward compatibility

## Current Themes

| Theme | Status | Parent | Palettes |
|-------|--------|--------|----------|
| default | Active | - | 4 (classic_red, ocean_blue, forest_green, sunset_orange) |
| brisbane | Active | default | 5 (gold_navy*, rose_gold, platinum, emerald_luxury, azure_prestige) |
| bologna | Active | default | 4 (terracotta_classic*, sage_stone, coastal_warmth, modern_slate) |
| barcelona | Disabled | default | 4 (catalan_classic*, gaudi_mosaic, coastal_sunset, modernista) |
| biarritz | Disabled | default | 4 (atlantic_blue*, basque_sunset, coastal_elegance, surf_vibes) |

\* = Default palette for that theme

## Related Files Reference

```
Core Models:
  app/models/pwb/website.rb
  app/models/pwb/theme.rb
  app/models/concerns/pwb/website_styleable.rb

Services:
  app/services/pwb/palette_loader.rb
  app/services/pwb/palette_validator.rb

Helpers:
  app/helpers/pwb/css_helper.rb

Views & CSS:
  app/views/pwb/custom_css/
  app/themes/*/palettes/
  app/themes/config.json
  app/themes/shared/color_schema.json
  app/assets/stylesheets/tailwind-*.css
  app/assets/builds/tailwind-*.css

Configuration:
  package.json (build scripts)
  config/importmap.rb
```

## Development Workflow

### Making a Theme Change

1. **Edit theme files** (views, CSS, palette)
   ```
   app/themes/brisbane/palettes/gold_navy.json
   app/themes/brisbane/views/pwb/components/_hero.html.erb
   ```

2. **Rebuild Tailwind** (if stylesheets changed)
   ```bash
   npm run tailwind:brisbane
   # or all themes:
   npm run tailwind:build
   ```

3. **Test** with theme preview or theme selection:
   ```
   http://localhost:3000/path?theme=brisbane
   website.update(theme_name: 'brisbane', selected_palette: 'rose_gold')
   ```

4. **Verify dark mode** (if applicable):
   - Test `dark_mode_setting: "auto"`
   - Test `dark_mode_setting: "dark"`
   - Check CSS generation includes dark mode

### Adding New Palette

1. Create JSON file:
   ```
   app/themes/brisbane/palettes/new_palette.json
   ```

2. Include required colors (9+)

3. Run validation:
   ```ruby
   loader = Pwb::PaletteLoader.new
   results = loader.validate_theme_palettes("brisbane")
   ```

4. No rebuild needed! Palettes load dynamically at runtime.

## Performance Optimization

- **Tailwind CSS:** Pre-compiled and static (excellent caching)
- **Palette data:** Loaded once per request and memoized
- **Theme model:** ActiveJSON (loaded from config.json once)
- **CSS variables:** Generated via ERB (inlined in `<style>` tag)
- **Overall:** ~2-3 CSS files per page + 1 inline style tag

## Migration Considerations

### From Old System
- Legacy keys are automatically normalized (footer_bg_color → footer_background_color)
- Single large CSS file → Multiple theme-specific files
- Database palette storage → File-based JSON palettes

### Backward Compatibility
- Palettes in config.json still supported (fallback)
- Legacy color keys still work (normalized)
- Old style_variables format compatible

## Testing

### Unit Tests
- `spec/models/concerns/pwb/website_styleable_spec.rb`
- `spec/services/pwb/palette_loader_spec.rb`
- `spec/services/pwb/palette_validator_spec.rb`

### Manual Testing
```ruby
# In console:
website = Pwb::Website.first
website.theme_name = "brisbane"
website.selected_palette = "rose_gold"
website.save

website.style_variables
website.current_theme
website.available_palettes
```

## Troubleshooting Guide

See [THEME_SYSTEM_QUICK_REFERENCE.md - Troubleshooting](./THEME_SYSTEM_QUICK_REFERENCE.md#troubleshooting)

## Contributing

When adding features to the theme system:

1. **Update schema** if adding new color keys to `app/themes/shared/color_schema.json`
2. **Add to all palettes** if making required color changes
3. **Run validators** to ensure JSON validity
4. **Rebuild Tailwind** if CSS changes
5. **Update documentation** in these files
6. **Add/update tests** for new functionality

## Questions?

Refer to the appropriate document:
- **"How does this work?"** → THEME_AND_COLOR_SYSTEM.md
- **"Where is X?"** → THEME_SYSTEM_QUICK_REFERENCE.md
- **"Show me code"** → THEME_IMPLEMENTATION_PATTERNS.md
- **"How do I...?"** → THEME_SYSTEM_QUICK_REFERENCE.md#common-tasks

---

**Documentation Version:** 2.0.0  
**Last Updated:** 2025-12-29  
**System Version:** PropertyWebBuilder v2.0+  
**Tailwind Version:** 4.1+
