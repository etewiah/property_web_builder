# Meta Tags Quick Reference

## TL;DR - Current Setup

PropertyWebBuilder already has comprehensive meta tag support:

**Status:** ✅ Fully implemented and working

- Open Graph tags (og:title, og:description, og:image, etc.)
- Twitter Card meta tags
- Canonical URLs (handles slug-based URLs)
- Structured data (JSON-LD) for real estate listings
- Organization schema
- Multi-language support (hreflang)
- Favicon management
- Robots directives (noindex/nofollow)

## How It Works

1. **Controller** (`props_controller.rb`) calls `set_property_seo(property, type)`
2. **Helper** (`seo_helper.rb`) stores data in `@seo_data`
3. **Layout** (`application.html.erb`) renders `<%= seo_meta_tags %>` in `<head>`
4. **Partial** (`_meta_tags.html.erb`) adds property-specific structured data

## Files to Know

| File | What It Does |
|------|-------------|
| `app/helpers/seo_helper.rb` | All SEO methods and tag generation |
| `app/controllers/pwb/props_controller.rb` | Calls `set_property_seo()` |
| `app/views/pwb/props/_meta_tags.html.erb` | Property schema and location metadata |
| `app/themes/*/views/layouts/pwb/application.html.erb` | Renders `seo_meta_tags` in head |

## Using SEO Helper in Controllers

```ruby
# In your controller
include SeoHelper

def my_page
  set_seo(
    title: "Custom Title",
    description: "Custom description",
    canonical_url: "https://example.com/path",
    image: property.primary_image_url,
    og_type: 'product'
  )
end
```

## In Views

```erb
<!-- Layout automatically includes -->
<%= seo_meta_tags %>

<!-- For additional property-specific tags -->
<%= property_json_ld(@property) %>
<%= organization_json_ld %>
```

## Property SEO Data Available

From `ListedProperty` or `Prop` model:
- `title` - Property name
- `description` - Property description
- `seo_title` - Custom SEO override (custom field)
- `meta_description` - Custom SEO override (custom field)
- `price_sale_current` - Sale price with currency
- `price_rental_monthly_current` - Rental price with currency
- `count_bedrooms, count_bathrooms` - Room counts
- `constructed_area, plot_area` - Square footage
- `street_address, city, region, postal_code, country` - Address
- `latitude, longitude` - Coordinates
- `primary_image_url` - First photo
- `prop_photos` - All photos
- `slug` - URL-friendly identifier
- `visible` - Published flag

## Routes

```
GET /properties/for-sale/:id/:url_friendly_title     => props#show_for_sale
GET /properties/for-rent/:id/:url_friendly_title     => props#show_for_rent
```

URL can use either slug or UUID as `:id` parameter.

## Adding Custom SEO Data

### Add fields to Property (already done)
```ruby
# Migration exists: db/migrate/20251208160548_add_seo_fields_to_props.rb
# Adds: seo_title, meta_description
```

### Use custom SEO in controller
```ruby
def set_property_seo(property, operation_type)
  set_seo(
    title: property.seo_title.presence || property.title,
    description: property.meta_description.presence || truncate_description(property.description),
    # ... other fields
  )
end
```

## Testing

Use these validators:
- **Google Rich Results** - https://search.google.com/test/rich-results
- **Facebook OG Debugger** - https://developers.facebook.com/tools/debug/
- **Twitter Card Validator** - https://cards-dev.twitter.com/validator
- **Schema.org Validator** - https://schema.org/validate

## Common Customizations

### Change OG image
```ruby
set_seo(image: custom_image_url)  # Replaces property.primary_image_url
```

### Add hreflang for translations
```ruby
set_seo(alternate_urls: {
  'en' => english_url,
  'es' => spanish_url
})
```

### Prevent indexing
```ruby
set_seo(noindex: true, nofollow: true)
```

### Custom site name in title
```ruby
set_seo(
  title: "Property Name",
  include_site_name: true  # or false
)
```

## Data Dictionary

### og:type Values
- `'product'` - Used for property listings (current)
- `'real_estate.property'- Alternative (not used)
- `'website'` - Default for pages

### JSON-LD Types
- `RealEstateListing` - Property listing
- `RealEstateAgent` - Agency/organization
- `BreadcrumbList` - Navigation path

### Monetize Fields
Properties use money-rails:
- `price_sale_current` - Sale price as Money object
- `price_rental_monthly_current` - Rental price as Money object
- Format: `.format(no_cents: true)` for display

## Troubleshooting

**Issue:** Meta tags not showing
- Check: `<%= seo_meta_tags %>` in layout's `<head>`
- Check: Controller calls `set_seo()`

**Issue:** Wrong title
- Check: `seo_title` field vs `title`
- Check: `include_site_name` setting

**Issue:** Missing images
- Check: Property has photos attached
- Check: `primary_image_url` method works
- Check: Image dimensions (1200x630 recommended)

**Issue:** Structured data invalid
- Check: All required fields present
- Check: Prices have currency codes
- Check: Dates in ISO 8601 format

## Performance

- Uses eager loading with `.with_eager_loading` scope
- JSON-LD generation has no additional queries
- Image URLs generated via Rails blob helpers
- Cached: Footer, nav links per website

## Security Notes

- All user input is escaped by Rails ERB
- Canonical URLs use `request.protocol` (respects HTTPS)
- No sensitive data in structured data
- Multi-tenant scoped via `current_website`
