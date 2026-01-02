# External Feed Configuration Data Flow

## 1. Admin Configuration Setup

```
┌─────────────────────────────────────────────────────────────────┐
│ Admin User: /site_admin/external_feed                           │
└─────────────────────────────────────────────────────────────────┘
         │
         │ GET (show page)
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ SiteAdmin::ExternalFeedsController#show                         │
├─────────────────────────────────────────────────────────────────┤
│ • @providers = available_providers                              │
│   - calls Registry.available_providers → [:resales_online]      │
│ • builds provider_config_fields for each                        │
│ • @feed_status = feed_status_info                               │
└─────────────────────────────────────────────────────────────────┘
         │
         │ renders show.html.erb
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ View: app/views/site_admin/external_feeds/show.html.erb        │
├─────────────────────────────────────────────────────────────────┤
│ • Displays list of available providers                          │
│ • For selected provider:                                        │
│   - API Key (password field)                                    │
│   - API ID (Sales)                                              │
│   - API ID (Rentals) - optional                                 │
│   - P1 Constant - optional                                      │
│ • Shows current config values (with masked passwords)           │
└─────────────────────────────────────────────────────────────────┘
         │
         │ Admin fills form and submits
         │ (sets external_feed_enabled, external_feed_provider,
         │  external_feed_config with credentials)
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ SiteAdmin::ExternalFeedsController#update                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. Extract params (external_feed_enabled, provider, config)     │
│ 2. Handle nested config hash                                    │
│    - Remove empty values                                        │
│    - Don't overwrite if value is "••••••••••••" (masked)       │
│    - Merge with existing to preserve secrets                    │
│ 3. website.update!(external_feed_params)                        │
│ 4. website.external_feed.invalidate_cache                       │
│ 5. Redirect with notice                                         │
└─────────────────────────────────────────────────────────────────┘
         │
         │ Saves to database
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ pwb_websites table                                              │
├─────────────────────────────────────────────────────────────────┤
│ id | external_feed_enabled | external_feed_provider |  external_feed_config
│ 1  | true                  | "resales_online"       | { "api_key": "xxx", ... }
└─────────────────────────────────────────────────────────────────┘
```

### Test Connection Flow

```
Admin clicks "Test Connection"
         │
         ↓
SiteAdmin::ExternalFeedsController#test_connection
         │
         ├─ @website.external_feed.search(page: 1, per_page: 1)
         │          │
         │          ↓ (see search flow below)
         │
         └─ result.error? 
            │
            ├─ true  → redirect with alert "Connection failed: ..."
            └─ false → redirect with notice "Found N properties"
```

---

## 2. Search/Filter Request Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Frontend Browser                                                │
├─────────────────────────────────────────────────────────────────┤
│ GET /external_listings?location=Marbella&min_price=100000       │
│ OR  /external_listings/filters (AJAX for filter options)        │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::Site::ExternalListingsController                           │
├─────────────────────────────────────────────────────────────────┤
│ 1. before_action :ensure_feed_enabled                           │
│    - checks @website.external_feed.configured?                  │
│    - redirects to root if not                                   │
│                                                                  │
│ 2. index action:                                                │
│    - extracts and validates search params                       │
│    - calls external_feed.search(@search_params)                 │
│    - calls external_feed.filter_options(locale: I18n.locale)    │
│    - passes @result and @filter_options to view                 │
└─────────────────────────────────────────────────────────────────┘
         │
         │ @search_params = {
         │   listing_type: :sale,
         │   location: "Marbella",
         │   min_price: 100000,
         │   page: 1,
         │   locale: :en,
         │   ... other permitted params ...
         │ }
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Manager#search(params)                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. normalized_params = normalize_search_params(params)          │
│    - defaults: locale, listing_type (:sale), per_page (24)      │
│    - converts to integers: prices, bedrooms, area, page         │
│                                                                  │
│ 2. cache.fetch_data(:search, normalized_params) do              │
│      provider.search(normalized_params)                         │
│    end                                                          │
│                                                                  │
│    Cache key: pwb:external_feed:1:resales_online:search:a1b2c3d│
│    TTL: 3600s (1 hour, from config[:cache_ttl_search])          │
└─────────────────────────────────────────────────────────────────┘
         │
         ├─ If cached: return cached NormalizedSearchResult
         │
         └─ If NOT cached:
            │
            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Providers::ResalesOnline#search(params)      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Determine API endpoint based on listing_type                 │
│    - :sale → SEARCH_URL_V6                                      │
│    - :rental → SEARCH_URL_V5                                    │
│                                                                  │
│ 2. build_search_query(params, api_id)                           │
│    - Maps normalized params to Resales Online API params        │
│    - Uses config[:api_key], config[:api_id_sales], etc.         │
│                                                                  │
│    Query: {                                                      │
│      p1: "1014359",        # from config[:p1_constant]          │
│      p2: "api_key_value",  # from config[:api_key]              │
│      p_apiid: "1234",      # from config[:api_id_sales]         │
│      p_PageSize: 24,       # from params[:per_page]             │
│      p_Location: "Marbella",                                     │
│      p_Min: 100000,                                              │
│      P_Lang: "1",          # from LANG_CODES[locale]            │
│      ...                                                         │
│    }                                                             │
│                                                                  │
│ 3. fetch_json(url_with_query_params)                            │
│    - Makes HTTP request to Resales Online API                   │
│    - Handles redirects, timeouts, HTTP errors                   │
│    - Parses JSON response                                       │
│                                                                  │
│ 4. normalize_search_results(response, params)                   │
│    - For each property in response["Property"]:                 │
│      • normalize_property(prop_data) → NormalizedProperty       │
│    - Create NormalizedSearchResult with:                        │
│      • properties: [NormalizedProperty, ...]                    │
│      • total_count: response["QueryInfo"]["PropertyCount"]      │
│      • page: response["QueryInfo"]["CurrentPage"]               │
│      • per_page: response["QueryInfo"]["PropertiesPerPage"]     │
│      • provider: :resales_online                                │
│      • query_params: params                                     │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓ Back to Manager
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Manager                                      │
├─────────────────────────────────────────────────────────────────┤
│ Returns NormalizedSearchResult from provider                     │
│ (or from cache if it was cached)                                │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓ Back to Controller
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::Site::ExternalListingsController#index (continued)         │
├─────────────────────────────────────────────────────────────────┤
│ @result = NormalizedSearchResult with properties array          │
│ @filter_options = external_feed.filter_options(...)             │
│                                                                  │
│ respond_to do |format|                                          │
│   format.html { render :index }  # → view with @result         │
│   format.json { render json: @result.to_h }                     │
│ end                                                              │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ View: app/views/pwb/site/external_listings/index.html.erb       │
├─────────────────────────────────────────────────────────────────┤
│ • Display search form with filters from @filter_options:        │
│   - location dropdown (from @filter_options.locations)          │
│   - property type checkboxes (from @filter_options.property_types)
│   - bedrooms (from @filter_options.bedrooms)                    │
│   - price range sliders, etc.                                   │
│ • Display results grid with @result.properties                  │
│   - Each NormalizedProperty rendered as property card           │
│   - Shows: image, title, location, price, beds/baths, area     │
│ • Pagination controls from @result (next_page, prev_page, etc) │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓ User sees search results page
```

---

## 3. Filter Options Discovery Flow

```
Frontend loads search page
         │
         │ JavaScript AJAX call
         ↓
GET /external_listings/filters
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::Site::ExternalListingsController#filters                   │
├─────────────────────────────────────────────────────────────────┤
│ @filter_options = external_feed.filter_options(                 │
│   locale: I18n.locale                                           │
│ )                                                               │
│ render json: @filter_options                                    │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Manager#filter_options(params)               │
├─────────────────────────────────────────────────────────────────┤
│ Returns Hash:                                                    │
│                                                                  │
│ {                                                               │
│   locations: locations(params),                                 │
│     ↓ calls provider.locations(params)                          │
│     ↓ (cached 1 week, or uses config[:locations])              │
│     ↓ returns [...{value, label}...]                            │
│                                                                  │
│   property_types: property_types(params),                       │
│     ↓ calls provider.property_types(params)                     │
│     ↓ (cached 1 week, or uses config[:property_types])         │
│     ↓ returns [...{value, label, subtypes?}...]                │
│                                                                  │
│   listing_types: [                                              │
│     {value: "sale", label: "For Sale"},                         │
│     {value: "rental", label: "For Rent"}                        │
│   ],                                                            │
│                                                                  │
│   sort_options: [                                               │
│     {value: "price_asc", label: "Price (Low to High)"},        │
│     {value: "price_desc", label: "Price (High to Low)"},       │
│     {value: "newest", label: "Newest First"},                   │
│     {value: "updated", label: "Recently Updated"}               │
│   ],                                                            │
│                                                                  │
│   bedrooms: [                                                   │
│     {value: "1", label: "1+"},                                  │
│     {value: "2", label: "2+"},                                  │
│     ... up to 6                                                 │
│   ],                                                            │
│                                                                  │
│   bathrooms: [                                                  │
│     {value: "1", label: "1+"},                                  │
│     {value: "2", label: "2+"},                                  │
│     {value: "3", label: "3+"},                                  │
│     {value: "4", label: "4+"}                                   │
│   ]                                                             │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
JSON Response: {
  locations: [{value: "Marbella", label: "Marbella"}, ...],
  property_types: [{value: "1-1", label: "Apartment", subtypes: [...]}, ...],
  listing_types: [{value: "sale", label: "For Sale"}, ...],
  sort_options: [...],
  bedrooms: [...],
  bathrooms: [...]
}
         │
         ↓ JavaScript populates form fields
```

---

## 4. Property Detail Lookup Flow

```
User clicks on property in search results
         │
         │ Click on "View Details" link
         │ href="/external_listings/R3096106?listing_type=sale"
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::Site::ExternalListingsController#show                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. before_action :set_listing                                   │
│    - extracts reference from params[:reference] ("R3096106")    │
│    - calls external_feed.find(reference, locale, listing_type)  │
│ 2. Checks if @listing is nil or unavailable                     │
│    - renders "unavailable" page if not available                │
│ 3. Loads similar properties:                                    │
│    @similar = external_feed.similar(@listing, limit: 6, ...)    │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Manager#find(reference, params)              │
├─────────────────────────────────────────────────────────────────┤
│ 1. cache.fetch_data(:property, {reference, ...params}) do       │
│      provider.find(reference, params)                           │
│    end                                                          │
│                                                                  │
│    Cache key: pwb:external_feed:1:resales_online:property:...   │
│    TTL: 86400s (24 hours)                                        │
└─────────────────────────────────────────────────────────────────┘
         │
         ├─ If cached: return cached NormalizedProperty
         │
         └─ If NOT cached:
            │
            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Providers::ResalesOnline#find(reference, p)  │
├─────────────────────────────────────────────────────────────────┤
│ 1. Build details query with:                                    │
│    - reference (property ID)                                    │
│    - api_key, api_id from config                                │
│    - locale language code                                       │
│                                                                  │
│ 2. fetch_json(DETAILS_URL?params)                               │
│    - Makes HTTP request to property details endpoint            │
│    - Handles errors                                             │
│                                                                  │
│ 3. Check property status:                                       │
│    - if "Off Market" or "Sold"                                  │
│      → normalize but set status :sold or :unavailable           │
│    - else → status :available                                   │
│                                                                  │
│ 4. normalize_property(response_data, params)                    │
│    → Returns NormalizedProperty with 80+ attributes             │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ Pwb::ExternalFeed::Manager#similar(property, params)            │
├─────────────────────────────────────────────────────────────────┤
│ Builds search params from property:                             │
│ {                                                               │
│   locale: params[:locale],                                      │
│   listing_type: property.listing_type,                          │
│   property_types: [property.property_type_raw],                 │
│   location: property.city,                                      │
│   min_price: property.price * 0.7,                              │
│   max_price: property.price * 1.3,                              │
│   min_bedrooms: property.bedrooms,                              │
│   sort: :newest,                                                │
│   per_page: (limit || 8) + 1                                    │
│ }                                                               │
│                                                                  │
│ Calls search(similar_params)                                    │
│ Filters out the current property                                │
│ Returns first N properties (excluding self)                     │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│ View: app/views/pwb/site/external_listings/show.html.erb        │
├─────────────────────────────────────────────────────────────────┤
│ • Display property details from @listing (NormalizedProperty)   │
│   - Gallery from @listing.images                                │
│   - Title, description                                          │
│   - Location: city, region, country                             │
│   - Details: bedrooms, bathrooms, built_area                    │
│   - Price: @listing.formatted_price                             │
│   - Features grouped by category                                │
│   - Energy rating                                               │
│ • Display similar properties from @similar                      │
│   - Show 6 related properties as cards                          │
│   - User can click to view more details                         │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓ User sees property details page
```

---

## 5. Configuration Data Structure

### In Database (JSON Column)

```
pwb_websites.external_feed_config (JSON)
│
├── api_key: "secret_key_from_provider"
├── api_id_sales: "1234"
├── api_id_rentals: "5678"
├── p1_constant: "1014359"
├── default_country: "Spain"
├── image_count: 0
├── cache_ttl_search: 3600
├── cache_ttl_property: 86400
├── cache_ttl_similar: 21600
├── cache_ttl_static: 604800
├── results_per_page: 24
├── default_locale: "en"
├── supported_locales: ["en", "es", "fr", "de", "nl"]
├── locations: [
│   {value: "Marbella", label: "Marbella"},
│   {value: "Estepona", label: "Estepona"},
│   ...
│ ]
├── property_types: [
│   {value: "1-1", label: "Apartment", subtypes: [...]},
│   {value: "2-1", label: "House", subtypes: [...]},
│   ...
│ ]
└── features: {
    pool: {param: "1Pool1", label: "Swimming Pool"},
    sea_views: {param: "1Views1", label: "Sea Views"},
    ...
  }
```

---

## 6. Caching Strategy

```
Manager.search(params)
  │
  ├─ normalize_params(params)
  │
  ├─ cache_key = "pwb:external_feed:1:resales_online:search:{hash}"
  │
  ├─ Rails.cache.fetch(key, expires_in: 3600.seconds) do
  │    provider.search(normalized_params)
  │  end
  │
  ├─ If hit: return cached NormalizedSearchResult (fresh)
  └─ If miss: execute provider.search, cache result, return
```

### Cache Keys by Operation

```
Search:         pwb:external_feed:1:resales_online:search:a1b2c3d4
Property:       pwb:external_feed:1:resales_online:property:hash
Similar:        pwb:external_feed:1:resales_online:similar:hash
Locations:      pwb:external_feed:1:resales_online:locations:hash
PropertyTypes:  pwb:external_feed:1:resales_online:property_types:hash
```

### Cache Invalidation

```
Website.clear_external_feed_cache
  │
  ├─ external_feed.invalidate_cache
  │    │
  │    └─ cache.invalidate_all
  │        │
  │        └─ Rails.cache.delete_matched(
  │             "pwb:external_feed:1:*"
  │           )
  │
  └─ All keys for this website deleted
```

---

## 7. Provider Registration at Startup

```
Rails boot
  │
  ├─ /config/initializers/external_feeds.rb runs
  │
  ├─ Rails.application.config.to_prepare do
  │    Pwb::ExternalFeed::Registry.register(
  │      Pwb::ExternalFeed::Providers::ResalesOnline
  │    )
  │  end
  │
  └─ Registry.providers = {
      resales_online: ResalesOnline class
    }
```

Later, when Manager instantiates provider:

```
Manager.build_provider
  │
  ├─ provider_name = @website.external_feed_provider.to_sym
  │   (e.g., :resales_online)
  │
  ├─ provider_class = Registry.find(provider_name)
  │   (looks up in @providers hash)
  │
  ├─ provider_class.new(@website, @config)
  │   (instantiate ResalesOnline with website and config)
  │
  └─ @provider = instance
```

---

## Summary: Configuration Layers

```
┌─────────────────────────────────────────────────────┐
│ Database Layer                                      │
│ (pwb_websites table)                               │
│                                                     │
│ external_feed_enabled: boolean                      │
│ external_feed_provider: string                      │
│ external_feed_config: json                          │
└─────────────────────────────────────────────────────┘
         │
         ↓ Loaded by
┌─────────────────────────────────────────────────────┐
│ Model Layer                                         │
│ (Pwb::Website)                                      │
│                                                     │
│ website.external_feed_enabled?                      │
│ website.external_feed_config                        │
│ website.configure_external_feed()                   │
└─────────────────────────────────────────────────────┘
         │
         ↓ Used by
┌─────────────────────────────────────────────────────┐
│ Service Layer                                       │
│ (Pwb::ExternalFeed::Manager)                        │
│                                                     │
│ manager = website.external_feed                     │
│ manager.search(params)                              │
│ manager.filter_options()                            │
│ manager.locations()                                 │
└─────────────────────────────────────────────────────┘
         │
         ├─ Uses Provider
         │  (Pwb::ExternalFeed::Providers::ResalesOnline)
         │   │
         │   ├─ search(params)                        │
         │   ├─ find(reference)                       │
         │   ├─ similar(property)                     │
         │   └─ locations()                           │
         │
         ├─ Uses Cache
         │  (Pwb::ExternalFeed::CacheStore)
         │
         └─ Returns NormalizedProperty / NormalizedSearchResult
         │
         ↓ Passed to
┌─────────────────────────────────────────────────────┐
│ Controller Layer                                    │
│ (Pwb::Site::ExternalListingsController)            │
│                                                     │
│ @result = external_feed.search()                    │
│ @filter_options = external_feed.filter_options()   │
└─────────────────────────────────────────────────────┘
         │
         ↓ Rendered by
┌─────────────────────────────────────────────────────┐
│ View Layer                                          │
│ (app/views/site/external_listings/)                │
│                                                     │
│ Display: @result.properties                         │
│ Filters: @filter_options                            │
│ Details: @listing, @similar                         │
└─────────────────────────────────────────────────────┘
```

