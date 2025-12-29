# Theme & Color System - Quick Reference

## Key Concepts at a Glance

### What is a Theme?
A complete visual package with:
- Page templates and layouts (`app/themes/{name}/views/`)
- Multiple color palettes (`app/themes/{name}/palettes/`)
- Style variable definitions (in `config.json`)
- Optional: inheritance from parent theme

### What is a Palette?
A JSON file with a complete set of colors:
- 9 required colors (primary, secondary, accent, background, text, header, footer)
- Optional colors (card, border, success, error, etc.)
- Preview colors for UI display
- Supports light/dark mode variants

### What is a Website Theme Selection?
Each Pwb::Website has:
- `theme_name` - Which theme to use (default, brisbane, bologna, etc.)
- `selected_palette` - Which palette within that theme (gold_navy, rose_gold, etc.)
- `style_variables_for_theme` - Customized variables on top of palette
- `dark_mode_setting` - light_only, auto, or dark

## Typical User Flow

1. **Create Website**
   ```ruby
   website = Pwb::Website.create(
     theme_name: 'brisbane',
     selected_palette: 'gold_navy'
   )
   ```

2. **Select Palette**
   ```ruby
   website.apply_palette!('rose_gold')
   # Updates website.selected_palette
   ```

3. **Access Colors**
   ```ruby
   website.style_variables
   # => { "primary_color" => "#c9a962", "secondary_color" => "#1a1a2e", ... }
   
   website.current_theme.palette_colors('rose_gold')
   # => { "primary_color" => "#b76e79", ... }
   ```

4. **Render Page**
   - Controller prepends: `app/themes/brisbane/views/`
   - Layout loads: `tailwind-brisbane.css` (pre-compiled)
   - Layout renders: `_brisbane.css.erb` (dynamic CSS variables)
   - Result: Theme views + theme CSS + dynamic colors

## File Locations Quick Map

**Theme Configuration:**
- `app/themes/config.json` - All themes + style_variables schema
- `app/themes/shared/color_schema.json` - Palette JSON schema

**Theme Templates:**
- `app/themes/default/views/` - Default theme views
- `app/themes/brisbane/views/` - Brisbane theme views (can override)
- `app/themes/brisbane/palettes/` - Brisbane color palettes

**CSS Generation:**
- `app/views/pwb/custom_css/_base_variables.css.erb` - Root CSS variables
- `app/views/pwb/custom_css/_default.css.erb` - Default theme CSS
- `app/views/pwb/custom_css/_brisbane.css.erb` - Brisbane theme CSS

**Pre-compiled Tailwind:**
- `app/assets/stylesheets/tailwind-input.css` - Default theme input
- `app/assets/stylesheets/tailwind-brisbane.css` - Brisbane theme input
- `app/assets/builds/tailwind-default.css` - Pre-built output
- `app/assets/builds/tailwind-brisbane.css` - Pre-built output

**Models & Services:**
- `app/models/pwb/website.rb` - Stores theme selection per tenant
- `app/models/pwb/theme.rb` - Loads themes from config.json
- `app/models/concerns/pwb/website_styleable.rb` - Style management
- `app/services/pwb/palette_loader.rb` - Loads palettes from disk
- `app/services/pwb/palette_validator.rb` - Validates palette JSON

## Color Application Methods

### CSS Variables Approach (Recommended)
```css
.button {
  background-color: var(--pwb-primary);
  color: var(--pwb-text-on-primary);
}
```
Changes per-website via dynamic CSS generation.

### Tailwind Utility Classes (Hardcoded)
```html
<button class="bg-blue-500 text-white">Click</button>
```
Hardcoded at build time, cannot change per-tenant.

### Tailwind with CSS Variable (Hybrid)
```html
<button class="bg-[var(--pwb-primary)] text-white">Click</button>
```
Uses Tailwind syntax but references dynamic variable.

## Common Tasks

### Check What Theme a Website Uses
```ruby
website = Pwb::Website.find(1)
website.theme_name # => "brisbane"
website.selected_palette # => "gold_navy"
```

### Get All Available Palettes for Theme
```ruby
website.available_palettes
# => { "gold_navy" => {...}, "rose_gold" => {...}, ... }

website.palette_options_for_select
# => [["Gold & Navy", "gold_navy"], ["Rose Gold", "rose_gold"], ...]
```

### Change Website Palette
```ruby
website.apply_palette!("rose_gold")
# Colors immediately available via website.style_variables
```

### Get Palette Colors
```ruby
colors = website.current_theme.palette_colors("gold_navy")
colors["primary_color"] # => "#c9a962"
```

### Generate CSS for Palette
```ruby
css = website.current_theme.generate_palette_css("gold_navy")
# Returns CSS custom property declarations
```

### Check Dark Mode Status
```ruby
website.dark_mode_enabled?   # true if "auto" or "dark"
website.force_dark_mode?     # true if "dark" 
website.auto_dark_mode?      # true if "auto"
website.dark_mode_html_class # => "pwb-dark" (if forced) or nil
```

## Theme Hierarchy

```
Rendering Flow:
  1. Check app/themes/brisbane/views/
  2. Check app/themes/default/views/ (if parent or not found)
  3. Fall back to app/views/

Style Variables:
  1. Load palette colors from selected_palette
  2. Merge with theme defaults
  3. Merge with website customizations
  4. Generate CSS variables dynamically
```

## Performance Characteristics

| Component | Cache Strategy | Performance |
|-----------|-----------------|-------------|
| Pre-compiled Tailwind CSS | Static file (CDN) | Very fast |
| Palette data | Loaded & memoized in PaletteLoader | Fast |
| Theme model | ActiveJSON (loaded once) | Fast |
| Dynamic CSS variables | Generated per-request via ERB | Good (inlined in <style> tag) |
| Custom CSS | Stored in website.raw_css | Fast |

## Troubleshooting

**Colors not showing?**
- Check `website.selected_palette` is valid
- Check `website.current_theme` exists
- Verify CSS variables are in `_base_variables.css.erb`

**Theme views not loading?**
- Check `prepend_view_path` in ApplicationController
- Verify path exists: `app/themes/{theme_name}/views/`
- Check parent_theme inheritance

**Palette validation failing?**
- Check all 9 required colors present
- Verify hex color format: #RRGGBB or #RGB
- Check against `color_schema.json` schema

**Tailwind not compiling?**
- Run: `npm run tailwind:build` to rebuild all themes
- For single theme: `npm run tailwind:brisbane`
- Check input file exists: `app/assets/stylesheets/tailwind-{theme}.css`

## References

- Full documentation: `/docs/architecture/THEME_AND_COLOR_SYSTEM.md`
- Theme models: `app/models/pwb/theme.rb`
- Website styles: `app/models/concerns/pwb/website_styleable.rb`
- Palette services: `app/services/pwb/palette_*.rb`
