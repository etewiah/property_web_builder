# Search Experience Improvements

This document details the search improvements implemented for the default theme and provides a plan for implementing them across all themes.

## Overview

The search experience has been reimagined to provide:

1. **URL-based state management** - Search filters are saved in the URL for bookmarking and sharing
2. **Seamless updates** - Results update without full page reloads using Turbo Frames
3. **SEO-friendly canonical URLs** - Consistent URL format for search engine optimization
4. **Improved filter UX** - Better dropdown population and state persistence

---

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Search Flow                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   URL Request                                                        │
│   /en/buy?type=apartment&bedrooms=2&price_min=100000                │
│        │                                                             │
│        ▼                                                             │
│   ┌─────────────────────┐                                           │
│   │ SearchParamsService │  ◄── Parses URL params to criteria        │
│   └─────────────────────┘                                           │
│        │                                                             │
│        ▼                                                             │
│   ┌─────────────────────┐                                           │
│   │  SearchController   │  ◄── Applies filters, pagination, sorting │
│   └─────────────────────┘                                           │
│        │                                                             │
│        ├──────────────────┐                                         │
│        ▼                  ▼                                         │
│   Full Page          Turbo Frame                                    │
│   (initial load)     (filter updates)                               │
│        │                  │                                         │
│        ▼                  ▼                                         │
│   ┌─────────────────────────────────────┐                          │
│   │    View Templates (buy/rent.html)   │                          │
│   │    - Filter form with URL state     │                          │
│   │    - Turbo Frame for results        │                          │
│   │    - Stimulus controller for UX     │                          │
│   └─────────────────────────────────────┘                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### File Structure

```
app/
├── controllers/
│   └── pwb/
│       └── search_controller.rb          # Main controller with Turbo support
│
├── services/
│   └── pwb/
│       └── search_params_service.rb      # URL ↔ criteria conversion
│
├── models/
│   └── concerns/
│       └── listed_property/
│           └── searchable.rb             # Search scopes (updated for slug matching)
│
├── views/
│   └── pwb/
│       └── search/
│           └── _search_results_frame.html.erb  # Turbo Frame wrapper
│
├── themes/
│   └── default/
│       └── views/
│           └── pwb/
│               └── search/
│                   ├── buy.html.erb      # Updated with URL state
│                   └── rent.html.erb     # Updated with URL state
│
└── javascript/
    └── controllers/
        └── search_controller.js          # Stimulus controller for URL management
```

---

## Key Improvements Implemented

### 1. URL-Based State Management

**Before:**
```
/en/buy                          # No filter state in URL
```

**After:**
```
/en/buy?type=apartment&bedrooms=2&price_min=100000&sort=price-asc
```

**Benefits:**
- Bookmarkable searches
- Shareable filter combinations
- Browser back/forward navigation works
- SEO indexable search result pages

### 2. SearchParamsService

Location: `app/services/pwb/search_params_service.rb`

Handles bidirectional conversion between URL parameters and internal search criteria:

```ruby
# URL to criteria
service = Pwb::SearchParamsService.new
criteria = service.from_url_params(params)
# => { property_type: 'apartment', bedrooms: 2, price_min: 100000 }

# Criteria to URL
url_string = service.to_url_params(criteria)
# => "bedrooms=2&price_min=100000&type=apartment"

# Canonical URL generation
canonical = service.canonical_url(criteria, locale: :en, operation: :buy)
# => "/en/buy?bedrooms=2&price_min=100000&type=apartment"
```

**Supported Parameters:**

| URL Param   | Internal Key     | Type    | Example           |
|-------------|------------------|---------|-------------------|
| `type`      | `:property_type` | String  | `apartment`       |
| `bedrooms`  | `:bedrooms`      | Integer | `2`               |
| `bathrooms` | `:bathrooms`     | Integer | `1`               |
| `price_min` | `:price_min`     | Integer | `100000`          |
| `price_max` | `:price_max`     | Integer | `500000`          |
| `features`  | `:features`      | Array   | `pool,garden`     |
| `zone`      | `:zone`          | String  | `costa-del-sol`   |
| `locality`  | `:locality`      | String  | `marbella`        |
| `sort`      | `:sort`          | String  | `price-asc`       |
| `view`      | `:view`          | String  | `grid`            |
| `page`      | `:page`          | Integer | `2`               |

### 3. Turbo Frame Updates

Results update without full page reload using Turbo Frames:

```erb
<%# In buy.html.erb %>
<%= form_with url: buy_path, method: :get,
              data: { turbo_frame: "search-results" } do |f| %>
  <%# Filter inputs %>
<% end %>

<%# Results wrapped in Turbo Frame %>
<turbo-frame id="search-results" data-turbo-action="advance">
  <%# Search results %>
</turbo-frame>
```

The `data-turbo-action="advance"` ensures the URL updates when filters change.

### 4. Controller Before Action Order

Critical fix for proper param processing:

```ruby
# CORRECT order (setup_search_params_service must run first)
before_action :header_image_url
before_action :setup_search_params_service  # Sets @search_criteria
before_action :normalize_url_params          # Uses @search_criteria
```

### 5. Operation-Specific Price Filtering

Price filters are now applied based on the current operation (buy vs rent):

```ruby
def map_criteria_to_search_params
  is_rental = action_name == 'rent' || action_name == 'search_ajax_for_rent'

  if @search_criteria[:price_min]
    if is_rental
      params[:search][:for_rent_price_from] = @search_criteria[:price_min]
    else
      params[:search][:for_sale_price_from] = @search_criteria[:price_min]
    end
  end
end
```

### 6. Property Type Slug Matching

The `property_type` scope now matches both exact keys and slug suffixes:

```ruby
# Matches 'apartment' against 'types.apartment'
scope :property_type, ->(property_type) {
  where('prop_type_key = ? OR prop_type_key LIKE ?',
        property_type, "%.#{property_type}")
}
```

### 7. Filter Dropdown Population

Dropdowns correctly populate from URL parameters:

```erb
<% Pwb::ListedProperty.distinct.pluck(:prop_type_key).compact.each do |type| %>
  <% type_slug = type.to_s.split('.').last %>
  <% is_selected = @search_criteria_for_view[:property_type].present? &&
                   (type == @search_criteria_for_view[:property_type] ||
                    type_slug == @search_criteria_for_view[:property_type]) %>
  <option value="<%= type_slug %>" <%= 'selected' if is_selected %>>
    <%= I18n.t("propertyTypes.#{type_slug}", default: type_slug.titleize) %>
  </option>
<% end %>
```

---

## Stimulus Controller

Location: `app/javascript/controllers/search_controller.js`

Handles:
- URL updates when filters change
- Browser history navigation (popstate)
- Mobile filter panel toggle
- Clear filters functionality

Key methods:
- `filterChanged()` - Updates URL and triggers Turbo Frame request
- `clearFilters()` - Resets all filters and navigates to base URL
- `toggleFilters()` - Shows/hides mobile filter panel
- `handlePopstate()` - Handles browser back/forward

---

## Testing

### Unit Tests

`spec/services/pwb/search_params_service_spec.rb` - 39 examples covering:
- Parameter parsing (type, bedrooms, price, features, etc.)
- URL generation with sorted params
- Canonical URL generation
- Round-trip consistency

### Request Tests

`spec/requests/pwb/search_spec.rb` - 16 examples covering:
- Basic page rendering
- URL parameter handling
- Error handling (malformed params, XSS)
- Turbo Frame requests

### E2E Tests

`tests/e2e/search.spec.js` - Playwright tests for:
- Filter interactions
- URL state persistence
- Page navigation
- Mobile responsiveness

---

## Known Issues & Solutions

### Issue 1: Price filtering applied to wrong operation
**Problem:** Both sale and rental price filters were applied simultaneously
**Solution:** Check `action_name` to determine operation type

### Issue 2: Property type not matching
**Problem:** URL uses 'apartment' but DB stores 'types.apartment'
**Solution:** Updated scope to match slug suffix

### Issue 3: Dropdowns not populated from URL
**Problem:** Option values didn't match URL param format
**Solution:** Extract slug from type key, compare against both formats

---

## Related Documentation

- [Search Reimagining Plan](./SEARCH_REIMAGINING_PLAN.md)
- [Search Wireframes](./wireframes/search-wireframes.md)
- [Pain Points & Improvements](../search/PAIN_POINTS_AND_IMPROVEMENTS.md)
- [Search Architecture](../search/SEARCH_ARCHITECTURE_COMPREHENSIVE.md)
