# Search Improvements: Theme Implementation Plan

This document outlines the plan to implement the search improvements across all PropertyWebBuilder themes.

## Current State

| Theme    | URL State | Turbo Frames | Filter Population | Status      |
|----------|-----------|--------------|-------------------|-------------|
| default  | ✅        | ✅           | ✅                | Complete    |
| brisbane | ✅        | ✅           | ✅                | Complete    |
| bologna  | ✅        | ✅           | ✅                | Complete    |

## Shared Components (Already Updated)

These components are shared across themes and have already been updated:

1. **`SearchController`** (`app/controllers/pwb/search_controller.rb`)
   - Turbo Frame support
   - URL parameter parsing via SearchParamsService
   - Operation-specific price filtering

2. **`SearchParamsService`** (`app/services/pwb/search_params_service.rb`)
   - URL ↔ criteria conversion
   - Canonical URL generation

3. **`ListedProperty::Searchable`** (`app/models/concerns/listed_property/searchable.rb`)
   - Updated `property_type` scope for slug matching

4. **`_search_results_frame.html.erb`** (`app/views/pwb/search/`)
   - Turbo Frame wrapper for results

---

## Implementation Tasks by Theme

### Brisbane Theme

**Files to update:**

```
app/themes/brisbane/views/pwb/search/
├── buy.html.erb           # Main buy page
├── rent.html.erb          # Main rent page
├── _search_form_for_sale.html.erb    # Filter form (sale)
├── _search_form_for_rent.html.erb    # Filter form (rent)
└── _search_results.html.erb          # Results display
```

**Task List:**

- [x] **1. Update `buy.html.erb`**
  - Change `data-controller="search-form"` to `data-controller="search"`
  - Add `data-search-operation-value="buy"` and `data-search-locale-value`
  - Add canonical URL meta tag in head
  - Replace `<%= render 'search_results' %>` with `<%= render 'pwb/search/search_results_frame' %>`
  - Add mobile filter backdrop div

- [x] **2. Update `rent.html.erb`**
  - Same changes as buy.html.erb
  - Change operation value to "rent"

- [x] **3. Update `_search_form_for_sale.html.erb`**
  - Change form to use `method: :get` with `data: { turbo_frame: "search-results" }`
  - Update property type dropdown to use slugs and match correctly
  - Update price dropdowns to populate from `@search_criteria_for_view`
  - Update bedroom/bathroom inputs to check against criteria
  - Add `data-action="change->search#filterChanged"` to all filter inputs

- [x] **4. Update `_search_form_for_rent.html.erb`**
  - Same changes as sale form
  - Ensure price labels say "Monthly Rent"

- [x] **5. Update `_search_results.html.erb`** (if theme-specific)
  - Ensure compatibility with Turbo Frame updates

**Estimated effort:** 2-3 hours (COMPLETED)

---

### Bologna Theme

**Files to update:**

```
app/themes/bologna/views/pwb/search/
├── buy.html.erb           # Main buy page
├── rent.html.erb          # Main rent page
└── _search_results.html.erb          # Results display
```

**Note:** Bologna now has theme-specific form partials in `app/themes/bologna/views/pwb/search/`

**Task List:**

- [x] **1. Update `buy.html.erb`**
  - Change `data-controller="search-form"` to `data-controller="search"`
  - Add `data-search-operation-value="buy"` and `data-search-locale-value`
  - Add canonical URL meta tag
  - Replace results rendering with Turbo Frame
  - Add mobile filter backdrop

- [x] **2. Update `rent.html.erb`**
  - Same changes as buy.html.erb
  - Change operation value to "rent"

- [x] **3. Create theme-specific form partials**
  - `app/themes/bologna/views/pwb/search/_search_form_for_sale.html.erb`
  - `app/themes/bologna/views/pwb/search/_search_form_for_rent.html.erb`

**Estimated effort:** 1-2 hours (COMPLETED)

---

## Detailed Implementation Steps

### Step 1: Update Main Page Template (buy.html.erb / rent.html.erb)

Replace the Stimulus controller declaration:

```erb
<%# BEFORE %>
<section class="..." data-controller="search-form">

<%# AFTER %>
<section class="..."
         data-controller="search"
         data-search-operation-value="buy"
         data-search-locale-value="<%= I18n.locale %>">
```

Add canonical URL in head:

```erb
<% content_for :head do %>
  <% if @canonical_url.present? %>
    <link rel="canonical" href="<%= @canonical_url %>">
  <% end %>
<% end %>
```

Replace results rendering:

```erb
<%# BEFORE %>
<div id="inmo-search-results" data-search-form-target="results">
  <%= render 'search_results' %>
</div>

<%# AFTER %>
<main class="search-results-main w-full lg:w-3/4 px-4 relative">
  <%= render 'pwb/search/search_results_frame' %>
</main>
```

Add mobile backdrop:

```erb
<div class="fixed inset-0 bg-black bg-opacity-50 z-40 hidden lg:hidden"
     data-search-target="backdrop"
     data-action="click->search#toggleFilters">
</div>
```

### Step 2: Update Filter Form Partial

Change form declaration:

```erb
<%# BEFORE %>
<%= form_with url: buy_path, method: :post, local: false,
              data: { action: "ajax:success->search-form#handleResults" } do |f| %>

<%# AFTER %>
<%= form_with url: buy_path, method: :get, local: true,
              data: {
                turbo_frame: "search-results",
                action: "submit->search#handleSubmit",
                search_target: "form"
              },
              class: "search-filter-form space-y-6" do |f| %>
```

Update property type dropdown:

```erb
<%# BEFORE %>
<select name="search[property_type]">
  <% @property_types.each do |type| %>
    <option value="<%= type %>"><%= type.titleize %></option>
  <% end %>
</select>

<%# AFTER %>
<select name="type"
        data-filter="type"
        data-action="change->search#filterChanged">
  <option value=""><%= I18n.t("propertyTypes.all", default: "All Types") %></option>
  <% Pwb::ListedProperty.distinct.pluck(:prop_type_key).compact.each do |type| %>
    <% type_slug = type.to_s.split('.').last %>
    <% is_selected = @search_criteria_for_view[:property_type].present? &&
                     (type == @search_criteria_for_view[:property_type] ||
                      type_slug == @search_criteria_for_view[:property_type]) %>
    <option value="<%= type_slug %>" <%= 'selected' if is_selected %>>
      <%= I18n.t("propertyTypes.#{type_slug}", default: type_slug.titleize) %>
    </option>
  <% end %>
</select>
```

Update bedroom/bathroom chips:

```erb
<% [nil, 1, 2, 3, 4, 5].each do |num| %>
  <label>
    <input type="radio"
           name="bedrooms"
           value="<%= num %>"
           data-filter="bedrooms"
           data-action="change->search#filterChanged"
           class="sr-only peer"
           <%= 'checked' if @search_criteria_for_view[:bedrooms].to_i == num.to_i &&
                            (num.present? || @search_criteria_for_view[:bedrooms].blank?) %>>
    <span class="chip-style">
      <%= num.nil? ? I18n.t("search.any", default: "Any") : "#{num}+" %>
    </span>
  </label>
<% end %>
```

Update price dropdowns:

```erb
<select name="price_min"
        data-filter="price_min"
        data-action="change->search#filterChanged">
  <option value=""><%= I18n.t("search.min", default: "Min") %></option>
  <% @prices_from_collection&.each do |price| %>
    <option value="<%= price %>"
            <%= 'selected' if @search_criteria_for_view[:price_min].to_i == price.to_i %>>
      <%= number_to_currency(price, precision: 0) %>
    </option>
  <% end %>
</select>
```

### Step 3: Update Stimulus Controller References

Replace all occurrences:

| Before                              | After                          |
|-------------------------------------|--------------------------------|
| `data-controller="search-form"`     | `data-controller="search"`     |
| `data-search-form-target="..."`     | `data-search-target="..."`     |
| `data-action="search-form#..."`     | `data-action="search#..."`     |

---

## Testing Checklist

For each theme, verify:

- [ ] Page loads without errors
- [ ] URL updates when filters are changed
- [ ] Filters populate correctly from URL params
- [ ] Browser back/forward works
- [ ] Mobile filter toggle works
- [ ] Clear filters resets to base URL
- [ ] Turbo Frame updates work (no full page reload)
- [ ] Pagination updates URL
- [ ] Sort updates URL
- [ ] Results count is accurate

---

## Migration Strategy

### Option A: Gradual Migration (Recommended)

1. Keep legacy `search-form` controller working
2. Add new `search` controller features
3. Migrate themes one at a time
4. Remove legacy controller after all themes migrated

### Option B: All-at-Once Migration

1. Update all themes simultaneously
2. Test thoroughly before deployment
3. Single release

**Recommendation:** Use Option A to minimize risk and allow for iterative testing.

---

## Rollback Plan

If issues are discovered after deployment:

1. Theme-specific views can be reverted independently
2. Controller maintains backward compatibility with legacy format
3. Shared partials have fallback behavior

---

## Timeline Estimate

| Phase                  | Duration | Dependencies        |
|------------------------|----------|---------------------|
| Brisbane theme         | 2-3 hrs  | None                |
| Bologna theme          | 1-2 hrs  | Shared forms update |
| Testing & QA           | 2-3 hrs  | Theme updates       |
| Documentation updates  | 1 hr     | All complete        |

**Total estimated time:** 6-9 hours

---

## Future Considerations

1. **Extract to ViewComponent** - Consider converting filter forms to ViewComponents for better reusability
2. **Shared form partial** - Create a single shared filter form that all themes can include
3. **Theme configuration** - Allow theme-specific filter layouts via configuration
4. **Advanced filters** - Add support for area range, features toggle, map bounds filtering
