# SEO Quick Reference & Checklist

Quick reference guide for PropertyWebBuilder SEO implementation priorities.

---

## Current SEO Status Overview

| Feature | Status | Priority | Effort |
|---------|--------|----------|--------|
| Page Titles | ✅ Partial | Medium | 1 day |
| Meta Descriptions | ❌ Missing | High | 2 days |
| Open Graph Tags | ⚠️ Partial | High | 2 days |
| Twitter Cards | ❌ Missing | Medium | 1 day |
| Canonical URLs | ❌ Missing | High | 2 days |
| JSON-LD Schema | ❌ Missing | High | 3 days |
| Robots.txt | ⚠️ Incomplete | Medium | 1 day |
| Sitemap XML | ❌ Missing | High | 3 days |
| Hreflang Tags | ❌ Missing | Medium | 1 day |
| Breadcrumb Schema | ❌ Missing | Medium | 1 day |
| **TOTAL ESTIMATED TIME** | — | — | **17 days** |

---

## Phase 1: Critical Foundations (1 Week)

### Phase 1A: Database & Models (2 days)
- [ ] Create migration to add `meta_description` to Props and Pages
- [ ] Create migration to add `seo_slug` to Props (optional, for cleaner slugs)
- [ ] Create migration to add `seo_settings` JSON to Website
- [ ] Add model validations for SEO fields (160 char limit for descriptions)

### Phase 1B: Controllers & Helpers (3 days)
- [ ] Create `SeoHelper` module with basic tag rendering
- [ ] Update all controllers to set `@meta_description`
- [ ] Update PropsController to properly set page titles and descriptions
- [ ] Update PagesController to properly set page titles and descriptions
- [ ] Update WelcomeController for homepage SEO
- [ ] Add `setup_seo_defaults` to ApplicationController

### Phase 1C: View Updates (2 days)
- [ ] Create `_seo_meta_tags.html.erb` partial
- [ ] Update all theme layouts to include SEO partial
- [ ] Ensure proper meta tag rendering for all pages
- [ ] Test meta tags on:
  - Homepage
  - Property page
  - Static pages
  - 404 page (noindex)

---

## Phase 2: Social Media & Sharing (1 Week)

### Phase 2A: Open Graph Complete (2 days)
- [ ] Add `og:title` support
- [ ] Add `og:description` support
- [ ] Add `og:type` support (product for properties, website for pages)
- [ ] Add `og:url` with canonical URLs
- [ ] Fix existing `og:image` implementation
- [ ] Test with Facebook Debugger

### Phase 2B: Twitter Cards (1 day)
- [ ] Add `twitter:card` support
- [ ] Add `twitter:title`
- [ ] Add `twitter:description`
- [ ] Add `twitter:image`
- [ ] Test with Twitter Card Validator

### Phase 2C: Canonical URLs (2 days)
- [ ] Implement `rel="canonical"` link tag
- [ ] Prefer slug-based URLs for properties
- [ ] Handle multi-locale canonical URLs
- [ ] Test for canonical URL duplication issues

### Phase 2D: Hreflang Tags (1 day)
- [ ] Add hreflang alternate links for multi-language pages
- [ ] Implement for properties, pages, and homepage
- [ ] Test language detection

---

## Phase 3: Search Engine Optimization (1 Week)

### Phase 3A: Robots.txt (1 day)
- [ ] Update `/public/robots.txt` with proper directives
- [ ] Add sitemap reference (placeholder for phase 3B)
- [ ] Add crawl-delay recommendations
- [ ] Disallow admin paths
- [ ] Test with robot validation tools

### Phase 3B: XML Sitemap (3 days)
- [ ] Choose implementation (gem vs custom)
- [ ] Create sitemap index for multi-tenant setup
- [ ] Generate property sitemap (visible only)
- [ ] Generate page sitemap
- [ ] Add static pages to sitemap
- [ ] Implement sitemap regeneration strategy
- [ ] Test with Google Search Console

### Phase 3C: Structured Data - JSON-LD (3 days)
- [ ] Create StructuredDataHelper for schema generation
- [ ] Implement Property schema for property pages
- [ ] Implement Organization schema for homepage
- [ ] Implement LocalBusiness schema for agency info
- [ ] Implement BreadcrumbList schema for navigation
- [ ] Test with Google Rich Results Test

---

## Quick Implementation Snippets

### Add Meta Description to Controller

```ruby
def show_for_rent
  @property_details = find_property_by_slug_or_id(params[:id])
  if @property_details && @property_details.visible && @property_details.for_rent
    @page_title = @property_details.title
    @meta_description = @property_details.meta_description || 
                       truncate(strip_tags(@property_details.description), length: 160)
    render "/pwb/props/show"
  end
end
```

### Add OG Tags to Layout

```erb
<meta property="og:title" content="<%= @page_title %>">
<meta property="og:description" content="<%= @meta_description %>">
<meta property="og:image" content="<%= @og_image %>">
<meta property="og:url" content="<%= request.original_url %>">
<meta property="og:type" content="<%= @og_type || 'website' %>">
```

### Add Canonical Link

```erb
<% if @canonical_url.present? %>
  <link rel="canonical" href="<%= @canonical_url %>">
<% end %>
```

### Add Twitter Card

```erb
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="<%= @page_title %>">
<meta name="twitter:description" content="<%= @meta_description %>">
<meta name="twitter:image" content="<%= @og_image %>">
```

### Add JSON-LD Property Schema

```erb
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "<%= @property_details.title %>",
  "description": "<%= @property_details.description %>",
  "image": "<%= @og_image %>",
  "url": "<%= request.original_url %>",
  "offers": {
    "@type": "Offer",
    "priceCurrency": "EUR",
    "price": "<%= @property_details.price %>"
  }
}
</script>
```

---

## Testing Checklist

### For Each Page Type:

#### Homepage
- [ ] Correct `<title>` tag
- [ ] Meta description present and 120-160 chars
- [ ] og:title, og:description, og:image present
- [ ] twitter:card tags present
- [ ] Organization schema renders correctly
- [ ] Mobile meta tags (viewport)
- [ ] Hreflang tags for all locales

#### Property Page
- [ ] Correct title format (Address - Company Name)
- [ ] Meta description from property or truncated description
- [ ] og:image is property image, not placeholder
- [ ] og:type = "product"
- [ ] Canonical URL points to slug-based URL
- [ ] Property schema includes all details
- [ ] Breadcrumb schema present
- [ ] Can't access via both ID and slug (redirect or canonical)

#### Static Page
- [ ] Page title correct (page_title - Company Name)
- [ ] Meta description from page settings
- [ ] og:tags properly set
- [ ] Canonical URL correct

#### 404 Page
- [ ] Noindex tag present
- [ ] Proper 404 HTTP status code
- [ ] No follow link suggestions (optional)

### Search Engine Tools

- [ ] Google Search Console - Crawl stats
- [ ] Google Search Console - Sitemaps submitted
- [ ] Google Rich Results Test - Schema validates
- [ ] Facebook Open Graph Debugger - OG tags correct
- [ ] Twitter Card Validator - Twitter tags correct
- [ ] Mobile-Friendly Test - Mobile display correct

---

## Multi-Tenant Considerations

When implementing SEO for multi-tenant setup:

### Database Level
- [ ] Scope all queries to current website via `@current_website`
- [ ] Separate SEO settings per website in `seo_settings` JSON
- [ ] Use `acts_as_tenant` for automatic scoping

### URL Level
- [ ] Each website might have custom domain
- [ ] Meta tags should include website-specific brand
- [ ] Sitemaps should be per-website
- [ ] Robots.txt should be dynamic (per website if needed)

### SEO Settings Per Website
```ruby
# In Pwb::Website
seo_settings: {
  site_description: "Professional real estate...",
  brand_name: "My Agency",
  logo_url: "https://...",
  twitter_handle: "@myagency",
  facebook_url: "https://facebook.com/myagency",
  enable_sitemap: true,
  enable_structured_data: true
}
```

---

## Common Pitfalls to Avoid

1. **Duplicate Content Without Canonical**
   - Properties accessible via ID and slug
   - Same property listed multiple times
   - Multi-language versions without hreflang

2. **Incomplete Meta Tags**
   - Title set but no description
   - og:image without og:title
   - Missing og:type

3. **Broken Schema Markup**
   - Missing required fields in schema.org
   - Invalid JSON in JSON-LD
   - Wrong schema type for content

4. **Indexing Problems**
   - Admin pages indexed (add noindex)
   - Draft/unpublished pages indexed
   - Pagination pages not properly linked

5. **Image Issues**
   - og:image too small (recommend 1200x630)
   - og:image missing alt text
   - Image URLs not absolute

6. **Mobile Issues**
   - Missing viewport meta tag
   - Text too small on mobile
   - Clickable elements too close together

---

## Performance Metrics to Track

### Before Implementation
- [ ] Record current organic search traffic (baseline)
- [ ] Check current Google Search Console impressions
- [ ] Screenshot current page rankings

### After Phase 1 (Meta Tags)
- [ ] Track CTR improvement in Search Console
- [ ] Monitor bounce rate changes
- [ ] Check indexing status in Search Console

### After Phase 2 (Social Media)
- [ ] Track social shares
- [ ] Monitor click-through from social media
- [ ] Check social media traffic in Analytics

### After Phase 3 (Schema & Sitemap)
- [ ] Check rich results in Search Console
- [ ] Monitor property click improvements
- [ ] Track crawl efficiency in Search Console
- [ ] Measure crawl budget usage

---

## Tools & Resources

### Testing Tools
- Google Search Central: https://search.google.com/
- Google Rich Results Test: https://search.google.com/test/rich-results
- Facebook OG Debugger: https://developers.facebook.com/tools/debug/
- Twitter Card Validator: https://cards-dev.twitter.com/validator
- Bing Webmaster Tools: https://www.bing.com/webmasters

### Reference Documentation
- Schema.org: https://schema.org/
- Open Graph: https://ogp.me/
- Twitter Cards: https://developer.twitter.com/en/docs/twitter-for-websites/cards
- Google SEO Starter Guide: https://developers.google.com/search/docs/beginner/seo-starter-guide
- Sitemap Protocol: https://www.sitemaps.org/

### Recommended Gems
- `sitemap_generator` - For sitemap generation
- `kaminari` or keep `pagy` - For pagination SEO
- `metanizer` - For complex meta tag management (optional)

---

## Checklist Template for Implementation

Copy and use this checklist in pull request descriptions:

```markdown
## SEO Implementation Checklist

### Phase [1/2/3]

**Meta Tags**
- [ ] Page titles set correctly
- [ ] Meta descriptions added
- [ ] OG tags complete
- [ ] Canonical URLs working
- [ ] Tested with debuggers

**Robots & Sitemaps**
- [ ] Robots.txt updated
- [ ] Sitemap generating correctly
- [ ] Sitemap submitted to GSC

**Testing**
- [ ] Google Rich Results Test passes
- [ ] Facebook OG Debugger shows correct tags
- [ ] Twitter Card Validator passes
- [ ] Mobile test passes
- [ ] No console errors

**Documentation**
- [ ] Updated SEO documentation
- [ ] Added comments to helper methods
- [ ] Tested all controller actions
```

---

## Expected SEO Improvements

### Timeline
- **Month 1 (After Phase 1):** Improved crawlability, better social sharing
- **Month 2 (After Phase 2):** Schema validation passes, rich results eligible
- **Month 3 (After Phase 3):** Improved indexation, potential featured snippets

### Expected Results
- 10-20% increase in organic impressions
- 5-10% improvement in CTR from search results
- Better mobile rankings
- Improved rich result display
- Better social media sharing experience

---

**Last Updated:** December 8, 2025  
**Next Review:** After Phase 1 completion
