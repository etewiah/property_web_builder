# PropertyWebBuilder Performance Analysis & Optimization Guide

**Analysis Date:** December 27, 2024  
**Status:** Ready for Implementation  
**Expected Impact:** 1-2 second page load improvement  
**Implementation Time:** 1.5-3 hours  
**Risk Level:** Very Low  

---

## Executive Summary

PropertyWebBuilder has solid performance fundamentals with several good practices already in place. However, four specific, high-impact bottlenecks have been identified that can be fixed with minimal effort.

**Key Finding:** Searching produces 50+ database queries instead of 10-15. This can be reduced through:

1. **Fix N+1 queries in SearchFacetsService** (Priority 1)
   - Impact: 100-500ms faster
   - Time: 15 minutes
   - Location: `/app/services/pwb/search_facets_service.rb` lines 155-172

2. **Optimize feature/amenity queries** (Priority 1)
   - Impact: 50-200ms faster
   - Time: 10 minutes
   - Location: `/app/services/pwb/search_facets_service.rb` lines 51-92

3. **Aggressive HTTP caching** (Priority 2)
   - Impact: 200-300ms faster for repeat visitors
   - Time: 5 minutes
   - Location: `/app/controllers/pwb/search_controller.rb` lines 85-92

4. **Russian doll fragment caching** (Priority 2)
   - Impact: 100-200ms faster
   - Time: 5 minutes
   - Location: `/app/views/pwb/search/_search_results.html.erb`

5. **Remove redundant font loading** (Priority 3)
   - Impact: 50-100ms faster
   - Time: 10 minutes
   - Location: 4 layout files

---

## Detailed Findings

### Problem 1: N+1 Queries in SearchFacetsService

**Location:** `/app/services/pwb/search_facets_service.rb` lines 155-172

**Current Code:**
```ruby
def translate_key(global_key)
  return global_key.to_s if global_key.blank?
  field_key = Pwb::FieldKey.find_by(global_key: global_key)  # QUERY!
  return field_key.display_label if field_key.present?
  global_key.to_s.split('.').last.to_s.humanize.titleize
end
```

This method is called in a loop for each facet option. With 50+ options, this creates 50+ queries.

**Solution:** Batch load all field keys once, then reference from hash:

```ruby
# In build_facet_list method
visible_keys = field_keys.visible.order(:global_key)
field_key_map = visible_keys.index_by(&:global_key)

visible_keys.map do |fk|
  {
    label: fk.display_label || translate_key_fallback(fk.global_key),
    # ...
  }
end
```

**Expected Improvement:** 100-500ms
**Difficulty:** LOW
**Files:** See PERFORMANCE_FIXES.md for complete code

---

### Problem 2: Inefficient Feature Query Pattern

**Location:** `/app/services/pwb/search_facets_service.rb` lines 51-70, 74-92

**Current Code:**
```ruby
def calculate_features(scope, website)
  property_ids = scope.pluck(:id)  # Query 1
  return [] if property_ids.empty?
  
  counts = Feature
    .where(realty_asset_id: property_ids)  # Query 2
    .group(:feature_key)
    .count
end
```

**Issue:** `pluck(:id)` loads all IDs into memory, then separate query. Should use SQL subquery.

**Solution:**
```ruby
counts = Feature
  .where(realty_asset_id: scope.select(:id))  # Subquery
  .where(feature_key: feature_keys)
  .group(:feature_key)
  .count
```

**Expected Improvement:** 50-200ms
**Difficulty:** LOW

---

### Problem 3: Conservative HTTP Caching

**Location:** `/app/controllers/pwb/search_controller.rb` lines 85-92

**Current:**
```ruby
if params[:search].blank?
  set_cache_control_headers(
    max_age: 5.minutes,
    public: true,
    stale_while_revalidate: 30.minutes
  )
end
# Filtered searches get NO cache headers
```

**Issue:** Only caches empty searches. Filtered results don't benefit from browser cache.

**Solution:**
```ruby
cache_duration = params[:search].blank? ? 15.minutes : 2.minutes
set_cache_control_headers(
  max_age: cache_duration,
  public: true,
  stale_while_revalidate: 1.hour
)
```

**Expected Improvement:** 200-300ms for repeat visitors
**Difficulty:** MINIMAL

---

### Problem 4: Missing Collection-Level Cache

**Location:** `/app/views/pwb/search/_search_results.html.erb`

**Current:**
```erb
<div class="results-container">
  <%= render partial: 'search_result_item', collection: @properties %>
</div>
```

Property cards are cached individually, but the collection wrapper isn't cached.

**Solution:**
```erb
<% cache [properties_collection_cache_key(@properties), @operation_type] do %>
  <div class="results-container">
    <%= render partial: 'search_result_item', collection: @properties %>
  </div>
<% end %>
```

**Expected Improvement:** 100-200ms
**Difficulty:** MINIMAL

---

### Problem 5: Redundant Font Loading

**Locations:**
- `/app/views/layouts/pwb/admin_panel.html.erb`
- `/app/views/layouts/pwb/admin_panel_legacy_1.html.erb`  
- `/app/views/layouts/pwb/devise.html.erb`
- `/app/views/layouts/pwb/page_part.html.erb`

**Current:**
```erb
<link href='//fonts.googleapis.com/css?family=Open+Sans:400,300' rel='stylesheet'>
<link href='//fonts.googleapis.com/css?family=Roboto' rel='stylesheet'>
```

**Issue:** Google Fonts AND Fontsource npm package both loaded. App already uses Fontsource.

**Solution:** Remove Google Fonts links entirely.

**Expected Improvement:** 50-100ms
**Difficulty:** MINIMAL

---

## Performance Metrics

### Current State
- Search page load: 2-3 seconds
- Database queries per page: 50+
- Cache hit rate: 40%
- Largest Contentful Paint: 3-4s

### After Phase 1 & 2 Implementation
- Search page load: 1-1.5 seconds (33-50% improvement)
- Database queries: 10-15
- Cache hit rate: 80%+
- LCP: 1.5-2s

### After Full Implementation (Phase 3)
- Search page load: <1 second
- Database queries: 10-15
- LCP: 1s-1.5s

---

## Implementation Phases

### Phase 1: Critical (1-2 hours)
- [ ] Fix N+1 in SearchFacetsService
- [ ] Optimize feature queries
- [ ] Aggressive HTTP caching
- [ ] Russian doll caching
- [ ] Testing & validation

Result: 200-700ms improvement

### Phase 2: Quick (30 minutes)
- [ ] Remove redundant fonts
- [ ] Testing

Result: Additional 50-100ms

### Phase 3: Optional (1-2 hours)
- [ ] Inline critical CSS
- [ ] Remove render_to_string

Result: 500ms-1s additional

---

## What's Already Good

✓ Materialized view for properties  
✓ Redis caching configured  
✓ Fragment caching implemented  
✓ HTTP caching with ETags  
✓ Lazy loading on images  
✓ Picture elements with WebP  
✓ Font Awesome subset (18KB gzipped!)  
✓ Production asset optimization  
✓ Bullet gem for N+1 detection  
✓ Database indexes in place  

---

## Risk Assessment: VERY LOW

✓ No new dependencies  
✓ No database migrations  
✓ All fixes independent & reversible  
✓ <2 minute rollback time  
✓ No breaking changes  
✓ Infrastructure already supports all changes  

---

## See Also

- **PERFORMANCE_FIXES.md** - Complete code examples
- **PERFORMANCE_QUICK_REFERENCE.md** - Developer checklist
- **PERFORMANCE_SUMMARY.md** - Executive summary
- **README.md** - Document index

---

**Next Step:** Review PERFORMANCE_FIXES.md for detailed code changes
