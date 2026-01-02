# Site Admin Settings Architecture

## Overview

PropertyWebBuilder uses a comprehensive multi-level settings system with two main admin dashboards:

1. **Site Admin** - Single website/tenant management (per-website settings)
2. **Tenant Admin** - Platform-wide management (cross-tenant settings)

This document focuses on the **Site Admin Settings System** for website-level configuration.

---

## Architecture Overview

### Routing Structure

**Site Admin Routes** (namespace: `site_admin`)
- Located in `/config/routes.rb` (lines 312-334)
- Scoped to the current website via SubdomainTenant concern
- All requests are multi-tenant aware through `current_website` context

**Key Routes:**
```ruby
namespace :website do
  get 'settings', to: 'settings#show', as: 'settings'
  get 'settings/:tab', to: 'settings#show', as: 'settings_tab'
  patch 'settings', to: 'settings#update'
  patch 'settings/links', to: 'settings#update_links'
  post 'test_notifications', to: 'settings#test_notifications'
end

namespace :properties do
  get 'settings', to: 'settings#index'
  get 'settings/:category', to: 'settings#show'
  post 'settings/:category', to: 'settings#create'
  patch 'settings/:category/:id', to: 'settings#update'
  delete 'settings/:category/:id', to: 'settings#destroy'
end
```

---

## Website Settings System

### Controller: `SiteAdmin::Website::SettingsController`

**Location:** `/app/controllers/site_admin/website/settings_controller.rb`

**Responsibilities:**
- Manages website-level configuration through tabs
- Handles multilingual settings
- Manages appearance (theme/palette selection)
- Controls notifications (ntfy push notifications)
- SEO and social media configuration
- Navigation link management

**Tab-based Architecture:**
```ruby
VALID_TABS = %w[general appearance navigation home notifications seo social].freeze
```

### Tab Structure

#### 1. **General Tab**
Settings in this tab update the Website model directly.

**Managed Fields:**
- `default_client_locale` - Default language for visitors
- `supported_locales` - Array of language codes
- `default_currency` - Permanent (locked after setup)
- `available_currencies` - Array of currencies for display/conversion
- `default_area_unit` - Unit of measurement (sqmt/sqft)
- `external_image_mode` - Allow external image URLs

**Form Handling:**
- Uses both `pwb_website` and `website` parameter keys for flexibility
- Filters out blank values from arrays
- Validates default locale is in supported locales

**Storage:** Direct Database Columns
```ruby
t.string :default_client_locale, default: "en-UK"
t.text :supported_locales, array: true, default: ["en-UK"]
t.string :default_currency, default: "EUR"
t.text :available_currencies, array: true
t.integer :default_area_unit, default: 0  # enum: sqmt/sqft
t.boolean :external_image_mode, default: false
```

#### 2. **Appearance Tab**
Theme and styling configuration using the WebsiteStyleable concern.

**Managed Fields:**
- `theme_name` - Selected theme
- `selected_palette` - Palette within theme
- `dark_mode_setting` - Dark mode preference
- `raw_css` - Custom CSS overrides
- `style_variables` - JSON with CSS variable values

**Palette System:**
- Dynamic mode: CSS variables set at runtime
- Compiled mode: Pre-generated static CSS
- Palettes include color swatches and descriptions
- Can compile to static CSS for production performance

**Storage:**
```ruby
t.string :theme_name
t.string :selected_palette
t.string :dark_mode_setting, default: "light_only"
t.text :raw_css
t.json :style_variables_for_theme, default: {}
t.string :palette_mode, default: "dynamic"
t.text :compiled_palette_css
t.datetime :palette_compiled_at
```

#### 3. **Navigation Tab**
Manages top navigation and footer links.

**Related Model:** `Pwb::Link`
- Associated with website via `has_many :links`
- Supports multilingual titles via Mobility gem
- Has visibility and sort_order attributes
- Ordered by `sort_order` asc

**Key Methods:**
- `update_navigation_links` - Batch update links from admin UI
- Supports both single title and locale-specific titles
- Uses Mobility for JSONB multilingual storage

**Storage:**
```ruby
class Link < ApplicationRecord
  # Uses Mobility for translations (JSONB)
  translates :link_title  # Stores in JSONB with locale keys
  
  # Direct columns
  t.string :link_path
  t.boolean :visible
  t.integer :sort_order
  t.string :link_title (fallback)
end
```

#### 4. **Home Tab**
Landing page configuration.

**Home Page Title:**
- Updates `Page` model where slug='home'
- Field: `page_title`

**Display Options:**
- `landing_hide_for_rent` - Flag to hide rental properties
- `landing_hide_for_sale` - Flag to hide sale properties
- `landing_hide_search_bar` - Flag to hide search bar

**Storage:** Using FlagShihTzu gem
```ruby
has_flags 1 => :landing_hide_for_rent,
          2 => :landing_hide_for_sale,
          3 => :landing_hide_search_bar
# Stored as integer bitmask in :flags column
```

#### 5. **Notifications Tab**
Push notification configuration via ntfy.sh service.

**Managed Fields:**
- `ntfy_enabled` - Boolean toggle
- `ntfy_server_url` - ntfy server URL
- `ntfy_topic_prefix` - Custom topic prefix
- `ntfy_access_token` - Authentication token (masked in forms)
- `ntfy_notify_inquiries` - Send on new inquiries
- `ntfy_notify_listings` - Send on listing changes
- `ntfy_notify_users` - Send on user events
- `ntfy_notify_security` - Send on security events

**Special Handling:**
- Password field masks token with placeholder '••••••••••••'
- Token not cleared if placeholder is submitted
- `test_notifications` action verifies configuration

**Storage:**
```ruby
t.boolean :ntfy_enabled, default: false
t.string :ntfy_server_url, default: "https://ntfy.sh"
t.string :ntfy_topic_prefix
t.string :ntfy_access_token  # Masked in forms
t.boolean :ntfy_notify_inquiries, default: true
t.boolean :ntfy_notify_listings, default: true
t.boolean :ntfy_notify_security, default: true
t.boolean :ntfy_notify_users, default: false
```

#### 6. **SEO Tab**
Search engine optimization and social media metadata.

**Managed Fields:**
- `default_seo_title` - Default page title
- `default_meta_description` - Default meta description
- `favicon_url` - Favicon URL
- `main_logo_url` - Main logo URL
- `social_media` - JSON object with social metadata

**Social Media:**
- Stored as JSON in `social_media` column
- Key-value pairs for different platforms
- Merged with current values, not replaced

**Storage:**
```ruby
t.string :default_seo_title
t.text :default_meta_description
t.string :favicon_url
t.string :main_logo_url
t.json :social_media, default: {}
```

#### 7. **Social Tab**
Social media link management.

**Related Model:** `Pwb::SocialMediaLink` (implied)
- Updates via `update_social_media_link(platform, url)` method
- Platforms: facebook, twitter, instagram, linkedin, etc.

**Special Features:**
- Uses `social_media_links_for_admin` method for form display
- Supports multiple social platforms per website

---

## Properties Settings System

### Controller: `SiteAdmin::Properties::SettingsController`

**Location:** `/app/controllers/site_admin/properties/settings_controller.rb`

**Purpose:** Manage property-specific field keys and categories

### Category Structure

**Uses Centralized Configuration:** `Pwb::Config::FIELD_KEY_CATEGORIES`

**Categories Include:**
- Property Types (types.*)
- Property States (states.*)
- Property Features (features.*)
- Property Amenities (amenities.*)
- Property Status (status.*)
- Property Highlights (highlights.*)
- Listing Origin (origin.*)

**URL-friendly mapping:**
```
property-types → database tag: 'property-types'
property-features → database tag: 'property-features'
etc.
```

### Field Key Model: `PwbTenant::FieldKey`

**Features:**
- Multi-tenant scoped via `acts_as_tenant`
- Automatic website_id assignment
- Multilingual labels via Mobility gem (JSONB storage)
- Global key format: `{prefix}.{snake_case_name}`
- Visibility and sort_order control

**Attributes:**
```ruby
t.string :global_key      # e.g., "types.apartment"
t.string :tag             # e.g., "property-types"
t.boolean :visible        # Show/hide in public interface
t.integer :sort_order     # Display order
# Mobility translations stored in JSONB:
t.jsonb :label_translations  # {"en": "Apartment", "es": "Apartamento"}
```

**Key Generation:**
- Prefix based on category (types, features, amenities, etc.)
- Base name from English translation (parameterized)
- Uniqueness check with timestamp suffix fallback

**Translation Management:**
- Uses Mobility gem for JSONB translations
- Supports per-locale labels
- Locale-specific setters: `label_en=`, `label_es=`, etc.

---

## Data Storage Patterns

### 1. **Direct Database Columns**
Used for frequently accessed, single-value settings:
- `theme_name`, `selected_palette`, `default_currency`
- `analytics_id`, `external_image_mode`
- Boolean toggles (flags)

### 2. **Text Arrays** (PostgreSQL text[])
Used for lists that don't need complex structure:
- `supported_locales` - Array of locale codes
- `available_currencies` - Array of currency codes
- `sale_price_options_from/till` - Price range options

**Advantages:**
- Simple indexed queries
- No parsing needed
- Rails handles conversion automatically
- Array-like access: `website.supported_locales[0]`

### 3. **JSON Columns**
Used for flexible, nested configuration:

**`configuration` (JSON):**
- `admin_page_links` - Cached navigation structure

**`social_media` (JSON):**
```ruby
{
  "twitter": "https://twitter.com/...",
  "facebook": "https://facebook.com/...",
  "og_title": "...",
  "og_description": "...",
  ...
}
```

**`style_variables_for_theme` (JSON):**
```ruby
{
  "default": {
    "primary_color": "#e91b23",
    "secondary_color": "#3498db",
    "font_primary": "Open Sans",
    ...
  }
}
```

**`external_feed_config` (JSON):**
Provider-specific configuration (resales_online, etc.)

### 4. **JSONB with Mobility** (Multilingual)
Used for content that needs translation:
- `FieldKey.label` - Property field labels in multiple languages
- `Link.link_title` - Navigation link text in multiple languages

**Storage Format:**
```ruby
# In JSONB column: label_translations
{
  "en": "Apartment",
  "es": "Apartamento",
  "fr": "Appartement"
}

# Accessed via:
Mobility.with_locale(:en) { field_key.label }  # => "Apartment"
Mobility.with_locale(:es) { field_key.label }  # => "Apartamento"
```

### 5. **Flags/Bitmask** (Integer)
Used for multiple boolean settings efficiently:
- Uses `FlagShihTzu` gem
- Single integer column stores multiple flags
- Each flag maps to a bit position

**Example:**
```ruby
has_flags 1 => :landing_hide_for_rent,
          2 => :landing_hide_for_sale,
          3 => :landing_hide_search_bar

# Stored as single integer in :flags column
# Bit 0 (value 1): landing_hide_for_rent
# Bit 1 (value 2): landing_hide_for_sale
# Bit 2 (value 4): landing_hide_search_bar
```

---

## Controller Parameter Handling

### Permitting Parameters

**General Settings:**
```ruby
params.require(param_key).permit(
  :company_display_name,
  :default_client_locale,
  :default_currency,
  :default_area_unit,
  supported_locales: [],
  available_currencies: []
)
```

**Appearance Settings:**
```ruby
params.require(:website).permit(
  :theme_name,
  :selected_palette,
  :dark_mode_setting,
  :raw_css
  # style_variables handled separately via to_unsafe_h
)
```

**Notification Settings:**
```ruby
params.require(param_key).permit(
  :ntfy_enabled,
  :ntfy_server_url,
  :ntfy_topic_prefix,
  :ntfy_access_token,
  :ntfy_notify_inquiries,
  :ntfy_notify_listings,
  :ntfy_notify_users,
  :ntfy_notify_security
)
```

### Key Features

**Flexible Parameter Keys:**
- Accept both `:pwb_website` and `:website` param keys
- Handles form naming inconsistencies
- Fallback pattern: `param_key = params.key?(:pwb_website) ? :pwb_website : :website`

**Array Filtering:**
- Removes blank values from array fields
- Ensures empty array when no checkboxes selected
- Uses hidden field + visible checkboxes pattern

**Unsafe Hashing:**
- Style variables use `.to_unsafe_h` for nested structures
- Required because style variables are flexible JSON

---

## Website Model Concerns

### Included Concerns

1. **WebsiteProvisionable** - Provisioning state management
2. **WebsiteDomainConfigurable** - Custom domain handling
3. **WebsiteStyleable** - Theme, palette, CSS management
4. **WebsiteSubscribable** - Subscription handling
5. **WebsiteSocialLinkable** - Social media links
6. **WebsiteLocalizable** - Locale validation and management
7. **WebsiteThemeable** - Theme accessibility and defaults

### WebsiteStyleable Concern

**Key Methods:**
- `style_variables` - Get merged variables (base + palette colors)
- `current_theme` - Get Theme object (falls back to 'default')
- `effective_palette_id` - Get palette ID (selected or default)
- `apply_palette!(palette_id)` - Apply palette to website
- `compile_palette!` - Generate static CSS
- `dark_mode_enabled?` - Check if dark mode is active
- `css_variables` - Get CSS variable declarations
- `css_variables_with_dark_mode` - Get full CSS with dark mode

**Palette Modes:**
- **Dynamic:** CSS variables at runtime (development-friendly)
- **Compiled:** Static CSS with hex values (production-optimized)

### WebsiteLocalizable Concern

**Key Methods:**
- `is_multilingual` - Check if multiple languages supported
- `supported_locales_with_variants` - Get locales with country variants
- `default_client_locale_to_use` - Get effective default language

**Validation:**
- `default_locale_in_supported_locales` - Ensures default is in supported list

### WebsiteThemeable Concern

**Key Methods:**
- `accessible_themes` - Themes available to this website
- `accessible_theme_names` - Theme name list
- `theme_accessible?(name)` - Check if theme is available
- `update_available_themes(themes)` - Set custom theme availability

**Theme Availability:**
- Website-specific list (if set)
- Falls back to tenant defaults from `TenantSettings`
- Always includes 'default' theme

---

## Tenant Settings

### Model: `Pwb::TenantSettings`

**Location:** `/app/models/pwb/tenant_settings.rb`

**Pattern:** Singleton model (only one record per tenant)

**Purpose:** Platform-wide defaults and configuration

**Key Fields:**
- `default_available_themes` - Array of theme names
- `configuration` - JSON for other settings

**Singleton Access:**
```ruby
Pwb::TenantSettings.instance                  # Get/create instance
Pwb::TenantSettings.default_themes            # Class method shorthand
Pwb::TenantSettings.update_default_themes([]) # Update defaults
```

---

## Form Views Architecture

### Tab Navigation Pattern

**File:** `/app/views/site_admin/website/settings/show.html.erb`

**Structure:**
```erb
<%= render 'tab_navigation', current_tab: @tab %>

<div>
  <% case @tab %>
  <% when 'general' %>
    <%= render 'general_tab' %>
  <% when 'appearance' %>
    <%= render 'appearance_tab' %>
  <% ... %>
</div>
```

### Tab Partial Patterns

Each tab is a separate partial with:
1. Form opening with hidden tab field
2. Setting-specific form groups
3. Styled form inputs using Tailwind CSS
4. Help text and validation messages
5. Submit button (or additional buttons)

**Form Conventions:**
- Use `form_with model: @website` with `local: true`
- Include `<input type="hidden" name="tab" value="...">` to track which tab
- Submit to single `site_admin_website_settings_path` with PATCH method
- Controller handles routing based on tab value

### Frontend Helpers

**Stimulus JS Controllers:**
- `theme-palette` - Dynamic theme/palette switching

**JavaScript Enhancements:**
- Locale validation (default in supported)
- Toggle visibility of conditional fields
- Password field masking for tokens
- Dynamic placeholder updates

---

## Multi-tenant Scoping

### Current Website Context

**Accessed via:**
```ruby
current_website  # Set by SubdomainTenant concern
```

**Automatic Scoping:**
- All queries scope to current_website
- `acts_as_tenant` on multi-tenant models
- website_id foreign keys on tenant-scoped tables

### Related Models Scoped to Website

- `Pwb::Link` - Navigation links
- `Pwb::Page` - Pages (via website_id)
- `Pwb::Content` - Page content
- `PwbTenant::FieldKey` - Property field keys
- `Pwb::EmailTemplate` - Email templates
- `Pwb::Media` - Media library
- `Pwb::Widget` - Embeddable widgets

---

## Validation & Error Handling

### Model Validations (in Concerns)

**WebsiteLocalizable:**
- `default_locale_in_supported_locales` - Custom validator

**WebsiteStyleable:**
- `palette_mode` - Inclusion validator (dynamic/compiled)

**WebsiteThemeable:**
- `theme_must_be_accessible` - Validates theme is in accessible list

### Controller Response Handling

**Success:**
```ruby
redirect_to site_admin_website_settings_tab_path(tab), 
            notice: 'Settings updated successfully'
```

**Failure:**
```ruby
@themes = @website.accessible_themes  # Reload for re-render
flash.now[:alert] = 'Failed to update settings'
render :show, status: :unprocessable_entity
```

---

## Performance Considerations

### Memoization

**Theme Caching:**
- `@current_theme ||= ...` - Cached per request
- Cleared when `theme_name` changes
- `refresh_theme_data!` - Force refresh

**Palette Loader:**
- `@palette_loader ||= PaletteLoader.new`
- Reads palette files once per request
- Cleared when palette selection changes

### Database Optimization

**Indexes:**
- `theme_name`, `selected_palette` - Indexed for quick lookups
- `provisioning_state`, `external_feed_enabled` - Indexed for filtering
- `subdomain`, `custom_domain` - Unique indexed

**Array Column Efficiency:**
- `supported_locales`, `available_currencies` - PostgreSQL arrays
- Direct queries: `where("supported_locales @> ?", ['en-UK'])`
- Efficient for small lists (< 50 items)

### Caching Strategies

**Configuration Caching:**
- `admin_page_links` - Cached in JSON when updated
- Generated from links on update
- Refreshed via `update_admin_page_links` method

---

## Extension Points & Patterns

### Adding a New Website Setting

**Steps:**

1. **Add Database Column**
   ```ruby
   # db/migrate/xxxxx_add_new_setting_to_websites.rb
   add_column :pwb_websites, :new_setting, :string, default: 'value'
   ```

2. **Add Form Input** (in appropriate tab partial)
   ```erb
   <div>
     <label>Setting Label</label>
     <%= f.text_field :new_setting, ... %>
   </div>
   ```

3. **Add Parameter Permission** (in controller)
   ```ruby
   def tab_settings_params
     params.require(:website).permit(:new_setting, ...)
   end
   ```

4. **Add Update Logic** (in controller)
   ```ruby
   def update_tab_settings
     if @website.update(tab_settings_params)
       redirect_to ..., notice: 'Success'
     else
       render :show, status: :unprocessable_entity
     end
   end
   ```

### Adding a New Field Key Category

**Steps:**

1. **Register in Pwb::Config::FIELD_KEY_CATEGORIES**
2. **Map URL-friendly name to database tag**
3. **Create translations/labels**
4. **Controller handles rest (uses centralized config)**

---

## Common Patterns & Best Practices

### 1. **Preserving Masked Passwords**
```ruby
if params[:field] == '••••••••••••' || params[:field].blank?
  filtered_params.delete(:field)
end
```

### 2. **Merging JSON (Don't Replace)**
```ruby
current_value = @website.social_media || {}
@website.social_media = current_value.merge(params[:social_media])
```

### 3. **Filtering Array Blanks**
```ruby
filtered_params[:array_field] = filtered_params[:array_field].reject(&:blank?)
```

### 4. **Multilingual Text with Mobility**
```ruby
Mobility.with_locale(locale.to_sym) do
  model.translatable_field = text
end
model.save!
```

### 5. **Tab-based Controller Pattern**
- Set tab in `before_action`
- Validate tab in whitelist
- Route all updates through single action
- Use nested case statement for logic

---

## Summary Table

| Component | Type | Location | Multi-tenant | Storage |
|-----------|------|----------|--------------|---------|
| Website Settings | Controller | `site_admin/website/settings` | Yes | Multiple |
| Properties Settings | Controller | `site_admin/properties/settings` | Yes | FieldKey model |
| Theme/Palette | Concern | WebsiteStyleable | Per-website | JSON + columns |
| Locales | Concern | WebsiteLocalizable | Per-website | Array column |
| Navigation Links | Model | Pwb::Link | Yes | Database |
| Field Keys | Model | PwbTenant::FieldKey | Yes | JSONB translations |
| Tenant Defaults | Model | Pwb::TenantSettings | No (singleton) | JSONB |

---

## Related Documentation

- Theme System: `/docs/admin/themes.md`
- Multilingual Support: `/docs/admin/localization.md`
- Field Keys System: `/docs/field_keys/`
- Multi-tenancy: `/docs/multi_tenancy/`
