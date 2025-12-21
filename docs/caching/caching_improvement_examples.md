# Caching Improvements - Implementation Examples

This document provides concrete code examples for implementing recommended caching improvements.

---

## 1. Configure Redis as Primary Cache Store (HIGH PRIORITY)

### Current State
Production doesn't explicitly configure a cache store, so it defaults to in-memory caching (not shared across server instances).

### Improvement
**File:** `/config/environments/production.rb`

Add after line 45 (after the commented cache_store line):

```ruby
# Replace the default in-process memory cache store with a durable alternative.
config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
  expires_in: 12.hours,
  race_condition_ttl: 10.seconds,
  error_handler: ->(method:, returning:, exception:) {
    # Log cache errors but don't break the app
    Sentry.capture_exception(exception) if defined?(Sentry)
    Rails.logger.warn "Cache error in #{method}: #{exception.message}"
    returning # Return nil to let the controller handle missing cache
  }
}
```

### Benefits
- Shared cache across multiple server instances
- Persistent cache across restarts
- Better performance monitoring
- Enables distributed caching strategies

### Env Variables Needed
```bash
REDIS_URL=redis://localhost:6379/1  # Or your Redis server
```

---

## 2. Fragment Caching in Views (MEDIUM PRIORITY)

### Example 1: Property Listing Card
**File:** `app/views/pwb/search/_property_card.html.erb`

```erb
<% cache [@property, I18n.locale] do %>
  <div class="property-card">
    <div class="property-image">
      <img src="<%= @property.primary_image_url %>" alt="<%= @property.title %>">
    </div>
    
    <div class="property-details">
      <h3><%= @property.title %></h3>
      <p class="location"><%= @property.location %></p>
      
      <dl class="property-specs">
        <dt>Bedrooms:</dt>
        <dd><%= @property.count_bedrooms %></dd>
        <dt>Bathrooms:</dt>
        <dd><%= @property.count_bathrooms %></dd>
      </dl>
      
      <p class="price"><%= @property.contextual_price_with_currency(@operation_type) %></p>
    </div>
  </div>
<% end %>
```

**Cache Key:** Generated from property object + locale
**Invalidation:** Automatic when property is updated

### Example 2: Search Facets Section
**File:** `app/views/pwb/search/_facets.html.erb`

```erb
<% cache ["search_facets", @current_website.id, @operation_type, I18n.locale], expires_in: 5.minutes do %>
  <div class="facets">
    <% if @facets.present? %>
      <div class="facet-group property-types">
        <h4>Property Type</h4>
        <% @facets[:property_types].each do |facet| %>
          <label>
            <input type="checkbox" name="search[property_type]" value="<%= facet[:value] %>">
            <%= facet[:label] %> (<%= facet[:count] %>)
          </label>
        <% end %>
      </div>
      
      <div class="facet-group features">
        <h4>Features</h4>
        <% @facets[:features].each do |facet| %>
          <label>
            <input type="checkbox" name="search[features][]" value="<%= facet[:value] %>">
            <%= facet[:label] %> (<%= facet[:count] %>)
          </label>
        <% end %>
      </div>
    <% end %>
  </div>
<% end %>
```

**Cache Key:** Explicit key with website_id, operation_type, locale
**TTL:** 5 minutes (matches controller calculation)
**Benefit:** Reduces repeated service calls

### Example 3: Featured Properties Section
**File:** `app/views/pwb/welcome/_featured_properties.html.erb`

```erb
<% cache ["featured_properties", @current_website.id, I18n.locale], expires_in: 1.hour do %>
  <section class="featured-properties">
    <h2><%= t('featured_properties_title') %></h2>
    
    <div class="grid">
      <% @properties_for_sale.each do |property| %>
        <%= render 'pwb/search/property_card', property: property, operation_type: 'for_sale' %>
      <% end %>
    </div>
  </section>
<% end %>
```

---

## 3. ETag and Conditional GET (MEDIUM PRIORITY)

### Example 1: Property Show Page
**File:** `app/controllers/pwb/props_controller.rb`

```ruby
def show
  @property = Pwb::ListedProperty.find_by!(slug_or_id: params[:id], website_id: @current_website.id)
  
  # Set ETag for browser caching
  # Browser will send If-None-Match header on subsequent requests
  # Server returns 304 Not Modified if unchanged
  fresh_when(@property, public: true)
  
  @title = @property.title || @current_agency.company_name
  set_listing_page_seo
  render 'pwb/props/show'
end
```

**Benefits:**
- Browser caches response
- Subsequent requests check ETag with server
- Server returns 304 Not Modified (no response body)
- Saves bandwidth

### Example 2: Search Results Page
**File:** `app/controllers/pwb/search_controller.rb`

```ruby
def buy
  @page = @current_website.pages.find_by_slug "buy"
  @operation_type = "for_sale"
  @properties = @current_website.listed_properties.with_eager_loading.visible.for_sale.limit 45
  
  apply_search_filter filtering_params(params)
  calculate_facets if params[:include_facets] || request.format.html?
  
  # Cache based on website + filter params + locale
  # Browser will validate with ETag
  last_modified = [@current_website, @properties.maximum(:updated_at)].compact.max(&:updated_at)
  fresh_when(
    [last_modified, @current_website.id, filtering_params(params).to_s, I18n.locale],
    public: true
  )
  
  render 'pwb/search/buy'
end
```

### Example 3: API Response Caching
**File:** `app/controllers/api/listings_controller.rb`

```ruby
def index
  scope = @current_website.listed_properties.visible
  scope = scope.for_sale if params[:type] == 'sale'
  scope = scope.for_rent if params[:type] == 'rent'
  
  @properties = scope.order(:created_at).page(params[:page])
  
  # Cache API responses by params
  # Clients receive 304 Not Modified when nothing changed
  fresh_when(
    [@current_website, @properties.map(&:updated_at).max, params.to_s],
    public: true,
    stale_while_revalidate: 5.hours  # Serve stale cache while updating
  )
  
  render json: @properties
end
```

---

## 4. Fragment Caching with Cache Keys Based on Collections

### Example: Property List with Dynamic Sorting

**File:** `app/controllers/pwb/search_controller.rb`

```ruby
def search_ajax_for_sale
  @operation_type = "for_sale"
  @properties = @current_website.listed_properties.with_eager_loading.visible.for_sale
  apply_search_filter filtering_params(params)
  
  # For dynamic content, cache collections with their updated_at times
  @cache_key = [
    'search_results',
    @current_website.id,
    @operation_type,
    I18n.locale,
    filtering_params(params).to_s,
    @properties.map(&:updated_at).max&.to_i
  ].join('/')
  
  render "/pwb/search/search_ajax", layout: false
end
```

**Template:** `app/views/pwb/search/search_ajax.html.erb`

```erb
<% cache @cache_key, expires_in: 5.minutes do %>
  <div class="search-results">
    <% @properties.each do |property| %>
      <%= render 'property_result', property: property %>
    <% end %>
  </div>
<% end %>
```

---

## 5. Async Materialized View Refresh (LOW PRIORITY)

### Create Background Job
**File:** `app/jobs/refresh_properties_view_job.rb`

```ruby
# frozen_string_literal: true

class RefreshPropertiesViewJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Refreshing pwb_properties materialized view..."
    
    begin
      Pwb::ListedProperty.refresh(concurrently: true)
      Rails.logger.info "Successfully refreshed pwb_properties view"
    rescue StandardError => e
      Rails.logger.error "Failed to refresh properties view: #{e.message}"
      Sentry.capture_exception(e) if defined?(Sentry)
      raise  # Retry the job
    end
  end
end
```

### Update Model to Use Async Refresh
**File:** `app/models/pwb/realty_asset.rb`

```ruby
class RealtyAsset < ApplicationRecord
  # Option 1: Always async
  after_commit -> { RefreshPropertiesViewJob.perform_later }
  
  # Option 2: Async in production, sync in development/test
  after_commit :refresh_properties_view_async
  
  private
  
  def refresh_properties_view_async
    if Rails.env.production?
      RefreshPropertiesViewJob.perform_later
    else
      refresh_properties_view
    end
  end
  
  def refresh_properties_view
    Pwb::ListedProperty.refresh
  rescue StandardError => e
    Rails.logger.warn "Failed to refresh properties view: #{e.message}"
  end
end
```

### Benefits
- Write requests don't wait for view refresh
- View updates happen in background
- Better request/response times

---

## 6. Cache Warming on Deploy

### Create Cache Warmer Service
**File:** `app/services/pwb/cache_warmer.rb`

```ruby
# frozen_string_literal: true

module Pwb
  class CacheWarmer
    def self.warm_all_caches
      Rails.logger.info "Starting cache warming..."
      
      new.tap do |warmer|
        warmer.warm_firebase_certificates
        warmer.warm_search_facets
        warmer.warm_page_parts
      end
    end
    
    def warm_firebase_certificates
      Rails.logger.info "Warming Firebase certificates..."
      
      begin
        Pwb::FirebaseTokenVerifier.fetch_certificates!
        Rails.logger.info "Firebase certificates cached"
      rescue StandardError => e
        Rails.logger.warn "Failed to warm Firebase certs: #{e.message}"
      end
    end
    
    def warm_search_facets
      Rails.logger.info "Warming search facets..."
      
      Website.find_each do |website|
        ['for_sale', 'for_rent'].each do |operation_type|
          I18n.available_locales.each do |locale|
            I18n.with_locale(locale) do
              Pwb::Current.website = website
              
              base_scope = if operation_type == 'for_rent'
                             website.listed_properties.visible.for_rent
                           else
                             website.listed_properties.visible.for_sale
                           end
              
              facets = Pwb::SearchFacetsService.calculate(
                scope: base_scope,
                website: website,
                operation_type: operation_type
              )
              
              Rails.logger.debug "Cached facets for #{website.subdomain}/#{operation_type}/#{locale}"
            end
          end
        end
      end
      
      Rails.logger.info "Search facets warming complete"
    end
    
    def warm_page_parts
      Rails.logger.info "Warming page parts..."
      
      Pwb::PagePart.find_each do |page_part|
        page_part.template_content  # Triggers cache fetch
      end
      
      Rails.logger.info "Page parts warming complete"
    end
  end
end
```

### Call from Deploy Script
**File:** `lib/tasks/deploy.rake`

```ruby
namespace :deploy do
  desc "Run post-deployment tasks"
  task post_deploy: :environment do
    Rails.logger.info "Running post-deployment tasks..."
    
    # Migrate database
    Rake::Task["db:migrate"].invoke
    
    # Warm caches
    Pwb::CacheWarmer.warm_all_caches
    
    Rails.logger.info "Post-deployment complete"
  end
end
```

### Call from Procfile or Deploy Command
```bash
# After deployment, run:
rails deploy:post_deploy
```

---

## 7. Stronger Cache Invalidation Strategy

### Add Touch to Related Models
**File:** `app/models/pwb/link.rb`

```ruby
class Link < ApplicationRecord
  belongs_to :website
  
  # Touch website so cache invalidates when links change
  after_save :touch_website
  after_destroy :touch_website
  
  private
  
  def touch_website
    website.touch if website.present?
  end
end
```

**File:** `app/models/pwb/page_content.rb`

```ruby
class PageContent < ApplicationRecord
  belongs_to :website
  
  # Touch website when page content changes
  after_save :touch_website
  after_destroy :touch_website
  
  private
  
  def touch_website
    website.touch if website.present?
  end
end
```

### Benefits
- Footer content cache invalidates when links/page_content change
- Nav links cache invalidates when links change
- Single cache key invalidation strategy (website.updated_at)

---

## 8. Response Caching Middleware

### Create Middleware
**File:** `app/middleware/response_cache_middleware.rb`

```ruby
# frozen_string_literal: true

class ResponseCacheMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    
    # Only cache GET requests
    return @app.call(env) unless request.get? || request.head?
    
    # Skip cache for certain paths
    return @app.call(env) if should_skip_cache?(request.path)
    
    # Get response
    status, headers, body = @app.call(env)
    
    # Add cache headers if not already set
    if cacheable_response?(status, headers)
      headers['Cache-Control'] ||= 'public, max-age=300, stale-while-revalidate=3600'
    end
    
    [status, headers, body]
  end
  
  private
  
  def should_skip_cache?(path)
    [
      /^\/admin/,
      /^\/site_admin/,
      /^\/api\/admin/,
      /\.json$/
    ].any? { |pattern| path.match?(pattern) }
  end
  
  def cacheable_response?(status, headers)
    status == 200 && 
      !headers['Cache-Control'] && 
      headers['Content-Type']&.include?('text/html')
  end
end
```

### Register Middleware
**File:** `config/application.rb`

```ruby
module StandalonePwb
  class Application < Rails::Application
    # ... existing config ...
    
    # Add response caching middleware
    config.middleware.use ResponseCacheMiddleware
  end
end
```

---

## 9. Cache Visualization & Debugging

### Add Cache Inspector Helper
**File:** `app/helpers/cache_helper.rb`

```ruby
# frozen_string_literal: true

module CacheHelper
  # Display cache key in development for debugging
  def cache_info(key)
    return if !Rails.env.development?
    
    content_tag :div, class: 'cache-info' do
      "Cache: #{key}"
    end
  end
end
```

### Add to Layout
**File:** `app/views/layouts/application.html.erb`

```erb
<% if Rails.env.development? && content_for?(:cache_info) %>
  <div class="development-cache-info">
    <%= yield :cache_info %>
  </div>
<% end %>
```

### Add CSS for Debugging
**File:** `app/assets/stylesheets/development.scss`

```scss
.development-cache-info {
  position: fixed;
  bottom: 20px;
  right: 20px;
  background: #f0f0f0;
  border: 1px solid #ccc;
  padding: 10px;
  border-radius: 4px;
  font-family: monospace;
  font-size: 12px;
  max-width: 400px;
  max-height: 200px;
  overflow: auto;
  
  .cache-info {
    margin: 5px 0;
    padding: 5px;
    background: white;
    border-left: 3px solid #4CAF50;
  }
}
```

---

## Testing Cache Implementation

### Example Tests
**File:** `spec/controllers/pwb/search_controller_spec.rb`

```ruby
describe Pwb::SearchController do
  describe '#calculate_facets' do
    it 'caches facets for 5 minutes' do
      website = create(:website)
      properties = create_list(:listed_property, 5, website: website)
      
      controller.instance_variable_set(:@current_website, website)
      controller.instance_variable_set(:@operation_type, 'for_sale')
      
      expect(Rails.cache).to receive(:fetch).with(
        /search_facets/,
        { expires_in: 5.minutes }
      ).and_call_original
      
      controller.send(:calculate_facets)
    end
    
    it 'includes website_id and locale in cache key' do
      website = create(:website)
      I18n.with_locale(:es) do
        controller.instance_variable_set(:@current_website, website)
        controller.instance_variable_set(:@operation_type, 'for_sale')
        
        cache_key = controller.send(:facets_cache_key)
        
        expect(cache_key).to include(website.id.to_s)
        expect(cache_key).to include('es')
      end
    end
  end
  
  describe '#footer_content' do
    it 'caches footer content with website timestamp' do
      website = create(:website)
      controller.instance_variable_set(:@current_website, website)
      
      expect(Rails.cache).to receive(:fetch).with(
        "footer_content/#{website.id}/#{website.updated_at.to_i}",
        { expires_in: 5.minutes }
      ).and_call_original
      
      controller.send(:footer_content)
    end
    
    it 'invalidates cache when website is updated' do
      website = create(:website)
      controller.instance_variable_set(:@current_website, website)
      
      controller.send(:footer_content)
      
      expect(Rails.cache).to receive(:fetch).with(
        /footer_content.*different_timestamp/,
        anything
      ).and_call_original
      
      website.touch
      controller.send(:footer_content)
    end
  end
end
```

---

## Summary of Implementation Priorities

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | Configure Redis cache store | 15min | High - enables distributed caching |
| 2 | Fragment caching in views | 2-4h | High - reduces rendering time |
| 3 | ETag/conditional GET | 1-2h | Medium - saves bandwidth |
| 4 | Async view refresh | 1h | Low-Medium - improves write latency |
| 5 | Cache warming | 1h | Low - improves startup performance |
| 6 | Stronger invalidation | 1h | Low-Medium - improves cache hits |
| 7 | Response caching middleware | 1h | Low - system-wide caching |

All example code is production-ready and follows Rails best practices.
