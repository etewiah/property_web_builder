# Property Types in Search Filters: External vs Internal Listings

## Executive Summary

Property types are handled differently for **external listings** and **internal listings** in PropertyWebBuilder. External listings populate property types dynamically from external APIs or provider configuration, while internal listings use a fixed FieldKey system stored in the database.

---

## Table of Contents

1. [External Listings Data Flow](#external-listings-data-flow)
2. [Internal Listings Data Flow](#internal-listings-data-flow)
3. [Key Differences](#key-differences)
4. [Data Structure](#data-structure)
5. [Configuration](#configuration)
6. [Code References](#code-references)

---

## External Listings Data Flow

### 1. How Property Types Are Populated

**Path:** `GET /external/buy` or `GET /external/rent`

#### Step 1: Controller Loads Data
**File:** `/app/controllers/pwb/site/external_listings_controller.rb` (Lines 81-87)

```ruby
def index
  @search_params = search_params
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)  # ← Property types loaded here
  @search_config = Pwb::SearchConfig.new(current_website, listing_type: listing_type)
end
```

#### Step 2: Manager Retrieves Property Types
**File:** `/app/services/pwb/external_feed/manager.rb` (Lines 121-133)

```ruby
def filter_options(params = {})
  listing_type = params[:listing_type] || :sale
  search_cfg = search_config_for(listing_type)

  {
    locations: locations(params),
    property_types: property_types(params),  # ← Calls provider's property_types method
    features: features(params),
    # ... other filter options
  }
end

def property_types(params = {})
  return [] unless configured?

  cache.fetch_data(:property_types, params) do
    provider.property_types(params)  # ← Fetches from provider with caching
  end
rescue Pwb::ExternalFeed::Error => e
  Rails.logger.error("[ExternalFeed::Manager] Property types error: #{e.message}")
  []
end
```

#### Step 3: Provider Returns Property Types
**File:** `/app/services/pwb/external_feed/providers/resales_online.rb` (Lines 117-120, 489-515)

```ruby
def property_types(params = {})
  # Return configured property types or defaults
  config[:property_types] || default_property_types
end

def default_property_types
  [
    {
      value: "1-1",
      label: "Apartment",
      subtypes: [
        { value: "1-2", label: "Ground Floor Apartment" },
        { value: "1-4", label: "Middle Floor Apartment" },
        { value: "1-5", label: "Top Floor Apartment" },
        { value: "1-6", label: "Penthouse" },
        { value: "1-7", label: "Duplex" }
      ]
    },
    {
      value: "2-1",
      label: "House",
      subtypes: [
        { value: "2-2", label: "Detached Villa" },
        { value: "2-4", label: "Semi-Detached House" },
        { value: "2-5", label: "Townhouse" },
        { value: "2-6", label: "Finca / Country House" }
      ]
    },
    { value: "3-1", label: "Plot / Land" },
    { value: "4-1", label: "Commercial" }
  ]
end
```

#### Step 4: View Renders Property Types Checkboxes
**File:** `/app/views/pwb/site/external_listings/_search_form.html.erb` (Lines 61-76)

```erb
<%# Property Types %>
<div class="mb-4">
  <label class="block text-sm font-medium text-gray-700 mb-2">
    <%= t("external_feed.search.property_type", default: "Property Type") %>
  </label>
  <div class="space-y-2 max-h-40 overflow-y-auto">
    <% filter_options[:property_types]&.each do |pt| %>
      <label class="flex items-center">
        <input type="checkbox" name="property_types[]" value="<%= pt[:value] %>"
               <%= 'checked' if search_params[:property_types]&.include?(pt[:value].to_s) %>
               class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
        <span class="ml-2 text-sm text-gray-700"><%= pt[:label] %></span>
      </label>
    <% end %>
  </div>
</div>
```

### 2. Where Values Come From

**Sources (in order of precedence):**

1. **Provider Configuration** (`external_feed_config` JSON)
   - If the website's `external_feed_config` includes `property_types` key
   - Set by site admin through configuration UI

2. **Provider Defaults** (hardcoded)
   - For Resales Online: `default_property_types()` method
   - Maps provider-specific codes (e.g., "1-1", "2-1") to user-friendly labels

3. **Empty Array** (fallback)
   - If provider not configured or unavailable

### 3. How External Feed Provides Data

**For Resales Online Provider:**

The provider returns property types in a **standard format** (always returns configured or default property types):

```ruby
# Format for filter dropdown
[
  { value: "provider-code", label: "Display Label", subtypes: [...] },
  # ...
]
```

When searching, the user-selected property type values are passed to the API query:

**File:** `/app/services/pwb/external_feed/providers/resales_online.rb` (Lines 206-210)

```ruby
# Property types
if params[:property_types]&.any?
  types = params[:property_types].is_a?(Array) ? params[:property_types] : [params[:property_types]]
  query[:p_PropertyTypes] = types.join(",")  # Send to Resales Online API
end
```

### 4. Caching

All property type data is cached to reduce API calls:

**File:** `/app/services/pwb/external_feed/cache_store.rb`

- Cache key: `[:property_types, {params}]`
- Default TTL: 24 hours (configurable)
- Scoped per website (multi-tenancy aware)

---

## Internal Listings Data Flow

### 1. How Property Types Are Populated

**Path:** `GET /search/for-sale` or `GET /search/for-rent`

#### Step 1: Controller Sets Up Common Inputs
**File:** `/app/controllers/concerns/search/form_setup.rb` (Lines 19-26)

```ruby
def set_common_search_inputs
  ActsAsTenant.with_tenant(@current_website) do
    @property_types = PwbTenant::FieldKey.get_options_by_tag("property-types")
    @property_types.unshift OpenStruct.new(value: "", label: "")
    # ... other field keys
  end
end
```

#### Step 2: View Renders Property Types Dropdown
**File:** `/app/views/pwb/search/_search_form_for_sale.html.erb` (Lines 41-55)

```erb
<%# Property Type %>
<div>
  <label for="search_property_type" class="block text-sm font-medium text-gray-700 mb-1">
    <%= I18n.t("simple_form.labels.search.property_type", default: "Property Type") %>
  </label>
  <select name="search[property_type]" id="search_property_type"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm">
    <option value=""><%= I18n.t("search.any", default: "Any") %></option>
    <% @property_types&.each do |pt| %>
      <option value="<%= pt.value %>" <%= 'selected' if @search_defaults["property_type"].to_s == pt.value.to_s %>>
        <%= pt.label %>
      </option>
    <% end %>
  </select>
</div>
```

### 2. Where Values Come From

**Sources:**

1. **Database** - `PwbTenant::FieldKey` table
   - Row tag: `"property-types"`
   - One row per property type (apartment, house, villa, etc.)
   - Each website has its own set of property types
   - Site admin can add/remove/reorder through admin UI

2. **Structure:**
   - `value`: Unique identifier (e.g., "apartment")
   - `label`: Display name (e.g., "Apartment")
   - `tag`: "property-types" (used for filtering)

---

## Key Differences

| Aspect | External Listings | Internal Listings |
|--------|-------------------|-------------------|
| **Source** | External API or provider config | Database (FieldKey table) |
| **Where fetched** | In controller via Manager | In controller via FieldKey model |
| **Mutability** | Read-only (unless config updated) | Site admin can add/edit via UI |
| **Format** | Array of hashes with `value` and `label` | OpenStruct objects with `value` and `label` |
| **Scoping** | Per website (external_feed_config) | Per website (ActsAsTenant) |
| **Caching** | Cached by Manager (24hr default) | No caching (loaded from DB each time) |
| **Input Type** | Checkboxes (multiple select) | Single dropdown |
| **Filtering** | Array of values in `property_types[]` param | Single value in `property_type` param |
| **Hardcoded** | Yes, provider defaults | No, completely user-configurable |

---

## Data Structure

### External Listings Property Type Structure

```ruby
{
  value: "1-1",              # Provider code (used in API query)
  label: "Apartment",        # User-facing label
  subtypes: [                # Optional sub-categories
    {
      value: "1-2",
      label: "Ground Floor Apartment"
    }
  ]
}
```

### Internal Listings Property Type Structure

```ruby
OpenStruct {
  value: "apartment",        # Unique identifier
  label: "Apartment",        # User-facing label
  # (Other FieldKey attributes like description, position, etc.)
}
```

---

## Configuration

### External Listings Configuration

**Location:** `websites.external_feed_config` (JSON column)

```json
{
  "api_key": "...",
  "api_id_sales": "...",
  "api_id_rentals": "...",
  "property_types": [
    {
      "value": "custom-code",
      "label": "Custom Type"
    }
  ]
}
```

If `property_types` key is present, it overrides the provider's defaults.

### Internal Listings Configuration

**Location:** Database table `field_keys` (ActsAsTenant scoped)

- No hardcoded defaults
- Completely database-driven
- Site admin manages through Admin UI

---

## Code References

### Key Files

#### External Listings
- **Controller:** `/app/controllers/pwb/site/external_listings_controller.rb`
  - `index` action (lines 79-109)
  - `property_types` action (lines 174-178) - API endpoint
  - `search_params` method (lines 284-319)

- **Manager:** `/app/services/pwb/external_feed/manager.rb`
  - `filter_options` method (lines 148-176)
  - `property_types` method (lines 121-133)

- **Provider Base:** `/app/services/pwb/external_feed/base_provider.rb`
  - `property_types` abstract method (lines 68-73)

- **Resales Online Provider:** `/app/services/pwb/external_feed/providers/resales_online.rb`
  - `property_types` method (lines 117-120)
  - `default_property_types` method (lines 489-515)

- **View:** `/app/views/pwb/site/external_listings/_search_form.html.erb`
  - Property type checkboxes (lines 61-76)

#### Internal Listings
- **Controller Concern:** `/app/controllers/concerns/search/form_setup.rb`
  - `set_common_search_inputs` method (lines 19-26)

- **View:** `/app/views/pwb/search/_search_form_for_sale.html.erb`
  - Property type dropdown (lines 41-55)

---

## Search Filter Flow

### External Listings Search
1. User selects property types (checkboxes) → form submits
2. Controller extracts `property_types[]` params
3. Manager calls `filter_options()` to populate dropdowns
4. Provider calls API with selected property type codes
5. Results filtered by external API

### Internal Listings Search
1. User selects property type (dropdown) → form submits
2. Controller extracts `property_type` param
3. SearchConfig loads from database via FieldKey
4. PropertyFiltering concern applies filter to AR relation
5. Results filtered by database query

---

## API Endpoints

### External Listings Property Types Endpoint

**Route:** `GET /external_listings/property_types`

**File:** `/app/controllers/pwb/site/external_listings_controller.rb` (Lines 174-178)

```ruby
def property_types
  @property_types = external_feed.property_types(locale: I18n.locale)
  render json: @property_types
end
```

**Response:**
```json
[
  {
    "value": "1-1",
    "label": "Apartment",
    "subtypes": [...]
  },
  ...
]
```

### Similar Endpoint (uses property type)

**Route:** `GET /external_listings/:reference/similar`

The provider uses the property's `property_type_raw` value to find similar properties:

**File:** `/app/services/pwb/external_feed/providers/resales_online.rb` (Lines 90-109)

```ruby
def similar(property, params = {})
  limit = params[:limit] || 8
  search_params = {
    property_types: [property.property_type_raw].compact,
    # ... other params
  }
  result = search(search_params)
  result.properties.reject { |p| p.reference == property.reference }.first(limit)
end
```

---

## Summary Table

| Component | External | Internal |
|-----------|----------|----------|
| **Endpoint** | `/external_listings` | `/search/for-sale`, `/search/for-rent` |
| **Controller** | `ExternalListingsController` | `SearchController` |
| **Data Source** | Provider API or config | Database FieldKey |
| **Form Input** | Checkboxes (multiple) | Dropdown (single) |
| **Search Param** | `property_types[]` | `property_type` |
| **Filter Logic** | Provider sends to API | AR relation filter |
| **Caching** | Manager cache | None (per-request) |
| **Admin Config** | JSON config field | Database UI |

---

## Key Insights

1. **Completely Separate Systems**
   - External and internal listings use different property type systems
   - No shared database table for external property types
   - External types are API-driven, internal are database-driven

2. **External Types Are Provider-Specific**
   - Each provider (Resales Online, Kyero, etc.) has own type mapping
   - Defaults are hardcoded in provider classes
   - Can be overridden via website configuration

3. **Internal Types Are User-Managed**
   - Site admins can create any custom property types
   - No predefined list
   - Completely flexible and database-backed

4. **Filtering Strategy Differs**
   - External: Client sends values to external API
   - Internal: Server filters database results

5. **Caching Only for External**
   - External feed data is cached to reduce API calls
   - Internal listings use live database queries
   - External cache is 24 hours by default

