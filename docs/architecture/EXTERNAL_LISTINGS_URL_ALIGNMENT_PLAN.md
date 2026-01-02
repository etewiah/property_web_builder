# External Listings URL Alignment Plan

## Objective

Align external listings URLs with internal listings URL patterns for consistency, SEO benefits, and better user experience.

## Current State

### Internal Listings (Target Pattern)
```
/en/properties/for-rent/{id}/{url-friendly-title}
/en/properties/for-sale/{id}/{url-friendly-title}
/es/properties/for-rent/{id}/{url-friendly-title}
```

**Characteristics:**
- Locale prefix (`/en/`, `/es/`)
- Listing type in path (`for-rent`, `for-sale`)
- ID/slug as identifier
- SEO-friendly title suffix

### External Listings (Current Pattern)
```
/external_listings?listing_type=sale
/external_listings/{reference}?listing_type=sale
```

**Issues:**
- No locale prefix in URL (relies on scope)
- Listing type passed as query param, not in path
- No SEO-friendly title in URL
- Different URL structure makes it harder to distinguish property types

---

## Proposed New URL Structure

### Show Page (Property Detail)
```
Current:  /en/external_listings/REF-123?listing_type=sale
Proposed: /en/external/for-sale/REF-123/luxury-villa-marbella
          /en/external/for-rent/REF-456/apartment-downtown
```

### Index Page (Search/List)
```
Current:  /en/external_listings?listing_type=sale
Proposed: /en/external/buy
          /en/external/rent

Or alternatively:
          /en/external/for-sale
          /en/external/for-rent
```

### Search Endpoint
```
Current:  /en/external_listings/search?listing_type=rental&location=marbella
Proposed: /en/external/rent?location=marbella
          /en/external/buy?min_price=100000
```

---

## Implementation Plan

### Phase 1: Routes Update

**File:** `config/routes.rb`

```ruby
# Current routes (lines 445-457)
scope module: :site do
  resources :external_listings, only: [:index, :show], param: :reference do
    collection do
      get :search
      get :locations
      get :property_types
      get :filters
    end
    member do
      get :similar
    end
  end
end

# Proposed routes
scope module: :site do
  # External listings with type-based paths (like internal properties)
  get "external/buy" => "external_listings#buy", as: "external_buy"
  get "external/rent" => "external_listings#rent", as: "external_rent"

  # Show pages with SEO-friendly URLs
  get "external/for-sale/:reference/:url_friendly_title" => "external_listings#show_for_sale",
      as: "external_show_for_sale"
  get "external/for-rent/:reference/:url_friendly_title" => "external_listings#show_for_rent",
      as: "external_show_for_rent"

  # Keep API endpoints for AJAX/JSON
  scope "external_listings" do
    get "locations" => "external_listings#locations"
    get "property_types" => "external_listings#property_types"
    get "filters" => "external_listings#filters"
    get ":reference/similar" => "external_listings#similar", as: "external_similar"
  end

  # Legacy redirects (for existing bookmarks/SEO)
  get "external_listings" => redirect { |params, request|
    listing_type = request.params[:listing_type]
    listing_type == "rental" ? "/#{I18n.locale}/external/rent" : "/#{I18n.locale}/external/buy"
  }
  get "external_listings/:reference" => redirect { |params, request|
    # Redirect to new URL pattern
    "/#{I18n.locale}/external/for-sale/#{params[:reference]}/show"
  }
end
```

### Phase 2: Controller Updates

**File:** `app/controllers/pwb/site/external_listings_controller.rb`

```ruby
# Add new actions for type-specific pages
def buy
  @listing_type = :sale
  @search_params = search_params.merge(listing_type: :sale)
  perform_search
  render :index
end

def rent
  @listing_type = :rental
  @search_params = search_params.merge(listing_type: :rental)
  perform_search
  render :index
end

def show_for_sale
  @listing_type = :sale
  set_listing
  render :show
end

def show_for_rent
  @listing_type = :rental
  set_listing
  render :show
end

# Update existing show method
def show
  # Redirect to new URL pattern if accessed via old URL
  if request.path.match?(/external_listings/)
    redirect_to_new_url
    return
  end
  # ... existing logic
end

private

def redirect_to_new_url
  type = @listing.listing_type == :rental ? "for-rent" : "for-sale"
  new_path = "/#{I18n.locale}/external/#{type}/#{@listing.reference}/#{url_friendly_title}"
  redirect_to new_path, status: :moved_permanently
end

def url_friendly_title
  @listing&.title&.parameterize.presence || "property"
end
```

### Phase 3: URL Helper Module

**File:** `app/models/concerns/external_listing/url_helpers.rb` (new file)

```ruby
# frozen_string_literal: true

module ExternalListing
  module UrlHelpers
    extend ActiveSupport::Concern

    # Returns a URL-friendly version of the title
    def url_friendly_title
      title && title.length > 2 ? title.parameterize : "property"
    end

    # Generates the appropriate show path based on listing type
    def contextual_show_path
      if listing_type == :rental
        Rails.application.routes.url_helpers.external_show_for_rent_path(
          locale: I18n.locale,
          reference: reference,
          url_friendly_title: url_friendly_title
        )
      else
        Rails.application.routes.url_helpers.external_show_for_sale_path(
          locale: I18n.locale,
          reference: reference,
          url_friendly_title: url_friendly_title
        )
      end
    end

    # Generates listing index path based on listing type
    def self.index_path_for(listing_type)
      if listing_type.to_sym == :rental
        Rails.application.routes.url_helpers.external_rent_path(locale: I18n.locale)
      else
        Rails.application.routes.url_helpers.external_buy_path(locale: I18n.locale)
      end
    end
  end
end
```

### Phase 4: View Updates

**Files to update:**
1. `app/views/pwb/site/external_listings/_property_card.html.erb`
2. `app/views/pwb/site/external_listings/index.html.erb`
3. `app/views/pwb/site/external_listings/_pagination.html.erb`
4. `app/views/pwb/site/external_listings/_search_form.html.erb`
5. `app/views/pwb/site/external_listings/show.html.erb`

**Property Card Update:**
```erb
<!-- Current -->
<a href="<%= external_listing_path(reference: property.reference, listing_type: property.listing_type) %>">

<!-- Proposed -->
<a href="<%= property.contextual_show_path %>">
```

**Pagination Update:**
```erb
<!-- Current -->
<a href="<%= external_listings_path(current_params.merge(page: page_num)) %>">

<!-- Proposed -->
<% base_path = @listing_type == :rental ? external_rent_path : external_buy_path %>
<a href="<%= "#{base_path}?#{current_params.merge(page: page_num).to_query}" %>">
```

### Phase 5: Update Canonical URLs

**Controller SEO method update:**
```ruby
def set_external_listings_seo
  # ...existing code...

  # Updated canonical URL
  @canonical_url = @listing_type == :rental ?
    external_rent_url(canonical_params) :
    external_buy_url(canonical_params)
end

def set_external_listing_detail_seo
  # ...existing code...

  # Updated canonical URL with new format
  @canonical_url = @listing.listing_type == :rental ?
    external_show_for_rent_url(reference: @listing.reference, url_friendly_title: url_friendly_title) :
    external_show_for_sale_url(reference: @listing.reference, url_friendly_title: url_friendly_title)
end
```

### Phase 6: Test Updates

**File:** `spec/requests/site/external_listings_spec.rb`

```ruby
describe "new URL structure" do
  it "routes /external/buy to index with sale listing type" do
    get external_buy_path
    expect(response).to be_successful
    expect(assigns(:listing_type)).to eq(:sale)
  end

  it "routes /external/rent to index with rental listing type" do
    get external_rent_path
    expect(response).to be_successful
    expect(assigns(:listing_type)).to eq(:rental)
  end

  it "routes /external/for-sale/:ref/:title to show" do
    get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-property")
    expect(response).to be_successful
  end

  it "redirects old URLs to new format" do
    get "/en/external_listings/TEST1"
    expect(response).to redirect_to(/external\/for-sale\/TEST1/)
  end
end
```

---

## URL Pattern Comparison (Before/After)

| Page | Current URL | New URL |
|------|-------------|---------|
| Buy Index | `/en/external_listings?listing_type=sale` | `/en/external/buy` |
| Rent Index | `/en/external_listings?listing_type=rental` | `/en/external/rent` |
| Property (Sale) | `/en/external_listings/REF-123?listing_type=sale` | `/en/external/for-sale/REF-123/villa-marbella` |
| Property (Rent) | `/en/external_listings/REF-456?listing_type=rental` | `/en/external/for-rent/REF-456/apartment-city` |
| Search (Sale) | `/en/external_listings/search?listing_type=sale&location=X` | `/en/external/buy?location=X` |
| Search (Rent) | `/en/external_listings/search?listing_type=rental&min_price=X` | `/en/external/rent?min_price=X` |

---

## Benefits

1. **SEO Consistency** - URLs follow same pattern as internal listings
2. **User Experience** - Clear distinction between buy/rent in URL
3. **Locale Support** - Proper locale prefix in all URLs
4. **Link Sharing** - More descriptive URLs when shared
5. **Analytics** - Easier to track buy vs rent traffic by URL pattern
6. **Canonical URLs** - Better for search engine indexing

---

## Migration Strategy

1. **Phase 1-3:** Implement new routes while keeping old routes functional
2. **Add 301 redirects** from old URLs to new URLs
3. **Update internal links** in views to use new URL helpers
4. **Monitor for 404s** and add any missing redirects
5. **After 3 months:** Consider removing legacy route support

---

## Files to Modify

| File | Changes |
|------|---------|
| `config/routes.rb` | Add new routes, legacy redirects |
| `app/controllers/pwb/site/external_listings_controller.rb` | Add `buy`, `rent`, `show_for_sale`, `show_for_rent` actions |
| `app/models/concerns/external_listing/url_helpers.rb` | New file for URL generation |
| `app/views/pwb/site/external_listings/_property_card.html.erb` | Update link generation |
| `app/views/pwb/site/external_listings/index.html.erb` | Update pagination/filter links |
| `app/views/pwb/site/external_listings/_pagination.html.erb` | Update page links |
| `app/views/pwb/site/external_listings/_search_form.html.erb` | Update form action |
| `spec/requests/site/external_listings_spec.rb` | Add tests for new routes |

---

## Estimated Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1: Routes | 1-2 hours | High |
| Phase 2: Controller | 2-3 hours | High |
| Phase 3: URL Helpers | 1 hour | High |
| Phase 4: Views | 2-3 hours | High |
| Phase 5: SEO/Canonical | 1 hour | Medium |
| Phase 6: Tests | 2-3 hours | High |

**Total: ~10-14 hours**

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Broken bookmarks | 301 redirects from old URLs |
| SEO ranking impact | Proper canonical URLs, 301 redirects |
| External links breaking | Keep old routes working during transition |
| Cache invalidation | Clear CDN cache after deployment |

---

**Created:** 2026-01-02
**Status:** IMPLEMENTED

---

## Implementation Summary

All phases have been completed:

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Routes | Completed | Added new routes at lines 445-475 in `config/routes.rb` |
| Phase 2: Controller | Completed | Added `buy`, `rent`, `show_for_sale`, `show_for_rent`, `legacy_index`, `legacy_show` actions |
| Phase 3: URL Helpers | Completed | Created `app/helpers/pwb/external_listing_url_helper.rb` |
| Phase 4: Views | Completed | Updated property card, pagination, search form, index, and show templates |
| Phase 5: SEO/Canonical | Completed | Updated canonical URLs in controller SEO methods |
| Phase 6: Tests | Completed | Updated `spec/requests/site/external_listings_spec.rb` with 44 tests, created `spec/helpers/pwb/external_listing_url_helper_spec.rb` with 20 tests |

### Files Modified

- `config/routes.rb` - New URL routes and legacy redirects
- `app/controllers/pwb/site/external_listings_controller.rb` - New actions and helper methods
- `app/helpers/pwb/external_listing_url_helper.rb` - NEW: URL generation helpers
- `app/views/pwb/site/external_listings/_property_card.html.erb` - Updated links
- `app/views/pwb/site/external_listings/_pagination.html.erb` - Updated pagination URLs
- `app/views/pwb/site/external_listings/_search_form.html.erb` - Updated form action and listing type toggle
- `app/views/pwb/site/external_listings/index.html.erb` - Updated filter chip URLs
- `app/views/pwb/site/external_listings/show.html.erb` - Updated breadcrumb link
- `spec/requests/site/external_listings_spec.rb` - Updated tests for new URL structure
- `spec/helpers/pwb/external_listing_url_helper_spec.rb` - NEW: Helper specs

### Test Results

All 64 tests pass:
- 44 request specs for external listings controller
- 20 helper specs for URL helper module
