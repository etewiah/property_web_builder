# PropertyWebBuilder Search Documentation

This folder contains comprehensive documentation for the PropertyWebBuilder search implementation.

## Documents

### 1. [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md)

**Purpose:** Complete technical reference for the search system

**Contents:**
- Architecture overview and technology stack
- Routes and endpoints
- Controllers and concerns
- Search models and scopes
- Views and templates
- JavaScript and Stimulus integration
- Services (SearchFacetsService)
- URL parameter handling
- Pain points and limitations
- Data flow diagrams

**When to Use:**
- Deep diving into how search works
- Understanding current implementation
- Modifying core search logic
- Adding new features
- Troubleshooting issues

**Length:** ~800 lines (comprehensive)

---

### 2. [QUICK_REFERENCE.md](./QUICK_REFERENCE.md)

**Purpose:** Quick lookup guide for common tasks

**Contents:**
- Search routes and endpoints
- Supported filter parameters
- Property model scopes
- View file structure
- Helper methods
- Common customizations
- Troubleshooting tips
- File location reference

**When to Use:**
- "How do I...?" questions
- Looking up specific methods
- Finding file locations
- Quick parameter reference
- Need fast answers

**Length:** ~400 lines (concise)

---

### 3. [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md)

**Purpose:** Identify current issues and plan improvements

**Contents:**
- Detailed pain point analysis (10 issues)
- Root causes and impacts
- Solution approaches
- 7-phase improvement roadmap
- Priority matrix
- Quick wins
- Estimated efforts

**When to Use:**
- Planning next improvements
- Understanding limitations
- Deciding what to work on
- Communicating with team
- Prioritizing features

**Length:** ~600 lines (strategic)

---

## Quick Navigation

### By Task

**I want to...**
- **Understand the current system** → Read [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md)
- **Add a new filter** → See [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) "Add New Filter"
- **Fix a bug** → Check [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) for known issues
- **Find a file** → Use [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) "Files to Remember"
- **Plan improvements** → Read [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md)
- **Understand a method** → Search [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md)
- **Add a feature** → See [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) "Improvement Roadmap"

### By Role

**Backend Developer**
- [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) - Main reference
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick lookups
- [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) - Future planning

**Frontend Developer**
- [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) - Sections: JavaScript, Views, Templates
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Stimulus section
- [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) - UX issues

**Tech Lead/PM**
- [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) - Full document
- [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) - Architecture section
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - For team reference

**QA/Tester**
- [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) - Understanding flows
- [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) - Known issues
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Troubleshooting

---

## Key Concepts

### Search Architecture

The search system is built on three main layers:

1. **Backend (Rails)**
   - Routes: `/buy`, `/rent`, `/search_ajax_*`
   - Controller: `Pwb::SearchController`
   - Concerns: PropertyFiltering, MapMarkers, FormSetup
   - Model Scopes: Via `ListedProperty::Searchable`

2. **Frontend (ERB/Liquid)**
   - Forms: `_search_form_for_*.html.erb`
   - Results: `_search_results.html.erb`
   - Filters: `_feature_filters.html.erb`
   - Response: `search_ajax.js.erb`

3. **Client-side (JavaScript)**
   - Stimulus: `SearchFormController`
   - Rails UJS: AJAX handling
   - Inline scripts: Filter interactions

### How Search Works

```
1. User visits /buy
   ↓
2. SearchController loads properties for this website
   ↓
3. Form displays with filter options
   ↓
4. User selects filters and clicks "Search"
   ↓
5. Form submits via AJAX (POST)
   ↓
6. SearchController applies filters
   ↓
7. Returns JavaScript that updates DOM
   ↓
8. Results displayed, map updated
```

### Supported Filters

- **Location:** locality, zone
- **Price:** for_sale_price_from/till, for_rent_price_from/till
- **Property Type:** property_type
- **Property State:** property_state
- **Room Counts:** count_bedrooms, count_bathrooms
- **Features:** features (array), features_match (all/any)

### Key Files

| File | Purpose |
|------|---------|
| `/app/controllers/pwb/search_controller.rb` | Main search logic |
| `/app/models/concerns/listed_property/searchable.rb` | Search scopes |
| `/app/services/pwb/search_facets_service.rb` | Filter counts |
| `/app/helpers/pwb/search_url_helper.rb` | URL conversion |
| `/app/javascript/controllers/search_form_controller.js` | AJAX handling |
| `/app/views/pwb/search/_search_form_*.html.erb` | Search forms |
| `/app/themes/*/views/pwb/search/buy.html.erb` | Theme pages |

---

## Current Pain Points (Summary)

1. **URL State Not Preserved** - Can't bookmark/share searches (CRITICAL)
2. **Deprecated Rails UJS** - Old AJAX architecture (HIGH)
3. **Fragile JS.erb** - Hard to maintain, security risks (HIGH)
4. **Form Submit Friction** - Must click button (MEDIUM)
5. **Feature Filter UX** - Hard to discover feature (MEDIUM)
6. **No Real-Time Counts** - Facets don't update (MEDIUM)
7. **Poor Mobile UX** - Sidebar not optimized (MEDIUM)
8. **No Pagination** - Doesn't scale (LOW-MEDIUM)
9. **Testing Gaps** - Limited coverage (MEDIUM)
10. **Accessibility Issues** - Missing ARIA labels (LOW)

See [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) for detailed analysis.

---

## Improvement Roadmap

### Phase 1: URL State Management (CRITICAL)
- Goal: Make searches bookmarkable
- Effort: 3-4 days
- Status: Needed

### Phase 2: Replace Rails UJS (HIGH)
- Goal: Modernize AJAX
- Effort: 2-3 days
- Status: Needed

### Phase 3: Feature Filter UX (MEDIUM)
- Goal: Improve discoverability
- Effort: 1-2 days
- Status: Planned

### Phase 4: Pagination (MEDIUM)
- Goal: Handle large sets
- Effort: 2-3 days
- Status: Planned

### Phase 5: Real-Time Facets (MEDIUM)
- Goal: Update counts live
- Effort: 1-2 days
- Status: Planned

### Phase 6: Testing (ONGOING)
- Goal: E2E + integration tests
- Effort: 2-3 days
- Status: Needed

### Phase 7: Mobile UX (LOW)
- Goal: Optimize for mobile
- Effort: 2-3 days
- Status: Planned

See [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md) for full roadmap.

---

## Related Documentation

- [SEARCH_REIMAGINING_PLAN.md](../ui/SEARCH_REIMAGINING_PLAN.md) - UX improvement vision
- [Field Keys Documentation](../field_keys/) - Filter option system
- [Property Models Reference](../architecture/PROPERTY_MODELS_QUICK_REFERENCE.md)
- [Multi-Tenancy Reference](../multi_tenancy/MULTI_TENANCY_QUICK_REFERENCE.md)
- [Caching Reference](../caching/caching_quick_reference.md)

---

## Common Tasks

### Add a New Filter

1. Update `filtering_params` in `/app/controllers/concerns/search/property_filtering.rb`
2. Add scope to `/app/models/concerns/listed_property/searchable.rb`
3. Add form input to `/app/views/pwb/search/_search_form_for_sale.html.erb`
4. Add facet calculation to `/app/services/pwb/search_facets_service.rb` (if needed)
5. Add i18n translation
6. Add tests

**See:** [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - "Add New Filter"

### Customize Search for Theme

1. Create `/app/themes/my-theme/views/pwb/search/buy.html.erb`
2. Can override layout, form, results, or entire page
3. Can reuse shared partials

**See:** [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - "Override Theme Search"

### Debug Search Not Working

1. Check if filters are in `filtering_params`
2. Verify scope exists on ListedProperty
3. Check form input name matches parameter
4. Verify parameter not filtered out
5. Check browser network tab

**See:** [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - "Troubleshooting"

### Understand Data Flow

1. User visits `/buy`
2. SearchController#buy renders page with properties
3. Form submits via AJAX
4. SearchController#search_ajax_for_sale applies filters
5. Returns JavaScript that updates DOM
6. User sees filtered results

**See:** [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) - "Data Flow Diagrams"

---

## Testing

### Current Test Coverage

- SearchFacetsService: ✅ Comprehensive
- SearchUrlHelper: ✅ Good coverage
- SearchParamsService: ✅ Specs exist (service not implemented)
- SearchController: ⚠️ Limited
- Integration: ⚠️ Limited
- E2E: ❌ None

### Test Files

- `/spec/controllers/pwb/search_controller_spec.rb`
- `/spec/services/pwb/search_facets_service_spec.rb`
- `/spec/services/pwb/search_params_service_spec.rb`
- `/spec/helpers/pwb/search_url_helper_spec.rb`
- `/tests/e2e/search.spec.js` - ⚠️ Not comprehensive

### Run Tests

```bash
# All search tests
rspec spec/controllers/pwb/search_controller_spec.rb
rspec spec/services/pwb/search_*_service_spec.rb
rspec spec/helpers/pwb/search_url_helper_spec.rb

# E2E tests (Playwright)
npm run test -- tests/e2e/search.spec.js
```

---

## Performance Considerations

### Facet Caching

- **Cache Key:** `[search_facets, website_id, operation_type, locale, website.updated_at.to_i]`
- **Duration:** 5 minutes
- **Invalidation:** When website.updated_at changes

### Query Optimization

- Use `.with_eager_loading` to include associations
- Limit results to 45 by default (see controller)
- Add indexes on frequently queried columns

### Pagination

- Not yet implemented (see Phase 4 of roadmap)

---

## Troubleshooting

### Filters Not Applying

**Check:**
1. Parameter in `filtering_params`?
2. Scope exists on ListedProperty?
3. Form input name correct?

**Debug:**
```ruby
# In controller
puts filtering_params(params).inspect
puts @properties.to_sql
```

### AJAX Not Working

**Check:**
1. Correct endpoint URL?
2. `remote: true` on form?
3. Network tab shows POST?
4. search_ajax.js.erb returns JavaScript?

### Results Stale

**Check:**
1. Cache invalidated?
2. Browser cache?
3. Facet counts correct?

```ruby
# Clear cache
Rails.cache.clear

# Check facets
@facets = nil  # Force recalculate
```

---

## Glossary

- **Facets:** Counts of results for each filter option
- **Global Key:** Field identifier like "features.pool" or "types.apartment"
- **Slug:** URL-friendly version like "pool" or "apartment"
- **Features:** Property characteristics (permanent attributes)
- **Amenities:** Equipment and services (temporary or user-configurable)
- **Operation Type:** "for_sale" or "for_rent"
- **Scoping:** Limiting queries to specific website (multi-tenancy)

---

## Next Steps

1. **Read** [SEARCH_ARCHITECTURE_COMPREHENSIVE.md](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md) for full context
2. **Reference** [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) for specific lookups
3. **Plan** improvements using [PAIN_POINTS_AND_IMPROVEMENTS.md](./PAIN_POINTS_AND_IMPROVEMENTS.md)
4. **Implement** Phase 1 (URL State Management) for biggest impact

---

## Questions?

See the specific document sections:
- **"How does..."** → SEARCH_ARCHITECTURE_COMPREHENSIVE.md
- **"Where is..."** → QUICK_REFERENCE.md
- **"Why doesn't..."** → PAIN_POINTS_AND_IMPROVEMENTS.md
- **"What should I..."** → PAIN_POINTS_AND_IMPROVEMENTS.md Improvement Roadmap

---

## Document Versions

| Date | Author | Changes |
|------|--------|---------|
| 2024-12-24 | Claude | Initial comprehensive documentation |

---

**Last Updated:** 2024-12-24
**Status:** Complete and Current
**Coverage:** Comprehensive (all major components)
