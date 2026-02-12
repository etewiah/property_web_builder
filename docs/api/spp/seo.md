# SPP SEO Coordination (Option B)

**Status:** Implemented
**Related:** [SPP–PWB Integration](./README.md) | [SppListing Model](./spp-listing-model.md)

---

## Summary

With Option B, both PWB and SPP can serve pages for the same property — creating a duplicate content problem. This document defines the SEO strategy to ensure search engines index the right page and properties aren't penalized for duplication.

## The Problem

A property listed on PWB exists at two URLs:

| System | URL Example | Page Type |
|--------|------------|-----------|
| PWB | `https://tenant.pwb.com/en/properties/for-sale/<uuid>/<slug>` | Standard listing page |
| SPP | `https://123-main-st.spp.example.com/` | Rich marketing microsite |

Without coordination, search engines may:
- Index both pages and split ranking signals
- Apply a duplicate content penalty
- Display the wrong page in search results

## Decision: SPP Is the Canonical Page

When a tenant uses SPP for a property, **SPP's page is the canonical version**. Rationale:

- SPP pages are purpose-built marketing pages with richer content
- The tenant chose to use SPP specifically to improve the property's online presence
- PWB's listing page still exists for internal use (admin, search results on PWB) but should defer to SPP for search engines

## Implementation

### 1. Canonical URL on PWB's Property Page

When a property has an SPP page, PWB's property page should include a canonical link pointing to SPP:

```html
<link rel="canonical" href="https://123-main-st.spp.example.com/">
```

**Where to implement:** In `PropsController#set_property_seo` (`app/controllers/pwb/props_controller.rb:152-190`), after determining the canonical URL:

```ruby
def set_property_seo(property, operation_type)
  # Check if this property has an SPP page
  spp_url = spp_live_url_for(property)

  canonical_url = if spp_url.present?
                    spp_url  # Defer to SPP as canonical
                  elsif property.slug.present?
                    "#{request.protocol}#{request.host_with_port}#{property.contextual_show_path(operation_type)}"
                  else
                    "#{request.protocol}#{request.host_with_port}#{request.path}"
                  end

  set_seo(
    title: ...,
    description: ...,
    canonical_url: canonical_url,
    # ...
  )
end
```

**How PWB knows the SPP URL:** The publish endpoint already computes `liveUrl` from `client_theme_config['spp_url_template']`. The same logic can be extracted into a shared method (`spp_live_url_for(property)`) that both the publish endpoint and `PropsController` can use.

Alternatively, store the SPP URL on the listing itself (e.g., a `spp_url` field) when the publish endpoint is called. This avoids recomputing the template each time.

### 2. Noindex on PWB's Property Page (Optional, Stronger)

For a belt-and-suspenders approach, add `noindex` to PWB's property page when an SPP page exists:

```ruby
should_noindex = listing&.noindex || listing&.archived || listing&.reserved || spp_url.present?
```

This uses the existing `noindex` infrastructure in `SeoHelper#seo_meta_tags` (`app/helpers/seo_helper.rb:149-154`), which already renders `<meta name="robots" content="noindex">` when the flag is set.

**Trade-off:** With `noindex`, PWB's page won't appear in search results at all. This is desirable if SPP is always the preferred page. If you want PWB's page to still rank as a fallback (e.g., if SPP goes down), use only the canonical link without noindex.

**Recommendation:** Use canonical link only (no noindex). This preserves PWB as a fallback while signaling SPP as preferred.

### 3. Canonical URL on SPP's Page

SPP's page should include a self-referencing canonical:

```html
<link rel="canonical" href="https://123-main-st.spp.example.com/">
```

This is standard practice. SPP should set this in its own `<head>` — no PWB change needed.

### 4. Sitemap Coordination

PWB generates per-tenant sitemaps via `SitemapsController` (`app/controllers/sitemaps_controller.rb`). The sitemap includes all visible properties at their PWB URLs.

**When a property has an SPP page**, the sitemap entry should point to the SPP URL instead of the PWB URL:

```xml
<!-- Without SPP -->
<url>
  <loc>https://tenant.pwb.com/en/properties/for-sale/abc/nice-villa</loc>
  <lastmod>2026-02-10</lastmod>
  <changefreq>weekly</changefreq>
  <priority>0.8</priority>
</url>

<!-- With SPP -->
<url>
  <loc>https://123-main-st.spp.example.com/</loc>
  <lastmod>2026-02-10</lastmod>
  <changefreq>weekly</changefreq>
  <priority>0.8</priority>
</url>
```

**Where to implement:** In the sitemap view (`app/views/sitemaps/index.xml.erb`), when building the `<loc>` for each property, check for an SPP URL:

```erb
<% url = spp_live_url_for(property) || property_url(property) %>
<loc><%= url %></loc>
```

This keeps the sitemap accurate — search engines see only one URL per property.

### 5. JSON-LD Structured Data

PWB generates `RealEstateListing` JSON-LD via `SeoHelper#property_json_ld` (`app/helpers/seo_helper.rb:160-245`). The JSON-LD includes a `url` field pointing to PWB's property page.

**When an SPP page exists**, the JSON-LD `url` should point to SPP:

```ruby
def property_json_ld(prop)
  spp_url = spp_live_url_for(prop)
  property_url = spp_url || "#{request.protocol}#{request.host_with_port}#{prop.contextual_show_path(...)}"

  {
    '@context' => 'https://schema.org',
    '@type' => 'RealEstateListing',
    'url' => property_url,
    # ... rest of JSON-LD
  }
end
```

**SPP should also generate its own JSON-LD.** SPP can fetch the same property data from `api_public` and produce identical structured data. The `url` in SPP's JSON-LD should be its own URL (matching the canonical).

To keep the JSON-LD consistent, consider adding a `json_ld` field to the property API response so SPP can embed it directly without reimplementing the generation logic.

### 6. Hreflang Tags

PWB generates hreflang alternate links for multi-language sites (`SeoHelper#seo_meta_tags`, lines ~139-147). If a property has SPP pages in multiple locales, the hreflang URLs should point to SPP's locale-specific pages.

**This is a lower-priority concern.** Most SPP pages are single-locale. If multi-locale SPP pages are needed later, the `spp_url_template` in `client_theme_config` can include a `{locale}` placeholder.

## Data Flow: How PWB Knows About SPP URLs

Two options, both compatible:

### Option 1: Compute from Template

`client_theme_config['spp_url_template']` stores a pattern like `https://{slug}.spp.example.com/`. PWB interpolates property data at render time.

**Pros:** No extra storage, always in sync with the template.
**Cons:** Template must be kept consistent with SPP's actual URL structure.

### Option 2: Store on the Listing

When the publish endpoint is called, store the computed `liveUrl` on the listing (e.g., `spp_url` column on `pwb_sale_listings`). PWB reads it directly.

**Pros:** Simple reads, no template parsing. SPP could also send a custom URL in the publish request.
**Cons:** Requires a migration. Could become stale if SPP's URL structure changes.

**Decision:** Both options are used. The publish endpoint computes the URL from `spp_url_template` (Option 1) and stores it on `SppListing#live_url` (Option 2). The `spp_live_url_for` helper reads from the stored `live_url` column — no template re-computation needed at render time.

## Shared Helper: `spp_live_url_for` (Implemented)

Implemented in `app/helpers/seo_helper.rb`, usable by `PropsController`, `SitemapsController`, and views:

```ruby
def spp_live_url_for(property, listing_type = nil)
  scope = Pwb::SppListing.where(realty_asset_id: property.id, active: true, visible: true)
  scope = scope.where(listing_type: listing_type) if listing_type
  scope.first&.live_url
end
```

Returns `nil` when no active+visible SPP listing exists, allowing callers to fall back to PWB's URL. Pass `listing_type` to scope by variant (e.g., PWB's sale page canonicals to the sale SPP listing). Covered by 8 specs in `spec/helpers/seo_helper_spp_spec.rb`.

## Implementation Checklist

- [x] `spp_live_url_for` helper in `SeoHelper` (8 specs)
- [x] `PropsController#set_property_seo` uses SPP URL as canonical when available
- [x] `SitemapsController` uses SPP URL in `<loc>` for sale and rental properties
- [x] JSON-LD reads from `seo_canonical_url` which already uses SPP URL (no change needed)
- [ ] SPP: Set self-referencing canonical on its own pages
- [ ] SPP: Generate its own JSON-LD from property API data

## Reference Files

| File | Relevance |
|------|-----------|
| `app/controllers/pwb/props_controller.rb:152-190` | `set_property_seo` — canonical URL logic |
| `app/helpers/seo_helper.rb:51-53` | `seo_canonical_url` — canonical rendering |
| `app/helpers/seo_helper.rb:108-157` | `seo_meta_tags` — meta tag generation including noindex |
| `app/helpers/seo_helper.rb:160-245` | `property_json_ld` — JSON-LD generation |
| `app/controllers/sitemaps_controller.rb` | Sitemap generation |
| `app/views/sitemaps/index.xml.erb` | Sitemap XML template |
| `app/controllers/robots_controller.rb` | Robots.txt (no changes needed) |
