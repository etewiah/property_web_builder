# Theming System Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Theme Configuration](#theme-configuration)
4. [Page Part Library](#page-part-library)
5. [CSS Custom Properties](#css-custom-properties)
6. [Theme Settings Schema](#theme-settings-schema)
7. [Custom Liquid Tags](#custom-liquid-tags)
8. [Theme Inheritance](#theme-inheritance)
9. [Per-Tenant Customization](#per-tenant-customization)
10. [Creating a New Theme](#creating-a-new-theme)
11. [API Reference](#api-reference)

---

## Overview

The PropertyWebBuilder theming system provides a flexible, extensible architecture for creating and customizing website themes. The system supports:

- **Theme inheritance**: Child themes can extend parent themes
- **Page part library**: 20+ pre-built, customizable page sections
- **CSS custom properties**: Native CSS variables for easy customization
- **Per-tenant customization**: Each website can customize theme variables
- **Custom Liquid tags**: Dynamic content rendering within templates

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Theme Model | `app/models/pwb/theme.rb` | Theme metadata, inheritance, capabilities |
| Page Part Library | `app/lib/pwb/page_part_library.rb` | Registry of available page parts |
| Theme Settings Schema | `app/lib/pwb/theme_settings_schema.rb` | UI schema for theme customization |
| CSS Variables | `app/views/pwb/custom_css/_base_variables.css.erb` | Core CSS custom properties |
| Liquid Tags | `app/lib/pwb/liquid_tags/` | Custom Liquid template tags |
| Theme Config | `app/themes/config.json` | Theme definitions and metadata |

---

## Architecture

### File Structure

```
app/
├── themes/
│   ├── config.json              # Theme definitions
│   ├── default/
│   │   └── views/pwb/           # Default theme views
│   └── brisbane/
│       └── views/pwb/           # Brisbane theme overrides
├── views/pwb/
│   ├── page_parts/              # Page part templates
│   │   ├── heroes/
│   │   ├── features/
│   │   ├── testimonials/
│   │   ├── cta/
│   │   ├── stats/
│   │   ├── teams/
│   │   ├── galleries/
│   │   ├── faqs/
│   │   └── pricing/
│   └── custom_css/
│       ├── _base_variables.css.erb
│       └── _component_styles.css.erb
├── lib/pwb/
│   ├── page_part_library.rb
│   ├── theme_settings_schema.rb
│   └── liquid_tags/
│       ├── property_card_tag.rb
│       ├── featured_properties_tag.rb
│       ├── contact_form_tag.rb
│       └── page_part_tag.rb
└── models/pwb/
    └── theme.rb
```

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌────────────────┐
│  Theme Config   │────▶│   Theme Model    │────▶│  View Paths    │
│  (config.json)  │     │   (theme.rb)     │     │  (prepended)   │
└─────────────────┘     └──────────────────┘     └────────────────┘
                                │
                                ▼
                        ┌──────────────────┐
                        │  Website Model   │
                        │ (style_variables)│
                        └──────────────────┘
                                │
                                ▼
┌─────────────────┐     ┌──────────────────┐     ┌────────────────┐
│ Page Part       │────▶│  Liquid Template │────▶│ Rendered HTML  │
│ Library         │     │  (with tags)     │     │                │
└─────────────────┘     └──────────────────┘     └────────────────┘
```

---

## Theme Configuration

### config.json Structure

Themes are defined in `app/themes/config.json`:

```json
{
  "name": "default",
  "friendly_name": "Default Theme",
  "id": "default",
  "version": "2.0.0",
  "description": "A clean, modern theme suitable for any real estate website",
  "author": "PropertyWebBuilder",
  "tags": ["modern", "minimal", "responsive"],
  "parent_theme": null,
  "screenshots": ["url/to/screenshot.png"],
  "supports": {
    "page_parts": ["heroes/hero_centered", "features/feature_grid_3col"],
    "layouts": ["default", "landing", "full_width", "sidebar"],
    "color_schemes": ["light", "dark"],
    "features": {
      "sticky_header": true,
      "back_to_top": true,
      "preloader": false,
      "animations": true
    }
  },
  "style_variables": {
    "colors": {
      "primary_color": {
        "type": "color",
        "default": "#e91b23",
        "label": "Primary Color",
        "description": "Main brand color"
      }
    },
    "typography": {
      "font_primary": {
        "type": "font_select",
        "default": "Open Sans",
        "label": "Primary Font",
        "options": ["Open Sans", "Roboto", "Lato"]
      }
    }
  },
  "page_parts_config": {
    "heroes": {
      "default_variant": "hero_centered",
      "available_variants": ["hero_centered", "hero_split", "hero_search"]
    }
  }
}
```

### Configuration Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Internal theme identifier |
| `friendly_name` | String | Display name for UI |
| `version` | String | Semantic version number |
| `parent_theme` | String/null | Parent theme name for inheritance |
| `supports.page_parts` | Array | List of supported page part keys |
| `supports.layouts` | Array | Available layout options |
| `supports.color_schemes` | Array | Color scheme variants |
| `supports.features` | Object | Feature flags |
| `style_variables` | Object | Customizable style variables by category |
| `page_parts_config` | Object | Category-specific page part configuration |

---

## Page Part Library

The Page Part Library (`Pwb::PagePartLibrary`) provides a registry of all available page part templates.

### Categories

| Category | Label | Description |
|----------|-------|-------------|
| `heroes` | Hero Sections | Large banner sections for page tops |
| `features` | Features | Sections showcasing services/benefits |
| `testimonials` | Testimonials | Customer reviews and testimonials |
| `cta` | Call to Action | Sections encouraging user action |
| `stats` | Statistics | Number counters and statistics |
| `teams` | Team | Team member profiles |
| `galleries` | Galleries | Image galleries and portfolios |
| `pricing` | Pricing | Pricing tables and comparisons |
| `faqs` | FAQs | Frequently asked questions |
| `content` | Content | General content sections |
| `contact` | Contact | Contact forms and information |

### Available Page Parts

#### Heroes
- `heroes/hero_centered` - Full-width hero with centered content
- `heroes/hero_split` - Two-column hero with image
- `heroes/hero_search` - Hero with property search form

#### Features
- `features/feature_grid_3col` - Three feature cards in grid
- `features/feature_cards_icons` - Four icon cards with colors

#### Testimonials
- `testimonials/testimonial_carousel` - Sliding carousel
- `testimonials/testimonial_grid` - Grid of testimonial cards

#### Call to Action
- `cta/cta_banner` - Full-width CTA banner
- `cta/cta_split_image` - Split CTA with image

#### Statistics
- `stats/stats_counter` - Animated number counters

#### Teams
- `teams/team_grid` - Team member grid with social links

#### Galleries
- `galleries/image_gallery` - Grid gallery with lightbox

#### FAQs
- `faqs/faq_accordion` - Expandable FAQ section

#### Pricing
- `pricing/pricing_table` - Three-column pricing comparison

### Usage

```ruby
# Get all page part keys
Pwb::PagePartLibrary.all_keys
# => ["heroes/hero_centered", "heroes/hero_split", ...]

# Get page parts by category
Pwb::PagePartLibrary.for_category(:heroes)
# => { "heroes/hero_centered" => { category: :heroes, ... } }

# Get definition for specific page part
Pwb::PagePartLibrary.definition("heroes/hero_centered")
# => { category: :heroes, label: "Centered Hero", fields: [...] }

# Get template path
Pwb::PagePartLibrary.template_path("heroes/hero_centered")
# => #<Pathname:app/views/pwb/page_parts/heroes/hero_centered.liquid>

# Get JSON schema for API
Pwb::PagePartLibrary.to_json_schema
```

---

## CSS Custom Properties

### Base Variables

The CSS custom properties system uses native CSS variables defined in `_base_variables.css.erb`:

```css
:root {
  /* Color System */
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

  /* Spacing Scale */
  --pwb-space-xs: 0.25rem;
  --pwb-space-sm: 0.5rem;
  --pwb-space-md: 1rem;
  --pwb-space-lg: 1.5rem;
  --pwb-space-xl: 2rem;
}
```

### Component Styles

Component styles in `_component_styles.css.erb` use these variables:

```css
/* Buttons */
.pwb-btn--primary {
  background-color: var(--pwb-primary);
  border-radius: var(--pwb-border-radius);
}

/* Cards */
.pwb-card {
  border-radius: var(--pwb-border-radius);
  box-shadow: var(--pwb-shadow-md);
}

/* Hero Sections */
.pwb-hero {
  font-family: var(--pwb-font-heading);
}
```

### Grid System

```css
.pwb-grid--2col { grid-template-columns: repeat(2, 1fr); }
.pwb-grid--3col { grid-template-columns: repeat(3, 1fr); }
.pwb-grid--4col { grid-template-columns: repeat(4, 1fr); }

@media (max-width: 768px) {
  .pwb-grid--2col,
  .pwb-grid--3col,
  .pwb-grid--4col {
    grid-template-columns: 1fr;
  }
}
```

---

## Theme Settings Schema

The `Pwb::ThemeSettingsSchema` defines the structure for theme customization UIs.

### Schema Structure

```ruby
SCHEMA = {
  colors: {
    label: "Colors",
    description: "Customize your website's color palette",
    icon: "palette",
    order: 1,
    fields: {
      primary_color: {
        type: :color,
        default: "#e91b23",
        label: "Primary Color",
        description: "Main brand color",
        css_variable: "--pwb-primary"
      },
      secondary_color: {
        type: :color,
        default: "#2c3e50",
        label: "Secondary Color"
      }
    }
  },
  typography: {
    label: "Typography",
    fields: {
      font_primary: {
        type: :font_select,
        default: "Open Sans",
        label: "Primary Font",
        options: ["Open Sans", "Roboto", "Lato", ...]
      }
    }
  }
}
```

### Field Types

| Type | Description | Properties |
|------|-------------|------------|
| `:color` | Color picker | `default`, `css_variable` |
| `:font_select` | Font dropdown | `options`, `default` |
| `:select` | Generic dropdown | `options`, `default` |
| `:number` | Numeric input | `min`, `max`, `step`, `unit` |
| `:toggle` | Boolean switch | `default` |
| `:text` | Text input | `default`, `placeholder` |

### Usage

```ruby
# Get full schema
Pwb::ThemeSettingsSchema::SCHEMA

# Get schema for specific section
Pwb::ThemeSettingsSchema::SCHEMA[:colors]

# Access field metadata
field = Pwb::ThemeSettingsSchema::SCHEMA[:colors][:fields][:primary_color]
field[:type]     # => :color
field[:default]  # => "#e91b23"
```

---

## Custom Liquid Tags

Custom Liquid tags extend template functionality with PropertyWebBuilder-specific features.

### property_card

Renders a property card for a specific property.

```liquid
{% property_card 123 %}
{% property_card property_id %}
{% property_card 123, style: "compact" %}
```

**Options:**
- `style`: Card style variant ("default", "compact")

### featured_properties

Renders a grid of featured properties.

```liquid
{% featured_properties %}
{% featured_properties limit: 6 %}
{% featured_properties limit: 4, type: "sale" %}
{% featured_properties limit: 3, style: "compact", columns: 3 %}
{% featured_properties highlighted: "true" %}
```

**Options:**
- `limit`: Number of properties (default: 6)
- `type`: Filter by type ("sale", "rent", "all")
- `style`: Grid style ("default", "compact", "card", "grid")
- `columns`: Number of columns (default: 3)
- `highlighted`: Show only highlighted properties
- `show_price`: Show/hide price (default: true)
- `show_location`: Show/hide location (default: true)

### contact_form

Renders a contact form.

```liquid
{% contact_form %}
{% contact_form style: "compact" %}
{% contact_form style: "inline", property_id: 123 %}
```

**Options:**
- `style`: Form style ("default", "compact", "inline", "sidebar")
- `property_id`: Associate with a property
- `show_phone`: Show phone field (default: true)
- `show_message`: Show message field (default: true)
- `button_text`: Custom button text
- `success_message`: Custom success message

### page_part

Renders another page part inline.

```liquid
{% page_part "heroes/hero_centered" %}
{% page_part "cta/cta_banner", style: "primary" %}
```

**Behavior:**
1. First tries to find a saved PagePart in the database
2. Falls back to rendering directly from template file
3. Supports nested page part rendering

---

## Theme Inheritance

Themes can inherit from parent themes, allowing customization without duplication.

### How Inheritance Works

```json
{
  "name": "brisbane",
  "parent_theme": "default",
  ...
}
```

When Brisbane theme is active:
1. Views are searched in Brisbane theme first
2. If not found, falls back to default theme
3. If not found there, uses application defaults

### Theme Model Methods

```ruby
theme = Pwb::Theme.find("brisbane")

# Check inheritance
theme.has_parent?
# => true

theme.parent
# => #<Pwb::Theme name="default">

# Get full inheritance chain
theme.inheritance_chain
# => [#<Pwb::Theme name="brisbane">, #<Pwb::Theme name="default">]

# Get view paths (child theme first)
theme.view_paths
# => ["app/themes/brisbane/views", "app/themes/default/views"]
```

### Page Part Inheritance

Child themes can:
- Override specific page part templates
- Add new page part variants
- Use parent theme's page parts as-is

```ruby
# Check if theme has custom template
theme.has_custom_template?("heroes/hero_centered")
# => false (uses parent's template)

# Get available page parts (including inherited)
theme.available_page_parts
# => ["heroes/hero_centered", "heroes/hero_split", ...]
```

---

## Per-Tenant Customization

Each website can customize theme variables without affecting other tenants.

### Website Style Variables

```ruby
website = Pwb::Website.find(1)

# Get current style variables
website.style_variables
# => { "primary_color" => "#ff0000", "font_primary" => "Roboto" }

# Update style variables
website.update(style_variables: {
  "primary_color" => "#00ff00",
  "secondary_color" => "#333333"
})
```

### Merging with Theme Defaults

```ruby
# Get theme defaults
theme = Pwb::Theme.find(website.theme_name)
defaults = theme.style_variable_defaults
# => { "primary_color" => "#e91b23", ... }

# Merge with website overrides
effective_styles = defaults.merge(website.style_variables || {})
```

### In Views

```erb
<%# app/views/pwb/custom_css/custom.css.erb %>
<%
  theme = Pwb::Theme.find(current_website.theme_name)
  defaults = theme.style_variable_defaults
  styles = defaults.merge(current_website.style_variables || {})

  primary_color = styles["primary_color"]
  font_primary = styles["font_primary"]
%>

<%= render "pwb/custom_css/base_variables",
           primary_color: primary_color,
           font_primary: font_primary %>
```

---

## Creating a New Theme

### Step 1: Add Theme Configuration

Add to `app/themes/config.json`:

```json
{
  "name": "my_theme",
  "friendly_name": "My Custom Theme",
  "id": "my_theme",
  "version": "1.0.0",
  "parent_theme": "default",
  "description": "A custom theme for my agency",
  "supports": {
    "page_parts": ["heroes/hero_centered", "features/feature_grid_3col"],
    "layouts": ["default", "landing"],
    "color_schemes": ["light"]
  },
  "style_variables": {
    "colors": {
      "primary_color": {
        "type": "color",
        "default": "#your-brand-color"
      }
    }
  }
}
```

### Step 2: Create Theme Directory

```bash
mkdir -p app/themes/my_theme/views/pwb
```

### Step 3: Override Views (Optional)

Copy and modify views from parent theme:

```bash
cp -r app/themes/default/views/pwb/layouts app/themes/my_theme/views/pwb/
```

### Step 4: Create Custom Page Part Variants (Optional)

```bash
mkdir -p app/themes/my_theme/views/pwb/page_parts/heroes
```

Create `hero_custom.liquid`:

```liquid
<section class="my-theme-hero">
  <div class="container">
    <h1>{{ page_part.title.content }}</h1>
    <p>{{ page_part.subtitle.content }}</p>
  </div>
</section>
```

### Step 5: Add Theme CSS

Create `app/views/pwb/custom_css/_my_theme.css.erb`:

```css
/* My Theme Custom Styles */
.my-theme-hero {
  background: linear-gradient(135deg, var(--pwb-primary), var(--pwb-secondary));
  padding: var(--pwb-space-xl) 0;
}
```

### Step 6: Test the Theme

```ruby
# In Rails console
website = Pwb::Website.first
website.update(theme_name: "my_theme")

# Verify theme loads
theme = Pwb::Theme.find("my_theme")
theme.view_paths
theme.available_page_parts
```

---

## API Reference

### Theme Model

```ruby
class Pwb::Theme
  # Class Methods
  Theme.all           # => Array of all themes
  Theme.find(name)    # => Theme instance or nil
  Theme.find!(name)   # => Theme instance or raises
  Theme.default       # => Default theme

  # Instance Methods
  theme.name              # => "brisbane"
  theme.friendly_name     # => "Brisbane Luxury Theme"
  theme.version           # => "2.0.0"
  theme.description       # => "A luxurious theme..."
  theme.author            # => "PropertyWebBuilder"
  theme.tags              # => ["luxury", "elegant"]
  theme.screenshots       # => ["url1", "url2"]

  # Inheritance
  theme.parent_theme      # => "default" or nil
  theme.parent            # => Theme instance or nil
  theme.has_parent?       # => true/false
  theme.inheritance_chain # => [child, parent, grandparent, ...]

  # Paths
  theme.root_path         # => Pathname to theme directory
  theme.view_paths        # => Array of view paths

  # Capabilities
  theme.supported_page_parts  # => ["heroes/hero_centered", ...]
  theme.supported_layouts     # => ["default", "landing", ...]
  theme.supported_color_schemes # => ["light", "dark"]
  theme.supported_features    # => { sticky_header: true, ... }

  # Page Parts
  theme.has_custom_template?(key) # => true/false
  theme.available_page_parts      # => All available parts
  theme.page_part_variants(category) # => Variants for category

  # Style Variables
  theme.style_variable_schema   # => Full schema from config
  theme.style_variable_defaults # => Default values hash

  # Serialization
  theme.as_api_json # => Hash for API responses
end
```

### PagePartLibrary

```ruby
module Pwb::PagePartLibrary
  # Categories
  CATEGORIES  # => Hash of category definitions

  # Definitions
  DEFINITIONS # => Hash of all page part definitions

  # Query Methods
  all_keys           # => Array of all keys
  by_category        # => Hash grouped by category
  for_category(cat)  # => Parts for specific category
  definition(key)    # => Definition hash for key
  exists?(key)       # => true/false

  # Templates
  template_exists?(key) # => true/false
  template_path(key)    # => Pathname or nil

  # Categories
  categories         # => All category definitions
  category_info(cat) # => Single category info

  # Filtering
  modern_parts      # => Non-legacy parts
  legacy_parts      # => Legacy parts only

  # API
  to_json_schema    # => Full schema for API
end
```

### ThemeSettingsSchema

```ruby
module Pwb::ThemeSettingsSchema
  SCHEMA # => Full schema hash

  # Structure:
  # {
  #   section_key: {
  #     label: "Section Name",
  #     description: "...",
  #     icon: "icon-name",
  #     order: 1,
  #     fields: {
  #       field_key: {
  #         type: :color|:font_select|:select|:number|:toggle|:text,
  #         default: "value",
  #         label: "Field Label",
  #         description: "...",
  #         options: [...],  # for select types
  #         min: 0, max: 100, step: 1, unit: "px"  # for number
  #       }
  #     }
  #   }
  # }
end
```

---

## Best Practices

### 1. Use Semantic CSS Classes

```liquid
<!-- Good -->
<div class="hero-section">
  <h1 class="hero-title">{{ title }}</h1>
</div>

<!-- Avoid -->
<div class="bg-gray-900 h-[600px] flex items-center">
  <h1 class="text-4xl font-bold text-white">{{ title }}</h1>
</div>
```

### 2. Leverage CSS Variables

```css
/* Good - Uses theme variables */
.hero-title {
  color: var(--pwb-primary);
  font-family: var(--pwb-font-heading);
}

/* Avoid - Hardcoded values */
.hero-title {
  color: #e91b23;
  font-family: "Montserrat", sans-serif;
}
```

### 3. Design for Inheritance

When creating themes, consider:
- Only override what needs to change
- Use parent theme's components where possible
- Keep customizations minimal and focused

### 4. Test Across Tenants

```ruby
# Ensure tenant isolation
Pwb::Website.find_each do |website|
  Pwb::Current.website = website
  theme = Pwb::Theme.find(website.theme_name)

  # Verify theme loads correctly
  assert theme.present?
  assert theme.view_paths.all? { |p| File.directory?(p) }
end
```

### 5. Document Custom Page Parts

When adding custom page parts, update the library:

```ruby
# In app/lib/pwb/page_part_library.rb
DEFINITIONS = {
  'my_theme/custom_hero' => {
    category: :heroes,
    label: 'Custom Hero',
    description: 'Theme-specific hero variant',
    fields: %w[title subtitle background_image]
  }
}
```

---

## Troubleshooting

### Theme Not Loading

1. Check theme exists in config.json
2. Verify website's `theme_name` matches config
3. Check view paths are correct:
   ```ruby
   theme = Pwb::Theme.find(current_website.theme_name)
   puts theme.view_paths
   ```

### Styles Not Applying

1. Clear Rails cache: `Rails.cache.clear`
2. Check CSS variables are defined in `_base_variables.css.erb`
3. Verify website's `style_variables` JSON is valid

### Page Part Not Rendering

1. Check template exists: `Pwb::PagePartLibrary.template_exists?(key)`
2. Verify Liquid syntax in template
3. Check `block_contents` has data for current locale

### Liquid Tag Errors

1. Ensure tags are loaded: check `config/initializers/liquid.rb`
2. Verify tag syntax matches documentation
3. Check Rails logs for Liquid parsing errors

---

## Migration from Legacy System

If migrating from the legacy theming system:

### 1. Update Theme Config

Convert old YAML configs to new JSON format in `config.json`.

### 2. Migrate Style Variables

```ruby
# Old format (in website model)
website.custom_css_styles # => "primary_color: #ff0000\n..."

# New format
website.style_variables # => { "primary_color" => "#ff0000" }
```

### 3. Update Page Parts

Legacy page parts are supported but marked:

```ruby
Pwb::PagePartLibrary.legacy_parts
# => { "our_agency" => { legacy: true, ... } }
```

Consider migrating to modern equivalents for better support.
