# PropertyWebBuilder Caching Implementation Analysis

## Executive Summary

PropertyWebBuilder has a **moderate but strategic caching implementation** focused on the highest-impact areas. The caching strategy emphasizes:

1. **Database Query Optimization** via materialized views for property searches
2. **HTTP-level Asset Caching** with digest fingerprinting
3. **Application-level Fragment Caching** with Redis-based cache store
4. **Performance Monitoring** via Rails Performance dashboard and Bullet gem

The application is well-positioned for caching improvements, particularly in view fragment caching and multi-tier invalidation strategies.

---

## Current Caching Implementation

### 1. Production Configuration
**File:** `/config/environments/production.rb` (Lines 14-22)

```ruby
# Turn on fragment caching in view templates.
config.action_controller.perform_caching = true

# Cache assets for far-future expiry since they are all digest stamped.
config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
```

**Status:** Enabled
- Fragment caching is active in production
- Asset caching set to 1 year (files are digest-stamped)
- Cache store is NOT explicitly configured (defaults to in-memory cache store)

**Location:** `/config/environments/production.rb`

### 2. Development Configuration
**File:** `/config/environments/development.rb` (Lines 13-23)

```ruby
if Rails.root.join("tmp/caching-dev.txt").exist?
  config.action_controller.perform_caching = true
  config.action_controller.enable_fragment_cache_logging = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
else
  config.action_controller.perform_caching = false
end

config.cache_store = :memory_store
```

**Status:** Togglable via `rails dev:cache` command
- Memory store for local development
- Fragment cache logging enabled when active

**Location:** `/config/environments/development.rb`

### 3. Cache Store (Redis-based)
**File:** `/config/initializers/rails_performance.rb` (Lines 15-20)

```ruby
config.redis = Redis.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
)
```

**Status:** Redis configured but NOT as primary cache store
- Redis is used for Rails Performance dashboard
- Logster uses Redis separately (`redis://localhost:6379/0`)
- Primary cache store defaults to in-memory (needs Redis configuration)

**Improvement Needed:** Production should explicitly set:
```ruby
config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL') }
```

### 4. Asset Fingerprinting & Caching
**File:** `/config/initializers/assets.rb`

```ruby
Rails.application.config.assets.version = "1.0"

Rails.application.config.assets.precompile += %w[
  pwb_admin_panel/application_legacy_1.css
  pwb/themes/default.css
  pwb/themes/berlin.css
  default.js
  berlin.js
  pwb_admin_panel/application_legacy_1.js
  pwb/config.js
  tailwind-default.css
  tailwind-bologna.css
  tailwind-brisbane.css
]
```

**Status:** Digest fingerprinting active
- All assets are precompiled with version stamps
- Vite.js pipeline for modern JavaScript compilation
- Theme-specific CSS assets precompiled

**Location:** `/config/initializers/assets.rb`

---

## Rails.cache Usage

### 1. Page Part Template Caching
**File:** `/app/models/pwb/page_part.rb` (Lines 66-88)

```ruby
def template_content
  cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
  
  Rails.cache.fetch(cache_key, expires_in: cache_duration) do
    load_template_content
  end
end

def cache_duration
  Rails.env.development? ? 5.seconds : 1.hour
end

def clear_template_cache
  cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
  Rails.cache.delete(cache_key)
end
```

**Cache Key Pattern:** `page_part/{id}/{page_part_key}/{theme_name}/template`
**TTL:** 5 seconds (dev), 1 hour (prod)
**Invalidation:** Automatic via `after_save` and `after_destroy` callbacks

**Lines:** 66-88

### 2. Footer Content Caching
**File:** `/app/controllers/pwb/application_controller.rb` (Lines 72-77)

```ruby
def footer_content
  cache_key = "footer_content/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
  @footer_content = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    footer_page_content = current_website&.ordered_visible_page_contents&.find_by_page_part_key "footer_content_html"
    footer_page_content.present? ? footer_page_content.content : OpenStruct.new
  end
end
```

**Cache Key Pattern:** `footer_content/{website_id}/{updated_at_timestamp}`
**TTL:** 5 minutes
**Invalidation:** Website timestamp-based (invalidates on website update)
**Scope:** Per-website

**Lines:** 72-77

### 3. Navigation Admin Link Caching
**File:** `/app/controllers/pwb/application_controller.rb` (Lines 79-88)

```ruby
def nav_links
  cache_key = "nav_admin_link/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
  if current_user
    @show_admin_link = false
  else
    @show_admin_link = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      top_nav_admin_link = @current_website&.links&.find_by_slug("top_nav_admin")
      top_nav_admin_link&.visible || false
    end
  end
end
```

**Cache Key Pattern:** `nav_admin_link/{website_id}/{updated_at_timestamp}`
**TTL:** 5 minutes
**Logic:** Only cached for unauthenticated users
**Scope:** Per-website

**Lines:** 79-88

### 4. Search Facets Caching
**File:** `/app/controllers/pwb/search_controller.rb` (Lines 266-282)

```ruby
def calculate_facets
  cache_key = facets_cache_key
  
  @facets = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    base_scope = if @operation_type == "for_rent"
                   @current_website.listed_properties.visible.for_rent
                 else
                   @current_website.listed_properties.visible.for_sale
                 end
    
    SearchFacetsService.calculate(
      scope: base_scope,
      website: @current_website,
      operation_type: @operation_type
    )
  end
end

def facets_cache_key
  [
    "search_facets",
    @current_website.id,
    @operation_type,
    I18n.locale,
    @current_website.updated_at.to_i
  ].join("/")
end
```

**Cache Key Pattern:** `search_facets/{website_id}/{operation_type}/{locale}/{updated_at_timestamp}`
**TTL:** 5 minutes
**Scope:** Per-website, per-operation-type, per-locale
**Service:** `SearchFacetsService.calculate`

**Lines:** 266-282, 291-301

### 5. Firebase Certificate Caching
**File:** `/app/services/pwb/firebase_token_verifier.rb` (Lines 78-106)

```ruby
def cached_certificates
  Rails.cache.fetch(CACHE_KEY, expires_in: DEFAULT_CACHE_TTL) do
    fetch_certificates
  end
end

def fetch_certificates
  Rails.logger.info 'FirebaseTokenVerifier: Fetching certificates from Google'
  
  response = Faraday.get(CERTIFICATES_URL)
  
  # Parse cache-control header for TTL
  cache_control = response.headers['cache-control']
  if cache_control && (match = cache_control.match(/max-age=(\d+)/))
    ttl = match[1].to_i.seconds
    certificates = JSON.parse(response.body)
    Rails.cache.write(CACHE_KEY, certificates, expires_in: ttl)
    Rails.logger.info "FirebaseTokenVerifier: Cached certificates for #{ttl.to_i} seconds"
    return certificates
  end
  
  JSON.parse(response.body)
end
```

**Cache Key:** `firebase/google_certificates`
**Default TTL:** 1 hour (with HTTP Cache-Control header override)
**Logic:** Respects Google's cache-control headers for certificate freshness
**Purpose:** Firebase token verification doesn't require live cert check on every request

**Lines:** 78-106

---

## Materialized View Optimization

### 1. ListedProperty Model (Read-Only)
**File:** `/app/models/pwb/listed_property.rb`

**Purpose:** Denormalizes property search data for optimized queries
- Joins `pwb_realty_assets` + `pwb_sale_listings` + `pwb_rental_listings`
- Single table for fast searches without N+1 queries
- Read-only interface to prevent accidental writes

**Key Scopes with Eager Loading:**
```ruby
scope :with_eager_loading, -> { includes(:website, :prop_photos) }
```

**Refresh Strategy:**
```ruby
def self.refresh(concurrently: true)
  Scenic.database.refresh_materialized_view(table_name, concurrently: concurrently, cascade: false)
end
```

**Lines:** Full model spans ~400 lines

### 2. Materialized View SQL
**File:** `/db/views/pwb_properties_v03.sql`

**Denormalized Fields:**
- Physical attributes (bedrooms, bathrooms, area, etc.)
- Location data
- Sale listing data (price, availability, furnished status)
- Rental listing data (monthly price, seasonal prices, furnished status)
- Computed visibility flags
- Search-optimized pricing

**Indexes:**
```
index_pwb_properties_on_for_rent
index_pwb_properties_on_for_sale
index_pwb_properties_on_price_sale_cents
index_pwb_properties_on_price_rental_cents
index_pwb_properties_on_lat_lng
```

### 3. View Refresh Triggers
**File:** `/app/models/pwb/realty_asset.rb` (Line 84)

```ruby
after_commit :refresh_properties_view

def refresh_properties_view
  Pwb::ListedProperty.refresh
rescue StandardError => e
  Rails.logger.warn "Failed to refresh properties view: #{e.message}"
end
```

**File:** `/app/models/concerns/listing_stateable.rb`

Same pattern for SaleListing and RentalListing models.

**Invalidation Strategy:**
- Synchronous refresh after property writes
- Concurrent refresh (allows reads during refresh)
- Graceful error handling (logs warning but doesn't fail request)

---

## Query Optimization Patterns

### 1. Eager Loading in Search
**File:** `/app/controllers/pwb/search_controller.rb`

```ruby
@properties = @current_website.listed_properties.with_eager_loading.visible.for_sale.limit 45
@properties = @current_website.listed_properties.with_eager_loading.visible.for_rent.limit 45
```

**Pattern:** `.with_eager_loading` scope preloads:
- `:website`
- `:prop_photos`

**Benefit:** Prevents N+1 queries when rendering property lists

### 2. Landing Page Eager Loading
**File:** `/app/controllers/pwb/welcome_controller.rb`

```ruby
@properties_for_sale = @current_website.listed_properties.for_sale.visible
  .includes(:prop_photos).order('highlighted DESC').limit 9
@properties_for_rent = @current_website.listed_properties.for_rent.visible
  .includes(:prop_photos).order('highlighted DESC').limit 9
```

### 3. Feature Search with Subqueries
**File:** `/app/models/pwb/listed_property.rb` (Lines 154-195)

```ruby
scope :with_features, ->(feature_keys) {
  return all if feature_keys.blank?
  
  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?
  
  property_ids = PwbTenant::Feature
    .where(feature_key: feature_array)
    .group(:realty_asset_id)
    .having("COUNT(DISTINCT feature_key) = ?", feature_array.length)
    .select(:realty_asset_id)
  
  where(id: property_ids)
}
```

**Pattern:** Subquery to find matching property IDs, then filter main scope
**Avoids:** GROUP BY issues with SELECT * from the materialized view

---

## HTTP Caching Headers

### Asset Caching
**Production config** sets assets to 1-year cache:
```ruby
config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
```

**Development config** uses 2-day cache:
```ruby
config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
```

**Note:** No explicit ETag or Cache-Control headers set for dynamic pages.

---

## Performance Monitoring

### 1. Rails Performance Dashboard
**File:** `/config/initializers/rails_performance.rb`

**Features:**
- Request throughput and response times
- Slow endpoint detection
- Database query monitoring
- Custom event tracking

**Configuration:**
- 7-day data retention (168 hours)
- Ignored endpoints: health checks, assets, admin dashboards
- Custom user identification for multi-tenant context
- Redis-based storage (never sent externally)

**Dashboard Location:** `/rails/performance`

### 2. Bullet Gem (N+1 Detection)
**File:** `/config/environments/development.rb` (Lines 96-103)

```ruby
Bullet.enable        = true
Bullet.alert         = false
Bullet.bullet_logger = true
Bullet.console       = true
Bullet.rails_logger  = true
Bullet.add_footer    = true
```

**Status:** Active in development
- Logs N+1 queries to console
- Adds footer alerts to HTML responses
- Helps identify missing eager loading

### 3. Ahoy Analytics
**File:** `/config/initializers/ahoy.rb`

**Features:**
- Tenant-scoped visit tracking
- Event tracking
- Bot filtering
- IP masking for privacy

**Caching Considerations:**
- Excludes admin/site_admin paths
- Tracks via cookies (4-hour visit duration)
- Server-side bot detection

---

## Cache Invalidation Strategies in Place

### 1. Timestamp-Based Cache Keys
Most cache keys include `website.updated_at.to_i`:
- `footer_content/{website_id}/{updated_at_timestamp}`
- `nav_admin_link/{website_id}/{updated_at_timestamp}`
- `search_facets/{website_id}/{operation}/{locale}/{updated_at_timestamp}`

**Benefit:** Cache automatically invalidates when website is updated
**Limitation:** Only works if website record is touched

### 2. Explicit Cache Deletion
**PagePart model** (Line 85):
```ruby
after_save :clear_template_cache
after_destroy :clear_template_cache

def clear_template_cache
  cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
  Rails.cache.delete(cache_key)
end
```

**Benefit:** Immediate cache invalidation when page parts change

### 3. View Refresh Callbacks
**RealtyAsset model** (Line 84):
```ruby
after_commit :refresh_properties_view

def refresh_properties_view
  Pwb::ListedProperty.refresh
rescue StandardError => e
  Rails.logger.warn "Failed to refresh properties view: #{e.message}"
end
```

**Benefit:** Materialized view stays in sync with source data
**Limitation:** Synchronous refresh may add latency on property writes

---

## Summary of Caching Coverage

| Aspect | Status | Details |
|--------|--------|---------|
| **Fragment Caching** | Implemented | Page parts, footer, nav links, search facets |
| **HTTP Caching** | Partial | Assets cached 1 year; no ETag/Cache-Control for pages |
| **Query Optimization** | Strong | Materialized views + eager loading scopes |
| **Invalidation** | Good | Timestamp-based + explicit deletion + view refresh |
| **Cache Store** | Needs Config | Redis available but not explicitly configured as primary store |
| **Performance Monitoring** | Excellent | Rails Performance dashboard + Bullet gem |
| **Multi-Tenancy** | Integrated | Cache keys include website_id; Ahoy tracks by tenant |

---

## Key Areas for Improvement

### 1. **Configure Redis as Primary Cache Store (HIGH PRIORITY)**
Currently missing in production config. Add to `/config/environments/production.rb`:
```ruby
config.cache_store = :redis_cache_store, { 
  url: ENV.fetch('REDIS_URL'), 
  expires_in: 12.hours 
}
```

### 2. **Fragment Caching in Views (MEDIUM PRIORITY)**
No evidence of `<% cache do %>` blocks in view templates. Opportunities:
- Property listing cards
- Search result snippets
- Property detail sections
- Footer components

### 3. **ETag and Conditional GET (MEDIUM PRIORITY)**
Add ETags for dynamic pages:
```ruby
def property_show
  @property = Pwb::ListedProperty.find(params[:id])
  fresh_when(@property, public: true) # Sets ETag
end
```

### 4. **Async View Refresh (LOW PRIORITY)**
Current sync view refresh adds latency. Could use background job:
```ruby
def self.refresh_async
  RefreshPropertiesViewJob.perform_later
end
```

### 5. **Cache Warming (LOW PRIORITY)**
Pre-populate caches on deployment:
- Search facets for popular filters
- Firebase certificates via `Pwb::FirebaseTokenVerifier.fetch_certificates!`
- Common page parts

### 6. **Response Caching for Expensive Queries (MEDIUM PRIORITY)**
Consider caching entire responses for:
- Property search results
- Facet counts
- Featured property sections

---

## Performance Recommendations (Ordered by Impact)

1. **Redis Cache Store** - Shared cache across multiple server instances
2. **Fragment Caching in Views** - Cache expensive view rendering
3. **ETag/Conditional GET** - Reduce unnecessary full page transfers
4. **Async View Refresh** - Background job for materialized view updates
5. **HTTP Cache Headers** - Cache-Control for public pages (max-age, stale-while-revalidate)
6. **Stronger Invalidation Strategy** - Touch website on related model updates

---

## Files Reference

All caching-related files:
- `/config/environments/production.rb` - Production cache config
- `/config/environments/development.rb` - Development cache config
- `/config/initializers/rails_performance.rb` - Performance monitoring
- `/config/initializers/ahoy.rb` - Analytics config
- `/app/models/pwb/page_part.rb` - Template caching
- `/app/controllers/pwb/application_controller.rb` - Footer & nav caching
- `/app/controllers/pwb/search_controller.rb` - Facets caching
- `/app/services/pwb/firebase_token_verifier.rb` - Certificate caching
- `/app/models/pwb/listed_property.rb` - Materialized view model
- `/app/models/pwb/realty_asset.rb` - View refresh callback
- `/db/views/pwb_properties_v03.sql` - View definition
