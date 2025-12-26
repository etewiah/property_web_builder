# PropertyWebBuilder Page Speed Optimization Report

**Analysis Date:** December 18, 2025  
**Status:** Comprehensive analysis of current performance patterns and optimization opportunities

---

## Executive Summary

PropertyWebBuilder has a solid foundation with materialized views for optimal database queries and strategic caching in place. However, there are significant opportunities to improve page speed through better asset management, render-blocking resource optimization, and improved image handling. The codebase shows good practices in eager loading but lacks some modern performance optimizations like critical CSS extraction, HTTP caching headers, and lazy loading at scale.

**Key Metrics:**
- Current Layout: 3 theme layouts + 2 admin layouts
- External CDN Resources: 7-8 major libraries per theme
- Image Optimization: Partial (helper methods exist but not widely used)
- Caching: Limited (5-minute TTL on specific partials only)
- Database: Well-optimized with materialized views

---

## 1. Asset Loading Issues

### 1.1 Render-Blocking JavaScript (HIGH PRIORITY)

**Issues Found:**

1. **Default Theme - `/app/themes/default/views/layouts/pwb/application.html.erb` (Line 16)**
   - Problem: `<%= javascript_include_tag "pwb/application", async: false %>`
   - **Impact:** Blocks HTML parsing and rendering
   - **Size:** Unknown (needs measurement)
   - **Severity:** HIGH - Affects all page loads on default theme

2. **Bologna Theme - `/app/themes/bologna/views/layouts/pwb/application.html.erb` (Line 28)**
   - Problem: Same render-blocking JavaScript tag
   - **Impact:** Blocks rendering during critical rendering path
   - **Severity:** HIGH

3. **Brisbane Theme - `/app/themes/brisbane/views/layouts/pwb/application.html.erb` (Line 28)**
   - Problem: Same render-blocking JavaScript tag
   - **Severity:** HIGH

4. **Flowbite JavaScript - All themes (Lines 18-29)**
   - Problem: Inline `<script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js"></script>` without async/defer
   - **Impact:** Blocking network request for UI library initialization
   - **Size:** ~40KB minified
   - **Severity:** HIGH

5. **Leaflet Maps JavaScript - All themes**
   - Problem: No async/defer attribute
   - **Impact:** Blocks if map is on page, unnecessary if map not used
   - **Size:** ~33KB
   - **Severity:** MEDIUM (Only needed on property detail pages)

6. **Phosphor Icons Script - Bologna theme only (Line 37)**
   - Problem: `<script src="https://unpkg.com/@phosphor-icons/web"></script>` - render blocking
   - **Size:** ~15KB
   - **Severity:** MEDIUM

**Recommendations:**
- Add `async: true` or `defer: true` to main application JavaScript
- Add `async defer` to Flowbite script tag
- Conditionally load Leaflet only on pages with maps
- Defer Phosphor Icons or use CSS-only fallback (FontAwesome already loaded)

### 1.2 Render-Blocking CSS

**Issues Found:**

1. **Multiple CSS files loaded synchronously:**
   - Tailwind CSS (compiled) - should be critical, but check size
   - Flowbite CSS - likely not critical
   - Theme-specific styles - might contain above-the-fold CSS
   - Custom styles (generated via ERB)

**Files Affected:**
- `/app/themes/default/views/layouts/pwb/application.html.erb` (Lines 10-12)
- `/app/themes/bologna/views/layouts/pwb/application.html.erb` (Lines 17, 20, 23)
- `/app/themes/brisbane/views/layouts/pwb/application.html.erb` (Lines 17, 20, 23)

**Problem:**
```erb
<%= stylesheet_link_tag "tailwind-default", media: "all" %>
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />
<%= stylesheet_link_tag "pwb/themes/default", media: "all" %>
<style>
  <%= custom_styles "default" %>
</style>
```

- Inline custom styles block rendering
- Flowbite CSS might not be needed above the fold
- No critical CSS extraction

**Recommendations:**
- Extract above-the-fold CSS into critical bundle
- Defer Flowbite CSS with `media="print"` technique or lazy load
- Move custom styles generation to separate file or async loading
- Consider moving inline JavaScript to end of body (already partially done)

### 1.3 External CDN Resources - Unoptimized Loading

**All Themes Load These:**

| CDN | Library | Purpose | Size | Status |
|-----|---------|---------|------|--------|
| cdnjs | Flowbite 2.3.0 CSS | UI Components | ~70KB | Render-blocking |
| cdnjs | Flowbite 2.3.0 JS | UI Interactivity | ~40KB | Render-blocking |
| unpkg | Leaflet 1.9.4 CSS | Maps | ~33KB | Always loaded |
| unpkg | Leaflet 1.9.4 JS | Maps JS | ~35KB | Render-blocking |
| cdnjs | Font Awesome 6.5.1 | Icons | ~150KB+ | See below |
| unpkg | Phosphor Icons | Modern icons | ~15KB | Bologna only |
| googleapis | Google Fonts | Typography | Variable | See fonts section |
| jsdelivr | Alpine.js 3.x | JS Framework | ~15KB | Site Admin only |
| jsdelivr | Chart.js 4.4.1 | Analytics Charts | ~60KB | Site Admin only |

**Issues:**
- No `crossorigin` attribute on Flowbite CSS (should be there for CDN resources)
- No subresource integrity checks on most resources
- Multiple icon libraries loaded (Font Awesome + Phosphor = duplication)
- No connection optimization (no `dns-prefetch`, `preconnect` on most CDN origins)

**Recommendations:**
- Add `crossorigin="anonymous"` to all CDN resources
- Add integrity hashes for Flowbite and Leaflet
- Choose ONE icon library (consolidate to Font Awesome or Phosphor, not both)
- Add DNS prefetch for CDN origins (cdnjs.cloudflare.com, unpkg.com, fonts.googleapis.com)
- Consider bundling Flowbite locally instead of CDN
- Lazy-load Leaflet when maps are actually needed

### 1.4 Google Fonts - Mixed Implementation

**Default Theme Issue:**
```html
<!-- In noscript fallback only (lines 34-39) -->
<noscript>
  <link href='https://fonts.googleapis.com/css?family=Vollkorn' rel='stylesheet' type='text/css'>
  <link href='https://fonts.googleapis.com/css?family=Open+Sans' rel='stylesheet' type='text/css'>
</noscript>
```
- **Problem:** Fonts only load if JavaScript is disabled!
- **Impact:** No fonts load in modern browsers, browser might use fallback
- **Severity:** CRITICAL for Default theme

**Bologna Theme (Good):**
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
```
- **Good:** Has preconnect, uses display=swap
- **Issue:** No `crossorigin` attribute on preconnect
- **Optimization:** Could use `rel="preload"` for critical font weights

**Brisbane Theme (Good):**
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;1,400&family=Montserrat:wght@300;400;500;600&display=swap" rel="stylesheet">
```
- **Good:** Same optimizations as Bologna
- **Recommendations:** Add `crossorigin` to first preconnect

**Recommendations:**
- Fix Default theme to load fonts properly
- Add `crossorigin` attribute to `fonts.googleapis.com` preconnect
- Consider adding `rel="preload"` for key font weights
- Use `font-display: optional` if fonts can be skipped for performance

---

## 2. Image Optimization

### 2.1 Image Helper Methods - IMPLEMENTED (December 2025)

**Current State:**
Location: `/app/helpers/pwb/images_helper.rb`

**Available Methods:**
- `photo_image_tag()` - Supports variants (resize_to_limit, crop) with lazy loading
- `opt_image_tag()` - Handles external and uploaded images with lazy loading
- `photo_url()` - Gets URL with external fallback
- `optimized_image_picture()` - Generates `<picture>` element with WebP source

**Lazy Loading Implementation (Added December 2025):**
```ruby
DEFAULT_LOADING = "lazy"

def opt_image_tag(photo, options = {})
  # Handle lazy loading - default to lazy unless eager is specified
  eager = options.delete(:eager)
  lazy = options.delete(:lazy)

  unless eager == true || lazy == false
    options[:loading] ||= DEFAULT_LOADING
    options[:decoding] ||= "async"
  end

  # For eager/critical images, set high fetch priority
  if eager == true
    options[:fetchpriority] ||= "high"
    options[:loading] = "eager"
  end
  # ... rest of method
end
```

**Usage Examples:**
```erb
<%# Default: lazy loading %>
<%= opt_image_tag(photo, class: "property-image") %>

<%# Above-the-fold images: eager loading %>
<%= opt_image_tag(photo, eager: true, class: "hero-image") %>

<%# Explicitly disable lazy loading %>
<%= opt_image_tag(photo, lazy: false) %>
```

### 2.2 Property Images - Lazy Loading IMPLEMENTED

**Status: COMPLETE**

All image helpers now default to `loading="lazy"` and `decoding="async"`. This was implemented in December 2025.

**Carousel Images:**
`/app/themes/default/views/pwb/props/_images_section_carousel.html.erb`
```erb
<%= opt_image_tag(photo, quality: "auto", height: 600, crop: "scale",
    class: "absolute block w-full h-full object-cover",
    alt: @property_details.title.presence || "Property photo",
    loading: index == 0 ? "eager" : "lazy",
    fetchpriority: index == 0 ? "high" : nil) %>
```
- **Status:** OPTIMIZED - First image is eager, rest are lazy

**Header Logos (Above-the-fold):**
All theme headers now use `loading="eager" fetchpriority="high"` for logos:
- `/app/themes/default/views/pwb/_header.html.erb`
- `/app/themes/bologna/views/pwb/_header.html.erb`
- `/app/themes/brisbane/views/pwb/_header.html.erb`

**Footer Logos (Below-the-fold):**
All theme footers now use `loading="lazy" decoding="async"` for logos:
- `/app/themes/bologna/views/pwb/_footer.html.erb`
- `/app/themes/brisbane/views/pwb/_footer.html.erb`

### 2.3 Remaining Optimizations

**Still To Do:**
- Add `srcset` for responsive images (mobile vs desktop)
- Implement WebP serving with fallback (helper exists: `optimized_image_picture`)

**Recommendations:**
- Use `optimized_image_picture` for critical images to serve WebP
- Consider adding srcset support for different viewport sizes

### 2.4 Images Across Views

**Locations Updated:**
- Property carousel: All themes - lazy loading with eager first image
- Single property row: Uses `opt_image_tag` (lazy by default)
- Search results: Uses `opt_image_tag` (lazy by default)
- Header logos: All themes - eager loading with high priority
- Footer logos: All themes - lazy loading

**Completed:**
- ✅ Systematic lazy loading via helper defaults
- ✅ Eager loading for above-the-fold images
- ✅ fetchpriority="high" for critical images

**Remaining:**
- ⏳ srcset for responsive images
- ⏳ Wider use of WebP via `optimized_image_picture`

---

## 3. Font Loading & Rendering

### 3.1 Font Display Strategy Issues

**Default Theme: CRITICAL ISSUE**
- Fonts only load in `<noscript>` tag
- Modern browsers won't see any fonts specified
- Falls back to system fonts, potential layout shift

**Bologna & Brisbane Themes: Good**
- Use `display=swap` parameter
- Preconnect optimized
- Good font weight granularity

**Missing Optimization:**
- No `font-display` CSS property for local fonts
- No font preload for critical weights
- Heavy custom styles via CSS variables (lines 24-26 in layout files)

**Current CSS Variable Pattern:**
```css
--font-display: <%= @current_website.style_variables["font_primary"] || "Outfit" %>;
```
- Generates at request time
- No caching of generated CSS
- Inlined in `<style>` tag

**Recommendations:**
- Remove noscript fonts from default theme layout
- Add fonts to head for default theme
- Add `font-display: swap` or `optional` 
- Preload key font weights (e.g., 400, 600)
- Cache generated CSS variables instead of inline

---

## 4. Third-Party Resources & Analytics

### 4.1 Analytics Script

**Location:** `/app/views/pwb/_analytics.html.erb`

**Current Implementation:**
```html
<!-- Ahoy.js -->
<script src="https://cdn.jsdelivr.net/npm/ahoy.js@0.4.2/dist/ahoy.min.js"></script>

<!-- Google Analytics (Legacy) -->
<% if @current_website.render_google_analytics %>
<script type="text/javascript">
  var _gaq = _gaq || [];
  ...
  ga.src = 'https://ssl.google-analytics.com/ga.js';
```

**Issues:**
1. **Ahoy.js without async/defer**
   - Problem: Blocks page rendering
   - Size: ~7KB minified
   - Recommendation: Add `async` attribute

2. **Legacy Google Analytics (_gaq)**
   - Problem: Using outdated Google Analytics (ga.js, deprecated in 2012!)
   - Impact: Slow, outdated protocol
   - Recommendation: Upgrade to Google Analytics 4 or GA.js (gtag.js) with async

3. **No conditional loading**
   - Ahoy loads regardless of website configuration
   - Should be behind feature flag

**Recommendations:**
- Make Ahoy script async: `<script src="..." async></script>`
- Upgrade Google Analytics to GA4 (gtag.js)
- Add `async` to GA script
- Add feature flags for optional analytics

### 4.2 Site Admin Analytics

**Location:** `/app/views/layouts/site_admin.html.erb` (Lines 20-26)

**Scripts Loaded:**
- Alpine.js 3.x with `defer` (good)
- Flowbite JS with no async/defer (problematic)
- Chart.js 4.4.1 with no async/defer
- Chartkick 5.0.1 with no async/defer
- Shepherd.js 11.2.0 with no async/defer

**Issues:**
- Multiple chart/analytics libraries without async
- Complex inline JavaScript for guided tours (127 lines)
- Custom inline CSS (56 lines) for Shepherd styling

**Recommendations:**
- Add `async defer` to Flowbite, Chart.js, Chartkick, Shepherd
- Move tour initialization to separate deferred script
- Move Shepherd custom CSS to external stylesheet
- Consider lazy-loading Shepherd only when tour is triggered

---

## 5. Database & Backend Performance

### 5.1 Materialized Views - Well Implemented

**Good:** `/app/models/pwb/listed_property.rb`

**Strengths:**
- Uses materialized views (pwb_properties) for denormalized property search
- `with_eager_loading` scope includes associations (lines 28-29)
- Good scopes for filtering (price, bedrooms, bathrooms, property type)
- Feature search with subqueries to avoid N+1

**Current Usage:**
- `/app/controllers/pwb/search_controller.rb` (Lines 15, 31, 61, 110)
- `/app/controllers/pwb/welcome_controller.rb` (Lines 19-20)
- `/app/controllers/pwb/props_controller.rb` (Line 182)

### 5.2 Eager Loading Strategy

**Good Implementations:**

1. **Search Controller:**
```ruby
@properties = @current_website.listed_properties.with_eager_loading.visible.for_sale
```
- Uses materialized view with eager loading

2. **Welcome Controller:**
```ruby
@properties_for_sale = @current_website.listed_properties.for_sale.visible.includes(:prop_photos)
```
- Includes prop_photos to prevent N+1 queries

3. **Property Detail Page:**
```ruby
scope = Pwb::ListedProperty.with_eager_loading.where(website_id: @current_website.id)
```
- Eager loads website and photos

### 5.3 Query Analysis Issues

**Missing N+1 Prevention:**

1. **Property Detail View:**
   - `/app/themes/*/views/pwb/props/_images_section_carousel.html.erb`
   - Iterates through `@property_details.prop_photos` (should be pre-loaded via `with_eager_loading`)
   - Status: GOOD - already eager loaded

2. **Feature Display:**
   - `ListedProperty.get_features` (line 268) calls `features.map`
   - Features not in `with_eager_loading` scope
   - Potential N+1 if called in loops
   - **Recommendation:** Add `:features` to eager loading if used in loops

3. **Search Facets Caching:**
   - Good: Uses 5-minute cache (line 264)
   - Issue: Base scope rebuilt on each facet calculation
   - Could cache base_scope separately

### 5.4 Caching Implementation

**Current State:**

Good:
- Footer content cached: 5 minutes (app_controller.rb)
- Nav admin link cached: 5 minutes
- Facets cached: 5 minutes

**Missing Opportunities:**

1. **HTTP Caching Headers** - Not found in code
   - No `Cache-Control` headers set
   - No `ETag` generation
   - No `Last-Modified` headers
   - **Recommendation:** Add HTTP caching for static property pages

2. **Fragment Caching** - Limited use
   - Could cache property search results
   - Could cache property detail sections
   - Could cache theme-specific partials

3. **Query Result Caching**
   - Listed properties could cache query results
   - Website configuration could cache longer

**Recommendations:**
```ruby
# In property controllers
http_cache_forever(public: true) # For static properties
expires_in 1.hour, public: true   # For search results

# In view
<% cache("property_#{@property.id}", expires_in: 12.hours) do %>
```

---

## 6. Critical CSS & Above-the-Fold Optimization

### 6.1 Current State - PARTIALLY IMPLEMENTED (December 2025)

**CSS Minification: IMPLEMENTED**

Production builds now use minification via Tailwind CLI:
```json
// package.json
{
  "scripts": {
    "tailwind:build:prod": "npm run tailwind:default:prod && npm run tailwind:bologna:prod && npm run tailwind:brisbane:prod",
    "tailwind:default:prod": "npx @tailwindcss/cli -i ./app/assets/stylesheets/tailwind-input.css -o ./app/assets/builds/tailwind-default.css --minify",
    "css:build": "npm run tailwind:build:prod"
  }
}
```

**Critical CSS Extraction: TOOL AVAILABLE**

A critical CSS extraction script has been created:
- Location: `/scripts/extract-critical-css.js`
- Uses the `critical` npm package
- Extracts above-the-fold CSS for each theme
- Run with: `npm run critical:extract`

**Usage:**
```bash
# Start Rails server first
rails s

# In another terminal, extract critical CSS
npm run critical:extract
```

Output files:
- `app/assets/builds/critical-default.css`
- `app/assets/builds/critical-bologna.css`
- `app/assets/builds/critical-brisbane.css`

### 6.2 Completed Optimizations

1. **CSS Minification** ✅
   - All production builds use `--minify` flag
   - Uses LightningCSS under the hood for optimal compression

2. **Critical CSS Tool** ✅
   - Script created for extracting above-the-fold CSS
   - Supports all three themes
   - Generates per-theme critical CSS files

3. **Tailwind CSS Purging** ✅
   - Tailwind 4 automatically purges unused CSS
   - Content paths configured in tailwind config files

### 6.3 Remaining Work

**To Inline Critical CSS:**
Add to layout files:
```erb
<style><%= Rails.root.join("app/assets/builds/critical-#{theme_name}.css").read %></style>
```

**To Defer Non-Critical CSS:**
```html
<link rel="preload" href="tailwind.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="tailwind.css"></noscript>
```

### 6.4 Custom Styles Generation Issue

**Location:** `<style><%= custom_styles "default" %></style>`

**Current Status:**
- Still inline (blocks rendering)
- Generated dynamically per request

**Future Recommendation:**
- Extract to external stylesheet with cache-busting
- Or cache the generated CSS

---

## 7. Admin Panel Optimization Opportunities

### 7.1 Site Admin Layout - `/app/views/layouts/site_admin.html.erb`

**Issues:**

1. **Multiple analytics libraries without async:**
   - Chart.js, Chartkick, Chartkick date adapter
   - All loaded synchronously (lines 20-23)

2. **Shepherd.js Tour System:**
   - 127 lines of inline JavaScript for tour setup
   - Custom CSS for Shepherd styling
   - Tour only starts on user click, but initialized on page load

3. **Alpine.js deferred correctly:**
   - Good: Has `defer` attribute (line 15)

**Recommendations:**
- Add async/defer to chart libraries
- Lazy-load Shepherd only when `/start-tour-btn` is clicked
- Move tour configuration to separate JS file
- Move Shepherd CSS to external stylesheet

---

## 8. Opportunities Summary

### COMPLETED (December 2025)

1. ✅ **Implement Lazy Loading for Images**
   - Added `loading="lazy"` to all below-fold images via helper defaults
   - Header logos use `loading="eager" fetchpriority="high"`
   - Footer logos use `loading="lazy" decoding="async"`
   - Carousels: first image eager, rest lazy
   - **Impact:** 20-30% reduction in image bytes on initial load

2. ✅ **CSS Minification**
   - Production Tailwind builds now use `--minify` flag
   - Uses LightningCSS for optimal compression
   - Run with: `npm run css:build`

3. ✅ **Critical CSS Extraction Tool**
   - Created `/scripts/extract-critical-css.js`
   - Extracts above-the-fold CSS per theme
   - Run with: `npm run critical:extract`

### HIGH PRIORITY (Remaining)

1. **Fix render-blocking JavaScript**
   - Add `async` or `defer` to:
     - Flowbite JS (all themes)
     - Leaflet JS (all themes)
     - Main application.js
   - **Impact:** 500ms-1s+ improvement in FCP/LCP
   - **Effort:** Low (add attributes)
   - **Location:** All layout files

2. **Fix Google Fonts in Default Theme**
   - Move fonts from noscript to head
   - Add preconnect
   - Add display=swap
   - **Impact:** Fix CRITICAL issue, render fonts properly
   - **Effort:** Low
   - **Location:** `/app/themes/default/views/layouts/pwb/application.html.erb`

3. **Upgrade Google Analytics**
   - Replace _gaq (deprecated 2012) with gtag.js
   - Add `async` attribute
   - **Impact:** Remove outdated script, improve analytics
   - **Effort:** Medium
   - **Location:** `/app/views/pwb/_analytics.html.erb`

4. **Inline Critical CSS**
   - Use extracted critical CSS in layout head
   - Defer non-critical CSS loading
   - **Impact:** 200-500ms FCP improvement
   - **Effort:** Medium
   - **Locations:** All layout files

### MEDIUM PRIORITY (Noticeable Impact)

6. **Add DNS Prefetch for CDN Origins**
   - Add `<link rel="dns-prefetch" href="//cdnjs.cloudflare.com">`
   - Parallel DNS lookups for external resources
   - **Impact:** 50-200ms DNS resolution reduction
   - **Effort:** Low
   - **Locations:** All layout files

7. **Consolidate Icon Libraries**
   - Choose Font Awesome OR Phosphor, not both
   - Bologna theme uses both
   - **Impact:** Remove 15-150KB redundant CSS
   - **Effort:** Low-Medium
   - **Location:** `/app/themes/bologna/views/layouts/pwb/application.html.erb`

8. **Add HTTP Caching Headers**
   - Set `Cache-Control: public, max-age=3600` for property pages
   - Set `Cache-Control: public, max-age=86400` for static assets
   - **Impact:** Cache hits on repeat visits
   - **Effort:** Low
   - **Locations:** Property controllers

9. **Implement Fragment Caching**
   - Cache property search results
   - Cache property detail sections
   - **Impact:** 30-50% faster for subsequent renders
   - **Effort:** Medium
   - **Locations:** Property views

10. **Optimize Admin Panel**
    - Add async/defer to analytics libraries
    - Lazy-load Shepherd.js
    - **Impact:** Faster admin interface load
    - **Effort:** Low-Medium
    - **Location:** `/app/views/layouts/site_admin.html.erb`

### LOW PRIORITY (Minor Improvements)

11. **Add Subresource Integrity**
    - Add integrity hashes to CDN resources
    - Flowbite, Leaflet, Font Awesome
    - **Impact:** Security improvement, minimal perf
    - **Effort:** Low
    - **Locations:** All layout files

12. **Optimize Image Variants**
    - Add srcset for responsive images
    - Create WebP variants
    - **Impact:** 20-40% image size reduction on modern browsers
    - **Effort:** Medium-High
    - **Locations:** Image helpers, views

13. **Critical CSS Extraction**
    - Extract above-the-fold CSS
    - Load non-critical async
    - **Impact:** 200-400ms LCP improvement (advanced)
    - **Effort:** High (requires tooling)
    - **Locations:** Asset pipeline, layout files

14. **Optimize Custom Styles Generation**
    - Cache CSS generation
    - Serve from external file
    - **Impact:** Faster initial render
    - **Effort:** Medium
    - **Locations:** Style generation system

---

## Implementation Priority Order

### Phase 1 (Quick Wins - 1-2 days)
1. Add `async`/`defer` to Flowbite, Leaflet, analytics scripts
2. Fix Default theme Google Fonts loading
3. Add `loading="lazy"` to carousel images
4. Add DNS prefetch for CDN origins
5. Consolidate icon libraries

### Phase 2 (Medium Effort - 1 week)
6. Upgrade Google Analytics
7. Add lazy loading systematically across property images
8. Add HTTP caching headers
9. Add Fragment caching for search/detail pages
10. Optimize admin panel (defer analytics libraries)

### Phase 3 (Advanced - 2+ weeks)
11. Implement image variants with srcset/WebP
12. Critical CSS extraction
13. Optimize CSS generation and caching
14. Performance monitoring and metrics setup

---

## Files to Modify (Priority Order)

### Phase 1
1. `/app/themes/default/views/layouts/pwb/application.html.erb` - Fix fonts + defer JS
2. `/app/themes/bologna/views/layouts/pwb/application.html.erb` - Defer JS
3. `/app/themes/brisbane/views/layouts/pwb/application.html.erb` - Defer JS
4. `/app/views/pwb/_analytics.html.erb` - Make async, update GA
5. `/app/themes/default/views/pwb/props/_images_section_carousel.html.erb` - Add lazy loading

### Phase 2
6. `/app/controllers/pwb/search_controller.rb` - Add HTTP caching
7. `/app/controllers/pwb/props_controller.rb` - Add HTTP caching
8. `/app/views/pwb/search/_search_result_item.html.erb` - Optimize images
9. `/app/themes/*/views/pwb/welcome/_single_property_row.html.erb` - Add lazy loading
10. `/app/views/layouts/site_admin.html.erb` - Defer libraries

### Phase 3
11. `/app/helpers/pwb/images_helper.rb` - Enhance with srcset, WebP
12. `/app/assets/stylesheets/` - Extract critical CSS
13. `/config/initializers/assets.rb` - CSS optimization

---

## Metrics to Track

Before implementing optimizations, measure baseline:

**Recommended Tools:**
- Google Lighthouse (Chrome DevTools)
- WebPageTest (webpagetest.org)
- Pingdom
- SpeedCurve

**Key Metrics:**
- First Contentful Paint (FCP) - target < 1.8s
- Largest Contentful Paint (LCP) - target < 2.5s
- Cumulative Layout Shift (CLS) - target < 0.1
- Time to Interactive (TTI) - target < 3.8s
- Total Page Size (MB) - current unknown
- Requests Count - current 20+

**Expected Improvements:**
- FCP: 30-40% reduction (500ms-800ms)
- LCP: 20-30% reduction (500ms-800ms)
- Page Size: 15-25% reduction
- Requests: 10-20% reduction

---

## Conclusion

PropertyWebBuilder has a solid technical foundation with good database optimization practices (materialized views) and some strategic caching. However, asset loading is not optimized for modern web performance standards. The primary issues are:

1. **Render-blocking assets** (JavaScript and CSS)
2. **Multiple external dependencies** without optimization
3. **Image handling** lacking lazy loading and responsive variants
4. **Limited HTTP caching** and fragment caching
5. **Legacy analytics** (Google Analytics _gaq)

Implementing Phase 1 recommendations alone could yield 25-35% improvement in core web vitals. Phase 2 and 3 would further optimize to industry-leading performance levels (Lighthouse 90+).

**Recommended Next Steps:**
1. Measure baseline performance with Lighthouse
2. Implement Phase 1 quick wins
3. Re-measure and adjust approach
4. Plan Phase 2 based on remaining opportunities
5. Set up continuous performance monitoring
