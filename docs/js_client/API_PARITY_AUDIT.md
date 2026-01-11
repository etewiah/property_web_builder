# PWB API Parity Audit for Headless Frontends

**Date**: 2026-01-11  
**Status**: Audit Complete

This document analyzes the current API coverage for headless JavaScript frontends (Astro.js, Next.js, etc.) to replicate the full functionality of the PWB Rails public-facing frontend.

---

## Current API Status: ~80% Complete

### ✅ Fully Covered Endpoints

| Feature | Endpoint | Status |
|---------|----------|--------|
| Properties (list/search) | `GET /api_public/v1/properties` | ✅ |
| Property details | `GET /api_public/v1/properties/:id` | ✅ Absolute URLs |
| Site configuration | `GET /api_public/v1/site_details` | ✅ Enhanced |
| Navigation links | `GET /api_public/v1/links` | ✅ Standardized |
| Theme/styling | `GET /api_public/v1/theme` | ✅ CSS variables |
| Pages with content | `GET /api_public/v1/pages/by_slug/:slug` | ✅ |
| Translations | `GET /api_public/v1/translations?locale=xx` | ✅ |
| Select values | `GET /api_public/v1/select_values` | ✅ |
| Property enquiry | `POST /api_public/v1/enquiries` | ✅ |
| Testimonials | `GET /api_public/v1/testimonials` | ✅ |

### Recent Improvements (2026-01-11)

1. **Property Images**: Now return absolute URLs with responsive variants (small/medium/large)
2. **Site Details**: Added `contact_info`, `social_links`, `top_nav_links`, `footer_links`
3. **Links**: Standardized JSON format with `title`, `url`, `external` fields
4. **Theme Endpoint**: New `/api_public/v1/theme` with CSS variables, colors, fonts
5. **Enquiries**: New `/api_public/v1/enquiries` for property contact forms
6. **Testimonials**: New `/api_public/v1/testimonials` for dynamic testimonials

---

## Gaps Requiring Additional Work

### Priority 1: Search Configuration Endpoint (HIGH)

**Gap**: Search page requires filter options (property types, price ranges, features) that are computed server-side.

**Solution**: Create `GET /api_public/v1/search/config`

```ruby
# app/controllers/api_public/v1/search_config_controller.rb
module ApiPublic
  module V1
    class SearchConfigController < BaseController
      def index
        website = Pwb::Current.website
        
        render json: {
          property_types: property_types_with_counts(website),
          price_options: {
            sale: {
              from: website.sale_price_options_from,
              to: website.sale_price_options_till
            },
            rent: {
              from: website.rent_price_options_from,
              to: website.rent_price_options_till
            }
          },
          features: available_features(website),
          bedrooms: [1, 2, 3, 4, 5],
          bathrooms: [1, 2, 3, 4],
          sort_options: [
            { value: 'price_asc', label: 'Price: Low to High' },
            { value: 'price_desc', label: 'Price: High to Low' },
            { value: 'newest', label: 'Newest First' }
          ]
        }
      end
      
      private
      
      def property_types_with_counts(website)
        website.listed_properties
               .visible
               .group(:prop_type_key)
               .count
               .map { |key, count| { key: key, count: count } }
      end
      
      def available_features(website)
        Pwb::Feature.where(website: website).map do |f|
          { key: f.feature_key, label: I18n.t(f.feature_key) }
        end
      end
    end
  end
end
```

**Route**: Add to `config/routes.rb`:
```ruby
get "/search/config" => "search_config#index"
```

---

### Priority 2: Map Markers in Search Response (HIGH)

**Gap**: Property search needs map markers with lat/lng coordinates.

**Solution**: Add to `PropertiesController#search`:

```ruby
def search
  properties = # ... existing search logic
  
  map_markers = properties.map do |prop|
    next unless prop.latitude.present? && prop.longitude.present?
    {
      id: prop.id,
      lat: prop.latitude,
      lng: prop.longitude,
      title: prop.title,
      price: prop.formatted_price,
      image: prop.primary_image_url,
      url: "/properties/#{prop.slug}"
    }
  end.compact
  
  render json: {
    properties: properties.as_json,
    map_markers: map_markers,
    meta: {
      total: properties.total_count,
      page: properties.current_page,
      per_page: properties.limit_value,
      total_pages: properties.total_pages
    }
  }
end
```

---

### Priority 3: Featured Properties Query (MEDIUM)

**Gap**: Homepage shows highlighted/featured properties.

**Solution**: Add query parameter support:

```ruby
# In PropertiesController#search
if params[:highlighted] == 'true'
  properties = properties.where(highlighted: true)
end

if params[:featured] == 'true'
  properties = properties.order(highlighted: :desc).limit(params[:limit] || 9)
end
```

**Usage**:
```
GET /api_public/v1/properties?highlighted=true&limit=9&sale_or_rental=sale
```

---

### Priority 4: General Contact Form (MEDIUM)

**Gap**: Contact page needs non-property-specific contact form.

**Solution**: Extend EnquiriesController or create ContactController:

```ruby
# Option A: Extend EnquiriesController
# Make property_id optional and add subject field

# Option B: New endpoint
# POST /api_public/v1/contact
module ApiPublic
  module V1
    class ContactController < BaseController
      def create
        contact = Pwb::Current.website.contacts.find_or_initialize_by(
          primary_email: contact_params[:email]
        )
        contact.assign_attributes(
          first_name: contact_params[:name],
          primary_phone_number: contact_params[:phone]
        )
        
        message = Pwb::Message.new(
          website: Pwb::Current.website,
          title: contact_params[:subject] || "General Enquiry",
          content: contact_params[:message],
          origin_email: contact_params[:email],
          origin_ip: request.ip
        )
        
        if contact.save && message.save
          message.update(contact: contact)
          ContactMailer.general_enquiry(contact, message).deliver_later
          render json: { success: true }, status: :created
        else
          render json: { errors: contact.errors.full_messages + message.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def contact_params
        params.require(:contact).permit(:name, :email, :phone, :message, :subject)
      end
    end
  end
end
```

---

### Priority 5: Property Extras/Features in as_json (LOW)

**Gap**: Property detail page shows features/extras not included in API.

**Solution**: Update `ListedProperty#as_json`:

```ruby
def as_json(options = nil)
  super(options).tap do |hash|
    # ... existing fields ...
    hash['extras'] = extras_for_display
    hash['features'] = get_features
    hash['highlighted'] = highlighted
  end
end
```

---

## Client-Side Implementation Requirements

The following features cannot be provided via API and must be implemented client-side:

### 1. Search Component
- Filter state management (URL params)
- Debounced search requests
- Result caching

### 2. Map Component
- Use Leaflet library
- Cluster markers for density
- Property popups on click

### 3. Currency Switching
- Store preference in localStorage
- Apply conversion rates client-side
- Get exchange rates from site_details if needed

### 4. Dark Mode
- Check theme.dark_mode settings
- Respect system preference for "auto"
- Toggle via localStorage

### 5. Rails Parts
Pages with `is_rails_part: true` render ERB partials on the server. JS clients must implement equivalent components:

| Rails Part | Client Component |
|------------|------------------|
| `_form_and_map.html.erb` | Contact form + Leaflet map |
| `_search_cmpt.html.erb` | Search widget |

---

## Implementation Checklist

### Backend Changes Needed

- [ ] Create `SearchConfigController` with filter options
- [ ] Add map_markers to properties search response
- [ ] Add pagination meta to search response
- [ ] Add `?highlighted=true` query support
- [ ] Add `extras` and `features` to ListedProperty.as_json
- [ ] Create general contact endpoint (optional)

### Frontend Implementation

- [ ] Property listing page with filters
- [ ] Property detail page with image carousel
- [ ] Search component with URL state
- [ ] Map component with Leaflet
- [ ] Contact form component
- [ ] Dark mode support
- [ ] Currency switching
- [ ] Language switching

---

## API Endpoint Quick Reference

```bash
# Site Configuration
GET /api_public/v1/site_details
GET /api_public/v1/theme
GET /api_public/v1/links?position=top_nav
GET /api_public/v1/translations?locale=en

# Properties
GET /api_public/v1/properties
GET /api_public/v1/properties?sale_or_rental=sale&property_type=apartment
GET /api_public/v1/properties/:id

# Pages & Content
GET /api_public/v1/pages/by_slug/:slug

# Forms
POST /api_public/v1/enquiries
# { enquiry: { name, email, phone, message, property_id } }

# Dynamic Content
GET /api_public/v1/testimonials
GET /api_public/v1/select_values?field_names=property-types

# Future (to be implemented)
GET /api_public/v1/search/config
POST /api_public/v1/contact
```

---

## Related Documentation

- [API Status](./API_STATUS.md)
- [Astro Implementation Guide](./ASTRO_IMPLEMENTATION_GUIDE.md)
- [Next.js Implementation Guide](./NEXTJS_IMPLEMENTATION_GUIDE.md)
- [Backend API Implementation Summary](./backend-api-implementation-summary.md)
