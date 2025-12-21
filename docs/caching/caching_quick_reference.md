# Caching Quick Reference Guide

## Current Cache Usage

### ApplicationController
```ruby
# app/controllers/pwb/application_controller.rb

footer_content_cache_key = "footer_content/{website_id}/{updated_at}"
nav_admin_link_cache_key = "nav_admin_link/{website_id}/{updated_at}"
# TTL: 5 minutes
```

### SearchController
```ruby
# app/controllers/pwb/search_controller.rb

facets_cache_key = "search_facets/{website_id}/{operation_type}/{locale}/{updated_at}"
# TTL: 5 minutes
```

### PagePart Model
```ruby
# app/models/pwb/page_part.rb

template_cache_key = "page_part/{id}/{page_part_key}/{theme_name}/template"
# TTL: 5 seconds (dev), 1 hour (prod)
# Auto-invalidated on save/destroy
```

### Firebase Token Verifier
```ruby
# app/services/pwb/firebase_token_verifier.rb

cache_key = "firebase/google_certificates"
# TTL: 1 hour (respects Google's cache-control header)
```

## Cache Configuration

### Production
- **Cache Store:** Not explicitly configured (defaults to in-memory)
- **Fragment Caching:** Enabled
- **Asset Caching:** 1 year (digest-stamped files)

**TODO:** Add to production config:
```ruby
config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL') }
```

### Development
- **Cache Store:** `:memory_store`
- **Fragment Caching:** Toggle with `rails dev:cache`
- **Asset Caching:** 2 days
- **N+1 Detection:** Bullet gem active

## Materialized View System

### ListedProperty (Read-Only View)
```ruby
# app/models/pwb/listed_property.rb

# Denormalizes:
# - pwb_realty_assets
# - pwb_sale_listings
# - pwb_rental_listings

# Refresh on writes:
Pwb::ListedProperty.refresh(concurrently: true)
```

### Eager Loading Scope
```ruby
.with_eager_loading  # includes(:website, :prop_photos)
```

### View Definition
```sql
-- db/views/pwb_properties_v03.sql
-- Denormalized search view with indexes on common filters
```

## Key Scopes & Eager Loading

```ruby
# Search Controller
@properties = @current_website.listed_properties
  .with_eager_loading
  .visible
  .for_sale
  .limit(45)

# Feature Search (with AND logic)
ListedProperty.with_features(['features.pool', 'features.sea_views'])

# Feature Search (with OR logic)
ListedProperty.with_any_features(['features.pool', 'features.sea_views'])
```

## Cache Invalidation Patterns

### Timestamp-Based (Most Keys)
```ruby
# Cache invalidates when website.updated_at changes
cache_key = "footer_content/#{website_id}/#{website.updated_at.to_i}"
```

### Explicit Deletion
```ruby
# PagePart - explicit cache deletion on save/destroy
after_save :clear_template_cache

def clear_template_cache
  Rails.cache.delete(cache_key)
end
```

### View Refresh (Materialized View)
```ruby
# RealtyAsset - refresh view after commits
after_commit :refresh_properties_view

def refresh_properties_view
  Pwb::ListedProperty.refresh
end
```

## Performance Monitoring

### Rails Performance Dashboard
```
URL: /rails/performance
Data: Request times, slow endpoints, query counts
Storage: Redis (7-day retention)
```

### Bullet Gem (Development)
```
Status: Enabled
Output: Console logs + HTML footer
Detects: N+1 queries, unused eager loading
```

## Multi-Tenancy Cache Keys

All cache keys include `website_id`:
- `footer_content/{website_id}/{timestamp}`
- `nav_admin_link/{website_id}/{timestamp}`
- `search_facets/{website_id}/{operation_type}/{locale}/{timestamp}`

Analytics scoped to tenant:
- Ahoy visits include `website_id`
- Rails Performance tracks tenant context

## Cache Expiration Times

| Component | TTL | Notes |
|-----------|-----|-------|
| Page Parts | 5s (dev), 1h (prod) | Explicit invalidation |
| Footer | 5 minutes | Timestamp-based |
| Nav Links | 5 minutes | Timestamp-based |
| Search Facets | 5 minutes | Timestamp-based |
| Firebase Certs | 1 hour | HTTP header override |
| Assets | 1 year | Digest fingerprinted |

## HTTP Headers (Current)

```ruby
# Assets (both dev/prod)
cache-control: "public, max-age=#{expiry}"

# Dynamic Pages
# (No explicit cache-control set - uses defaults)
```

## Missing Implementations

1. **Fragment Caching in Views** - No `<% cache do %>` blocks found
2. **ETag Support** - No fresh_when/stale_if_any usage
3. **Redis as Primary Store** - Not explicitly configured
4. **Async View Refresh** - Currently synchronous
5. **Response Caching** - No caching of entire API responses
6. **Cache Warming** - No pre-population on deploy

## Useful Commands

```ruby
# View cache contents (Rails console)
Rails.cache.read("footer_content/1/1234567890")

# Clear specific cache
Rails.cache.delete("footer_content/1/1234567890")

# Clear all caches
Rails.cache.clear

# Check cache store type
Rails.cache.class

# Toggle dev caching
rails dev:cache

# View performance dashboard
# Visit /rails/performance in browser
```

## Files to Check for Cache Issues

1. **View Fragments:** `app/views/**/*.erb` - Look for repeated rendering
2. **Controllers:** `app/controllers/pwb/**/*.rb` - Check for expensive queries
3. **Models:** `app/models/pwb/**/*.rb` - Check eager loading
4. **Services:** `app/services/pwb/**/*.rb` - Check for expensive computations
