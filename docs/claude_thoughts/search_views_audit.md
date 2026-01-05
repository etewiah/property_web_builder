# Search-Related Views, Partials, and Forms Audit

## Overview

This document provides a comprehensive inventory of all search-related views, partials, forms, and controllers in the PropertyWebBuilder codebase. It identifies current patterns, hardcoded arrays that should be replaced with SearchConfig, and controllers that need to provide configuration to views.

---

## 1. Search Form Files Location

### Internal Property Search Forms

#### Base Fallback Views (app/views/pwb/search/)
- `_search_form_for_sale.html.erb` - Sale property search form
- `_search_form_for_rent.html.erb` - Rental property search form  
- `_search_form_landing.html.erb` - Landing page search form (for homepage hero)
- `_search_results.html.erb` - Results display template
- `_search_result_item.html.erb` - Individual result card
- `_search_results_frame.html.erb` - Turbo frame wrapper for results
- `search_ajax.js.erb` - AJAX response template
- `_feature_filters.html.erb` - Feature/amenity filter partial

#### Theme-Specific Views
Each theme has its own search form variants:

**Default Theme** (`app/themes/default/views/pwb/search/`)
- `_search_form_for_sale.html.erb`
- `_search_form_for_rent.html.erb`
- `_search_form_landing.html.erb`
- `_search_results.html.erb`
- `_search_result_item.html.erb`
- `buy.html.erb` - Sale search page (uses form)
- `rent.html.erb` - Rental search page (uses form)

**Barcelona Theme** (`app/themes/barcelona/views/pwb/search/`)
- `_search_form_for_sale.html.erb` - URL-based, Turbo Frames
- `_search_form_for_rent.html.erb`
- `_search_results.html.erb`
- `buy.html.erb`
- `rent.html.erb`

**Biarritz Theme** (`app/themes/biarritz/views/pwb/search/`)
- `_search_form_for_sale.html.erb`
- `_search_form_for_rent.html.erb`
- `_search_results.html.erb`
- `buy.html.erb`
- `rent.html.erb`

**Bologna Theme** (`app/themes/bologna/views/pwb/search/`)
- `_search_form_for_sale.html.erb`
- `_search_form_for_rent.html.erb`
- `_search_results.html.erb`
- `buy.html.erb`
- `rent.html.erb`

**Brisbane Theme** (`app/themes/brisbane/views/pwb/search/`)
- `_search_form_for_sale.html.erb`
- `_search_form_for_rent.html.erb`
- `_search_form_landing.html.erb`
- `_search_results.html.erb`
- `buy.html.erb`
- `rent.html.erb`

### External Listings Search
- `app/views/pwb/site/external_listings/_search_form.html.erb` - External feed search/filter form

### Other Search-Related Views
- `app/views/site_admin/website/settings/_search_tab.html.erb` - Admin search configuration UI
- `app/views/pwb/site/my/saved_searches/no_searches.html.erb` - Empty state for saved searches
- `app/views/pwb/search_alert_mailer/new_properties_alert.html.erb` - Email template
- `app/views/pwb/search_alert_mailer/new_properties_alert.text.erb` - Email text template

### Liquid Templates (Dynamic Components)
- `app/views/pwb/page_parts/search_cmpt.liquid` - Liquid component for search
- `app/views/pwb/page_parts/heroes/hero_search.liquid` - Hero section with search

### Component References
Theme component search boxes (referenced in headers/components):
- `app/themes/brisbane/views/pwb/components/_search_cmpt.html.erb`
- `app/themes/default/views/pwb/components/_search_cmpt.html.erb`
- `app/themes/bologna/views/pwb/components/_search_cmpt.html.erb`

---

## 2. Current Patterns & Hardcoded Arrays

### Price Filter Arrays
**Location**: Multiple form files (sale and rent variants)

**Pattern Found**:
```erb
<!-- Current: Using instance variables from controller -->
<select name="search[for_sale_price_from]">
  <% @prices_from_collection&.each do |price| %>
    <option value="<%= price %>">
      <%= number_to_currency(price, precision: 0) %>
    </option>
  <% end %>
</select>
```

**Issue**: Instance variables `@prices_from_collection` and `@prices_till_collection` are set in controller but not consistently across all forms.

**SearchConfig Equivalent**:
- `SearchConfig#price_min_presets` - Returns appropriate presets based on listing type
- `SearchConfig#price_max_presets` - Returns max presets

### Bedroom Filter Arrays
**Location**: Multiple theme forms

**Pattern Found** - Hardcoded Ranges:
```erb
<!-- In default form (fallback) -->
<% (1..6).each do |n| %>
  <option value="<%= n %>"><%= n %>+</option>
<% end %>

<!-- In default theme -->
<% (0..50).map { |n| [n, n] } %>

<!-- In barcelona theme - Hardcoded chips -->
<% [nil, 1, 2, 3, 4, 5].each do |num| %>
```

**Issues**:
1. Inconsistent ranges across themes (1..6, 0..50, [1,2,3,4,5])
2. Hardcoded arrays instead of centralized config
3. Different min/max option handling

**SearchConfig Equivalent**:
- `SearchConfig#bedroom_min_options` - ["Any", 1, 2, 3, 4, 5, "6+"]
- `SearchConfig#bedroom_max_options` - [1, 2, 3, 4, 5, 6, "No max"]
- `SearchConfig#bedroom_min_options_for_view` - Formatted for select dropdowns

### Bathroom Filter Arrays
**Location**: Multiple theme forms

**Pattern Found** - Hardcoded Ranges:
```erb
<!-- In default form (fallback) -->
<% (1..4).each do |n| %>
  <option value="<%= n %>"><%= n %>+</option>
<% end %>

<!-- In default theme -->
<% (0..20).map { |n| [n, n] } %>

<!-- In barcelona theme - Hardcoded chips -->
<% [nil, 1, 2, 3, 4].each do |num| %>

<!-- In external listings form -->
<% (1..5).each do |n| %> <!-- min -->
<% (1..8).each do |n| %> <!-- max -->
```

**Issues**:
1. Ranges vary: (1..4), (0..20), (1..5), (1..8)
2. Different handling for "Any" vs empty
3. External listings uses completely different ranges

**SearchConfig Equivalent**:
- `SearchConfig#bathroom_min_options` - ["Any", 1, 2, 3, 4, "5+"]
- `SearchConfig#bathroom_max_options` - [1, 2, 3, 4, 5, "No max"]
- `SearchConfig#bathroom_min_options_for_view` - Formatted for select dropdowns

### External Listings Specific Arrays
**Location**: `app/views/pwb/site/external_listings/_search_form.html.erb`

**Hardcoded Patterns**:
```erb
<!-- Bedrooms -->
<% (1..6).each do |n| %>  <!-- min -->
<% (1..10).each do |n| %> <!-- max -->

<!-- Bathrooms -->
<% (1..5).each do |n| %>  <!-- min -->
<% (1..8).each do |n| %>  <!-- max -->

<!-- Area -->
<!-- Manual input, no presets -->
```

**Issue**: Completely separate from internal search config; uses different ranges and logic.

---

## 3. Controllers Setting Up Search Variables

### Primary Controller
**File**: `app/controllers/pwb/search_controller.rb`

**Key Methods**:
1. `perform_search(operation_type:, page_slug:)` - Main search action
2. `perform_ajax_search(operation_type:)` - AJAX search action

**Instance Variables Set**:
- `@prices_from_collection` - From `SearchConfig#price_presets` (should use min/max)
- `@prices_till_collection` - From `SearchConfig#price_presets`
- `@property_types` - From `PwbTenant::FieldKey` (FieldKey system)
- `@property_states` - From `PwbTenant::FieldKey`
- `@property_features` - From `PwbTenant::FieldKey`
- `@property_amenities` - From `PwbTenant::FieldKey`
- `@zones` - From website zones
- `@localities` - From website localities
- `@search_defaults` - From URL params
- `@search_criteria_for_view` - Normalized search params
- `@facets` - Search result facet counts

**Concern Module**: `Search::FormSetup`
```ruby
def set_common_search_inputs
  @property_types = PwbTenant::FieldKey.get_options_by_tag("property-types")
  @property_features = PwbTenant::FieldKey.get_options_by_tag("property-features")
  @property_amenities = PwbTenant::FieldKey.get_options_by_tag("property-amenities")
end
```

### External Listings Controller
**File**: Not directly visible but referenced in search form
- Uses `filter_options` helper to provide options
- Gets filter options from search config

---

## 4. SearchConfig Service Integration

### Current Status
**File**: `app/services/pwb/search_config.rb`

**Already Implemented**:
- Comprehensive DEFAULT constants for all filter arrays
- Methods to access price, bedroom, bathroom options
- Support for website-level customization
- Formatting methods for view helpers (e.g., `bedroom_options_for_view`)
- Filter enable/disable logic

**Methods Available**:
```ruby
# Price configuration
config.price_min_presets        # [50000, 100000, ...]
config.price_max_presets        # [100000, 150000, ...]
config.price_presets            # Legacy alias for min_presets

# Bedroom configuration  
config.bedroom_min_options      # ["Any", 1, 2, 3, 4, 5, "6+"]
config.bedroom_max_options      # [1, 2, 3, 4, 5, 6, "No max"]
config.bedroom_options          # Legacy alias for min_options
config.bedroom_min_options_for_view  # Formatted for dropdowns
config.bedroom_max_options_for_view

# Bathroom configuration
config.bathroom_min_options     # ["Any", 1, 2, 3, 4, "5+"]
config.bathroom_max_options     # [1, 2, 3, 4, 5, "No max"]
config.bathroom_options         # Legacy alias for min_options
config.bathroom_min_options_for_view
config.bathroom_max_options_for_view

# Features & area
config.filter(:features)        # Feature filter config
config.area_presets             # Area/sqm options
config.area_unit                # "sqm" or "sqft"

# Display options
config.show_map?                # Whether to show map
config.show_save_search?        # Whether to show save search button
config.show_favorites?          # Whether to show favorites
config.default_sort             # Default sort order
config.sort_options             # Available sort options
config.filter_options_for_view  # Complete view helper hash
```

### Integration Points
1. SearchController uses `search_config_for(operation_type)` method
2. Returns hash with `prices_from` and `prices_till`
3. Not yet providing full SearchConfig to views

---

## 5. Key Inconsistencies & Problems

### A. Bedroom Options Inconsistency
| Location | Min | Max | Pattern |
|----------|-----|-----|---------|
| Fallback form | 1-6 | - | (1..6).each |
| Default theme | 0-50 | 0-50 | (0..50).map |
| Barcelona theme | [1,2,3,4,5] | - | Hardcoded array |
| External listings | 1-6 | 1-10 | Separate ranges |
| SearchConfig | "Any", 1-5, "6+" | 1-6, "No max" | Designed properly |

**Impact**: Users see different options depending on theme

### B. Bathroom Options Inconsistency
| Location | Min | Max | Pattern |
|----------|-----|-----|---------|
| Fallback form | 1-4 | - | (1..4).each |
| Default theme | 0-20 | 0-20 | (0..20).map |
| Barcelona theme | [1,2,3,4] | - | Hardcoded array |
| External listings | 1-5 | 1-8 | Separate ranges |
| SearchConfig | "Any", 1-4, "5+" | 1-5, "No max" | Designed properly |

**Impact**: Users see different maximum options depending on theme

### C. Price Configuration
- Currently using `@prices_from_collection` and `@prices_till_collection`
- SearchConfig has proper min/max presets
- Not being passed to all views/themes

### D. External Listings Form Isolation
- `app/views/pwb/site/external_listings/_search_form.html.erb` is separate
- Uses completely different hardcoded ranges
- Uses `filter_options` local variable (not standard)
- Should align with main SearchConfig

---

## 6. Files That Need SearchConfig Integration

### High Priority (Hardcoded Arrays)
1. **Fallback forms** - `app/views/pwb/search/_search_form_*.html.erb`
   - Replace (1..6), (1..4) with SearchConfig calls
   - Use @prices_from_collection and @prices_till_collection correctly

2. **External listings form** - `app/views/pwb/site/external_listings/_search_form.html.erb`
   - Replace all hardcoded ranges with SearchConfig
   - Align with main search configuration
   - Update controller to provide @search_config

3. **Theme forms** - All theme-specific search forms
   - Barcelona: Replace [1,2,3,4,5] hardcoding
   - Default: Fix (0..50) ranges to use SearchConfig
   - Biarritz: Review and align
   - Bologna: Review and align
   - Brisbane: Review and align

### Medium Priority (Instance Variables)
4. **SearchController.perform_search()**
   - Create full @search_config instance variable
   - Pass to all views, not just prices

5. **External listings controller** (needs to be found)
   - Provide SearchConfig to external_listings form

### Documentation
6. **Admin settings form** - `app/views/site_admin/website/settings/_search_tab.html.erb`
   - Document what can be customized
   - Show how changes affect all views

---

## 7. Implementation Checklist

### Phase 1: Establish SearchConfig as Source of Truth
- [ ] Update SearchController to pass `@search_config` instance variable
- [ ] Ensure all controllers that render search forms initialize SearchConfig
- [ ] Document SearchConfig API in views

### Phase 2: Update Fallback Forms
- [ ] `_search_form_for_sale.html.erb` - Use SearchConfig for bedrooms/bathrooms
- [ ] `_search_form_for_rent.html.erb` - Use SearchConfig for bedrooms/bathrooms
- [ ] Verify @prices_from_collection and @prices_till_collection are properly set

### Phase 3: Update Theme-Specific Forms
- [ ] Default theme - Replace (0..50) with SearchConfig
- [ ] Barcelona theme - Replace hardcoded arrays with SearchConfig
- [ ] Biarritz, Bologna, Brisbane themes - Audit and update

### Phase 4: External Listings Alignment
- [ ] Update `_search_form.html.erb` to use SearchConfig
- [ ] Find and update external listings controller
- [ ] Use same filter options as internal search

### Phase 5: Feature/Amenity Consolidation
- [ ] Ensure features use FieldKey system consistently
- [ ] Consider adding amenities to FieldKey if not present
- [ ] Test feature filtering across all themes

---

## 8. References

### Related Files
- **SearchConfig Service**: `/app/services/pwb/search_config.rb`
- **Form Setup Concern**: `/app/controllers/concerns/search/form_setup.rb`
- **FieldKey Model**: Via `PwbTenant::FieldKey` (manages property-types, property-features, etc.)
- **SearchParamsService**: `/app/services/pwb/search_params_service.rb`
- **SearchFacetsService**: `/app/services/pwb/search_facets_service.rb`

### Related Specs
- `spec/views/themes/search_conformance_spec.rb` - Theme search conformance tests
- `spec/controllers/pwb/search_controller_spec.rb` - Search controller tests

---

## 9. Example: Replacing Hardcoded Array

### Before (Current)
```erb
<select name="search[count_bedrooms]">
  <option value=""><%= I18n.t("search.any") %></option>
  <% (1..6).each do |n| %>
    <option value="<%= n %>"><%= n %>+</option>
  <% end %>
</select>
```

### After (With SearchConfig)
```erb
<select name="search[count_bedrooms]">
  <% @search_config.bedroom_min_options_for_view.each do |opt| %>
    <option value="<%= opt[:value] %>" <%= 'selected' if @search_defaults["count_bedrooms"].to_s == opt[:value] %>>
      <%= opt[:label] %>
    </option>
  <% end %>
</select>
```

### Or Simpler (Using Presets)
```erb
<select name="search[count_bedrooms]">
  <% [["Any", ""]] + @search_config.bedroom_min_options.map { |n| [n.to_s, n] }.each do |label, value| %>
    <option value="<%= value %>"><%= label %></option>
  <% end %>
</select>
```

---

## Summary

The codebase has:
- **Excellent SearchConfig service** with all the data needed
- **Multiple search forms** across themes with inconsistent hardcoded arrays
- **Clear opportunity** to unify all filter options through SearchConfig
- **External listings form** that's completely isolated and should be aligned
- **Controllers** that need to consistently pass SearchConfig to views

The key to consistency is ensuring all views receive `@search_config` instance variable initialized from `Pwb::SearchConfig.new(@current_website, listing_type: type)`.
