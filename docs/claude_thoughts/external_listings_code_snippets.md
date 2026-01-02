# External Listings Feature - Code Snippets & Common Tasks

## Essential Patterns & Code Examples

### 1. Accessing the External Feed in Views

**In Controller:**
```ruby
# ExternalListingsController
def index
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)
end

# Helper method
def external_feed
  @external_feed ||= current_website.external_feed
end
```

**In View - Display Results:**
```erb
<% if @result.any? %>
  <% @result.properties.each do |property| %>
    <%= render "property_card", property: property %>
  <% end %>
<% end %>
```

**In View - Show Results Range:**
```erb
<%= t("external_feed.search.showing",
      range: @result.results_range,
      default: "Showing %{range} properties") %>
<!-- Outputs: "Showing 1-24 of 150 properties" -->
```

---

### 2. Searching for Properties

**Basic Search:**
```ruby
# From controller
result = external_feed.search(
  listing_type: :sale,
  location: "Marbella",
  min_price: 100000,
  max_price: 500000,
  page: 1,
  per_page: 24
)

# Use result
result.properties.each do |property|
  puts property.title
  puts property.formatted_price
end
```

**Search with Full Parameters:**
```ruby
result = external_feed.search({
  listing_type: :sale,           # :sale or :rental
  location: "Marbella",           # City name
  min_price: 100000,              # In euros/original currency
  max_price: 500000,              # In euros/original currency
  min_bedrooms: 2,                # Minimum bedrooms
  max_bedrooms: 5,                # Maximum bedrooms
  min_bathrooms: 1,               # Minimum bathrooms
  max_bathrooms: 3,               # Maximum bathrooms
  min_area: 100,                  # Minimum m² built area
  max_area: 300,                  # Maximum m² built area
  property_types: ["apartment", "house"], # Array of types
  features: ["pool", "garden"],   # Array of feature codes
  sort: :price_asc,               # :price_asc, :price_desc, :newest, :updated
  page: 1,                        # 1-indexed
  per_page: 24,                   # Results per page
  locale: :en                     # Language code
})
```

**Accessing Search Results:**
```ruby
result.properties       # Array<NormalizedProperty>
result.total_count      # Total matching (may > current page)
result.current_page     # Current page number
result.total_pages      # Total pages
result.per_page         # Results per page
result.results_range    # "X-Y of Z" string
result.next_page        # Next page number or nil
result.prev_page        # Previous page number or nil
result.has_next_page?   # Boolean
result.error?           # Boolean if search failed
result.error            # Error message if failed
result.empty?, result.any?  # Collection checks
```

---

### 3. Finding a Single Property

**Get Property Details:**
```ruby
property = external_feed.find(
  "REF123456",  # Provider's reference code
  listing_type: :sale,
  locale: :en
)

if property.nil?
  # Not found or not available
  render "unavailable", status: :gone
else
  # Display property
  render :show, locals: { property: property }
end
```

**Checking Property Status:**
```ruby
property = external_feed.find(reference)

case property.status
when :available
  # Show full details
when :sold
  message = t("external_feed.status.sold", default: "This property has been sold")
when :rented
  message = t("external_feed.status.rented", default: "This property has been rented")
else
  message = t("external_feed.status.unavailable", default: "This property is no longer available")
end
```

---

### 4. Getting Similar Properties

**Find Similar Properties:**
```ruby
# In controller
property = external_feed.find(reference)
similar = external_feed.similar(property, limit: 6, locale: I18n.locale)

# In view
<% if @similar.present? && @similar.any? %>
  <%= render "similar", properties: @similar %>
<% end %>
```

**How Similar Works:**
```ruby
# Internally, similar() creates search params from the property:
# - Same listing_type
# - Same property type
# - Same city/location
# - Price range ±30% around current property
# - Min bedrooms = property bedrooms
# - Excludes the property itself
```

---

### 5. Getting Filter Options

**Load All Filter Options:**
```ruby
# In controller
@filter_options = external_feed.filter_options(locale: I18n.locale)

# Access options in view
<select name="location">
  <% @filter_options[:locations].each do |loc| %>
    <option value="<%= loc[:value] %>">
      <%= loc[:label] %>
    </option>
  <% end %>
</select>
```

**Filter Options Structure:**
```ruby
{
  locations: [
    { value: "Marbella", label: "Marbella" },
    { value: "Estepona", label: "Estepona" },
    # ...
  ],
  property_types: [
    { value: "apartment", label: "Apartment" },
    { value: "house", label: "House" },
    # ...
  ],
  listing_types: [
    { value: "sale", label: "For Sale" },
    { value: "rental", label: "For Rent" }
  ],
  sort_options: [
    { value: "price_asc", label: "Price (Low to High)" },
    { value: "price_desc", label: "Price (High to Low)" },
    { value: "newest", label: "Newest First" },
    { value: "updated", label: "Recently Updated" }
  ]
}
```

---

### 6. Displaying Properties in Views

**Property Card:**
```erb
<article class="bg-white rounded-lg shadow-md">
  <a href="<%= external_listing_path(
        reference: property.reference, 
        listing_type: property.listing_type) %>">
    <img src="<%= property.main_image %>" alt="<%= property.title %>">
    <span class="absolute top-2 left-2 badge">
      <%= t("external_feed.listing_type.#{property.listing_type}", 
            default: "For Sale") %>
    </span>
  </a>

  <div class="p-4">
    <p class="text-xl font-bold">
      <%= property.formatted_price %>
    </p>
    <h3><%= property.title %></h3>
    <p><%= property.location %>, <%= property.province %></p>
    
    <% if property.bedrooms %>
      <span><%= property.bedrooms %> beds</span>
    <% end %>
    <% if property.bathrooms %>
      <span><%= property.bathrooms %> baths</span>
    <% end %>
    <% if property.built_area %>
      <span><%= property.built_area %> m²</span>
    <% end %>
  </div>
</article>
```

**Property Detail Page:**
```erb
<div class="lg:grid lg:grid-cols-2">
  <!-- Main Content -->
  <div>
    <!-- Image Gallery -->
    <img id="main-image" src="<%= @property.main_image %>" alt="">
    <div class="thumbnails">
      <% @property.images.each do |img| %>
        <img src="<%= img[:thumbnail] %>" 
             onclick="document.getElementById('main-image').src='<%= img[:url] %>'">
      <% end %>
    </div>

    <!-- Title & Location -->
    <h1><%= @property.title %></h1>
    <p><%= [@property.location, @property.province, @property.country].compact.join(", ") %></p>

    <!-- Key Features -->
    <div class="grid grid-cols-4">
      <% if @property.bedrooms %>
        <div><p class="text-2xl"><%= @property.bedrooms %></p>
          <p><%= t("external_feed.features.bedrooms") %></p></div>
      <% end %>
      <% if @property.bathrooms %>
        <div><p class="text-2xl"><%= @property.bathrooms %></p>
          <p><%= t("external_feed.features.bathrooms") %></p></div>
      <% end %>
      <% if @property.built_area %>
        <div><p class="text-2xl"><%= number_with_delimiter(@property.built_area) %></p>
          <p><%= t("external_feed.features.built_area_m2") %></p></div>
      <% end %>
    </div>

    <!-- Description -->
    <h2><%= t("external_feed.property.description") %></h2>
    <div class="prose"><%= simple_format(@property.description) %></div>

    <!-- Features -->
    <% if @property.features.any? %>
      <h2><%= t("external_feed.property.features") %></h2>
      <ul>
        <% @property.features.each do |feature| %>
          <li><%= feature %></li>
        <% end %>
      </ul>
    <% end %>

    <!-- Energy Rating -->
    <% if @property.energy_rating %>
      <div>
        <h2><%= t("external_feed.property.energy") %></h2>
        <span class="rating <%= energy_class(@property.energy_rating) %>">
          <%= @property.energy_rating %>
        </span>
      </div>
    <% end %>

    <!-- Map -->
    <% if @property.latitude && @property.longitude %>
      <div id="property-map" 
           data-latitude="<%= @property.latitude %>"
           data-longitude="<%= @property.longitude %>">
        <!-- Map rendered by JavaScript -->
      </div>
    <% end %>
  </div>

  <!-- Sidebar -->
  <div class="sticky">
    <!-- Price Card -->
    <div class="bg-white shadow p-6">
      <p class="text-3xl font-bold"><%= @property.formatted_price %></p>
      <% if @property.listing_type == :rental && @property.price_frequency %>
        <p class="text-sm">/ <%= t("external_feed.frequency.#{@property.price_frequency}") %></p>
      <% end %>
      <% if @property.price_reduced? %>
        <p class="line-through text-gray-500">
          <%= number_to_currency(@property.original_price, unit: @property.currency, precision: 0) %>
        </p>
      <% end %>
      <button class="w-full bg-blue-600 text-white py-2 rounded">
        <%= t("external_feed.property.contact_agent") %>
      </button>
    </div>

    <!-- Details Card -->
    <div class="bg-white shadow p-6">
      <h3><%= t("external_feed.property.details") %></h3>
      <dl>
        <div class="flex justify-between">
          <dt><%= t("external_feed.property.type") %></dt>
          <dd><%= t("external_feed.property_types.#{@property.property_type}") %></dd>
        </div>
        <div class="flex justify-between">
          <dt><%= t("external_feed.features.bedrooms") %></dt>
          <dd><%= @property.bedrooms %></dd>
        </div>
        <div class="flex justify-between">
          <dt><%= t("external_feed.features.bathrooms") %></dt>
          <dd><%= @property.bathrooms %></dd>
        </div>
      </dl>
    </div>
  </div>
</div>

<!-- Similar Properties -->
<% if @similar.any? %>
  <h2><%= t("external_feed.property.similar") %></h2>
  <%= render "similar", properties: @similar %>
<% end %>
```

---

### 7. Using the Filter Form with Stimulus

**HTML Setup:**
```erb
<div data-controller="filter" data-filter-submit-on-change-value="true">
  <div class="filter-header">
    <h2><%= t("external_feed.search.filters") %></h2>
    <span data-filter-target="count">No filters</span>
    <button data-action="filter#clear" class="text-sm">
      <%= t("external_feed.search.clear_filters") %>
    </button>
  </div>

  <form data-filter-target="form" 
        action="<%= external_listings_path %>"
        method="get"
        data-action="change->filter#submitOnChange">
    
    <!-- Filters -->
    <div class="mb-4">
      <label><%= t("external_feed.search.location") %></label>
      <select name="location" data-filter-target="input">
        <option><%= t("external_feed.search.any_location") %></option>
        <% @filter_options[:locations].each do |loc| %>
          <option value="<%= loc[:value] %>" 
                  <%= selected(loc[:value], @search_params[:location]) %>>
            <%= loc[:label] %>
          </option>
        <% end %>
      </select>
    </div>

    <div class="mb-4">
      <label><%= t("external_feed.search.price_range") %></label>
      <input type="number" name="min_price" 
             value="<%= @search_params[:min_price] %>"
             data-filter-target="input"
             placeholder="Min">
      <input type="number" name="max_price" 
             value="<%= @search_params[:max_price] %>"
             data-filter-target="input"
             placeholder="Max">
    </div>

    <button type="submit" class="w-full bg-blue-600 text-white py-2">
      <%= t("external_feed.search.apply_filters") %>
    </button>
  </form>
</div>
```

**JavaScript Behavior:**
- User changes any filter (select, input, checkbox, radio)
- Stimulus controller captures `change` event
- `submitOnChange()` is called
- `updateCount()` updates the filter count display
- If `submitOnChange` value is true, form auto-submits after 300ms debounce
- Prevents excessive requests while user is adjusting filters

---

### 8. Translation Implementation

**In Views - Simple Keys:**
```erb
<h1><%= t("external_feed.search.title", default: "Property Search") %></h1>
<p><%= t("external_feed.search.subtitle", default: "Browse available properties...") %></p>
```

**In Views - With Interpolation:**
```erb
<p><%= t("external_feed.search.showing",
        range: @result.results_range,
        default: "Showing %{range} properties") %></p>
<!-- Outputs: "Showing 1-24 of 150 properties" -->
```

**In Views - Dynamic Keys:**
```erb
<!-- Property types -->
<%= t("external_feed.property_types.#{property.property_type}", 
      default: property.property_type.titleize) %>
<!-- Outputs: "Apartment", "House", etc. based on property.property_type value -->

<!-- Rental frequency -->
<%= t("external_feed.frequency.#{property.price_frequency}", 
      default: property.price_frequency.to_s) %>
<!-- Outputs: "Month", "Week", "Day" based on frequency -->

<!-- Listing type -->
<%= t("external_feed.listing_type.#{property.listing_type}", 
      default: "For Sale") %>
<!-- Outputs: "For Sale" or "For Rent" -->
```

**In Controller - Passing to View:**
```ruby
@filter_options = external_feed.filter_options(locale: I18n.locale)
# Returns pre-translated option labels

# Filter options include pre-translated sort options:
sort_options: [
  { value: "price_asc", label: "Price (Low to High)" },  # Already translated
  { value: "price_desc", label: "Price (High to Low)" },
  # ...
]
```

**Property Type Translation Pattern:**
```ruby
# In provider or view:
property_types: [
  { value: "apartment", label: t("external_feed.property_types.apartment") },
  { value: "house", label: t("external_feed.property_types.house") },
  { value: "villa", label: t("external_feed.property_types.villa") },
]
```

---

### 9. Admin Configuration - Setting Up External Feed

**In Admin View:**
```erb
<h2>External Feed Configuration</h2>

<%= form_with model: @website, url: site_admin_external_feed_path, method: :patch do |f| %>
  <!-- Enable/disable -->
  <div class="mb-4">
    <%= f.label :external_feed_enabled %>
    <%= f.check_box :external_feed_enabled %>
  </div>

  <!-- Provider selection -->
  <div class="mb-4">
    <%= f.label :external_feed_provider, "Provider" %>
    <%= f.select :external_feed_provider, 
                 options_for_select(@providers.map { |p| [p[:display_name], p[:name]] }),
                 { include_blank: "None" } %>
  </div>

  <!-- Provider config fields -->
  <% if @providers.any? %>
    <fieldset>
      <legend>Provider Configuration</legend>
      
      <% @providers.each do |provider| %>
        <% provider[:config_fields].each do |field| %>
          <div class="mb-4">
            <%= label_tag "pwb_website[external_feed_config][#{field[:key]}]", field[:label] %>
            
            <% if field[:type] == :password %>
              <%= password_field_tag "pwb_website[external_feed_config][#{field[:key]}]",
                  @website.external_feed_config&.dig(field[:key].to_s) ? "••••••••••••" : "",
                  class: "form-control" %>
            <% else %>
              <%= text_field_tag "pwb_website[external_feed_config][#{field[:key]}]",
                  @website.external_feed_config&.dig(field[:key].to_s),
                  class: "form-control" %>
            <% end %>
            
            <% if field[:help] %>
              <small><%= field[:help] %></small>
            <% end %>
            <% if field[:required] %>
              <span class="text-red-600">*</span>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </fieldset>
  <% end %>

  <!-- Status info -->
  <% if @feed_status[:configured] %>
    <div class="alert alert-info">
      <strong>Provider:</strong> <%= @feed_status[:provider_display_name] %>
      <strong>Status:</strong> <%= @feed_status[:enabled] ? "Enabled" : "Configured but unavailable" %>
    </div>
  <% end %>

  <!-- Buttons -->
  <div class="mt-6">
    <%= f.submit "Save Configuration", class: "btn btn-primary" %>
    <%= link_to "Test Connection", site_admin_external_feed_test_connection_path, 
                method: :post, class: "btn btn-secondary" %>
    <%= link_to "Clear Cache", site_admin_external_feed_clear_cache_path, 
                method: :post, class: "btn btn-warning" %>
  </div>
<% end %>
```

**Controller Parameter Handling:**
```ruby
def external_feed_params
  # Use pwb_website key (from form_with model: @website)
  param_key = params.key?(:pwb_website) ? :pwb_website : :website
  
  permitted = params.require(param_key).permit(
    :external_feed_enabled,
    :external_feed_provider
  )
  
  # Handle config hash specially for password masking
  if params[param_key][:external_feed_config].present?
    config_params = params[param_key][:external_feed_config].to_unsafe_h
    
    # Filter out empty values and password placeholder
    config_params = config_params.reject { |_k, v| v.blank? || v == "••••••••••••" }
    
    # Merge with existing config to preserve unchanged secrets
    if @website.external_feed_config.present?
      existing_config = @website.external_feed_config.dup
      config_params.each do |key, value|
        existing_config[key] = value unless value == "••••••••••••"
      end
      permitted[:external_feed_config] = existing_config
    else
      permitted[:external_feed_config] = config_params
    end
  end
  
  permitted
end
```

---

### 10. Caching & Performance

**Clear Cache from Controller:**
```ruby
# Manually clear all cached results
@website.external_feed.invalidate_cache

# After configuration change
if @website.update(external_feed_params)
  @website.external_feed.invalidate_cache
  redirect_to site_admin_external_feed_path, notice: "Settings saved"
end
```

**Cache Store Operations (Internal):**
```ruby
# In manager or service
@cache.fetch_data(:search, normalized_params) do
  provider.search(normalized_params)
end

@cache.fetch_data(:property, { reference: ref, locale: :en }) do
  provider.find(ref, locale: :en)
end
```

---

### 11. Error Handling Examples

**Search Error Handling:**
```erb
<% if @result.error? %>
  <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
    <p class="text-sm text-yellow-700">
      <%= t("external_feed.search.error", 
            default: "Unable to load properties at this time. Please try again later.") %>
    </p>
  </div>
<% end %>
```

**Property Not Found:**
```ruby
def show
  @listing = external_feed.find(params[:reference])
  
  if @listing.nil?
    render "pwb/props/not_found", status: :not_found
    return
  end
  
  unless @listing.available?
    @status_message = case @listing.status
                      when :sold then t("external_feed.status.sold", default: "This property has been sold")
                      when :rented then t("external_feed.status.rented", default: "This property has been rented")
                      else t("external_feed.status.unavailable", default: "This property is no longer available")
                      end
    render "unavailable", status: :gone
    return
  end
  
  # Property is available, show details
end
```

**Feed Configuration Check:**
```ruby
def ensure_feed_enabled
  unless external_feed.configured?
    redirect_to root_path, alert: t("external_feed.not_configured", default: "External listings are not available")
    return
  end
  
  unless external_feed.enabled?
    Rails.logger.warn("[ExternalListings] Feed configured but not available for website #{current_website.id}")
    # Still allow access, but results may be empty
  end
end
```

---

### 12. Creating a New Provider

**Step 1: Create Provider Class**
```ruby
# app/services/pwb/external_feed/providers/my_provider.rb

module Pwb
  module ExternalFeed
    module Providers
      class MyProvider < BaseProvider
        API_URL = "https://api.example.com"
        
        def self.provider_name
          :my_provider
        end
        
        def self.display_name
          "My Property Provider"
        end
        
        def search(params)
          # Implement search
          # Return NormalizedSearchResult
        end
        
        def find(reference, params = {})
          # Implement find by reference
          # Return NormalizedProperty
        end
        
        def similar(property, params = {})
          # Implement similar properties search
          # Return Array<NormalizedProperty>
        end
        
        def locations(params = {})
          # Return available locations
          # Return Array<{value:, label:}>
        end
        
        def property_types(params = {})
          # Return available property types
          # Return Array<{value:, label:}>
        end
        
        def available?
          # Check if provider is accessible
          # Return Boolean
        end
        
        protected
        
        def required_config_keys
          [:api_key, :api_id]  # Define what config is required
        end
        
        private
        
        def fetch_api(endpoint, query_params)
          # Implement API call logic
          # Handle errors and return parsed JSON
        end
        
        def normalize_property(api_data, params)
          # Convert provider's data format to NormalizedProperty
          NormalizedProperty.new(
            reference: api_data['id'],
            title: api_data['name'],
            price: (api_data['price'] * 100).to_i,  # Convert to cents
            # ... map other fields
          )
        end
      end
    end
  end
end
```

**Step 2: Register Provider**
```ruby
# config/initializers/external_feeds.rb

Rails.application.config.to_prepare do
  Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::ResalesOnline)
  Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::MyProvider)  # Add here
end
```

**Step 3: Add Configuration UI**
```ruby
# In SiteAdmin::ExternalFeedsController#provider_config_fields

case provider_class.provider_name
when :my_provider
  [
    {
      key: :api_key,
      label: "API Key",
      type: :password,
      required: true,
      help: "Your API key from My Provider"
    },
    {
      key: :api_id,
      label: "API ID",
      type: :text,
      required: true,
      help: "Your API ID"
    }
  ]
end
```

---

## Common Translation Keys Reference

| Key | Default Value | Used In |
|-----|---------------|---------|
| `external_feed.search.title` | "Property Search" | Index page header |
| `external_feed.search.filters` | "Filters" | Filter sidebar title |
| `external_feed.search.apply_filters` | "Apply Filters" | Submit button |
| `external_feed.search.clear_filters` | "Clear Filters" | Clear button |
| `external_feed.search.showing` | "Showing %{range} properties" | Results count |
| `external_feed.search.no_results` | "No properties found" | Empty state |
| `external_feed.pagination.next` | "Next" | Pagination button |
| `external_feed.pagination.previous` | "Previous" | Pagination button |
| `external_feed.property_types.*` | Titleized value | Dynamic property types |
| `external_feed.listing_type.sale` | "For Sale" | Badge/badge |
| `external_feed.listing_type.rental` | "For Rent" | Badge/badge |
| `external_feed.status.sold` | "This property has been sold" | Unavailable page |
| `external_feed.status.rented` | "This property has been rented" | Unavailable page |
| `external_feed.property.contact_agent` | "Contact Agent" | Detail page button |
| `external_feed.features.bedrooms` | "Bedrooms" | Property features |
| `external_feed.features.bathrooms` | "Bathrooms" | Property features |
| `external_feed.features.built_area_m2` | "m² Built" | Property features |

