# PropertyWebBuilder Listing Types Overview

This document provides a structured overview of the two property listing systems in PropertyWebBuilder.

## System Architecture

PropertyWebBuilder supports a dual-listing architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PropertyWebBuilder                            │
├──────────────────────────────┬──────────────────────────────────┤
│   INTERNAL LISTINGS          │   EXTERNAL LISTINGS              │
│   (Local Management)         │   (Feed-Based)                   │
├──────────────────────────────┼──────────────────────────────────┤
│ • Admin-created properties   │ • Third-party feed integration   │
│ • Full CRUD operations       │ • Read-only, feed-managed        │
│ • Custom fields              │ • Standard feed schema           │
│ • Direct database control    │ • External API/feed source       │
│ • SEO slug support           │ • Reference code based           │
└──────────────────────────────┴──────────────────────────────────┘
```

---

## 1. INTERNAL LISTINGS

### Overview
Internal listings are properties created, managed, and controlled directly within PropertyWebBuilder's admin interface.

### Key Characteristics

| Feature | Details |
|---------|---------|
| **Data Storage** | PostgreSQL `pwb_props` and related tables |
| **Admin Access** | Full create, read, update, delete capabilities |
| **Identifiers** | UUID (primary), Slug (optional, custom) |
| **Customization** | Fully customizable fields and configuration |
| **Availability** | Manual control via UI |
| **Pricing** | Manual entry and bulk import support |

### Database Tables

```
pwb_props (legacy)
├─ pwb_realty_assets (normalized)
├─ pwb_sale_listings (sale-specific data)
└─ pwb_rental_listings (rental-specific data)

Materialized View:
└─ pwb_properties (ListedProperty read-only view)
```

### URL Structure

**Pattern:**
```
/{locale}/properties/{listing-type}/{identifier}/{friendly-title}

Examples:
/en/properties/for-rent/abc-uuid/cozy-apartment-downtown
/es/properties/for-rent/my-custom-slug/apartamento-acogedor
/fr/properties/for-sale/xyz-uuid/villa-luxe-cote-azur
```

**Components:**
- `{locale}` - Optional language prefix (en, es, fr, etc.)
- `{listing-type}` - `for-rent` or `for-sale`
- `{identifier}` - Slug (preferred) or UUID (fallback)
- `{friendly-title}` - URL-parameterized title (SEO only)

### Route Helpers

```ruby
# Primary routes
prop_show_for_rent_path(id: identifier, url_friendly_title: title, locale: :en)
prop_show_for_sale_path(id: identifier, url_friendly_title: title, locale: :en)

# Shorthand from model
property.contextual_show_path("for_rent")
property.contextual_show_path("for_sale")
```

### Controller Actions

**File:** `/app/controllers/pwb/props_controller.rb`

```ruby
def show_for_rent
  # Find by slug, fallback to ID
  @property_details = find_property_by_slug_or_id(params[:id])
  
  # Validate visibility and rental listing
  if @property_details&.visible && @property_details&.for_rent
    render property detail page
  else
    render "not_found", status: :not_found
  end
end

def show_for_sale
  # Find by slug, fallback to ID
  @property_details = find_property_by_slug_or_id(params[:id])
  
  # Validate visibility and sale listing
  if @property_details&.visible && @property_details&.for_sale
    render property detail page
  else
    render "not_found", status: :not_found
  end
end

def request_property_info_ajax
  # Contact/inquiry form submission
  # Creates Message and Contact records
end
```

### Lookup Strategy

```
Input: params[:id]
  │
  ├─ Try: Pwb::ListedProperty.find_by(slug: identifier)
  │   └─ Return if found
  │
  └─ Fallback: Pwb::ListedProperty.find_by(id: identifier)
      └─ Return (UUID or integer ID)
```

### SEO Features

- **Custom Slug:** Optional, user-defined URL component
- **SEO Title:** Per-listing override for page title
- **Meta Description:** Per-listing custom description
- **Canonical URL:** Automatic generation using slug or ID
- **noindex Support:** Can exclude archived/reserved properties from search
- **Open Graph:** Full social sharing metadata

### Admin Interface

**Location:** `/site_admin/props/`

**Capabilities:**
- Create new properties
- Edit general info, text, location, photos, pricing
- Manage sale and rental listings separately
- Activate/archive listings
- Bulk import from CSV or URL scraping
- SEO field editing

---

## 2. EXTERNAL LISTINGS

### Overview
External listings are properties sourced from third-party feed providers (like MLS, property portals, or partner APIs).

### Key Characteristics

| Feature | Details |
|---------|---------|
| **Data Storage** | External provider (cached in PropertyWebBuilder) |
| **Admin Access** | Read-only, configuration only |
| **Identifiers** | Provider reference code (e.g., "EXT-REF-12345") |
| **Customization** | Limited to provider schema |
| **Availability** | Feed-controlled, dynamic |
| **Pricing** | Provider-supplied, auto-updated |

### External Feed Integration

```
External Provider
    ↓
Feed Fetch (Scheduled)
    ↓
External Feed Service
    ↓
PropertyWebBuilder Cache
    ↓
Display/Search
```

### URL Structure

**Pattern:**
```
/{locale}/external_listings/{reference}

Examples:
/en/external_listings/EXT-REF-12345
/es/external_listings/EXT-REF-12345
/fr/external_listings/EXT-REF-12345

With filters:
/en/external_listings?location=Madrid&min_price=200000&max_price=500000
/en/external_listings/search?listing_type=rental&bedrooms=2
```

**Components:**
- `{locale}` - Optional language prefix
- `{reference}` - Provider-assigned unique identifier
- Query parameters - For search filters

### Route Helpers

```ruby
# Primary routes
external_listings_path                                    # Index/search
external_listing_path(reference: ref)                     # Detail page
external_listing_path(reference: ref, listing_type: :sale) # With type
external_listing_path(reference: ref, locale: I18n.locale) # With locale

# Collection routes (JSON)
external_listings_locations_path       # Available locations
external_listings_property_types_path  # Available property types
external_listings_filters_path         # Filter options
```

### Controller Actions

**File:** `/app/controllers/pwb/site/external_listings_controller.rb`

```ruby
def index
  # Search external listings
  @search_params = search_params  # Parse filters from request
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)
  
  # Set cache headers, render results
end

def search
  # Alias for index with search semantics
  index
end

def show
  # Display external property detail
  @listing = external_feed.find(params[:reference], locale: I18n.locale)
  
  if @listing&.available?
    render property detail page
  else
    render "unavailable", status: :gone
  end
end

def similar
  # Get similar properties
  @similar = external_feed.similar(@listing, limit: 6, locale: I18n.locale)
  render json: @similar.map(&:to_h)
end

def locations
  # JSON API: available locations
  render json: external_feed.locations(locale: I18n.locale)
end

def property_types
  # JSON API: available property types
  render json: external_feed.property_types(locale: I18n.locale)
end

def filters
  # JSON API: all filter options
  render json: external_feed.filter_options(locale: I18n.locale)
end
```

### Lookup Strategy

```
Input: params[:reference]
  │
  └─ Call: external_feed.find(reference, locale: I18n.locale)
      ├─ Query external provider
      ├─ Apply locale translations
      └─ Return listing object or nil
```

### Search Filters

Supported search parameters:

```ruby
@search_params = {
  listing_type: :sale,           # :sale or :rental
  location: "Madrid",             # Location string
  min_price: 200000,              # Minimum price
  max_price: 500000,              # Maximum price
  min_bedrooms: 2,                # Minimum bedrooms
  max_bedrooms: 4,                # Maximum bedrooms
  min_bathrooms: 1,               # Minimum bathrooms
  max_bathrooms: 2,               # Maximum bathrooms
  min_area: 100,                  # Minimum area (m²)
  max_area: 200,                  # Maximum area (m²)
  property_types: ['apartment', 'villa'], # Property types
  features: ['pool', 'garden'],   # Features/amenities
  sort: 'price-asc',              # Sort order
  page: 1,                        # Pagination
  per_page: 10,                   # Items per page
  locale: I18n.locale             # Language
}
```

### SEO Features

- **Dynamic Title:** Generated from listing data
- **Dynamic Description:** Built from features and location
- **Canonical URL:** Automatic generation with reference
- **Open Graph:** Automatic from listing images and data
- **No Custom Fields:** Limited to provider schema

### Admin Interface

**Location:** `/site_admin/external_feed/` (configuration only)

**Capabilities:**
- Enable/disable external feed integration
- Configure feed provider credentials
- Test feed connection
- Clear cache
- View feed status and statistics

---

## Comparison Matrix

### Data Management

| Aspect | Internal | External |
|--------|----------|----------|
| **Create** | Admin UI | Feed provider |
| **Read** | Admin UI + Public | Admin UI + Public |
| **Update** | Admin UI + Bulk import | Feed provider only |
| **Delete** | Admin UI (archive) | Feed provider decides |

### URL Generation

| Aspect | Internal | External |
|--------|----------|----------|
| **URL Pattern** | `/properties/{type}/{id}/{title}` | `/external_listings/{ref}` |
| **ID Type** | UUID or Slug | Reference code |
| **Title in URL** | Yes (SEO) | No |
| **Query Params** | Rare | Common (filters) |

### Identifier Schemes

| Aspect | Internal | External |
|--------|----------|----------|
| **Primary ID** | UUID | Reference code |
| **Secondary ID** | Slug (optional) | None |
| **Lookup Path** | Slug → UUID | Reference only |
| **Uniqueness** | Unique in system | Unique in provider |

### Customization

| Aspect | Internal | External |
|--------|----------|----------|
| **Fields** | Fully customizable | Provider schema only |
| **SEO** | Full control | Auto-generated |
| **Pricing** | Manual or bulk | Auto-updated |
| **Availability** | Manual control | Feed-controlled |

### Performance

| Aspect | Internal | External |
|--------|----------|----------|
| **Data Source** | Local database | External API/feed |
| **Query Speed** | Milliseconds | Feed latency + network |
| **Caching** | Built-in (views) | External + local cache |
| **Scalability** | Limited by DB | Limited by feed |

---

## Hybrid Architecture

The system supports simultaneous use of both listing types:

### Use Cases

1. **Core Inventory:** Internal listings for agency properties
2. **Partner Network:** External listings from partner agencies
3. **Market Data:** External MLS listings for market comparison
4. **Saved Properties:** Users can save both types to favorites

### Implementation Example

```ruby
# Saved Properties - Mixed Provider Support
class SavedProperty
  enum provider: { internal: 0, external: 1 }
  
  # Link to correct listing based on provider
  def listing_url
    if internal?
      # Internal property URL
      prop_show_for_rent_path(id: external_reference, url_friendly_title: title)
    else
      # External property URL
      external_listing_path(reference: external_reference)
    end
  end
end
```

---

## Migration Path

Existing implementations can:

1. **Start with internal only** - Full control, manual management
2. **Add external listings** - Gradual feed integration
3. **Transition to hybrid** - Best of both approaches
4. **Migrate between types** - Convert external to internal if needed

---

## Decision Tree: Which Type to Use?

```
Do you manage the properties directly?
├─ YES → Use INTERNAL LISTINGS
│        ├─ Create in admin UI
│        ├─ Full customization
│        └─ Maximum SEO control
│
└─ NO → Is data from external provider?
        ├─ YES → Use EXTERNAL LISTINGS
        │        ├─ Configure feed
        │        ├─ Auto-updated
        │        └─ Read-only
        │
        └─ MAYBE → Use BOTH (Hybrid)
                   ├─ Own properties as internal
                   ├─ Partner properties as external
                   └─ Users can save both
```

---

## Technical Stack

### Internal Listings

**Stack:**
- Rails Models: `Pwb::Prop`, `Pwb::RealtyAsset`, `Pwb::SaleListing`, `Pwb::RentalListing`
- View: `Pwb::ListedProperty` (materialized view for reads)
- Controller: `Pwb::PropsController`
- Database: PostgreSQL with normalized schema

**Key Gems:**
- Mobility (translations)
- Scenic (materialized views)
- Pagy (pagination)

### External Listings

**Stack:**
- Model: `Pwb::ExternalFeed` (provider abstraction)
- Controller: `Pwb::Site::ExternalListingsController`
- Data Source: External API/feed (provider-dependent)
- Caching: Rails cache + provider cache

**Key Gems:**
- Any HTTP client (REST API calls)
- XML/JSON parsers (for feed processing)

---

## Configuration

### Internal Listings - Enabled by Default

No additional configuration required. Works out of the box.

### External Listings - Requires Setup

```ruby
# Configuration
external_feed = current_website.external_feed
external_feed.configured?  # Check if set up
external_feed.enabled?     # Check if active

# Provider-specific settings
external_feed.provider_type    # e.g., "mls", "portal", "custom"
external_feed.api_key          # Credentials
external_feed.api_endpoint     # Endpoint URL
external_feed.refresh_schedule # Update frequency
```

---

## Related Documentation

- **Detailed Routing Guide:** `url_routing_comparison.md`
- **Quick Reference:** `url_routing_quick_reference.md`
- **External Feed Integration:** Search docs for "external_feed"
- **SEO Documentation:** See theme documentation for meta tags

---

## Summary

| Aspect | Best For |
|--------|----------|
| **Internal** | Owned properties, full control, SEO optimization |
| **External** | Aggregated content, partner listings, market data |
| **Both** | Comprehensive marketplace with mixed inventory |

Choose internal listings for primary business inventory, and external listings for supplementary or partner content.

---

*Version 1.0*
*Last Updated: 2025-01-02*
