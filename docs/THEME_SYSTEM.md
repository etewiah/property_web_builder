# Theme System Documentation

This document explains how the theme system works in PropertyWebBuilder, including architecture, usage, customization, and testing.

## Overview

PropertyWebBuilder supports multiple frontend themes that allow complete customization of the public-facing website appearance. Themes are designed to be:

- **Multi-tenant aware** - Each website instance can have its own theme
- **Override-able via URL** - Themes can be temporarily switched using query parameters
- **View-based** - Themes provide custom view templates
- **Isolated** - Each theme's views are completely independent

## Architecture

### Components

#### 1. Theme Model (`Pwb::Theme`)

Located: [`app/models/pwb/theme.rb`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/theme.rb)

The `Pwb::Theme` class uses **ActiveJSON** (similar to ActiveHash) to load theme configuration from a JSON file.

```ruby
class Theme < ActiveJSON::Base
  set_root_path "#{Rails.root}/app/themes"
  set_filename "config"
  
  has_one :website, foreign_key: "theme_name", class_name: "Pwb::Website", primary_key: "name"
end
```

**Key Features:**
- Loads theme definitions from `app/themes/config.json`
- Each theme has a `name`, `friendly_name`, and `id`
- Themes are read-only at runtime (defined in JSON file)

#### 2. Theme Configuration

Located: [`app/themes/config.json`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/themes/config.json)

```json
[{
  "name": "default",
  "friendly_name": "Default Theme",
  "id": "default",
  "screenshots": [...]
}, {
  "name": "berlin",
  "friendly_name": "Berlin Theme",
  "id": "berlin"
}]
```

**Note:** Some themes in the directory are commented out in the config file and not available for selection.

#### 3. Theme Directories

Located: `app/themes/[theme_name]/`

Each theme directory contains:
```
app/themes/
├── config.json              # Theme registry
├── default/
│   └── views/               # View templates for default theme
│       ├── layouts/
│       ├── pwb/
│       └── ...
├── berlin/
│   └── views/               # View templates for berlin theme
│       ├── layouts/
│       ├── pwb/
│       └── ...
└── ...
```

#### 4. Website-Theme Association

Located: [`app/models/pwb/website.rb`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/website.rb)

```ruby
class Website < ApplicationRecord
  belongs_to_active_hash :theme, 
    optional: true, 
    foreign_key: "theme_name", 
    class_name: "Pwb::Theme", 
    primary_key: "name"
end
```

**Database Field:**
- `theme_name` (string) - Stores the name of the theme (e.g., "default", "berlin")
- Must match a theme defined in `config.json`

#### 5. Theme Resolution (ApplicationController)

Located: [`app/controllers/pwb/application_controller.rb`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/application_controller.rb)

```ruby
def set_theme_path
  theme_name = current_website&.theme_name
  
  # Allow URL parameter override
  if params[:theme].present?
    if %w(berlin default).include? params[:theme]
      theme_name = params[:theme]
    end
  end
  
  # Default to 'default' theme if not set
  theme_name = theme_name.present? ? theme_name : "default"
  
  # Prepend theme's view path
  prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"
end
```

**Resolution Order:**
1. Check URL parameter (`?theme=berlin`)
2. Use website's `theme_name` from database
3. Fall back to "default" theme

## Usage

### Setting a Theme for a Website

#### Via Admin API

```bash
PATCH /api/v1/websites/:id
Content-Type: application/json

{
  "website": {
    "theme_name": "berlin"
  }
}
```

#### Via Rails Console

```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')
website.update(theme_name: 'berlin')
```

**Validation:** The `theme_name=` setter validates that the theme exists before saving:

```ruby
def theme_name=(theme_name_value)
  theme_with_name_exists = Pwb::Theme.where(name: theme_name_value).count > 0
  if theme_with_name_exists
    write_attribute(:theme_name, theme_name_value)
  end
end
```

### Testing Themes Without Changing Settings

You can temporarily override the theme using a URL parameter:

```
http://localhost:3000/en/buy?theme=berlin
http://localhost:3000/en/contact-us?theme=default
```

**Limitation:** Only themes whitelisted in `ApplicationController#set_theme_path` can be used (currently: `berlin` and `default`).

### Listing Available Themes

#### Via API

```bash
GET /api/v1/themes
```

Response:
```json
[
  {
    "name": "default",
    "friendly_name": "Default Theme",
    "id": "default"
  },
  {
    "name": "berlin",
    "friendly_name": "Berlin Theme",
    "id": "berlin"
  }
]
```

#### Via Rails Console

```ruby
Pwb::Theme.all
# Returns array of all themes from config.json
```

## Creating a New Theme

### 1. Create Theme Directory

```bash
mkdir -p app/themes/mytheme/views
```

### 2. Add Theme to Configuration

Edit `app/themes/config.json`:

```json
[{
  "name": "default",
  ...
}, {
  "name": "berlin",
  ...
}, {
  "name": "mytheme",
  "friendly_name": "My Custom Theme",
  "id": "mytheme"
}]
```

### 3. Copy Views from Existing Theme

```bash
cp -r app/themes/default/views/* app/themes/mytheme/views/
```

### 4. Customize Views

Edit the views in `app/themes/mytheme/views/` to match your design.

### 5. Enable URL Override (Optional)

Edit `app/controllers/pwb/application_controller.rb`:

```ruby
def set_theme_path
  theme_name = current_website&.theme_name
  if params[:theme].present?
    if %w(berlin default mytheme).include? params[:theme]  # Add your theme here
      theme_name = params[:theme]
    end
  end
  # ...
end
```

### 6. Test Your Theme

```bash
# Via URL parameter
http://localhost:3000/?theme=mytheme

# Or set it for a website
website.update(theme_name: 'mytheme')
```

## Multi-Tenant Behavior

Each website (tenant) in the system can have its own theme. This is fully isolated:

```ruby
# Tenant A
website_a = Pwb::Website.find_by(subdomain: 'tenant-a')
website_a.update(theme_name: 'default')

# Tenant B
website_b = Pwb::Website.find_by(subdomain: 'tenant-b')
website_b.update(theme_name: 'berlin')
```

When users visit:
- `tenant-a.example.com` → Uses "default" theme
- `tenant-b.example.com` → Uses "berlin" theme

**Isolation:** Theme settings are stored per-website and do not affect other tenants.

## Testing

### Existing Specs

Location: [`spec/requests/pwb/themes_spec.rb`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/spec/requests/pwb/themes_spec.rb)

The test suite covers:

1. **Theme Resolution Per Tenant**
   - Default theme usage
   - Berlin theme usage
   - Fallback to default when `theme_name` is nil or empty

2. **Theme Isolation Between Tenants**
   - Verifies each tenant has correct theme
   - Tests that themes don't leak between tenants

3. **URL Parameter Override** (implied but could be expanded)

### Running Theme Tests

```bash
# Run all theme tests
bundle exec rspec spec/requests/pwb/themes_spec.rb

# Run specific test
bundle exec rspec spec/requests/pwb/themes_spec.rb:16
```

### Example Test

```ruby
it 'uses berlin theme' do
  host! 'theme-test.example.com'
  get '/'
  
  view_paths = controller.view_paths.map(&:to_s)
  expect(view_paths.any? { |p| p.include?('themes/berlin') }).to be true
end
```

## API Reference

### Theme Model

```ruby
Pwb::Theme.all           # Returns all themes from config.json
Pwb::Theme.find(1)       # Find theme by ID
Pwb::Theme.where(name: "berlin")  # Find theme by name
```

### Website Theme Methods

```ruby
website.theme            # Returns Pwb::Theme object
website.theme_name       # Returns string name (e.g., "berlin")
website.theme_name = "default"  # Set theme (with validation)
website.friendly_name    # Shortcut to theme.friendly_name
```

### Controller Methods

```ruby
current_website.theme_name    # Get current tenant's theme
params[:theme]                # URL override parameter
```

## Style Variables

Themes also support customizable style variables stored in the `style_variables_for_theme` JSONB column:

```ruby
website.style_variables  # Returns hash of style variables
# => {
#   "primary_color" => "#e91b23",
#   "secondary_color" => "#3498db",
#   "theme" => "light"
# }

website.style_variables = { primary_color: "#ff0000" }
```

**Note:** Style variables are separate from theme selection and can be customized independently.

## Troubleshooting

### Theme Not Appearing

**Problem:** Changed theme but still seeing old theme

**Solutions:**
1. Restart Rails server to reload view paths
2. Clear browser cache
3. Check `theme_name` in database matches theme in `config.json`
4. Verify theme directory exists and has views

### Invalid Theme Name

**Problem:** Setting theme_name doesn't work

**Cause:** Theme validation rejects non-existent themes

**Solution:** 
1. Verify theme exists in `app/themes/config.json`
2. Check theme name spelling (case-sensitive)
3. Restart server after adding new theme to config

### Views Not Found

**Problem:** ActionView::MissingTemplate error

**Cause:** Theme directory missing required views

**Solution:**
1. Copy all views from `default` theme as starting point
2. Ensure directory structure matches: `app/themes/[name]/views/`
3. Check view file extensions (.html.erb)

## Advanced Topics

### Theme-Specific Assets

While themes primarily control views, you can also organize assets per theme:

```
app/assets/stylesheets/pwb/themes/
├── berlin/
│   └── colors/
│       ├── default-theme.css
│       ├── dark-red-theme.css
│       └── ...
└── default/
    └── ...
```

### Dynamic Theme Loading

To add themes at runtime (not recommended for production):

1. Add theme directory
2. Update `config.json`
3. Reload ActiveJSON:
   ```ruby
   Pwb::Theme.reload
   ```

## Best Practices

1. **Always copy from default theme** when creating new themes
2. **Test on multiple screen sizes** - themes should be responsive
3. **Maintain view structure** - keep same file organization as default
4. **Document custom themes** - add README in theme directory
5. **Version control themes** - commit entire theme directory
6. **Test multi-tenant isolation** - ensure themes don't leak

## Summary

The PropertyWebBuilder theme system provides:
- ✅ Multi-tenant theme support
- ✅ URL-based theme preview
- ✅ Complete view customization
- ✅ Theme isolation
- ✅ Easy theme creation
- ✅ Comprehensive testing

For implementation details, refer to the source code files linked throughout this document.
