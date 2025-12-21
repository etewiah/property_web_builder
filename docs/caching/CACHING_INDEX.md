# PropertyWebBuilder Caching Documentation Index

This directory contains a comprehensive analysis of the caching implementation in PropertyWebBuilder, including current state, opportunities for improvement, and production-ready code examples.

## Documentation Files

### 1. **CACHING_SUMMARY.txt** (Start Here)
Quick reference summary with key findings and file locations.
- **Size:** ~200 lines
- **Purpose:** Executive summary and quick lookup
- **Use When:** You need a 5-minute overview of the caching system
- **Contains:**
  - Key findings and strongest/weakest areas
  - All file locations with line numbers
  - Critical missing configuration
  - Improvement recommendations with effort estimates

### 2. **caching_analysis.md** (Comprehensive Reference)
Detailed technical analysis of all caching implementations.
- **Size:** 575 lines (~17KB)
- **Purpose:** Complete reference guide for understanding current caching
- **Use When:** You need to understand the full caching architecture
- **Contains:**
  - Current configuration (production, development)
  - All `Rails.cache.fetch` implementations
  - Materialized view system
  - Query optimization patterns
  - HTTP caching headers
  - Performance monitoring setup
  - Cache invalidation strategies
  - Summary tables
  - Improvement recommendations

### 3. **caching_quick_reference.md** (Lookup Guide)
Quick reference for cache keys, TTLs, and common operations.
- **Size:** 212 lines (~5KB)
- **Purpose:** Quick lookup while coding
- **Use When:** You need to find a specific cache key or configuration
- **Contains:**
  - Current cache usage patterns
  - Cache configuration snippets
  - Materialized view information
  - Key scopes and eager loading
  - Cache invalidation patterns
  - Performance monitoring
  - Multi-tenancy cache keys
  - Cache expiration times
  - Useful Rails console commands

### 4. **caching_improvement_examples.md** (Implementation Guide)
Production-ready code examples for all recommended improvements.
- **Size:** 666 lines (~17KB)
- **Purpose:** Implement caching improvements
- **Use When:** You're ready to improve caching performance
- **Contains:**
  - 9 complete improvement examples:
    1. Redis cache store configuration
    2. Fragment caching in views
    3. ETag and conditional GET
    4. Fragment caching with cache keys
    5. Async view refresh job
    6. Cache warming on deploy
    7. Stronger invalidation strategy
    8. Response caching middleware
    9. Cache visualization helpers
  - Testing code samples
  - Priority matrix with effort/impact

---

## Quick Navigation

### "I want to..."

**...understand the current caching system**
→ Read `caching_analysis.md` (complete reference)

**...find a specific cache key**
→ Use `caching_quick_reference.md` (lookup)

**...improve caching performance**
→ Follow `caching_improvement_examples.md` (implementation)

**...get a quick overview**
→ Read `CACHING_SUMMARY.txt` (executive summary)

**...add new caching logic**
→ Check `caching_quick_reference.md` for patterns

**...debug a cache issue**
→ See "Cache Invalidation Patterns" in `caching_quick_reference.md`

---

## Key Findings Summary

### Current State: MODERATE
- **Fragment caching:** Enabled in production
- **Database optimization:** Strong (materialized views)
- **Query optimization:** Strong (eager loading scopes)
- **HTTP caching:** Partial (assets only)
- **Cache store:** Not configured (defaults to in-memory)

### Strongest Areas
✓ Materialized views for property searches  
✓ Eager loading to prevent N+1 queries  
✓ Asset caching (1-year TTL)  
✓ Multi-tenant cache key scoping  
✓ Performance monitoring infrastructure  

### Weakest Areas
✗ Redis not configured as primary cache store  
✗ No fragment caching in view templates  
✗ No ETag/conditional GET headers  
✗ No async view refresh  
✗ No response-level caching  

---

## File Locations Quick Reference

| Component | File | Lines |
|-----------|------|-------|
| Prod Config | `/config/environments/production.rb` | 14, 17 |
| Dev Config | `/config/environments/development.rb` | 13-23 |
| Assets | `/config/initializers/assets.rb` | - |
| Performance | `/config/initializers/rails_performance.rb` | 15-20 |
| Page Parts | `/app/models/pwb/page_part.rb` | 66-88 |
| Footer Cache | `/app/controllers/pwb/application_controller.rb` | 72-77 |
| Nav Cache | `/app/controllers/pwb/application_controller.rb` | 79-88 |
| Facets Cache | `/app/controllers/pwb/search_controller.rb` | 266-301 |
| Firebase Cache | `/app/services/pwb/firebase_token_verifier.rb` | 78-106 |
| Listed Property | `/app/models/pwb/listed_property.rb` | All |
| View Refresh | `/app/models/pwb/realty_asset.rb` | 84 |
| View SQL | `/db/views/pwb_properties_v03.sql` | - |

---

## Improvement Priority Matrix

| Priority | Task | Effort | Impact | Docs |
|----------|------|--------|--------|------|
| HIGH | Configure Redis cache store | 15min | High | Example 1 |
| HIGH | Fragment caching in views | 2-4h | High | Example 2 |
| HIGH | ETag/conditional GET | 1-2h | Medium | Example 3 |
| MEDIUM | Cache invalidation | 1h | Medium | Example 7 |
| MEDIUM | HTTP Cache headers | 1-2h | Medium | Example 3 |
| LOW | Async view refresh | 1h | Low | Example 5 |
| LOW | Cache warming | 1h | Low | Example 6 |
| LOW | Cache visualization | 1h | Low | Example 9 |

**Estimated Quick Win (High Priority):** 4-6 hours → 15-25% performance improvement

---

## Cache Keys Reference

```
page_part/{id}/{page_part_key}/{theme_name}/template
  TTL: 5 seconds (dev), 1 hour (prod)
  Invalidation: explicit on save/destroy

footer_content/{website_id}/{updated_at_timestamp}
  TTL: 5 minutes
  Invalidation: timestamp-based (touch website)

nav_admin_link/{website_id}/{updated_at_timestamp}
  TTL: 5 minutes
  Invalidation: timestamp-based (touch website)

search_facets/{website_id}/{operation_type}/{locale}/{updated_at_timestamp}
  TTL: 5 minutes
  Invalidation: timestamp-based (touch website)

firebase/google_certificates
  TTL: 1 hour (respects Google's cache-control header)
  Invalidation: automatic TTL expiry
```

---

## Commands & Debugging

### Rails Console
```ruby
# View cache contents
Rails.cache.read("footer_content/1/1234567890")

# Clear specific cache
Rails.cache.delete("footer_content/1/1234567890")

# Clear all caches
Rails.cache.clear

# Check cache store type
Rails.cache.class

# List all cache keys (Redis)
Rails.cache.redis.keys("*").sort
```

### Rails CLI
```bash
# Toggle development caching
rails dev:cache

# View performance dashboard
# Visit http://localhost:3000/rails/performance

# Clear all caches
rails c -e production
> Rails.cache.clear
```

---

## Testing Caching

See `caching_improvement_examples.md` for complete testing examples.

Key test areas:
- Cache hit/miss on repeated requests
- Cache invalidation on model updates
- Multi-tenant cache isolation
- Cache expiration timing
- Website timestamp-based invalidation

---

## Performance Monitoring

### Rails Performance Dashboard
- **URL:** `/rails/performance`
- **Data:** Request times, slow endpoints, query counts
- **Storage:** Redis (7-day retention)

### Bullet Gem (Development)
- **Status:** Enabled in development
- **Output:** Console logs + HTML footer
- **Detects:** N+1 queries, unused eager loading

### Ahoy Analytics
- **Tracking:** Tenant-scoped visit and event tracking
- **Privacy:** IP masking enabled
- **Scope:** Per-website analytics isolation

---

## Multi-Tenancy Considerations

All caching is designed for multi-tenant architecture:
- Cache keys include `website_id`
- Timestamp-based invalidation uses `website.updated_at`
- Analytics scoped to tenant
- No cross-tenant cache pollution

---

## Getting Started

### For New Developers
1. Read `CACHING_SUMMARY.txt` for overview
2. Review current implementations in `caching_analysis.md`
3. Use `caching_quick_reference.md` as daily reference

### For Performance Optimization
1. Check `CACHING_SUMMARY.txt` for quick wins
2. Review examples in `caching_improvement_examples.md`
3. Start with high-priority items
4. Measure performance before/after changes

### For Adding New Caching
1. Check `caching_quick_reference.md` for patterns
2. Follow cache key naming convention (tag/attribute/value)
3. Include `website_id` for multi-tenant safety
4. Set appropriate TTL (5min to 1h typical)
5. Consider cache invalidation strategy

---

## Common Issues & Solutions

### "Cache not working in production"
→ Check if Redis is configured in `/config/environments/production.rb`
→ See Example 1 in `caching_improvement_examples.md`

### "Cache not invalidating when model changes"
→ Check if model has `after_save :touch_website` or explicit cache deletion
→ Review "Cache Invalidation Patterns" in `caching_quick_reference.md`

### "N+1 queries in production"
→ Check if controller uses `.with_eager_loading` scope
→ See query optimization patterns in `caching_analysis.md`

### "Different cache across server instances"
→ Configure Redis as primary cache store (Example 1)
→ Verify `REDIS_URL` environment variable is set

---

## Additional Resources

- Rails Caching Guide: https://guides.rubyonrails.org/caching_with_rails.html
- Scenic Gem (Materialized Views): https://github.com/scenic-views/scenic
- Redis Cache Store: https://guides.rubyonrails.org/caching_with_rails.html#activesupport-cache-rediscachestore
- ETag Guide: https://guides.rubyonrails.org/caching_with_rails.html#conditional-get-support

---

## Document Maintenance

Last Updated: December 20, 2025
Analysis Scope: PropertyWebBuilder (Rails 8.1, Ruby 3.4.7)
Multi-tenancy: acts_as_tenant gem with website scoping

### Version History
- v1.0 (Dec 20, 2025): Initial comprehensive analysis
  - All caching implementations documented
  - 9 improvement examples provided
  - Line-by-line code references
  - Production-ready implementation code
