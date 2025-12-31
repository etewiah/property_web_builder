# PropertyWebBuilder Admin Interface Documentation

## Overview

The PropertyWebBuilder admin interface provides a comprehensive dashboard for managing properties, website settings, pages, and content. This documentation focuses on the `/en/admin/properties/settings` section and its subsections.

**Access URL**: `http://tenant-b.e2e.localhost:3001/en/admin/properties/settings`

## Architecture

### Frontend

The admin interface is a **Vue.js Single Page Application (SPA)** located in:
```
app/frontend/v-admin-app/src/
```

**Key Components**:
- **Router**: `src/router/index.js` - Uses Vue Router with history mode at `/v-admin/` base path
- **Layout**: `src/layouts/MainLayout.vue` - Contains sidebar navigation and main content area
- **Components**: Modular Vue components for different admin sections

### Backend

**Controller**: `Pwb::AdminPanelController` ([view file](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/admin_panel_controller.rb))
- Serves the Vue SPA
- Authenticates users via Devise
- Checks admin permissions with `user_is_admin_for_subdomain?` method
- Layout: `pwb/admin_panel` loads the compiled Vue application

**Routes** (`config/routes.rb`):
```ruby
get "/admin" => "admin_panel#show"
get "/admin/*path" => "admin_panel#show"
scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
  get "/admin" => "admin_panel#show", as: "admin_with_locale"
  get "/admin/*path" => "admin_panel#show"
end
```

## Dashboard Structure

### Main Navigation Sections

![Admin Dashboard](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/admin_dashboard_exploration_1764855512829.webp)

1. **Home** - Dashboard with quick actions
2. **Properties** - Property management
   - List
   - Labels (settings)
   - New Property
3. **Website** - Website configuration
   - Settings
   - Footer
4. **Pages** - Content pages
   - Home, Sell, About Us, Contact Us, Legal Notice, Privacy Policy
5. **Import Data** - Bulk import functionality

## Properties Settings

The Properties Settings section (`/en/admin/properties/settings`) provides four configuration tabs for managing property-related metadata and classifications.

### 1. Property Types

**URL**: `/en/admin/properties/settings/property-types`

![Property Types Settings](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/properties_settings_types_1764855588571.png)

**Purpose**: Define and manage the types of properties available in the system.

**Default Types**:
- Apartment
- Villa
- Land
- Commercial
- Office

**Features**:
- **Multilingual Support**: Each property type has translations in multiple languages (English, Spanish, French visible in UI)
- **CRUD Operations**:
  - Add new property types via "Add New Entry" button
  - Edit existing types inline
  - Delete types (trash icon)
- **Usage**: Appears in property listings, search filters, and property creation forms

**Database Tag**: `property-types`

### 2. Features (Extras)

**URL**: `/en/admin/properties/settings/extras`

![Property Features Settings](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/properties_settings_features_1764855592087.png)

**Purpose**: Manage amenities and features that can be associated with properties.

**Default Features**:
- Air conditioning
- Alarm
- Balcony
- Barbecue
- Elevator
- Fitted wardrobes
- Garden
- Garage
- Heating
- Pool
- Sea views
- Storage room
- Terrace

**Features**:
- **Multilingual Support**: Feature names translated across all supported languages
- **CRUD Operations**: Add, edit, and delete features
- **Checkbox System**: Features are typically displayed as checkboxes in property forms
- **Usage**: Used in property detail pages and search filters

**Database Tag**: `extras`

### 3. Property States

**URL**: `/en/admin/properties/settings/property-states`

![Property States Settings](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/properties_settings_states_1764855608343.png)

**Purpose**: Define the condition or state of properties.

**Default States**:
- New
- Good
- Needs renovation
- To reform

**Features**:
- **Multilingual Support**: State names in all supported languages
- **CRUD Operations**: Full management capabilities
- **Usage**: Helps buyers/renters understand property condition

**Database Tag**: `property-states`

### 4. Property Labels

**URL**: `/en/admin/properties/settings/property-labels`

![Property Labels Settings](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/properties_settings_prop_labels_1764855611821.png)

**Purpose**: Manage special labels/tags that can be applied to properties for highlighting or categorization.

**Default Labels**:
- Featured
- Sold
- Rented
- New on market
- Price reduced
- Reserved

**Features**:
- **Multilingual Support**: Label text in all languages
- **CRUD Operations**: Complete management
- **Visual Indicators**: Often displayed as badges/tags on property listings
- **Usage**: Marketing and status communication

**Database Tag**: `property-labels`

## Backend Implementation

### FieldKey Model

**File**: `app/models/pwb/field_key.rb`

The `FieldKey` model is the core data structure for all settings:

```ruby
class Pwb::FieldKey < ApplicationRecord
  # Stores:
  # - tag: category identifier (e.g., "property-types", "extras")
  # - global_key: unique i18n translation key
  # - Other attributes for visibility, ordering, etc.
  
  scope :visible, -> { where(visible: true) }
  
  # Methods for retrieving options by tag
  def self.get_options_by_tag(tag)
    where(tag: tag).visible.pluck("global_key")
  end
end
```

**Database Table**: `pwb_field_keys`

### API Endpoints

#### Get Settings Values

**Endpoint**: `GET /api/v1/select_values/by_field_names`

**Controller**: `Pwb::Api::V1::SelectValuesController` ([view file](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/api/v1/select_values_controller.rb))

**Parameters**:
- `field_names` (string): Comma-separated list of tags

**Example Request**:
```
GET /api/v1/select_values/by_field_names?field_names=property-types,extras
```

**Response**:
```json
{
  "property-types": [
    "prop_type.apartment",
    "prop_type.villa",
    "prop_type.land"
  ],
  "extras": [
    "extras.air_conditioning",
    "extras.alarm",
    "extras.balcony"
  ]
}
```

**Implementation**:
```ruby
def by_field_names
  field_names_string = params["field_names"] || ""
  field_names_array = field_names_string.split(",")
  select_values = {}
  
  field_names_array.each do |field_name_id|
    field_name_id = field_name_id.strip
    translation_keys = FieldKey.where(tag: field_name_id).visible.pluck("global_key")
    select_values[field_name_id] = translation_keys
  end
  
  render json: select_values
end
```

### Internationalization (I18n)

The system uses Rails I18n for translations:

1. **Storage**: Translation keys stored in `FieldKey.global_key`
2. **Format**: Keys follow pattern `category.item` (e.g., `prop_type.apartment`)
3. **Files**: Translations in `config/locales/*/`
4. **Frontend**: Vue components fetch and display localized strings

## Frontend-Backend Interaction Flow

### Loading Settings

```
1. User navigates to /en/admin/properties/settings/property-types
   ↓
2. Vue Router loads the settings component
   ↓
3. Component makes API request:
   GET /api/v1/select_values/by_field_names?field_names=property-types
   ↓
4. Backend queries FieldKey model:
   FieldKey.where(tag: "property-types").visible.pluck("global_key")
   ↓
5. Returns array of i18n keys:
   ["prop_type.apartment", "prop_type.villa", ...]
   ↓
6. Frontend displays with translations in all languages
```

### Saving Changes

```
1. User edits a property type name
   ↓
2. Vue component sends update request
   ↓
3. Backend updates FieldKey record
   ↓
4. Updates corresponding i18n translations
   ↓
5. Returns success/error response
   ↓
6. Frontend refreshes display
```

## Technical Stack

### Frontend
- **Framework**: Vue 3
- **Router**: Vue Router 4 (history mode)
- **State**: Composition API
- **UI**: Quasar Framework components
- **Build**: Vite

### Backend
- **Framework**: Ruby on Rails 7+
- **Authentication**: Devise
- **API**: RESTful JSON endpoints
- **Database**: PostgreSQL (inferred from multi-tenancy)

## Multi-Tenancy

The admin interface is **tenant-scoped**:

- Each subdomain has its own set of field settings
- `FieldKey` records are associated with `Pwb::Website`
- Admin users can only modify settings for their subdomain
- Permission check: `current_user.admin_for?(website)`

## Security

**Authentication**:
- Required for all admin routes
- Devise `authenticate_user!` before action
- Redirects to sign-in if not authenticated

**Authorization**:
- `user_is_admin_for_subdomain?` method checks:
  - User is authenticated
  - Subdomain is present
  - Website exists for subdomain
  - User has admin/owner role for that specific website

**CSRF Protection**:
- Rails CSRF tokens for form submissions
- API controller uses `protect_from_forgery with: :null_session`

## Usage Examples

### Adding a New Property Type

1. Navigate to `/en/admin/properties/settings/property-types`
2. Click "Add New Entry"
3. Enter name in all supported languages
4. Save
5. New type immediately available in property creation forms

### Editing a Feature

1. Go to `/en/admin/properties/settings/extras`
2. Click inline on the feature name
3. Modify text for any language
4. Changes auto-saved
5. Updated feature appears in property edit forms

## Related Files

**Frontend**:
- Router: [app/frontend/v-admin-app/src/router/routes.js](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/frontend/v-admin-app/src/router/routes.js)
- Components directory: `app/frontend/v-admin-app/src/components/`
- Editor forms: `app/frontend/v-admin-app/src/components/editor-forms/`

**Backend**:
- Controller: [app/controllers/pwb/admin_panel_controller.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/admin_panel_controller.rb)
- API Controller: [app/controllers/pwb/api/v1/select_values_controller.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/pwb/api/v1/select_values_controller.rb)
- Model: [app/models/pwb/field_key.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/field_key.rb)
- Routes: [config/routes.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/config/routes.rb)

## Next Steps for Enhancement

1. **Validation**: Add frontend validation for duplicate entries
2. **Ordering**: Implement drag-and-drop reordering
3. **Bulk Operations**: Add import/export for settings
4. **Audit Trail**: Track who modified settings and when
5. **UI Improvements**: Add preview of how settings appear on public site
