# PropertyWebBuilder SEO Audit Report

**Date:** December 8, 2025  
**Codebase:** PropertyWebBuilder (Rails 8.0 Multi-Tenant)  
**Status:** Initial Audit - Partial SEO Implementation Found

---

## Executive Summary

PropertyWebBuilder has a **partial SEO implementation** with some features in place but significant gaps for a comprehensive SEO solution. The system currently handles basic meta tags for social sharing and has page title management, but lacks critical SEO components like sitemap generation, robots.txt configuration, structured data markup, and canonical URL management.

---

## Detailed Findings

### 1. Meta Tags (Title, Description, Keywords, Open Graph)

#### What EXISTS:
- **Basic page title support:**
  - `@page_title` variable set in controllers (e.g., `PropsController`, `WelcomeController`)
  - `page_title` helper method in `ApplicationHelper` to set content
  - Rendered in layout via `<%= yield(:page_title) %>`
  - Example: `/app/controllers/pwb/props_controller.rb` lines 19-20, 42-43

- **Open Graph (OG) image tags (PARTIAL):**
  - Property images: `app/views/pwb/props/_meta_tags.html.erb`
    ```erb
    <meta property="og:image" content="...">
    <meta property="place:location:latitude" content="...">
    <meta property="place:location:longitude" content="...">
    ```
  - Page images: `app/views/pwb/_meta_tags.html.erb`
  - Only OG images implemented, no og:title, og:description, og:url, og:type

- **Viewport and basic meta tags:**
  - Located in: `app/themes/default/views/layouts/pwb/application.html.erb` line 6
  ```html
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="index, follow">
  ```

#### What's MISSING:
- **og:title** - Not set anywhere
- **og:description** - Not set anywhere
- **og:type** - Not defined (should be "product" for properties, "website" for pages)
- **og:url** - No canonical URL implementation
- **twitter:card** - Not implemented
- **twitter:title**, **twitter:description**, **twitter:image** - Not implemented
- **Meta description tags** - No implementation found
- **Meta keywords tags** - No implementation (deprecated but still useful)
- **Page description support** - Only properties have `@page_description` variable, pages don't
- **Schema.org alternate meta tags** for geo-location - Incomplete (only lat/long, no full schema)
- **Application meta tags** - No HTML5 app manifest, no pinned site icons

---

### 2. Sitemap Generation

#### Status: NOT IMPLEMENTED
- No sitemap gem installed (checked Gemfile - not present)
- No sitemap routes found in `config/routes.rb`
- No sitemap controller or generator
- Legacy comment in routes (line 282): `# comfy_route :cms, :path => '/comfy', :sitemap => false`

#### Expected Implementation Would Include:
- Dynamic sitemap for properties (by status, listing type)
- Page sitemap
- Sitemap index for large property databases
- XML sitemap generation
- Robots.txt directive to sitemap location

---

### 3. Robots.txt Handling

#### What EXISTS:
- **File present:** `/public/robots.txt`
- **Content:** Minimal - only header comment with documentation link

#### What's MISSING:
- No actual directives (Allow/Disallow rules)
- No sitemap reference
- No User-agent specific rules
- No crawl-delay configuration
- Not dynamically generated per website (multi-tenant issue)

#### Current robots.txt:
```
# See https://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file
```

---

### 4. Schema.org / JSON-LD Structured Data

#### Status: NOT IMPLEMENTED
- No JSON-LD markup found
- No schema.org micro-data implementation
- Only partial geo-location meta tags in properties

#### Critical Missing Schemas for Real Estate:
- **Schema.org/Property** or **Schema.org/RealEstateAgent**
- Property details (bedrooms, bathrooms, price, address)
- Agent/Agency information
- Organization schema for homepage
- BreadcrumbList schema for navigation
- LocalBusiness schema for agency contact info

---

### 5. Canonical URLs

#### Status: NOT IMPLEMENTED
- No canonical URL tags found
- Could be critical for duplicate content issues:
  - Properties accessible by ID and slug
  - Multiple listing types (for-rent vs for-sale)
  - Multi-locale support
  - Query parameters on search pages

#### Routes with Potential Duplicates:
```ruby
# Both could reference same property (lines 368-369 in routes.rb):
get "/properties/for-rent/:id/:url_friendly_title" => "props#show_for_rent"
get "/properties/for-sale/:id/:url_friendly_title" => "props#show_for_sale"

# find_property_by_slug_or_id method (props_controller.rb line 110-118)
# accepts both slug AND id, creating duplicate access paths
```

---

### 6. SEO-Related Models, Controllers, and Helpers

#### Models with SEO Relevance:
- **Pwb::Prop** (`app/models/pwb/prop.rb`)
  - Has `:title` and `:description` via Mobility translations
  - Table: `pwb_props` with `title` and `description` fields
  - Multi-locale support via Mobility gem

- **Pwb::Website** (`db/schema.rb`)
  - No dedicated SEO fields
  - Has `company_display_name`, analytics_id, configuration JSON
  - Could benefit from: site description, meta tags template, SEO settings

- **Pwb::Page** (`db/schema.rb`)
  - Has `slug` field (good for URLs)
  - Has `translations` JSONB column for multi-locale support
  - Missing: meta_description, meta_keywords fields

- **Pwb::RealtyAsset** (UUID-based property asset)
  - Has basic property data
  - No SEO-specific fields

#### Controllers Setting Page Titles:
- **PropsController** (`app/controllers/pwb/props_controller.rb` lines 19, 42)
  ```ruby
  @page_title = @property_details.title
  @page_description = @property_details.description
  ```

- **WelcomeController** (`app/controllers/pwb/welcome_controller.rb` lines 9, 14)
  ```ruby
  @page_title = @current_agency.company_name
  @page_title = @page.page_title + ' - ' + @current_agency.company_name
  ```

- **PagesController** (inferred from routes, not fully reviewed)

#### Helpers:
- **ApplicationHelper** - Basic `page_title` helper (line 11-13), no SEO-specific helpers
- **NavigationHelper** - For site navigation (no SEO relevance)
- **CssHelper** - For styling (no SEO relevance)
- **SearchUrlHelper** - Might be relevant for URL generation

---

### 7. Head Section / Meta Tag Infrastructure

#### Current Implementation:
- **Layout:** `app/themes/default/views/layouts/pwb/application.html.erb`
- **Yield blocks:**
  - `<%= yield(:page_title) %>` - Page title
  - `<%= yield(:page_head) %>` - Custom head content
  - `<%= yield(:page_script) %>` - Footer scripts

- **Meta tag partials:**
  - `app/views/pwb/_meta_tags.html.erb` - General page images
  - `app/views/pwb/props/_meta_tags.html.erb` - Property-specific images

#### Pattern for Adding Meta Tags:
```erb
<% content_for :page_head do %>
  <meta property="og:image" content="..." />
<% end %>
```

#### Missing Infrastructure:
- No centralized meta tag management
- No helper method for consistent og: tag generation
- No twitter: card support
- No structured data builder
- No multi-locale alternate link support (`hreflang`)

---

### 8. SEO Gems and Dependencies

#### Gemfile Analysis:
- **No SEO-specific gems found**
- Checked for common SEO gems:
  - `sitemap_generator` - NOT installed
  - `meta-tags` - NOT installed (commented out in one layout)
  - `json-ld` - NOT installed
  - `seo_helper` - NOT installed

#### Existing Relevant Gems:
- **Mobility** (`~> 1.0`) - Multi-language/locale support
- **Acts as Tenant** (`~> 1.0`) - Multi-tenancy, important for SEO scoping
- **Cloudinary** (`~> 1.23`) - Image optimization
- **Pagy** (`~> 9.0`) - Pagination (important for pagination rel links)

---

### 9. Multi-Tenancy Impact on SEO

#### Considerations Found:
- **Acts as Tenant gem** in use for database-level scoping
- **Pwb::Website** as tenant model
- **Routes with subdomain handling** (inferred from routes structure)
- **Each website has separate**: pages, properties, analytics configuration, custom styles

#### SEO Implications:
- Sitemap must be per-website
- Robots.txt must be per-website or wildcard
- Analytics tracking must be per-website (already done via `analytics_id`)
- Canonical URLs must respect tenant boundaries
- Schema.org markup must include website-specific data

---

### 10. Current SEO Configuration

#### Website Model Configuration:
```ruby
# From db/schema.rb - pwb_websites table
t.json "configuration", default: {}
t.json "style_variables_for_theme", default: {}
t.json "search_config_rent", default: {}
t.json "search_config_buy", default: {}
t.json "search_config_landing", default: {}
t.json "admin_config", default: {}
t.json "styles_config", default: {}
```

- No dedicated SEO configuration section
- Could store: site description, keywords, brand name, etc.

#### Analytics Setup:
- **analytics_id** field exists in both Agencies and Websites tables
- **analytics_id_type** field suggests support for different analytics (GA, etc.)
- Good foundation for integrating Google Search Console

---

## Summary Table: SEO Feature Coverage

| Feature | Status | Location | Notes |
|---------|--------|----------|-------|
| **Page Titles** | ✅ Partial | Controllers, Layouts | Only set in some controllers |
| **Meta Descriptions** | ❌ Missing | — | Not implemented anywhere |
| **Meta Keywords** | ❌ Missing | — | Not implemented (deprecated anyway) |
| **OG:title** | ❌ Missing | — | Not in any property/page rendering |
| **OG:description** | ❌ Missing | — | Not in any property/page rendering |
| **OG:image** | ✅ Partial | `/pwb/props/_meta_tags.html.erb` | Only images, incomplete |
| **OG:url** | ❌ Missing | — | No canonical URL implementation |
| **OG:type** | ❌ Missing | — | Not set for any pages |
| **Twitter Cards** | ❌ Missing | — | No twitter: tags anywhere |
| **Canonical URLs** | ❌ Missing | — | Duplicate URL issues exist |
| **Robots.txt** | ⚠️ Incomplete | `/public/robots.txt` | File exists, no actual directives |
| **Sitemap XML** | ❌ Missing | — | No generator or routes |
| **JSON-LD Schema** | ❌ Missing | — | No structured data |
| **Breadcrumb Schema** | ❌ Missing | — | Not implemented |
| **LocalBusiness Schema** | ❌ Missing | — | Not implemented |
| **Property/RealEstate Schema** | ❌ Missing | — | Not implemented |
| **Hreflang Tags** | ❌ Missing | — | Multi-locale but no alternate links |
| **Pagination rel="next/prev"** | ❌ Missing | — | Pagy gem used but no implementation |
| **Mobile-friendly Meta** | ✅ Yes | Default layout | Viewport tag present |
| **Charset** | ✅ Yes | Default layout | UTF-8 specified |
| **Analytics Integration** | ✅ Partial | Database fields | Infrastructure exists, not in views |
| **URL Rewriting** | ✅ Yes | Routes | Clean URLs for properties/pages |
| **Multi-language Support** | ✅ Yes | Mobility gem | Full translation support |

---

## Critical Issues for SEO

### Issue 1: Duplicate Property URLs
**Severity:** HIGH
- Properties accessible via both ID and slug
- No canonical URL to indicate preferred version
- Same property visible at different URLs

### Issue 2: Missing Structured Data
**Severity:** HIGH
- No Schema.org markup for properties
- Google can't understand property details
- Reduces search result quality/appearance

### Issue 3: No Sitemap
**Severity:** HIGH
- Search engines must crawl to discover properties
- Inefficient for large catalogs
- Multi-tenant setup needs dynamic sitemaps

### Issue 4: Incomplete Meta Tags
**Severity:** MEDIUM
- Missing og:description, og:type, og:url
- No Twitter card support
- Poor social media sharing experience

### Issue 5: No Robots.txt Rules
**Severity:** MEDIUM
- Search engines have no crawling guidance
- Could crawl unnecessary pages
- No sitemap reference

---

## Opportunities & Recommendations

### Phase 1: Quick Wins (1-2 weeks)
1. **Enhance Page Titles**
   - Add page title to all controller actions
   - Ensure proper format: "Property Address - Company Name"

2. **Add Meta Descriptions**
   - Add `meta_description` field to Prop and Page models
   - Render in all layouts (155-160 chars limit)

3. **Implement Open Graph Tags**
   - Create helper method for consistent og: tag generation
   - Add og:title, og:description, og:type, og:url

4. **Twitter Card Support**
   - Add twitter:card, twitter:title, twitter:description, twitter:image
   - Mirror from OG tags where applicable

5. **Fix robots.txt**
   - Add basic Allow/Disallow rules
   - Add future sitemap reference
   - Make dynamic per website if needed

### Phase 2: Structured Data (2-3 weeks)
1. **JSON-LD Implementation**
   - Create SchemaGenerator service for each content type
   - Property schema with all listing details
   - LocalBusiness/Organization schema for homepage
   - BreadcrumbList schema for navigation

2. **Canonical URL Tags**
   - Implement `rel="canonical"` for properties (prefer slug over ID)
   - Handle multi-language canonicals

3. **Hreflang Tags**
   - Multi-language alternate links
   - Important with Mobility gem's locale support

### Phase 3: Sitemap Generation (2-3 weeks)
1. **Dynamic Sitemap**
   - Install `sitemap_generator` gem or custom implementation
   - Separate sitemaps for:
     - Properties (by visibility/status)
     - Pages
     - Sitemaps index for multi-tenant setup

2. **Sitemap Update Strategy**
   - Regenerate on property/page changes
   - Consider Sidekiq/background job

3. **Robots.txt Integration**
   - Link to sitemap location

### Phase 4: Advanced SEO (3-4 weeks)
1. **Admin Panel for SEO Settings**
   - Website-level SEO configuration
   - Per-page/property SEO overrides
   - Meta tag templates

2. **SEO Audit Dashboard**
   - Missing meta descriptions
   - Duplicate titles
   - Missing images
   - Page performance metrics

3. **Google Search Console Integration**
   - Verification methods
   - Sitemap submission
   - Performance monitoring

---

## Implementation Checklist

### Database Migrations Needed:
```ruby
# Add to Pwb::Prop and Pwb::Page models
t.text :meta_description, limit: 160
t.text :meta_keywords  # Optional, deprecated
t.boolean :noindex, default: false
t.boolean :nofollow, default: false

# Add to Pwb::Website for SEO configuration
t.json :seo_settings, default: {}  # Store defaults and rules
```

### Files to Create/Modify:
1. **New File:** `app/services/seo/schema_generator.rb`
2. **New File:** `app/helpers/seo_helper.rb`
3. **New File:** `app/controllers/sitemaps_controller.rb` (optional)
4. **Modify:** All theme layouts to include new meta tags
5. **Modify:** Property and Page controllers to set descriptions
6. **Modify:** `public/robots.txt` to be dynamic/templated
7. **Modify:** Gemfile (add sitemap_generator if needed)

---

## References & Standards

- [Open Graph Protocol](https://ogp.me/)
- [Twitter Card Documentation](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/abouts-cards)
- [Schema.org Documentation](https://schema.org/)
- [Google Search Central SEO Guide](https://developers.google.com/search/docs)
- [XML Sitemap Protocol](https://www.sitemaps.org/)
- [RFC 7231 - Web Linking](https://tools.ietf.org/html/rfc7231#section-3.2.2)

---

## Multi-Tenant SEO Considerations

Since PropertyWebBuilder is a multi-tenant SaaS:

1. **Sitemap per tenant** - Each website should have its own sitemap
2. **Robots.txt per domain** - If using custom domains, each gets its own rules
3. **Analytics per tenant** - Already implemented via `analytics_id` field
4. **Schema brand info** - Each website has its own company_name, needs in markup
5. **Isolation** - Use `Pwb::Current.website` for all SEO scoping

---

## Files Examined

- `/Gemfile` - No SEO gems found
- `/public/robots.txt` - Minimal implementation
- `/app/themes/default/views/layouts/pwb/application.html.erb` - Main layout
- `/app/themes/*/views/pwb/props/show.html.erb` - Property view
- `/app/views/pwb/_meta_tags.html.erb` - General meta tags partial
- `/app/views/pwb/props/_meta_tags.html.erb` - Property meta tags
- `/app/controllers/pwb/props_controller.rb` - Property controller
- `/app/controllers/pwb/welcome_controller.rb` - Homepage controller
- `/app/helpers/pwb/application_helper.rb` - Application helpers
- `/db/schema.rb` - Database schema
- `/config/routes.rb` - Route definitions
- `/app/models/pwb/*.rb` - Various models

---

**Report Status:** COMPLETE  
**Next Steps:** Review with team and prioritize implementation phases
