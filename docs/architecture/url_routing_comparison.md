# URL Routing and Structure Comparison: External vs Internal Listings

This document provides a detailed analysis of how PropertyWebBuilder handles URL routing and path generation for two types of property listings: external listings (from third-party feeds) and internal listings (directly managed properties).

## Overview

PropertyWebBuilder supports two distinct property listing channels:

1. **Internal/Regular Listings** - Properties created and managed directly in the system
2. **External Listings** - Properties sourced from third-party feed providers

These two systems have different URL structures, routing patterns, and identifier schemes.

---

## Route Definitions

### Configuration Location
**File:** `/config/routes.rb` (lines 435-457)

### Internal/Regular Property Listings Routes

```ruby
# For internal properties - created/managed in the system
scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
  # Rent listings
  get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
  
  # Sale listings
  get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"
end
```

**URL Pattern Examples:**
- For Rent: `https://example.com/properties/for-rent/abc-123-uuid/cozy-apartment-in-downtown`
- For Sale: `https://example.com/properties/for-sale/xyz-456-uuid/luxury-villa-seaside`
- With Locale: `https://example.com/es/properties/for-rent/abc-123-uuid/cozy-apartment-in-downtown`

### External Listings Routes

```ruby
# External property listings (from third-party feeds)
scope module: :site do
  resources :external_listings, only: [:index, :show], param: :reference do
    collection do
      get :search
      get :locations
      get :property_types
      get :filters
    end
    member do
      get :similar
    end
  end
end
```

**URL Pattern Examples:**
- Index/Search: `https://example.com/external_listings`
- Search with Filters: `https://example.com/external_listings/search?listing_type=sale&location=Madrid`
- Property Detail: `https://example.com/external_listings/EXT-REF-12345`
- Similar Properties: `https://example.com/external_listings/EXT-REF-12345/similar`
- With Locale: `https://example.com/es/external_listings`
- With Locale Detail: `https://example.com/es/external_listings/EXT-REF-12345`

---

## Controllers and Actions

### Internal Listings Controller

**File:** `/app/controllers/pwb/props_controller.rb`

```ruby
class PropsController < ApplicationController
  def show_for_rent
    # Find by slug first, then fall back to ID
    @property_details = find_property_by_slug_or_id(params[:id])
    
    if @property_details && @property_details.visible && @property_details.for_rent
      # Render property detail page
    else
      render "not_found", status: :not_found
    end
  end
  
  def show_for_sale
    # Find by slug first, then fall back to ID
    @property_details = find_property_by_slug_or_id(params[:id])
    
    if @property_details && @property_details.visible && @property_details.for_sale
      # Render property detail page
    else
      render "not_found", status: :not_found
    end
  end
  
  private
  
  def find_property_by_slug_or_id(identifier)
    scope = Pwb::ListedProperty.where(website_id: @current_website.id)
    
    # Try slug first
    property = scope.find_by(slug: identifier)
    return property if property
    
    # Fall back to ID (UUID or integer)
    scope.find_by(id: identifier)
  end
end
```

**Key Actions:**
- `show_for_rent` - Display rental property (operation_type: "for_rent")
- `show_for_sale` - Display sale property (operation_type: "for_sale")

### External Listings Controller

**File:** `/app/controllers/pwb/site/external_listings_controller.rb`

```ruby
class Pwb::Site::ExternalListingsController < Pwb::ApplicationController
  before_action :ensure_feed_enabled
  before_action :set_listing, only: [:show, :similar]
  
  def index
    @search_params = search_params
    @result = external_feed.search(@search_params)
    # Render search results
  end
  
  def search
    # Alias for index with search semantics
    index
  end
  
  def show
    # Find by reference (third-party unique identifier)
    @listing = external_feed.find(
      params[:reference],
      locale: I18n.locale,
      listing_type: listing_type_param
    )
    
    if @listing && @listing.available?
      # Render property detail page
    else
      render "unavailable", status: :gone
    end
  end
  
  def similar
    # Get similar properties
    @similar = external_feed.similar(@listing, limit: 6, locale: I18n.locale)
  end
  
  def locations
    @locations = external_feed.locations(locale: I18n.locale)
    render json: @locations
  end
  
  def property_types
    @property_types = external_feed.property_types(locale: I18n.locale)
    render json: @property_types
  end
  
  def filters
    @filter_options = external_feed.filter_options(locale: I18n.locale)
    render json: @filter_options
  end
end
```

**Key Actions:**
- `index` / `search` - Display search results
- `show` - Display external property detail (by reference)
- `similar` - Get similar properties for current listing
- `locations`, `property_types`, `filters` - JSON API endpoints for search filters

---

## URL Generation and Path Helpers

### Internal Listings URL Generation

**File:** `/app/models/concerns/listed_property/url_helpers.rb`

```ruby
module ListedProperty
  module UrlHelpers
    # Returns a URL-friendly version of the title
    # "Cozy Apartment in Downtown" => "cozy-apartment-in-downtown"
    def url_friendly_title
      title && title.length > 2 ? title.parameterize : "show"
    end
    
    # Returns the slug for URL generation, falling back to ID
    # Preference: slug > UUID > integer ID
    def slug_or_id
      slug.presence || id
    end
    
    # Generates contextual show path based on listing type
    def contextual_show_path(rent_or_sale)
      rent_or_sale ||= for_rent ? "for_rent" : "for_sale"
      
      if rent_or_sale == "for_rent"
        prop_show_for_rent_path(
          locale: I18n.locale,
          id: slug_or_id,                    # Slug or UUID
          url_friendly_title: url_friendly_title
        )
      else
        prop_show_for_sale_path(
          locale: I18n.locale,
          id: slug_or_id,
          url_friendly_title: url_friendly_title
        )
      end
    end
  end
end
```

**Generated URL Examples:**
```ruby
property = Pwb::ListedProperty.find(uuid)

# With slug
property.slug = "luxury-villa-barca"
property.contextual_show_path("for_sale")
# => "/en/properties/for-sale/luxury-villa-barca/luxury-villa-barcelona"

# Without slug (fallback to ID)
property.slug = nil
property.contextual_show_path("for_rent")
# => "/en/properties/for-rent/abc-def-123-uuid/luxury-villa-barcelona"
```

### External Listings URL Generation

**Stored in View Helper Usage**

External listings use Rails route helpers directly:

```ruby
# Route helper usage in views
external_listing_path(reference: property.reference, listing_type: property.listing_type)
# => "/external_listings/EXT-REF-12345?listing_type=sale"

# Or without listing_type (defaults to listing_type)
external_listing_path(reference: property.reference)
# => "/external_listings/EXT-REF-12345"

# With locale
external_listing_path(reference: property.reference, listing_type: property.listing_type, locale: I18n.locale)
# => "/es/external_listings/EXT-REF-12345?listing_type=rental"
```

---

## URL Parameter Comparison

| Aspect | Internal Listings | External Listings |
|--------|------------------|-------------------|
| **Primary Identifier** | UUID or slug | Third-party reference code |
| **Identifier Type** | System-generated UUID or custom slug | Provider-specific string |
| **URL Pattern** | `/properties/{type}/{id}/{friendly-title}` | `/external_listings/{reference}` |
| **Listing Type in URL** | Implicit in path (`for-rent` or `for-sale`) | Query parameter or implicit from data |
| **URL-Friendly Title** | Included in URL (parameterized) | Not included in URL |
| **Locale Handling** | Prefix: `/locale/properties/...` | Prefix: `/locale/external_listings/...` |
| **SEO-Friendliness** | High (slug + title in URL) | Medium (reference only) |

---

## Slug and ID Handling

### Internal Listings - Slug Strategy

The ListedProperty model uses a cascading lookup strategy:

```
1. Try to find by slug (first choice)
   └─ Example: "luxury-villa-barca"
   
2. Fall back to UUID ID
   └─ Example: "550e8400-e29b-41d4-a716-446655440000"
```

**URL Examples Showing Slug Hierarchy:**

```
With slug:     /en/properties/for-sale/luxury-villa-barca/luxury-villa-barcelona
Without slug:  /en/properties/for-sale/550e8400-e29b-41d4-a716-446655440000/luxury-villa-barcelona
```

The `url_friendly_title` parameter in both cases serves for SEO purposes but is NOT used for lookup.

### External Listings - Reference Strategy

External listings use provider-assigned reference codes as primary identifiers:

```
Example references:
- "EXT-REF-12345"
- "PROPERTY-98765"
- "APP-ID-XXXXXX"
```

These are passed directly as route parameters and used for lookups in the external feed provider.

---

## Locale Handling

### Internal Listings Locale

```ruby
# Route definition
scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
  get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent"
end

# URL generation in controller/helper
prop_show_for_rent_path(locale: I18n.locale, id: slug_or_id, url_friendly_title: title)

# Generated URLs
/en/properties/for-rent/abc-123/my-property
/es/properties/for-rent/abc-123/mi-propiedad
/fr/properties/for-rent/abc-123/ma-propriete
```

### External Listings Locale

```ruby
# Route definition (also within locale scope)
scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
  resources :external_listings, only: [:index, :show], param: :reference
end

# URL generation
external_listing_path(reference: ref, listing_type: type, locale: I18n.locale)

# Generated URLs
/en/external_listings/EXT-REF-12345
/es/external_listings/EXT-REF-12345
/fr/external_listings/EXT-REF-12345
```

Both use the locale scope from routes.rb, making locale-aware URLs available through I18n.locale.

---

## View Template Implementation

### Internal Listings Link Generation

**File:** `/app/themes/barcelona/views/pwb/welcome/_single_property_row.html.erb`

```erb
<%# Internal property links use contextual_show_path %>
<% operation_type = property.for_rent ? "for_rent" : "for_sale" %>
<a href="<%= property.contextual_show_path(operation_type) %>">
  View Property
</a>
```

### External Listings Link Generation

**File:** `/app/views/pwb/site/external_listings/_property_card.html.erb`

```erb
<%# External property links use external_listing_path helper %>
<a href="<%= external_listing_path(reference: property.reference, listing_type: property.listing_type) %>">
  View Property
</a>
```

### Mixed Context - Saved Properties

**File:** `/app/views/pwb/site/my/saved_properties/index.html.erb`

This view handles both internal and external listings:

```erb
<% property_url = if saved.provider == "internal"
  # For internal properties, determine path by listing type
  url_title = saved.title.to_s.parameterize.presence || "property"
  if saved.listing_type.to_s == "rental"
    prop_show_for_rent_path(id: saved.external_reference, url_friendly_title: url_title)
  else
    prop_show_for_sale_path(id: saved.external_reference, url_friendly_title: url_title)
  end
else
  # For external properties, use external_listing_path
  external_listing_path(reference: saved.external_reference)
end %>

<%= link_to property_url %>
```

---

## HTTP Caching Headers

Both listing types use HTTP caching, but with different durations:

### Internal Listings

**File:** `/app/controllers/pwb/props_controller.rb`

```ruby
def show_for_rent
  # ... find property ...
  
  # HTTP caching - return 304 if content hasn't changed
  return if fresh_response?(@property_details, max_age: 10.minutes, public: true)
  
  # Render property detail page
end
```

### External Listings

**File:** `/app/controllers/pwb/site/external_listings_controller.rb`

```ruby
def index
  # ... search properties ...
  
  # Longer cache for unfiltered results
  cache_duration = has_active_filters? ? 2.minutes : 10.minutes
  set_cache_control_headers(
    max_age: cache_duration,
    public: true,
    stale_while_revalidate: 1.hour
  )
end

def show
  # ... find property ...
  
  # HTTP caching for property details
  set_cache_control_headers(
    max_age: 15.minutes,
    public: true,
    stale_while_revalidate: 1.hour
  )
end
```

---

## SEO Implementation

### Internal Listings SEO

**File:** `/app/controllers/pwb/props_controller.rb`

```ruby
def set_property_seo(property, operation_type)
  # Build canonical URL using slug if available
  canonical_path = if property.slug.present?
                     property.contextual_show_path(operation_type)
                   else
                     request.path
                   end
  
  # SEO fields from listing model
  listing = if operation_type == 'for_sale'
              property.sale_listing
            else
              property.rental_listing
            end
  
  set_seo(
    title: listing&.seo_title.presence || property.title,
    description: listing&.meta_description.presence || truncate_description(property.description),
    canonical_url: canonical_url,
    image: property.primary_image_url,
    og_type: 'product',
    noindex: listing&.noindex || listing&.archived || listing&.reserved
  )
end
```

**SEO Features:**
- Customizable SEO title and meta description per listing
- Automatic canonical URL generation
- Support for `noindex` flag for archived/reserved properties
- Open Graph metadata

### External Listings SEO

**File:** `/app/controllers/pwb/site/external_listings_controller.rb`

```ruby
def set_external_listing_detail_seo
  # Page title from listing
  @page_title = "#{@listing.title} | #{company_name}"
  
  # Meta description from features
  location_parts = [@listing.location, @listing.province].compact.join(", ")
  features = []
  features << "#{@listing.bedrooms} bedrooms" if @listing.bedrooms.present?
  features << "#{@listing.bathrooms} bathrooms" if @listing.bathrooms.present?
  
  @meta_description = "#{@listing.title} - #{@listing.formatted_price}. #{features.join(', ')} in #{location_parts}."
  
  # Canonical URL
  @canonical_url = external_listing_url(@listing.reference, listing_type: @listing.listing_type)
  
  # Open Graph data
  @og_title = @listing.title
  @og_description = @meta_description
  @og_image = @listing.main_image
  @og_type = "website"
end
```

**SEO Features:**
- Dynamic page title generation
- Programmatic meta description building
- Automatic canonical URL generation
- Open Graph metadata for social sharing

---

## Key Differences Summary

### Identification Method

| Feature | Internal | External |
|---------|----------|----------|
| Primary Key | UUID (system-generated) | Reference (provider-assigned) |
| Alternative Identifier | Slug (optional, custom) | None |
| Lookup Strategy | Slug → UUID | Reference only |
| Backward Compatibility | Slug or ID both work | Reference only |

### URL Structure

| Feature | Internal | External |
|---------|----------|----------|
| Path Template | `/properties/{type}/{id}/{title}` | `/external_listings/{reference}` |
| Listing Type Indicator | In path name | Query param or implicit |
| SEO Component | Title included in URL | Not included |
| Query Parameters | Minimal | Search filters |

### Data Source

| Feature | Internal | External |
|---------|----------|----------|
| Source | Direct system database | Third-party feed provider |
| Lookup Method | Database query | External API/feed |
| Caching | Materialized views | External provider cache |
| Availability | Always available | Depends on feed |

### Operations Supported

| Operation | Internal | External |
|-----------|----------|----------|
| Create/Edit | ✓ Full admin interface | ✗ Read-only |
| Price Updates | ✓ Manual or bulk import | ✓ Feed-provided |
| Availability Status | ✓ Manual control | ✓ Feed-controlled |
| Listing Type | ✓ Configurable per property | ✓ Feed-provided |
| Custom Fields | ✓ Fully customizable | ✗ Feed schema only |

---

## Implementation Notes

### When to Use Internal Listings

- Properties you own or manage directly
- Need full control over data and availability
- Want custom fields and detailed configuration
- SEO is critical (including URL slug)
- Long-term property listing

### When to Use External Listings

- Aggregating properties from multiple sources
- Partner properties from external systems
- High-volume listings that need frequent updates
- No need for custom fields beyond feed schema
- Temporary or rotating inventory

### Mixed Implementation (Current Best Practice)

The system supports both simultaneously:
- **Internal catalog** of core properties
- **External feeds** for partner properties or market data
- **Saved properties** can mix both types
- Users can search both simultaneously or separately

---

## Related Files Reference

### Route Definitions
- `/config/routes.rb` - Lines 435-457, 411-438

### Controllers
- `/app/controllers/pwb/props_controller.rb` - Internal listings
- `/app/controllers/pwb/site/external_listings_controller.rb` - External listings

### Models
- `/app/models/pwb/listed_property.rb` - Read-only internal view
- `/app/models/concerns/listed_property/url_helpers.rb` - URL generation

### Views (Templates)
- `/app/views/pwb/props/show.html.erb` - Internal property detail
- `/app/views/pwb/site/external_listings/show.html.erb` - External property detail
- `/app/views/pwb/site/my/saved_properties/index.html.erb` - Mixed provider handling

### Helpers
- `/app/helpers/pwb/search_url_helper.rb` - URL parameter building
- `/app/helpers/pwb/application_helper.rb` - General URL helpers

---

## Testing Considerations

When testing URL generation and routing:

1. **Test slug fallback:** Verify both slug and ID lookups work for internal listings
2. **Test reference lookup:** Verify reference-based lookup for external listings
3. **Test locale prefixes:** Ensure locale scope works for both listing types
4. **Test cross-provider views:** Test saved properties with mixed provider types
5. **Test canonical URLs:** Verify proper canonical URL generation for SEO
6. **Test 404 handling:** Test unavailable properties return appropriate status codes

---

*Last Updated: 2025-01-02*
*Document Version: 1.0*
