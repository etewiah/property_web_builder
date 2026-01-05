# URL Routing Quick Reference

## TL;DR Comparison Table

| Aspect | Internal Listings | External Listings |
|--------|-------------------|-------------------|
| **URL Pattern** | `/properties/for-{type}/{id}/{title}` | `/external_listings/{reference}` |
| **Controller** | `Pwb::PropsController` | `Pwb::Site::ExternalListingsController` |
| **Primary ID** | UUID or Slug | Provider Reference Code |
| **Route Name** | `prop_show_for_rent` / `prop_show_for_sale` | `external_listing_path` |
| **Find By** | Slug first, then UUID | Reference code directly |
| **Example URL** | `/en/properties/for-rent/abc-uuid/my-apartment` | `/en/external_listings/EXT-REF-12345` |
| **Data Source** | Database | External feed provider |
| **Editable** | Yes (admin interface) | No (read-only) |
| **Listing Type** | Separate routes per type | Same route, type in data/query |

---

## URL Generation Examples

### Internal Properties

```ruby
# From ListedProperty model
property.contextual_show_path("for_rent")
# => "/en/properties/for-rent/luxury-villa-slug/luxury-villa-name"

# Using route helper
prop_show_for_rent_path(
  locale: :en,
  id: "luxury-villa-slug",
  url_friendly_title: "luxury-villa-name"
)

# Backward compatible (using ID instead of slug)
prop_show_for_rent_path(
  locale: :en,
  id: "550e8400-e29b-41d4-a716-446655440000",
  url_friendly_title: "luxury-villa-name"
)
```

### External Properties

```ruby
# Using route helper
external_listing_path(
  reference: "EXT-REF-12345",
  listing_type: :sale,
  locale: :en
)
# => "/en/external_listings/EXT-REF-12345?listing_type=sale"

# Without listing_type (often implicit in data)
external_listing_path(reference: "EXT-REF-12345")
# => "/external_listings/EXT-REF-12345"
```

---

## In Views - Common Patterns

### Linking to Internal Property

```erb
<%# Method 1: Using model helper %>
<a href="<%= @property.contextual_show_path("for_rent") %>">
  View Property
</a>

<%# Method 2: Direct route helper %>
<%= link_to "View", prop_show_for_rent_path(
  id: @property.slug_or_id,
  url_friendly_title: @property.url_friendly_title
) %>
```

### Linking to External Property

```erb
<%# Using external_listing_path helper %>
<a href="<%= external_listing_path(reference: @property.reference, listing_type: @property.listing_type) %>">
  View Property
</a>

<%# Or using link_to %>
<%= link_to "View", external_listing_path(reference: @property.reference) %>
```

### Mixed Provider Context (Saved Properties)

```erb
<% if saved_property.provider == "internal" %>
  <a href="<%= prop_show_for_rent_path(id: saved_property.id, url_friendly_title: saved_property.url_friendly_title) %>">
    View Internal
  </a>
<% else %>
  <a href="<%= external_listing_path(reference: saved_property.external_reference) %>">
    View External
  </a>
<% end %>
```

---

## Controller Actions Quick Reference

### Internal Listings (`PropsController`)

```ruby
GET /properties/for-rent/:id/:url_friendly_title
  → props#show_for_rent
  → Looks up by slug, falls back to UUID
  
GET /properties/for-sale/:id/:url_friendly_title
  → props#show_for_sale
  → Looks up by slug, falls back to UUID
```

### External Listings (`ExternalListingsController`)

```ruby
GET /external_listings
  → external_listings#index
  → Lists all or searches
  
GET /external_listings/search
  → external_listings#search
  → Same as index with search semantics
  
GET /external_listings/:reference
  → external_listings#show
  → Finds by reference code
  
GET /external_listings/:reference/similar
  → external_listings#similar
  → Gets similar properties
  
GET /external_listings/locations      (JSON)
  → external_listings#locations
  
GET /external_listings/property_types (JSON)
  → external_listings#property_types
  
GET /external_listings/filters        (JSON)
  → external_listings#filters
```

---

## Lookup Strategies

### Internal Properties - Lookup Logic

```ruby
def find_property_by_slug_or_id(identifier)
  scope = Pwb::ListedProperty.where(website_id: @current_website.id)
  
  # Step 1: Try slug
  property = scope.find_by(slug: identifier)
  return property if property
  
  # Step 2: Fall back to ID (UUID or integer)
  scope.find_by(id: identifier)
end
```

**Priority:**
1. Slug (if present in database)
2. UUID/ID (fallback for legacy URLs)

### External Properties - Lookup Logic

```ruby
def set_listing
  @listing = external_feed.find(
    params[:reference],
    locale: I18n.locale,
    listing_type: listing_type_param
  )
end
```

**Priority:**
1. Reference code (provider-assigned)
2. No fallback - exact match required

---

## Locale Handling

Both listing types support locale prefixes:

```
Internal:
/en/properties/for-rent/abc-uuid/title
/es/properties/for-rent/abc-uuid/titulo
/fr/properties/for-rent/abc-uuid/titre

External:
/en/external_listings/EXT-REF-123
/es/external_listings/EXT-REF-123
/fr/external_listings/EXT-REF-123
```

Use `I18n.locale` to generate locale-aware URLs:

```ruby
# Internal
prop_show_for_rent_path(id: id, url_friendly_title: title, locale: I18n.locale)

# External
external_listing_path(reference: ref, locale: I18n.locale)
```

---

## URL Component Breakdown

### Internal Property URL

```
/en/properties/for-rent/luxury-villa-slug/luxury-villa-barcelona
│   │              │       │              │
│   │              │       │              └─ URL-friendly title (SEO, not used for lookup)
│   │              │       └─ Slug or UUID (used for lookup)
│   │              └─ Listing type indicator (in path)
│   └─ Listing type (for-rent or for-sale)
└─ Locale (optional prefix)
```

### External Property URL

```
/en/external_listings/EXT-REF-12345
│   │                 │
│   │                 └─ Reference code (used for lookup)
│   └─ Collection name (external_listings)
└─ Locale (optional prefix)
```

---

## Parameter Differences

### Internal Properties - URL Parameters

```ruby
prop_show_for_rent_path(
  locale: :en,              # Locale code
  id: slug_or_id,           # Slug preferred, UUID fallback
  url_friendly_title: "my-property"  # For SEO only
)

# Only 'id' is used for database lookup
# 'url_friendly_title' is for SEO and user readability
# 'locale' changes the URL prefix
```

### External Properties - URL Parameters

```ruby
external_listing_path(
  reference: "EXT-REF-123",  # Required, used for lookup
  listing_type: :sale,        # Optional, can be in URL or query string
  locale: :en                 # Locale code
)

# All parameters except 'locale' can vary by provider
# Usually: reference is required, others are optional/contextual
```

---

## SEO Considerations

### Internal Properties

- **Slug in URL:** Use custom slug for better SEO
- **Title in URL:** Automatically added, helps with rankings
- **Canonical URL:** Generated to avoid duplicates
- **noindex support:** Can flag archived/reserved properties

**Best Practice:**
```ruby
# Create a good slug
property.update(slug: "luxury-beachfront-villa-marbella")

# This generates SEO-friendly URL:
/en/properties/for-sale/luxury-beachfront-villa-marbella/luxury-beachfront-villa-marbella
```

### External Properties

- **Reference in URL:** Not SEO-friendly but necessary
- **Title not in URL:** Less optimal for SEO
- **Dynamic canonical:** Prevents duplicate content

**Improvement Opportunity:**
- Consider adding provider + title to external listing URLs for better SEO

---

## Migration/Compatibility Notes

### Old vs New Internal URLs

```ruby
# Old (legacy, still works with ID fallback)
/properties/for-rent/12345/my-property

# New (with slug)
/properties/for-rent/my-property-slug/my-property

# Both work because of find_property_by_slug_or_id logic
```

### External Listings

```ruby
# Current implementation
/external_listings/EXT-REF-12345

# Could be enhanced to:
/external_listings/EXT-REF-12345/property-title
# But would require route and model changes
```

---

## Common Issues and Solutions

### Issue: URL returns 404 for valid property

**Internal Properties:**
- Check if property is marked `visible: true`
- Check if property has correct `for_rent` or `for_sale` flag
- Verify slug exists in database or fallback to ID works

**External Properties:**
- Verify feed is `enabled` and `configured`
- Check reference code matches exactly (case-sensitive)
- Verify `listing_type` matches available data

### Issue: Slug not being used in URL

**Solution:**
- Ensure slug is populated in database
- Check: `property.slug.present?` returns true
- Verify slug doesn't exceed 255 characters

### Issue: External listing not appearing in search

**Solution:**
- Verify external feed provider is configured
- Check feed is returning results: `external_feed.configured?` && `external_feed.enabled?`
- Verify search parameters are correct

---

## Testing Checklist

- [ ] Internal property loads with slug
- [ ] Internal property loads with UUID (fallback)
- [ ] External property loads with reference
- [ ] Locale prefixes work for both types
- [ ] SEO meta tags are correct for both types
- [ ] Canonical URLs are generated correctly
- [ ] 404 handling works for invalid identifiers
- [ ] Mixed provider scenarios (saved properties) work
- [ ] Search filters work for external listings
- [ ] HTTP caching headers are set appropriately

---

## File References

| File | Purpose |
|------|---------|
| `/config/routes.rb` | Route definitions |
| `/app/controllers/pwb/props_controller.rb` | Internal listing controller |
| `/app/controllers/pwb/site/external_listings_controller.rb` | External listing controller |
| `/app/models/concerns/listed_property/url_helpers.rb` | URL generation logic |
| `/app/helpers/pwb/search_url_helper.rb` | Search URL helpers |

---

*Quick Reference Version 1.0*
*For detailed information, see url_routing_comparison.md*
