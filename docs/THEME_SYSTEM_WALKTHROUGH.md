# Theme System Walkthrough

This walkthrough summarizes the theme changing feature in PropertyWebBuilder.

## Feature Overview

PropertyWebBuilder includes a flexible theme system that allows each tenant to customize their frontend appearance by selecting from available themes.

**Key Features:**
- Multi-tenant theme support (each website can have its own theme)
- URL parameter override for theme preview
- Complete view customization per theme
- Isolated theme settings between tenants

## Architecture

### Components Created/Documented

#### 1. Theme Documentation
[THEME_SYSTEM.md](file:///Users/etewiah/dev/sites-legacy/property_web_builder/docs/THEME_SYSTEM.md)

Comprehensive documentation covering:
- Architecture and components
- Usage instructions
- Creating new themes
- Multi-tenant behavior
- API reference
- Troubleshooting guide
- Best practices

#### 2. Theme Model
[theme.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/theme.rb)

- Uses ActiveJSON to load themes from config file
- Provides association with Website model
- Read-only at runtime (configured via JSON)

#### 3. Theme Configuration
[config.json](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/themes/config.json)

- Defines available themes
- Currently: `default` and `berlin` themes are active
- Other themes (airbnb, matt, vic) exist but are commented out

#### 4. Theme Resolution
[application_controller.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/application_controller.rb#L8-L20)

- Runs before each request via `set_theme_path`
- Checks URL parameter first (`?theme=berlin`)
- Falls back to website's `theme_name` setting
- Defaults to `default` theme if not set
- Prepends theme view path

#### 5. Website Model Integration
[website.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/website.rb#L4)

- `belongs_to_active_hash :theme` association
- `theme_name` column stores selected theme
- Validates theme exists before saving
- Stores theme-specific style variables

## Testing

### Test Suite

[themes_spec.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/spec/requests/pwb/themes_spec.rb)

**Test Coverage (9 examples, 0 failures):**

1. **Theme Resolution Per Tenant** (4 tests)
   - Default theme usage
   - Berlin theme usage
   - Fallback when `theme_name` is `nil`
   - Fallback when `theme_name` is empty string

2. **Theme Isolation Between Tenants** (2 tests)
   - Correct theme per tenant
   - No leakage of style_variables between tenants

3. **URL Parameter Override** (3 tests - NEW)
   - Override to berlin theme
   - Override to default theme
   - Ignore invalid theme parameters

### Running Tests

```bash
# Run all theme tests
bundle exec rspec spec/requests/pwb/themes_spec.rb

# Output: 9 examples, 0 failures
```

## Usage Examples

### Set Theme for a Website

**Via API:**
```bash
PATCH /api/v1/websites/1
{
  "website": {
    "theme_name": "berlin"
  }
}
```

**Via Rails Console:**
```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')
website.update(theme_name: 'berlin')
```

### Preview Theme via URL

```
http://localhost:3000/?theme=berlin
http://localhost:3000/en/buy?theme=default
```

### List Available Themes

**Via API:**
```bash
GET /api/v1/themes

# Response:
[
  {"name": "default", "friendly_name": "Default Theme", "id": "default"},
  {"name": "berlin", "friendly_name": "Berlin Theme", "id": "berlin"}
]
```

**Via Rails Console:**
```ruby
Pwb::Theme.all
# => [#<Pwb::Theme:...>, #<Pwb::Theme:...>]
```

## Available Themes

### Active Themes

1. **Default Theme** (`default`)
   - Classic PropertyWebBuilder appearance
   - Full-featured
   - Well-tested

2. **Berlin Theme** (`berlin`)
   - Modern design
   - Alternative layout
   - Custom color schemes available

### Inactive Themes

The following themes exist in the filesystem but are not available for selection (commented out in config):
- `airbnb`
- `matt` 
- `vic`

To activate, uncomment in `app/themes/config.json`.

## Multi-Tenant Behavior

Each tenant (website) maintains its own theme selection:

```ruby
# Tenant A
website_a = Pwb::Website.find_by(subdomain: 'tenant-a')
website_a.update(theme_name: 'default')

# Tenant B
website_b = Pwb::Website.find_by(subdomain: 'tenant-b')
website_b.update(theme_name: 'berlin')
```

When users visit:
- `tenant-a.example.com` → Uses default theme
- `tenant-b.example.com` → Uses berlin theme

**Isolation Verified:** Tests confirm theme settings don't leak between tenants.

## Creating a New Theme

**Steps:**

1. Create theme directory: `app/themes/mytheme/views/`
2. Add to `config.json`:
   ```json
   {
     "name": "mytheme",
     "friendly_name": "My Custom Theme",
     "id": "mytheme"
   }
   ```
3. Copy views from default theme
4. Customize views as needed
5. Update whitelist in `ApplicationController#set_theme_path` for URL override support

See full guide in [THEME_SYSTEM.md](file:///Users/etewiah/dev/sites-legacy/property_web_builder/docs/THEME_SYSTEM.md).

## Technical Details

### View Path Resolution

When a request comes in:
1. `ApplicationController#set_theme_path` runs
2. Theme name determined (URL param → website setting → "default")
3. View path prepended: `app/themes/[theme_name]/views/`
4. Rails looks for views in theme directory first
5. Falls back to main app views if not found

### Theme-Specific Assets

Themes can also have custom CSS:
```
app/assets/stylesheets/pwb/themes/
├── berlin/colors/
│   ├── default-theme.css
│   ├── dark-red-theme.css
│   └── ...
└── default/
    └── ...
```

### Style Variables

Themes support customizable style variables (independent of theme selection):

```ruby
website.style_variables
# => {"primary_color"=>"#e91b23", "theme"=>"light", ...}

website.style_variables = { primary_color: "#ff0000" }
website.save
```

## Validation

The `Website#theme_name=` setter validates themes before saving:

```ruby
def theme_name=(theme_name_value)
  theme_with_name_exists = Pwb::Theme.where(name: theme_name_value).count > 0
  if theme_with_name_exists
    write_attribute(:theme_name, theme_name_value)
  end
end
```

**Effect:** Invalid theme names are silently ignored.

## Summary

✅ Complete documentation created  
✅ Test coverage expanded (6 → 9 tests)  
✅ All tests passing  
✅ Multi-tenant isolation verified  
✅ URL override functionality tested  
✅ Usage examples provided  

The theme system provides a robust, multi-tenant-aware way to customize the frontend appearance of PropertyWebBuilder instances.
