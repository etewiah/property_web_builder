# External Listings Theme Support

This document describes the theme support implementation for external listings pages.

## Overview

External listings (properties from external feed providers) now support the same theme system as internal property pages. Each theme can provide custom views for external listings, with automatic fallback to the default views.

## Directory Structure

Theme-specific views for external listings are located at:

```
app/themes/{theme_name}/views/pwb/site/external_listings/
```

Fallback views (used when a theme doesn't provide custom views):

```
app/views/pwb/site/external_listings/
```

## Available Views

### Main Views

| View | Purpose |
|------|---------|
| `show.html.erb` | Property detail page |
| `index.html.erb` | Search results page |
| `unavailable.html.erb` | Sold/rented property page |

### Partials

Reusable partials available for all themes:

| Partial | Purpose |
|---------|---------|
| `_images_carousel.html.erb` | Image gallery with thumbnails |
| `_info_list.html.erb` | Property info (title, location, key features) |
| `_features_list.html.erb` | Features grid with energy rating |
| `_price_card.html.erb` | Sidebar price card with CTA buttons |
| `_details_card.html.erb` | Sidebar property details list |
| `_agency_card.html.erb` | Agency contact information |
| `_contact_form.html.erb` | Inquiry form |
| `_meta_tags.html.erb` | SEO meta tags (Open Graph, Twitter, JSON-LD) |
| `_search_form.html.erb` | Search filters |
| `_property_card.html.erb` | Property card for listings |
| `_pagination.html.erb` | Pagination controls |
| `_similar.html.erb` | Similar properties grid |

## Theme Implementations

### Brisbane Theme

Located at: `app/themes/brisbane/views/pwb/site/external_listings/`

Uses brisbane's consistent styling patterns:
- `property-detail-page` section class
- `property-detail-container` for max-width container
- `property-detail-layout` for main/sidebar grid
- `property-detail-main` and `property-detail-sidebar` for columns

### Bologna Theme

Located at: `app/themes/bologna/views/pwb/site/external_listings/`

Uses bologna's distinctive styling:
- Warm color palette (`warm-gray-*`, `terra-*`, `olive-*`)
- Soft rounded corners (`rounded-softer`, `rounded-soft`)
- Soft shadows (`shadow-soft`)
- Font display classes (`font-display`)
- Gradient backgrounds

## Creating a New Theme

To add external listings support to a new theme:

1. Create the directory:
   ```bash
   mkdir -p app/themes/{your_theme}/views/pwb/site/external_listings/
   ```

2. Copy the show.html.erb from an existing theme and customize:
   ```bash
   cp app/themes/brisbane/views/pwb/site/external_listings/show.html.erb \
      app/themes/{your_theme}/views/pwb/site/external_listings/
   ```

3. Update the styling to match your theme's design system

4. The shared partials in `app/views/pwb/site/external_listings/` will be used automatically for any partials you don't override

## Fragment Caching

External listings use fragment caching for expensive sections:

```erb
<% cache external_listing_cache_key(@listing, "gallery") do %>
  <%= render 'pwb/site/external_listings/images_carousel' %>
<% end %>

<% cache external_listing_cache_key(@listing, "info") do %>
  <%= render 'pwb/site/external_listings/info_list' %>
<% end %>

<% cache external_listing_cache_key(@listing, "features") do %>
  <%= render 'pwb/site/external_listings/features_list' %>
<% end %>
```

The cache keys are tenant-scoped and include:
- Website ID
- Current locale
- Listing reference
- Listing type (sale/rental)
- Last updated timestamp

## Theme Resolution

Theme resolution happens automatically via the `set_theme_path` method in `Pwb::ApplicationController`. The order of view lookup is:

1. `app/themes/{current_theme}/views/`
2. `app/views/` (fallback)

Themes can also be switched via URL parameter for testing:
```
/external_listings/REF123?theme=bologna
```

Note: Only themes in `ALLOWED_THEMES` can be switched via URL parameter.

## Testing

Theme support is tested in:
```
spec/views/pwb/site/external_listings_theme_spec.rb
```

Run the tests:
```bash
bundle exec rspec spec/views/pwb/site/external_listings_theme_spec.rb
```

## Related Documentation

- [Theme System Overview](./README_THEME_SYSTEM.md)
- [Theme Creation Checklist](./THEME_CREATION_CHECKLIST.md)
- [Theme Implementation Patterns](./THEME_IMPLEMENTATION_PATTERNS.md)
