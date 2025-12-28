# PropertyWebBuilder: Embeddable Widget Analysis

## Executive Summary

PropertyWebBuilder has a well-structured multi-tenant architecture with public APIs ready to support embeddable property widgets. The system uses Rack::CORS for cross-origin requests, Stimulus.js for frontend interactions, and provides JSON endpoints for property data serialization.

## Current API Structure

### Public API Routes
Located in `/config/routes.rb` - `api_public` namespace:

```
namespace :api_public do
  namespace :v1 do
    get "/properties/:id" => "properties#show"
    get "/properties" => "properties#search"
    get "/pages/:id" => "pages#show"
    get "/pages/by_slug/:slug" => "pages#show_by_slug"
    get "/translations" => "translations#index"
    get "/links" => "links#index"
    get "/site_details" => "site_details#index"
    get "/select_values" => "select_values#index"
    post "/auth/firebase" => "auth#firebase"
  end
end
```

### Properties API Controllers

**1. ApiPublic::V1::PropertiesController** (`app/controllers/api_public/v1/properties_controller.rb`)
- **Location**: `/api_public/v1/properties`
- **Methods**:
  - `GET /api_public/v1/properties/:id` - Fetch single property
  - `GET /api_public/v1/properties?params` - Search properties
- **Uses**: Pwb::ListedProperty (materialized view)
- **Tenant Scoping**: Via SubdomainTenant concern in BaseController
- **Authentication**: None required (public endpoints)
- **Output Format**: Standard JSON via `as_json`

**2. Pwb::Api::V1::PropertiesController** (`app/controllers/pwb/api/v1/properties_controller.rb`)
- **Location**: `/api/v1/properties`
- **Methods**:
  - `GET /api/v1/properties` - Index all properties
  - `GET /api/v1/properties/:id` - Show single property
  - `POST /api/v1/properties/bulk_create` - Create multiple properties
  - `POST /api/v1/properties/:id/photo` - Add photos
  - Write endpoints for property management
- **Uses**: Custom serialization via LocalizedSerializer concern
- **Serialization**: Custom `serialize_property_data()` with translated attributes
- **Authentication**: Requires authentication (not suitable for widgets)
- **Limitation**: DEPRECATED - should use Pwb::RealtyAsset + Pwb::SaleListing/RentalListing for writes

## Property Data Serialization

### Model Architecture
Three interconnected models for property data:

1. **Pwb::ListedProperty** (read-only materialized view)
   - Table: `pwb_properties`
   - Optimized for read operations and search
   - Denormalizes: RealtyAsset + SaleListing + RentalListing
   - Used by public API
   - Key method: `as_json(options = nil)`

2. **Pwb::Prop** (legacy model, deprecated)
   - Still used for backwards compatibility
   - Table: `pwb_props`
   - Translates: title, description (via Mobility gem)
   - Area unit enum: sqmt (0), sqft (1)
   - Custom serialization via `as_json()`

3. **Pwb::RealtyAsset + Pwb::SaleListing + Pwb::RentalListing** (new model)
   - Normalized property structure
   - Recommended for new writes
   - ListedProperty materializes view from these tables

### JSON Serialization Methods

**ListedProperty#as_json()**
```ruby
def as_json(options = nil)
  super(options).tap do |hash|
    hash['prop_photos'] = prop_photos.map do |photo|
      if photo.image.attached?
        { 'image' => Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) }
      else
        { 'image' => nil }
      end
    end
    hash['title'] = title
    hash['description'] = description
  end
end
```

**Serialized Fields** (from ListedProperty schema):
- Core: `id`, `title`, `description`, `reference`
- Location: `street_address`, `street_name`, `street_number`, `postal_code`, `city`, `region`, `country`, `latitude`, `longitude`
- Pricing:
  - Sale: `price_sale_current_cents`, `price_sale_current_currency`
  - Rental: `price_rental_monthly_current_cents`, `price_rental_monthly_current_currency`, `price_rental_monthly_high_season_cents`, `price_rental_monthly_low_season_cents`
- Physical: `count_bedrooms`, `count_bathrooms`, `count_garages`, `count_toilets`, `constructed_area`, `plot_area`, `year_construction`
- Status: `for_sale`, `for_rent`, `for_rent_short_term`, `for_rent_long_term`, `visible`, `highlighted`, `reserved`, `furnished`
- Features: `currency`, `area_unit`, `energy_rating`, `energy_performance`
- Map: `show_map`, `hide_map`, `obscure_map`
- Photos: `prop_photos` array with image paths
- Metadata: `prop_type_key`, `prop_state_key`, `prop_origin_key`, `created_at`, `updated_at`, `website_id`

### LocalizedSerializer Concern
Located: `app/controllers/concerns/localized_serializer.rb`

Dynamically serializes translated attributes for all BASE_LOCALES:
```ruby
serialize_translated_attributes(property, :title, :description)
# Returns:
# {
#   "title-en" => "Beach House",
#   "title-es" => "Casa de Playa",
#   "description-en" => "Beautiful...",
#   "description-es" => "Hermosa...",
#   ...
# }
```

## CORS Configuration

Located: `config/initializers/cors.rb`

Current setup:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:4200'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

**Status**: Currently only allows localhost:4200
**For Production**: Needs configuration to allow external domains

## JavaScript/Frontend Architecture

### JS Asset Pipeline
- **Type**: Import maps (Rails 7.1+)
- **Config**: `config/importmap.rb`
- **Included Packages**:
  - `@hotwired/stimulus` (preloaded)
  - `@hotwired/stimulus-loading` (preloaded)
  - `@rails/ujs` (via JSPM CDN)
  
### Stimulus.js Controllers
Located: `app/javascript/controllers/`

Registered controllers:
- `dropdown` - DropdownController
- `filter` - FilterController
- `gallery` - GalleryController
- `tabs` - TabsController
- `toggle` - ToggleController
- `contact-form` - ContactFormController
- `map` - MapController
- `search-form` - SearchFormController
- `search` - SearchController
- `search-header` - SearchHeaderController
- `theme-palette` - ThemePaletteController
- `skeleton` - SkeletonController
- `location-picker` - LocationPickerController
- `currency-selector` - CurrencySelectorController

**Notable Controllers for Widget Development**:
- **GalleryController** - Property photo carousel (reusable component)
- **SearchController** - Advanced filtering and search
- **SearchFormController** - Form handling
- **MapController** - Map rendering

### HTTP Requests in JS
- Uses native `fetch()` API (found in contact_form_controller.js)
- Uses Turbo for frame loading
- No jQuery dependency (Rails UJS handles AJAX forms)
- Supports AbortController for cancellation

## Multi-Tenancy & Subdomain Routing

### Tenant Resolution
- Via `SubdomainTenant` concern in controllers
- Property queries automatically scoped to `Pwb::Current.website`
- Public API uses `current_website_from_subdomain` helper

**Example from API controller**:
```ruby
def current_website_from_subdomain
  return nil unless request.subdomain.present?
  Website.find_by_subdomain(request.subdomain)
end
```

### Widget Considerations
- Widgets requesting from different domains need CORS configuration
- Can filter by `website_id` or `reference` field
- Each website is a separate tenant with its own properties

## Content Security Policy

Located: `config/initializers/content_security_policy.rb`

**Current Status**: CSP is commented out (disabled)
- When enabled, may restrict inline scripts and styles
- Important for embedded widgets using iframes

## Search Capabilities

### API Parameters
From `ApiPublic::V1::PropertiesController#search`:

Query Parameters:
- `sale_or_rental`: "sale" or "rent" (default: "sale")
- `currency`: currency code (default: "usd")
- `for_sale_price_from` / `for_sale_price_till`: price ranges
- `for_rent_price_from` / `for_rent_price_till`: rental price ranges
- `bedrooms_from`: minimum bedrooms
- `bathrooms_from`: minimum bathrooms
- `property_type`: filter by type

### Search Method
Uses `Pwb::ListedProperty#properties_search(**args)` from searchable concern.

## Existing Widget/Embed Functionality

**Finding**: No existing widget or embed endpoints found.
- No `widget_controller` or similar
- No iframe-specific routes
- No embed-as-iframe patterns
- No JavaScript widget loader

This is a greenfield opportunity for implementing embeddable widgets.

## Recommendations for Embeddable Property Widget

### 1. Add Widget Controller
Create `app/controllers/api_public/v1/widgets_controller.rb` to serve:
- Rendered HTML snippets (for iframe embedding)
- JavaScript widget loader script
- Styling configuration

### 2. Extend CORS Configuration
Modify `config/initializers/cors.rb`:
```ruby
# Allow multiple domains for embedded widgets
origins '*'  # Or specify whitelist of customer domains
```

### 3. Create Widget Assets
- **JavaScript**: Standalone widget that doesn't require Stimulus (can work without Rails)
- **CSS**: Scoped styling to prevent conflicts with host site
- **Templates**: Lightweight HTML for property cards, search forms, etc.

### 4. Use Existing API Endpoints
The `/api_public/v1/properties` endpoints are already suitable for:
- Fetching individual properties
- Searching with filters
- Getting translations via separate endpoint

### 5. Property Photo Handling
- Photos use Rails Active Storage
- URLs format: `/rails/active_storage/blobs/...`
- Widget should cache/proxy these URLs or request via API

### 6. Search Parameters
Public API search already supports:
- Price range filtering
- Bedroom/bathroom filtering
- Property type filtering
- Sale vs. rental toggling

### 7. Multi-language Support
- Use `/api_public/v1/translations` endpoint
- Serialize translated fields using LocalizedSerializer pattern
- Support `locale` parameter in requests

### 8. Performance Considerations
- Use ListedProperty (materialized view) for fast queries
- Consider pagination for large property lists
- Cache CORS headers appropriately
- Gzip compress API responses

### 9. Security Considerations
- Keep CSP disabled or configure appropriately for iframe embedding
- Validate origin headers
- Rate limit widget API endpoints
- Don't expose sensitive admin endpoints

### 10. Styling Strategy
- Provide multiple theme options (matches theme system)
- Use CSS custom properties for customization
- Keep CSS footprint minimal
- Isolate widget styles to prevent host site conflicts

## Key Technical Insights

1. **Materialized View Pattern**: ListedProperty is a read-only view, making it perfect for high-performance API queries

2. **Tenant Scoping**: Automatic via subdomain routing means each widget instance is naturally scoped to its website

3. **Translation Infrastructure**: LocalizedSerializer provides pattern for multilingual property data

4. **Stimulus.js Ready**: Existing Stimulus controllers (gallery, search, map) can be extracted/adapted for widgets

5. **Rails 7.1 Import Maps**: Modern frontend architecture without build step complexity

6. **Active Storage Integration**: Photos handled by Rails, URLs need to be included in API responses

## Files to Review for Widget Implementation

Core Architecture:
- `/app/controllers/api_public/v1/base_controller.rb` - Public API base
- `/app/controllers/api_public/v1/properties_controller.rb` - Properties API
- `/config/routes.rb` - API routes

Models & Serialization:
- `/app/models/pwb/listed_property.rb` - Read-only property model
- `/app/models/pwb/prop.rb` - Legacy property model
- `/app/controllers/concerns/localized_serializer.rb` - Translation serialization

Frontend:
- `/app/javascript/controllers/gallery_controller.js` - Reusable gallery component
- `/app/javascript/controllers/search_controller.js` - Search patterns
- `/config/importmap.rb` - JS dependency management

Configuration:
- `/config/initializers/cors.rb` - CORS setup
- `/config/initializers/content_security_policy.rb` - CSP (currently disabled)
