# Search Implementation - Quick Reference

## Search Routes

```ruby
GET  /buy                         # Buy/sale search page
GET  /rent                        # Rent search page
POST /search_ajax_for_sale.js     # AJAX update for buy
POST /search_ajax_for_rent.js     # AJAX update for rent
```

## Main Controller: `Pwb::SearchController`

**File:** `/app/controllers/pwb/search_controller.rb`

| Action | HTTP | Purpose |
|--------|------|---------|
| `buy` | GET | Render buy page with initial filters |
| `rent` | GET | Render rent page with initial filters |
| `search_ajax_for_sale` | POST | AJAX update for sale filters |
| `search_ajax_for_rent` | POST | AJAX update for rent filters |

## Search Filters

### Supported Parameters

```ruby
# Location
:in_locality         # String - "madrid"
:in_zone            # String - "zona-norte"

# Prices (in cents)
:for_sale_price_from
:for_sale_price_till
:for_rent_price_from
:for_rent_price_till

# Property classification
:property_type      # String - "types.apartment"
:property_state     # String - "states.new_build"

# Room counts (minimum)
:count_bedrooms     # Integer - 3
:count_bathrooms    # Integer - 2

# Features
:features           # Array - ["features.pool", "features.sea_views"]
:features_match     # "all" (default) or "any"
```

## Property Model Scopes

```ruby
# Visibility
.visible
.for_sale
.for_rent
.highlighted

# Filters
.property_type(key)
.property_state(key)
.for_sale_price_from(cents)
.for_sale_price_till(cents)
.for_rent_price_from(cents)
.for_rent_price_till(cents)
.count_bedrooms(min)
.count_bathrooms(min)

# Features
.with_features(keys)       # ALL features required (AND)
.with_any_features(keys)   # ANY feature required (OR)
.without_features(keys)
```

## View Structure

```
app/views/pwb/search/
  _search_form_for_sale.html.erb    # Buy form
  _search_form_for_rent.html.erb    # Rent form
  _search_results.html.erb          # Results list
  _search_result_item.html.erb      # Single result
  _feature_filters.html.erb         # Features/amenities
  search_ajax.js.erb                # AJAX response

app/themes/*/views/pwb/search/
  buy.html.erb                      # Theme-specific buy page
  rent.html.erb                     # Theme-specific rent page
  _search_results.html.erb          # Theme-specific results
```

## Form Usage

### Search Form

```erb
<%= simple_form_for :search, 
    url: '/search_ajax_for_sale.js',
    method: 'post',
    html: { class: 'form-light' },
    remote: true do |f| %>
  
  <%= f.input :property_type, collection: @property_types %>
  <%= f.input :for_sale_price_from, collection: @prices_from_collection %>
  <%= f.input :for_sale_price_till, collection: @prices_till_collection %>
  <%= f.input :count_bedrooms, collection: 0..50 %>
  <%= f.input :count_bathrooms, collection: 0..20 %>
  
  <%= render 'pwb/search/feature_filters' %>
  
  <%= f.button :button, class: 'btn btn-primary' do %>
    <%= I18n.t("search") %>
  <% end %>
<% end %>
```

## Key Helpers

### SearchUrlHelper

```ruby
include Pwb::SearchUrlHelper

# Global key to URL slug
feature_to_slug('features.private_pool')
# => 'private-pool'

# URL slug to global key
slug_to_feature('private-pool', 'property-features')
# => 'features.private_pool'

# Build search URL with features
search_url_with_features(
  base_path: '/buy',
  features: ['features.pool'],
  type: 'types.apartment'
)

# Parse friendly URL params
parse_friendly_url_params({type: 'apartment', bedrooms: '3'})

# Generate canonical URL
canonical_search_url(operation_type: 'for_sale', search_params: {...})
```

## Services

### SearchFacetsService

```ruby
Pwb::SearchFacetsService.calculate(
  scope: @properties,
  website: @current_website,
  operation_type: 'for_sale'
)
# => {
#   property_types: [...],
#   property_states: [...],
#   features: [...],
#   amenities: [...],
#   bedrooms: [...],
#   bathrooms: [...]
# }
```

## Concerns

### Search::PropertyFiltering

```ruby
include Search::PropertyFiltering

filtering_params(params)        # Extract filter parameters
feature_params()                # Extract feature/amenity filters
apply_search_filter(filters)    # Apply filters to @properties
apply_feature_filters()         # Apply feature-specific filters
```

### Search::MapMarkers

```ruby
include Search::MapMarkers

set_map_markers()               # Generate marker data
# Sets: @map_markers = [{id, title, show_url, image_url, display_price, position}]
```

### Search::FormSetup

```ruby
include Search::FormSetup

set_common_search_inputs()      # Load filter options
set_select_picker_texts()       # Load i18n texts
header_image_url()              # Get header image
```

## JavaScript

### Stimulus Controller: SearchFormController

```javascript
// File: app/javascript/controllers/search_form_controller.js

// Targets
static targets = ["form", "results", "spinner"]

// Event Handlers
connect()              // Initialize
disconnect()           // Cleanup
showLoading()          // Show spinner
hideLoading()          // Hide spinner
handleSuccess()        // AJAX success
handleError()          // AJAX error
truncateDescriptions() // Limit text length
sortResults()          // Sort by price
updateUrlParams()      // Push state
toggleFilters()        // Toggle sidebar
```

### AJAX Response

```javascript
// File: app/views/pwb/search/search_ajax.js.erb

// Updates results container
resultsContainer.innerHTML = "<%= j (render 'search_results') %>";

// Updates map markers
mapElement.mapController.updateMarkers(<%= @map_markers.to_json %>);

// Dispatches custom event
document.dispatchEvent(new CustomEvent('search:updated', {...}));
```

## URL Parameters Examples

### Traditional Format

```
/buy?search[property_type]=types.apartment&search[count_bedrooms]=3
```

### Friendly Format

```
/buy?type=apartment&bedrooms=3&features=pool,sea-views
```

Both formats are supported and automatically converted.

## Price Conversion

Prices are stored in **cents**:

```ruby
# Convert price to cents
price_string = "100000"        # Display price
currency = "usd"               # Currency code
price_cents = price_string.gsub(/\D/, "").to_i * 100
# => 10000000 cents = $100,000

# SearchController handles this automatically
convert_price_to_cents("100000")
```

## Form Submission Flow

```
User fills form
  ↓
Clicks "Search" button
  ↓
Rails UJS intercepts (remote: true)
  ↓
POST to /search_ajax_for_sale.js
  ↓
SearchController#search_ajax_for_sale
  ↓
apply_search_filter(params)
  ↓
render search_ajax.js.erb
  ↓
JavaScript updates DOM
  ↓
Results displayed
```

## Stimulus Controller Integration

```erb
<!-- In theme buy.html.erb -->
<section data-controller="search-form">
  <div data-search-form-target="spinner" class="hidden">
    Loading...
  </div>
  
  <form data-search-form-target="form" 
        data-action="ajax:beforeSend->search-form#showLoading 
                     ajax:complete->search-form#hideLoading">
    <!-- Form inputs -->
  </form>
  
  <div id="inmo-search-results" data-search-form-target="results">
    <!-- Results here -->
  </div>
</section>
```

## Facet Caching

```ruby
# Cache key format
["search_facets", website_id, operation_type, locale, website.updated_at.to_i].join("/")

# Cache duration: 5 minutes
# Invalidates when website updated_at changes
```

## Common Customizations

### Add New Filter

1. Update `filtering_params` in concern
2. Add scope to `ListedProperty::Searchable`
3. Add form input to partial
4. Add facet calculation if needed
5. Add i18n translation

### Override Theme Search

1. Create `/app/themes/my-theme/views/pwb/search/buy.html.erb`
2. Can override form, results, entire layout
3. Can reuse shared partials with `render '/pwb/search/...'`

### Change Sort Order

In `SearchFormController#sortResults()`:

```javascript
// Get sort param from URL
const sortOrder = new URLSearchParams(window.location.search).get("sort") || "price-asc"

// Sort items
items.sort((a, b) => {
  const priceA = parseFloat(a.dataset.price) || 0
  const priceB = parseFloat(b.dataset.price) || 0
  
  if (sortOrder === "price-desc") {
    return priceB - priceA
  }
  return priceA - priceB
})
```

## Troubleshooting

### Filters Not Working

1. Check `filtering_params` in SearchController
2. Verify scope exists in ListedProperty
3. Check form input name matches parameter
4. Verify parameter is not being filtered out

### Results Not Updating

1. Check AJAX endpoint is correct (`/search_ajax_for_sale.js`)
2. Verify `remote: true` on form
3. Check browser network tab for POST request
4. Check `search_ajax.js.erb` template renders correctly

### Facet Counts Wrong

1. Check cache invalidation (website.updated_at)
2. Verify facet scope logic
3. Check Feature model associations
4. Clear cache: `Rails.cache.clear`

### URL Parameters Not Working

1. Check `parse_friendly_url_params` in helper
2. Verify field keys exist in database
3. Check parameter format in URL
4. Use browser dev tools to inspect params

## Files to Remember

| Task | File |
|------|------|
| Add filter | `/app/controllers/concerns/search/property_filtering.rb` |
| Add scope | `/app/models/concerns/listed_property/searchable.rb` |
| Update form | `/app/views/pwb/search/_search_form_for_sale.html.erb` |
| Update results | `/app/views/pwb/search/_search_results.html.erb` |
| Update JS behavior | `/app/javascript/controllers/search_form_controller.js` |
| Update AJAX response | `/app/views/pwb/search/search_ajax.js.erb` |
| URL helpers | `/app/helpers/pwb/search_url_helper.rb` |
| Facet counts | `/app/services/pwb/search_facets_service.rb` |
| Main logic | `/app/controllers/pwb/search_controller.rb` |

## See Also

- [Full Architecture Documentation](./SEARCH_ARCHITECTURE_COMPREHENSIVE.md)
- [Search Reimagining Plan](../ui/SEARCH_REIMAGINING_PLAN.md)
- [Field Keys Documentation](../field_keys/)
- [Property Models Reference](../architecture/PROPERTY_MODELS_QUICK_REFERENCE.md)
