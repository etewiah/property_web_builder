# Color Palettes Architecture - PropertyWebBuilder

## Overview

PropertyWebBuilder implements a sophisticated color palette system that allows websites to apply pre-defined, harmonious color schemes. The system is built on a foundation of:

1. **Theme-based Palettes**: Each theme defines multiple color palettes in separate JSON files
2. **Database Persistence**: Selected palette is stored per website
3. **Style Variable Integration**: Palette colors are merged into CSS variables
4. **CSS Generation**: Colors are rendered as CSS custom properties for dynamic styling
5. **Dark Mode Support**: Palettes can define explicit dark mode colors or auto-generate them
6. **Validation & Utilities**: Schema validation, color utilities, and shade generation

## Architecture Diagram

```
Palette Files (JSON per theme)
       ↓
┌─────────────────────────────────────┐
│  app/themes/[theme]/palettes/*.json │
│  - default/palettes/ (4 files)      │
│  - brisbane/palettes/ (4 files)     │
│  - bologna/palettes/ (4 files)      │
│  - barcelona/palettes/ (4 files)    │
│  - biarritz/palettes/ (4 files)     │
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  PaletteLoader (Ruby Service)       │
│  app/services/pwb/palette_loader.rb │
│  - Loads palettes from JSON files   │
│  - Light/dark mode color extraction │
│  - CSS variable generation          │
│  - Validation via PaletteValidator  │
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  Theme Model (Ruby)                 │
│  app/models/pwb/theme.rb            │
│  - Uses PaletteLoader               │
│  - Methods: palettes(), palette(),  │
│    palette_colors(), valid_palette()|
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  Website Model (Rails)              │
│  app/models/pwb/website.rb          │
│  - selected_palette (DB column)     │
│  - style_variables_for_theme (JSON) │
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  WebsiteStyleable Concern           │
│  app/models/concerns/pwb/          │
│    website_styleable.rb             │
│  - style_variables (computed)       │
│  - effective_palette_id             │
│  - apply_palette!()                 │
│  - available_palettes()             │
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  CSS Generation                     │
│  app/views/pwb/custom_css/          │
│  - _base_variables.css.erb          │
│  - _default.css.erb (theme-specific)│
│  - _brisbane.css.erb                │
│  - _bologna.css.erb                 │
│  - _barcelona.css.erb               │
│  - _biarritz.css.erb                │
└─────────────────────────────────────┘
       ↓
┌─────────────────────────────────────┐
│  Browser CSS Variables              │
│  :root { --pwb-primary, etc. }      │
│  Used by Tailwind & custom CSS      │
└─────────────────────────────────────┘
```

## 1. Color Definition (Palette Files)

### Location
`/app/themes/[theme_name]/palettes/*.json` - Separate JSON files per palette

### Structure
Each palette is a separate JSON file with standardized schema:

```json
{
  "id": "classic_red",
  "name": "Classic Red",
  "description": "Bold and energetic with professional appeal",
  "preview_colors": ["#e91b23", "#2c3e50", "#3498db"],
  "is_default": true,
  "colors": {
    "primary_color": "#e91b23",
    "secondary_color": "#2c3e50",
    "accent_color": "#3498db",
    "background_color": "#ffffff",
    "text_color": "#333333",
    "light_color": "#f8f9fa",
    "link_color": "#e91b23",
    "header_background_color": "#ffffff",
    "header_text_color": "#333333",
    "footer_background_color": "#2c3e50",
    "footer_text_color": "#ffffff",
    "action_color": "#e91b23"
  }
}
```

### Dark Mode Support (Optional)
Palettes can define explicit dark mode colors using the `modes` structure:

```json
{
  "id": "modern_slate",
  "name": "Modern Slate",
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

### Palette Object Properties

| Property | Type | Purpose |
|----------|------|---------|
| `id` | string | Unique identifier for palette (snake_case) |
| `name` | string | Display name in UI (max 50 chars) |
| `description` | string | User-friendly description |
| `preview_colors` | array | 3-5 hex colors for visual preview |
| `is_default` | boolean | Whether this is theme's default palette |
| `supports_dark_mode` | boolean | Whether palette has explicit dark mode |
| `colors` | object | Single color set (light mode, dark auto-generated) |
| `modes` | object | Explicit light/dark color sets |

### Color Schema
The standardized color schema is defined in `app/themes/shared/color_schema.json`.

**Required Colors:**
- `primary_color`, `secondary_color`, `accent_color`
- `background_color`, `text_color`
- `header_background_color`, `header_text_color`
- `footer_background_color`, `footer_text_color`

**Optional Colors:**
- `card_background_color`, `card_text_color`, `border_color`
- `surface_color`, `surface_alt_color`
- `success_color`, `warning_color`, `error_color`
- `link_color`, `link_hover_color`, `muted_text_color`
- `button_primary_background`, `button_primary_text`
- `input_background_color`, `input_border_color`, `input_focus_color`

### Current Themes and Palettes

#### Default Theme
- **Classic Red** (default)
- **Ocean Blue**
- **Forest Green**
- **Sunset Orange**

#### Brisbane (Luxury)
- **Gold & Navy** (default)
- **Rose Gold**
- **Platinum**
- **Emerald Luxury**

#### Bologna (Modern)
- **Terracotta Classic** (default)
- **Sage & Stone**
- **Coastal Warmth**
- **Modern Slate**

#### Barcelona (Mediterranean)
- **Catalan Classic** (default)
- **Gaudí Mosaic**
- **Coastal Sunset**
- **Modernista**

#### Biarritz (Coastal)
- **Atlantic Blue** (default)
- **Basque Sunset**
- **Coastal Elegance**
- **Surf Vibes**

## 2. Database Schema

### Column: `selected_palette` (String)

```ruby
# Migration: 20251225200000_add_selected_palette_to_websites.rb
add_column :pwb_websites, :selected_palette, :string
add_index :pwb_websites, :selected_palette
```

**Characteristics:**
- Stores the palette ID (e.g., "classic_red", "gold_navy")
- Optional (can be nil, defaults to theme's default palette)
- Indexed for efficient lookups
- Persisted per website

**Related Column:**
- `style_variables_for_theme` (JSON) - Stores custom color overrides

## 3. Ruby/Rails Implementation

### Theme Model
**File:** `app/models/pwb/theme.rb` (ActiveJSON-based)

**Key Methods:**
```ruby
# Get all palettes for theme
theme.palettes() → Hash<palette_id, palette_config>

# Get default palette ID
theme.default_palette_id() → String

# Get palette by ID
theme.palette(palette_id) → Hash

# Get colors from palette
theme.palette_colors(palette_id) → Hash<color_name, hex_value>

# Get preview colors for UI
theme.palette_preview_colors(palette_id) → Array<hex_values>

# Check if palette is valid
theme.valid_palette?(palette_id) → Boolean

# Get palette options for form selects
theme.palette_options() → Array<[name, id]>
```

### WebsiteStyleable Concern
**File:** `app/models/concerns/pwb/website_styleable.rb`

**Key Methods:**
```ruby
# Get computed style variables with palette colors merged
website.style_variables() → Hash
  # Returns base variables merged with selected palette colors

# Get effective palette ID (selected or theme default)
website.effective_palette_id() → String

# Apply a palette to website
website.apply_palette!(palette_id) → Boolean

# Get available palettes for current theme
website.available_palettes() → Hash

# Get palette options for form selects
website.palette_options_for_select() → Array<[name, id]>
```

**Flow:**
```
style_variables():
  1. Get base variables from style_variables_for_theme["default"]
  2. If selected_palette present AND valid:
     a. Get palette_colors from current_theme
     b. Merge palette colors into base variables
  3. Return merged variables
```

## 4. Style Variable System

### Base Variables (with Defaults)
**File:** `app/models/concerns/pwb/website_styleable.rb`

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
}.freeze
```

### Palette Color Keys (per Theme)
Common across all themes:
- `primary_color` - Main brand color
- `secondary_color` - Secondary brand color
- `accent_color` - Highlight color
- `background_color` - Page background
- `text_color` - Body text
- `light_color` - Light background variant
- `link_color` - Link color
- `header_bg_color` - Header background
- `header_text_color` - Header text
- `footer_bg_color` - Footer background
- `footer_text_color` - Footer text
- `action_color` - CTA/button color

**Theme-Specific Keys:**
- Bologna/Barcelona/Biarritz: `footer_main_text_color` (additional)

## 5. CSS Generation Pipeline

### Step 1: Base CSS Variables
**File:** `app/views/pwb/custom_css/_base_variables.css.erb`

Generates CSS custom properties (`:root`) with computed values:
```css
:root {
  --pwb-primary: #e91b23;
  --pwb-primary-light: color-mix(in srgb, #e91b23 70%, white);
  --pwb-primary-dark: color-mix(in srgb, #e91b23 70%, black);
  --pwb-secondary: #3498db;
  /* ... 50+ more CSS variables ... */
}
```

**Variables Generated:**
- Color system (primary, secondary, accent variants)
- Typography (fonts, sizes, weights)
- Spacing & layout
- Shadows, borders, transitions

### Step 2: Theme-Specific CSS
**Files:** `app/views/pwb/custom_css/_<theme>.css.erb`

Each theme has a custom CSS partial that:
1. Accesses theme-specific style variables
2. Generates CSS rules using variables
3. Example: Header/footer styling, component customization

**Example from Default Theme:**
```css
:root {
  --primary-color: <%= @current_website.style_variables['primary_color'] %>;
  --secondary-color: <%= @current_website.style_variables['secondary_color'] %>;
  /* ... theme-specific variables ... */
}

.service-card {
  background: var(--primary-color);
  border-color: var(--secondary-color);
}
```

### Step 3: CSS Rendering in Layout
**File:** `app/views/layouts/pwb/page_part.html.erb`

```erb
<style>
  <%= custom_styles(theme_name) %>
</style>
```

**Helper:** `app/helpers/pwb/css_helper.rb`
```ruby
def custom_styles(theme_name)
  render partial: "pwb/custom_css/#{theme_name}", 
         locals: {}, 
         formats: :css
end
```

## 6. Admin UI - Palette Selection

### Location
`app/views/site_admin/website/settings/_appearance_tab.html.erb`

### Features
1. **Theme Selection** - Radio buttons for available themes
2. **Palette Selection** - Grid of palette cards with:
   - Preview color swatches
   - Palette name and description
   - Visual feedback on selection
3. **Advanced Color Settings** - Collapsible section for manual color overrides
   - Primary color picker
   - Secondary color picker
   - Action color picker

### Controller Handling
**File:** `app/controllers/site_admin/website/settings_controller.rb`

```ruby
def appearance_settings_params
  params.require(:website).permit(
    :theme_name,
    :selected_palette,  # Palette ID (e.g., "classic_red")
    :raw_css
  )
end

def update_appearance_settings
  if @website.update(appearance_settings_params)
    redirect_to site_admin_website_settings_tab_path('appearance'),
                notice: 'Appearance settings updated successfully'
  end
end
```

## 7. Color Usage in Templates

### Style Variables Access
In ERB templates:
```erb
<style>
  .my-element {
    color: <%= @current_website.style_variables['primary_color'] %>;
  }
</style>
```

### CSS Variable Usage
In CSS/SCSS files:
```css
.button {
  background-color: var(--pwb-primary);
  color: var(--pwb-text-on-primary);
  border: 1px solid var(--pwb-primary-dark);
}
```

### Tailwind Integration
Tailwind CSS classes work with CSS variables:
```html
<button class="bg-blue-500 text-white">
  <!-- Uses Tailwind defaults, but can override with CSS variables -->
</button>
```

## 8. Resolved Pain Points (Dec 2025 Refactoring)

The following issues were addressed in the palette system refactoring:

### RESOLVED: Color Key Inconsistency
- **Before:** `footer_text_color` vs `footer_main_text_color`
- **After:** Standardized to `footer_text_color`, `header_background_color`, etc.
- **Legacy Support:** `PaletteValidator` auto-migrates old keys with warnings

### RESOLVED: No Validation or Type Safety
- **Before:** No validation, malformed palettes possible
- **After:** `PaletteValidator` validates structure, required colors, hex formats
- **Schema:** `app/themes/shared/color_schema.json` defines JSON Schema

### RESOLVED: No Color Variants
- **Before:** Manual definition of all lighter/darker variants
- **After:** `ColorUtils.generate_shade_scale()` auto-generates Tailwind-style scales
- **CSS:** Automatically generates `--pwb-primary-50` through `--pwb-primary-950`

### RESOLVED: Monolithic config.json
- **Before:** All palettes in single 1400+ line file
- **After:** Separate JSON files per palette (20 files across 5 themes)
- **Benefits:** Easier version control, smaller diffs, better organization

### PARTIALLY ADDRESSED: Dark Mode Support
- **Before:** No dark mode support
- **After:** Palettes can define explicit `modes.light`/`modes.dark`
- **Auto-generation:** `ColorUtils.generate_dark_mode_colors()` creates dark mode from light
- **CSS:** `generate_dual_mode_css_variables()` outputs `prefers-color-scheme` media query

### Still Outstanding
- Tailwind config integration at build time
- Real-time palette preview in admin UI

## 9. Data Flow Summary

### Palette Selection to Rendering

```
1. Admin selects palette in UI
   ↓
2. Form submits: website[selected_palette] = "classic_red"
   ↓
3. Controller updates: website.update(selected_palette: "classic_red")
   ↓
4. Database: pwb_websites.selected_palette = "classic_red"
   ↓
5. On page request: @current_website.style_variables
   a. Loads style_variables_for_theme["default"]
   b. Gets current_theme.palette_colors("classic_red")
   c. Merges palette colors
   d. Returns merged hash
   ↓
6. CSS generation: custom_styles(theme_name)
   a. Renders _base_variables.css.erb
   b. Uses @current_website.style_variables
   c. Generates CSS custom properties
   ↓
7. Browser: :root { --pwb-primary: #e91b23; ... }
```

### Color Application Layers

```
Database Layer:
  pwb_websites.selected_palette (string)
  pwb_websites.style_variables_for_theme (JSON)
  
Ruby Layer:
  Website#style_variables (computed)
  Theme#palette_colors (loaded from JSON)
  Website#effective_palette_id (fallback logic)
  
View Layer:
  custom_styles(theme_name) helper
  @current_website.style_variables in ERB
  
CSS Layer:
  :root CSS custom properties
  Theme-specific CSS rules
  Tailwind classes + CSS variables
```

## 10. Palette Services

### PaletteLoader (`app/services/pwb/palette_loader.rb`)
Loads and manages theme color palettes from separate JSON files.

```ruby
loader = Pwb::PaletteLoader.new
palettes = loader.load_theme_palettes("brisbane")  # All palettes for theme
palette = loader.get_palette("brisbane", "gold_navy")  # Specific palette
default = loader.get_default_palette("brisbane")  # Default palette

# Light/Dark mode support
light_colors = loader.get_light_colors("brisbane", "gold_navy")
dark_colors = loader.get_dark_colors("brisbane", "gold_navy")  # Auto-generated if not explicit

# CSS generation
css = loader.generate_css_variables("brisbane", "gold_navy")
full_css = loader.generate_full_css("brisbane", "gold_navy")  # Includes dark mode
```

### PaletteValidator (`app/services/pwb/palette_validator.rb`)
Validates palettes against the standardized schema.

```ruby
validator = Pwb::PaletteValidator.new
result = validator.validate(palette_hash)
result.valid?       # => true/false
result.errors       # => ["Missing required color: 'primary_color'", ...]
result.warnings     # => ["Migrated legacy key 'footer_main_text_color'", ...]
result.normalized_palette  # => Palette with legacy keys migrated
```

### ColorUtils (`app/services/pwb/color_utils.rb`)
Color manipulation and generation utilities.

```ruby
# Color conversion
Pwb::ColorUtils.hex_to_rgb("#FF5733")  # => [255, 87, 51]
Pwb::ColorUtils.rgb_to_hex(255, 87, 51)  # => "#ff5733"

# Shade generation (Tailwind-style)
shades = Pwb::ColorUtils.generate_shade_scale("#3498db")
# => { 50 => "#e9f4fb", 100 => "#d4e9f7", ..., 900 => "#081d2b", 950 => "#040f16" }

# Dark mode generation
dark_colors = Pwb::ColorUtils.generate_dark_mode_colors(light_colors)

# CSS generation
css = Pwb::ColorUtils.generate_dual_mode_css_variables(light_colors, dark_colors)
# Outputs :root {}, @media (prefers-color-scheme: dark) {}, .dark {}

# Accessibility
ratio = Pwb::ColorUtils.contrast_ratio("#000000", "#FFFFFF")  # => 21.0
Pwb::ColorUtils.wcag_aa_compliant?("#333", "#fff")  # => true
```

## 11. Rake Tasks

```bash
# Validate all theme palettes
rake palettes:validate

# List all available palettes
rake palettes:list

# Generate CSS custom properties
rake palettes:css[brisbane,gold_navy]

# Generate CSS with dark mode support
rake palettes:css_dark[brisbane,gold_navy]

# Show dark mode color generation
rake palettes:dark_mode[brisbane,gold_navy]

# Generate shade variants for a color
rake palettes:shades[#3498db]

# Check contrast ratios for accessibility
rake palettes:contrast[brisbane,gold_navy]

# Migrate palettes from config.json to separate files
rake palettes:migrate
```

## 12. Related Files

### Palette Services
- `/app/services/pwb/palette_loader.rb` - Palette loading and management
- `/app/services/pwb/palette_validator.rb` - Schema validation
- `/app/services/pwb/color_utils.rb` - Color utilities

### Schema & Palettes
- `/app/themes/shared/color_schema.json` - JSON Schema for palettes
- `/app/themes/[theme]/palettes/*.json` - Palette files (20 total)

### Configuration & Models
- `/app/themes/config.json` - Theme definitions (palettes moved to separate files)
- `/app/models/pwb/theme.rb` - Theme model (uses PaletteLoader)
- `/app/models/pwb/website.rb` - Website model
- `/app/models/concerns/pwb/website_styleable.rb` - Style methods

### Admin UI
- `/app/controllers/site_admin/website/settings_controller.rb` - Settings controller
- `/app/views/site_admin/website/settings/_appearance_tab.html.erb` - Palette UI

### CSS Generation
- `/app/helpers/pwb/css_helper.rb` - CSS rendering helper
- `/app/views/pwb/custom_css/_base_variables.css.erb` - Base CSS variables
- `/app/views/pwb/custom_css/_default.css.erb` - Default theme CSS
- `/app/views/pwb/custom_css/_brisbane.css.erb` - Brisbane theme CSS
- `/app/views/pwb/custom_css/_bologna.css.erb` - Bologna theme CSS
- `/app/views/pwb/custom_css/_barcelona.css.erb` - Barcelona theme CSS
- `/app/views/pwb/custom_css/_biarritz.css.erb` - Biarritz theme CSS

### Tests
- `/spec/services/pwb/palette_validator_spec.rb` - Validator tests
- `/spec/services/pwb/palette_loader_spec.rb` - Loader tests
- `/spec/services/pwb/color_utils_spec.rb` - ColorUtils tests
- `/spec/models/concerns/pwb/website_styleable_spec.rb` - Palette integration tests
- `/spec/models/pwb/theme_spec.rb` - Theme model tests

### Layouts
- `/app/views/layouts/pwb/page_part.html.erb` - Page part layout with style injection

## 11. Testing Coverage

**WebsiteStyleable Tests** (`website_styleable_spec.rb`):
- ✓ DEFAULT_STYLE_VARIABLES constants
- ✓ style_variables merging (with/without palette)
- ✓ effective_palette_id (fallback logic)
- ✓ apply_palette! (validation and updates)
- ✓ available_palettes
- ✓ palette_options_for_select
- ✓ Cross-theme palette application (6 theme/palette combinations)
- ✓ Edge cases (nil, empty, missing keys)

**Extensive palette test coverage across all themes ensures correctness of color application.**

## Future Improvement Opportunities

### Completed (Dec 2025)
- [x] Type Safety: PaletteValidator with JSON Schema validation
- [x] Color Variants: Auto-generate Tailwind-style shade scales (50-950)
- [x] Color Consistency: Standardized color keys with legacy migration
- [x] Accessibility: WCAG contrast ratio checking via ColorUtils
- [x] Separate Files: Split palettes into 20 individual JSON files
- [x] Dark Mode: Auto-generation from light colors with explicit override support

### Still Outstanding
1. **Tailwind Integration**: Generate `tailwind.config.js` from palettes at build time
2. **State Colors**: Extend schema for hover, disabled, focus state colors
3. **Real-time Preview**: Live palette preview in admin appearance settings
4. **Library**: Extract palettes to shareable npm/gem package
