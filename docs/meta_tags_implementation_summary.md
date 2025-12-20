# Meta Tags Implementation Summary for PropertyWebBuilder

## Current Meta Tag Infrastructure

PropertyWebBuilder has a well-established and comprehensive meta tag system already in place. The implementation is modern, supporting Open Graph, Twitter Cards, structured data (JSON-LD), and canonical URLs.

### Key Files

**Core Infrastructure:**
- `/app/helpers/seo_helper.rb` - Central helper for all SEO functionality
- `/app/views/pwb/props/_meta_tags.html.erb` - Property-specific meta tags and structured data
- `/app/views/layouts/pwb/application.html.erb` - Theme layout that renders meta tags in `<head>`
- `/app/controllers/pwb/props_controller.rb` - Controller that sets up SEO data

**Database Migrations:**
- `db/migrate/20251208160548_add_seo_fields_to_props.rb` - Adds `seo_title` and `meta_description` to properties
- `db/migrate/20251208160550_add_seo_fields_to_pages.rb` - Similar fields for pages
- `db/migrate/20251208160552_add_seo_fields_to_websites.rb` - Website-level SEO configuration

## Property Detail Pages: Rendering Flow

### Routes
```ruby
# From config/routes.rb
get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent", as: "prop_show_for_rent"
get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale", as: "prop_show_for_sale"
```

### Controller Logic
**File:** `/app/controllers/pwb/props_controller.rb`

1. **show_for_rent & show_for_sale methods:**
   - Find property by slug or ID from `ListedProperty` (materialized view)
   - Verify property is visible and matches operation type
   - Call `set_property_seo()` to configure SEO metadata
   - Render `/pwb/props/show` template

2. **Key Properties Accessed:**
   - `@property_details` - ListedProperty object with all property data
   - `@page_title` - Simple title for page display
   - `@page_description` - Description text
   - `@seo_property` - Passed to JSON-LD generation in views
   - `@map_markers` - Map data if property has location

3. **SEO Setup:**
   ```ruby
   set_property_seo(@property_details, 'for_sale')  # or 'for_rent'
   ```

### Views & Templates
**Theme-based layouts:**
- `/app/themes/default/views/pwb/props/show.html.erb` - Default theme
- `/app/themes/brisbane/views/pwb/props/show.html.erb` - Brisbane theme
- `/app/themes/bologna/views/pwb/props/show.html.erb` - Bologna theme

**Theme application layout:**
- `/app/themes/default/views/layouts/pwb/application.html.erb`
  - Renders `<%= seo_meta_tags %>` in `<head>`
  - Yields `:page_head` content block for additional meta tags
  - Includes canonical URLs, Open Graph, Twitter Cards

## Existing SEO Infrastructure in Detail

### SeoHelper Methods

#### Meta Tag Generation
```ruby
seo_meta_tags          # Main method rendering all meta tags
seo_title              # Page title with site name fallback
seo_description        # Meta description with fallbacks
seo_canonical_url      # Canonical URL for search engines
seo_image              # OG image URL (handles ActiveStorage)
favicon_tags           # Favicon links for browser/mobile
```

#### Structured Data (JSON-LD)
```ruby
property_json_ld(prop)           # RealEstateListing structured data
organization_json_ld             # RealEstateAgent/organization data
breadcrumb_json_ld(breadcrumbs)  # Breadcrumb navigation
```

### What's Currently Generated

#### Meta Tags
- `<title>` - Page title with site name
- `<meta name="description">` - Meta description
- `<link rel="canonical">` - Canonical URL (handles slug vs ID)
- `<meta property="og:*">` - Open Graph (type, title, description, url, site_name, image, locale)
- `<meta name="twitter:*">` - Twitter Card (card, title, description, image)
- `<meta name="robots">` - Noindex/nofollow directives
- `<link rel="alternate" hreflang="">` - Multi-language alternatives
- Favicon tags (ico, svg, apple-touch-icon)

#### Structured Data (JSON-LD)
**Property Listing:**
- Type: `RealEstateListing`
- Fields: name, description, URL, price with currency
- Location: full postal address (street, city, region, postal code, country)
- Property features: bedrooms, bathrooms, floor size in m²
- Images: up to 5 property photos
- Date posted: ISO 8601 format

**Organization:**
- Type: `RealEstateAgent`
- Fields: name, URL, logo, description, phone, email

### Data Flow

```
Controller (props_controller.rb)
    ↓
set_property_seo(@property_details, 'for_sale')
    ↓ (calls SeoHelper methods)
set_seo(title:, description:, canonical_url:, image:, og_type:)
    ↓ (stores in @seo_data)
View Template (show.html.erb)
    ↓
render 'pwb/props/meta_tags'
    ↓
<%= seo_meta_tags %>
    ↓
SeoHelper renders <head> tags
```

## Property Data Models & Attributes

### ListedProperty (Materialized View - for reads)
Primary model used in property detail pages. Denormalizes data from:
- `pwb_realty_assets` - Physical property data
- `pwb_sale_listings` - Sale transaction data
- `pwb_rental_listings` - Rental transaction data

**Key attributes:**
- `title, description` - From sale/rental listing (Mobility translations)
- `price_sale_current_cents, price_sale_current_currency`
- `price_rental_monthly_current_cents, price_rental_monthly_current_currency`
- `count_bedrooms, count_bathrooms`
- `constructed_area, plot_area` (floor size)
- `latitude, longitude` (for maps)
- `street_address, city, region, postal_code, country`
- `prop_photos` - Associated photos with `image` attachments
- `slug` - URL-friendly identifier
- `for_sale, for_rent, for_rent_short_term` - Availability flags
- `visible` - Published flag
- `website_id` - Tenant scoping

### Prop (Legacy Model)
Still available for backward compatibility. Has same structure but stored in `pwb_props` table directly.

Both models provide:
- `seo_title, meta_description` - Custom SEO overrides (migration added Dec 2024)
- `primary_image_url` - First photo URL
- `contextual_show_path(rent_or_sale)` - Dynamic URL generation
- `contextual_price_with_currency()` - Formatted price with currency

## Current Meta Tag Output Example

A property detail page outputs approximately 30-40 meta tags:

```html
<head>
  <title>Beautiful 3BR Apartment in Barcelona | MyAgency</title>
  
  <!-- Basic Meta Tags -->
  <meta name="description" content="Spacious 3-bedroom apartment with sea views in Barcelona center...">
  <link rel="canonical" href="https://myagency.com/properties/for-sale/apt-123/beautiful-3br-apartment">
  
  <!-- Open Graph -->
  <meta property="og:type" content="product">
  <meta property="og:title" content="Beautiful 3BR Apartment in Barcelona">
  <meta property="og:description" content="Spacious 3-bedroom apartment...">
  <meta property="og:url" content="https://myagency.com/properties/for-sale/apt-123/...">
  <meta property="og:site_name" content="MyAgency">
  <meta property="og:image" content="https://myagency.com/path/to/image.jpg">
  <meta property="og:locale" content="en_US">
  
  <!-- Twitter Cards -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Beautiful 3BR Apartment in Barcelona">
  <meta name="twitter:description" content="...">
  <meta name="twitter:image" content="https://myagency.com/path/to/image.jpg">
  
  <!-- Structured Data (JSON-LD) -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "RealEstateListing",
    "name": "Beautiful 3BR Apartment in Barcelona",
    "description": "...",
    "url": "https://myagency.com/properties/for-sale/apt-123/...",
    "price": "450000",
    "priceCurrency": "EUR",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "123 Main St",
      "addressLocality": "Barcelona",
      "addressRegion": "Catalonia",
      "postalCode": "08002",
      "addressCountry": "ES"
    },
    "numberOfRooms": 3,
    "numberOfBathroomsTotal": 2,
    "floorSize": {
      "@type": "QuantitativeValue",
      "value": "120",
      "unitCode": "MTK"
    },
    "image": ["url1", "url2", ...],
    "datePosted": "2024-12-01T10:00:00Z"
  }
  </script>
  
  <!-- Organization Schema -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "RealEstateAgent",
    "name": "MyAgency",
    "url": "https://myagency.com/",
    "logo": "https://myagency.com/logo.png",
    "telephone": "+34-91-123-4567"
  }
  </script>
</head>
```

## Recommended Approach for Enhancements

### Current Strengths
1. **Centralized:** All SEO logic in `SeoHelper` - single point of maintenance
2. **Flexible:** Controller calls `set_seo()` to pass custom data
3. **View support:** Property-specific partial (_meta_tags.html.erb) for additional tags
4. **Structured data:** Comprehensive JSON-LD with fallbacks
5. **Tenant-aware:** Works with multi-tenant architecture
6. **Multi-language:** Supports hreflang tags and locale switching

### To Enhance This System

#### 1. Add SEO Field Management UI
Create admin UI for managing `seo_title` and `meta_description` per property:
- Path: `/site_admin/props/:id/edit/seo`
- Fields for custom SEO overrides
- Character counters (title: 50-60 chars, description: 150-160 chars)
- Preview of how it will appear in search results

#### 2. Improve Image Selection for Social Sharing
Current: Uses first photo via `ordered_photo(1)`

Enhance to:
- Allow selecting primary image for social sharing
- Validate image dimensions (1200x630 recommended for OG)
- Auto-resize using existing `opt_image_url` helper
- Support multiple locale-specific primary images

#### 3. Add Dynamic Breadcrumbs
In property show templates, add breadcrumb JSON-LD:
```ruby
breadcrumbs = [
  { name: "Home", url: root_url },
  { name: property.for_rent? ? "Rentals" : "Buy", url: ... },
  { name: property.title, url: request.original_url }
]
<%= breadcrumb_json_ld(breadcrumbs) %>
```

#### 4. Add Custom Fields for SEO
Add to `Prop` and property models:
- `seo_keywords` - Target keywords (informational, not meta keyword tag)
- `internal_notes` - SEO notes for content team
- `slug` - Already partially implemented for URL structure

#### 5. Enhance Price Display in Structured Data
Currently handles sale/rental split. Could add:
- Availability status (inStock, outOfStock, preOrder)
- Price history tracking
- Alternative prices (furnished vs unfurnished)

#### 6. Add Location/Map Schema
Already has latitude/longitude. Could add:
- GeoShape for neighborhood boundary
- Place context for nearby amenities
- Multiple location addresses for large properties

#### 7. SEO Audit/Health Check
Create a helper to score SEO metadata:
```ruby
def seo_health_check(property)
  issues = []
  issues << "Missing seo_title" if property.seo_title.blank?
  issues << "Description too short" if property.description.blank? || property.description.length < 100
  issues << "No images" if property.prop_photos.empty?
  issues
end
```

## Key Files to Modify for Changes

| File | Purpose | Current Content |
|------|---------|-----------------|
| `/app/helpers/seo_helper.rb` | Core SEO methods | Helper methods, JSON-LD generation |
| `/app/controllers/pwb/props_controller.rb` | SEO setup for properties | `set_property_seo()` method |
| `/app/views/pwb/props/_meta_tags.html.erb` | Property meta tags | JSON-LD scripts, location metadata |
| `/app/themes/*/views/layouts/pwb/application.html.erb` | Layout with `<head>` | Calls `<%= seo_meta_tags %>` |
| `/app/models/pwb/prop.rb` | Property model | Add `seo_title`, `meta_description` fields |
| `/app/models/pwb/listed_property.rb` | Read-only view model | Accessor methods for SEO data |
| Database | Storage | Migrations for SEO columns |

## Multi-Tenant Considerations

PropertyWebBuilder uses website-scoped meta tags:
- Each website can have custom `default_meta_description`
- Logo URL comes from `current_website.logo_url`
- Company name from `current_website.company_display_name`
- Locale from `current_website.default_client_locale_to_use`

Ensure new SEO features:
- Use `current_website` or `Pwb::Current.website` for context
- Don't leak data across tenants
- Support per-website configuration

## Testing Considerations

Test the complete meta tag output:
1. **Meta tag generation** - Verify `seo_meta_tags` helper output
2. **Structured data validation** - Use Schema.org validator on JSON-LD
3. **Open Graph** - Test with Facebook debugger
4. **Twitter Cards** - Test with Twitter Card validator
5. **Canonical URLs** - Verify slug vs ID handling
6. **Multi-language** - Test hreflang generation
7. **Property data** - Verify correct property data in tags
8. **Image optimization** - Verify correct image dimensions

## Performance Notes

The current implementation:
- Uses eager loading (`with_eager_loading`) to avoid N+1 queries
- Caches website logo and descriptions
- Generates JSON-LD efficiently (no additional queries needed)
- Integrates with ActiveStorage for images

Potential optimizations:
- Cache seo_meta_tags output per property (invalidate on update)
- Pre-generate JSON-LD for featured properties
- Use CDN for images with proper dimensions
