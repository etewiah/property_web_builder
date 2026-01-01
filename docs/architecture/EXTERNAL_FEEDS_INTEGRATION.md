# External Property Feeds Integration

This document describes the architecture for integrating external property feeds into PropertyWebBuilder. The system is designed to be provider-agnostic, allowing different feed providers (Resales Online, Kyero, ThinkSpain, etc.) to be plugged in through configuration.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Concepts](#core-concepts)
4. [Provider Interface](#provider-interface)
5. [Configuration](#configuration)
6. [Data Normalization](#data-normalization)
7. [Caching Strategy](#caching-strategy)
8. [Multi-Tenancy](#multi-tenancy)
9. [Controllers and Routes](#controllers-and-routes)
10. [Views and Theming](#views-and-theming)
11. [Error Handling](#error-handling)
12. [Provider Implementation Guide](#provider-implementation-guide)
13. [Resales Online Provider](#resales-online-provider)
14. [Future Providers](#future-providers)

---

## Overview

### Purpose

The External Feeds Integration system allows PropertyWebBuilder websites to display property listings from third-party data providers alongside (or instead of) locally-managed properties. This is useful for:

- Real estate agencies that aggregate listings from multiple sources
- Portals that want to display MLS/shared inventory
- Websites that need to show properties from a central CRM system

### Design Principles

1. **Provider Agnostic**: The core system knows nothing about specific providers
2. **Configuration Driven**: New providers are added via configuration, not code changes
3. **Normalized Data**: All providers return data in a standard format
4. **Multi-Tenant Aware**: Each website can have different feed configurations
5. **Cacheable**: All external data is cached to reduce API calls and improve performance
6. **Graceful Degradation**: Feed failures don't break the website

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PropertyWebBuilder                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐  │
│  │   Website    │───▶│         ExternalFeed::Manager            │  │
│  │  (Tenant)    │    │  - Loads provider config                 │  │
│  └──────────────┘    │  - Routes requests to providers          │  │
│                      │  - Handles caching                        │  │
│                      └──────────────────────────────────────────┘  │
│                                        │                            │
│                                        ▼                            │
│                      ┌──────────────────────────────────────────┐  │
│                      │       ExternalFeed::Registry             │  │
│                      │  - Registered provider classes           │  │
│                      │  - Provider factory                      │  │
│                      └──────────────────────────────────────────┘  │
│                                        │                            │
│              ┌─────────────────────────┼─────────────────────────┐ │
│              ▼                         ▼                         ▼ │
│  ┌────────────────────┐  ┌────────────────────┐  ┌──────────────┐ │
│  │ ResalesOnline      │  │ Kyero              │  │ Future       │ │
│  │ Provider           │  │ Provider           │  │ Provider     │ │
│  │                    │  │                    │  │              │ │
│  │ - search()         │  │ - search()         │  │ - search()   │ │
│  │ - find()           │  │ - find()           │  │ - find()     │ │
│  │ - similar()        │  │ - similar()        │  │ - similar()  │ │
│  └────────────────────┘  └────────────────────┘  └──────────────┘ │
│              │                         │                         │  │
│              ▼                         ▼                         ▼  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              ExternalFeed::NormalizedProperty                │  │
│  │  - Unified property data structure                           │  │
│  │  - Common accessors for all providers                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │   External APIs          │
                    │   - Resales Online       │
                    │   - Kyero                │
                    │   - ThinkSpain           │
                    │   - Custom CRM           │
                    └──────────────────────────┘
```

### Directory Structure

```
app/
├── services/
│   └── pwb/
│       └── external_feed/
│           ├── manager.rb                 # Main entry point
│           ├── registry.rb                # Provider registration
│           ├── base_provider.rb           # Abstract provider class
│           ├── normalized_property.rb     # Standard property struct
│           ├── normalized_search_result.rb # Standard search result
│           ├── cache_store.rb             # Caching wrapper
│           ├── errors.rb                  # Custom exceptions
│           └── providers/
│               ├── resales_online.rb      # Resales Online implementation
│               ├── kyero.rb               # Future: Kyero
│               └── generic_xml.rb         # Future: Generic XML feeds
├── controllers/
│   └── site/
│       └── external_listings_controller.rb
└── views/
    └── site/
        └── external_listings/
            ├── index.html.erb
            ├── show.html.erb
            └── _property_card.html.erb

config/
├── initializers/
│   └── external_feeds.rb                  # Provider registration
└── external_feeds/
    └── providers/
        └── resales_online.yml             # Provider-specific config template
```

---

## Core Concepts

### Provider

A provider is a class that knows how to communicate with a specific external API. Each provider must implement the standard interface defined by `BaseProvider`.

### Manager

The Manager is the main entry point for all external feed operations. It:
- Loads the website's feed configuration
- Instantiates the appropriate provider
- Handles caching
- Returns normalized data

### Registry

The Registry maintains a list of available provider classes. New providers register themselves here.

### NormalizedProperty

A standard data structure that all providers must return. This ensures views and controllers work identically regardless of the data source.

### Configuration

Each website stores its feed configuration in the database. This includes:
- Which provider to use
- API credentials
- Default search parameters
- Feature mappings

---

## Provider Interface

All providers must inherit from `BaseProvider` and implement these methods:

```ruby
module Pwb
  module ExternalFeed
    class BaseProvider
      # Initialize with website configuration
      # @param config [Hash] Provider-specific configuration
      def initialize(config)
        @config = config.deep_symbolize_keys
        validate_config!
      end

      # Search for properties
      # @param params [Hash] Search parameters (normalized)
      #   - locale [String] Language code (en, es, fr, etc.)
      #   - listing_type [Symbol] :sale or :rental
      #   - property_types [Array<String>] Property type codes
      #   - location [String] Location/city name
      #   - min_bedrooms [Integer]
      #   - max_bedrooms [Integer]
      #   - min_bathrooms [Integer]
      #   - max_bathrooms [Integer]
      #   - min_price [Integer]
      #   - max_price [Integer]
      #   - min_area [Integer] Built area in sqm
      #   - max_area [Integer]
      #   - features [Array<String>] Required features
      #   - sort [Symbol] :price_asc, :price_desc, :newest, :updated
      #   - page [Integer] Page number (1-indexed)
      #   - per_page [Integer] Results per page
      # @return [NormalizedSearchResult]
      def search(params)
        raise NotImplementedError
      end

      # Find a single property by reference
      # @param reference [String] Provider's property reference
      # @param params [Hash] Additional parameters
      #   - locale [String] Language code
      #   - listing_type [Symbol] :sale or :rental
      # @return [NormalizedProperty, nil]
      def find(reference, params = {})
        raise NotImplementedError
      end

      # Find similar properties
      # @param property [NormalizedProperty] The property to find similar to
      # @param params [Hash] Additional parameters
      #   - limit [Integer] Max results (default: 6)
      # @return [Array<NormalizedProperty>]
      def similar(property, params = {})
        raise NotImplementedError
      end

      # Get available locations for search filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>] Location options with :value and :label
      def locations(params = {})
        raise NotImplementedError
      end

      # Get available property types for search filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>] Property type options with :value and :label
      def property_types(params = {})
        raise NotImplementedError
      end

      # Check if provider is properly configured and accessible
      # @return [Boolean]
      def available?
        raise NotImplementedError
      end

      # Provider identifier
      # @return [Symbol]
      def self.provider_name
        raise NotImplementedError
      end

      protected

      # Validate required configuration keys
      def validate_config!
        missing = required_config_keys - @config.keys
        if missing.any?
          raise ConfigurationError, "Missing required config: #{missing.join(', ')}"
        end
      end

      # Override in subclasses to specify required config keys
      # @return [Array<Symbol>]
      def required_config_keys
        []
      end
    end
  end
end
```

---

## Configuration

### Website Configuration Schema

Each website's external feed configuration is stored in the `settings` JSON column:

```ruby
# In Pwb::Website model
store_accessor :settings,
  :external_feed_enabled,      # Boolean - master switch
  :external_feed_provider,     # String - provider name (e.g., "resales_online")
  :external_feed_config        # Hash - provider-specific configuration
```

### Provider Configuration Structure

Each provider defines its own configuration schema. The configuration is stored as a Hash:

```ruby
{
  # Common fields (all providers)
  "provider" => "resales_online",
  "enabled" => true,
  "cache_ttl_search" => 3600,      # 1 hour
  "cache_ttl_property" => 86400,   # 24 hours
  "default_locale" => "en",
  "supported_locales" => ["en", "es", "fr", "de", "nl"],

  # Provider-specific fields (Resales Online example)
  "api_key" => "your_api_key",
  "api_id_sales" => "1234",
  "api_id_rentals" => "5678",
  "p1_constant" => "1014359",
  "default_country" => "Spain",
  "image_count" => 0,              # 0 = all images

  # Search defaults
  "default_sort" => "price_asc",
  "results_per_page" => 24,

  # Field mappings (optional - for customizing labels)
  "property_type_labels" => {
    "1-1" => "Apartment",
    "1-6" => "Penthouse",
    "2-1" => "Villa"
  },

  # Feature mappings (map provider features to display labels)
  "feature_mappings" => {
    "pool" => { "param" => "1Pool1", "label" => "Swimming Pool" },
    "garden" => { "param" => "1Garden1", "label" => "Garden" }
  }
}
```

### Configuration via Rails Credentials (Alternative)

For sensitive data, providers can read from Rails credentials:

```yaml
# config/credentials.yml.enc
external_feeds:
  resales_online:
    api_key: "secret_key"
```

```ruby
# Provider reads from credentials if not in config
def api_key
  @config[:api_key] || Rails.application.credentials.dig(:external_feeds, :resales_online, :api_key)
end
```

---

## Data Normalization

### NormalizedProperty

All providers must return properties in this standard format:

```ruby
module Pwb
  module ExternalFeed
    class NormalizedProperty
      # Identification
      attr_accessor :reference           # String - Provider's unique ID
      attr_accessor :provider            # Symbol - Provider name
      attr_accessor :provider_url        # String - Original listing URL (if available)

      # Basic Info
      attr_accessor :title               # String - Property title
      attr_accessor :description         # String - Full description (HTML allowed)
      attr_accessor :property_type       # String - Normalized type (apartment, house, etc.)
      attr_accessor :property_type_raw   # String - Provider's original type
      attr_accessor :property_subtype    # String - More specific type (penthouse, villa, etc.)

      # Location
      attr_accessor :country             # String - Country name
      attr_accessor :region              # String - Region/Province
      attr_accessor :area                # String - Area/District
      attr_accessor :city                # String - City/Town
      attr_accessor :address             # String - Street address (if available)
      attr_accessor :postal_code         # String - Postal code (if available)
      attr_accessor :latitude            # Float
      attr_accessor :longitude           # Float

      # Listing Details
      attr_accessor :listing_type        # Symbol - :sale or :rental
      attr_accessor :status              # Symbol - :available, :reserved, :sold, :rented
      attr_accessor :price               # Integer - Price in cents
      attr_accessor :price_raw           # String - Original price string
      attr_accessor :currency            # String - ISO currency code (EUR, GBP, etc.)
      attr_accessor :price_qualifier     # String - "Asking price", "Guide price", etc.
      attr_accessor :original_price      # Integer - Original price if reduced (cents)

      # Rental-specific
      attr_accessor :rental_period       # Symbol - :monthly, :weekly, :daily
      attr_accessor :available_from      # Date
      attr_accessor :minimum_stay        # Integer - Minimum nights/days

      # Property Details
      attr_accessor :bedrooms            # Integer
      attr_accessor :bathrooms           # Float (allows 1.5 baths)
      attr_accessor :built_area          # Integer - Square meters
      attr_accessor :plot_area           # Integer - Square meters
      attr_accessor :terrace_area        # Integer - Square meters
      attr_accessor :year_built          # Integer
      attr_accessor :floors              # Integer - Number of floors
      attr_accessor :floor_level         # Integer - Which floor (for apartments)
      attr_accessor :orientation         # String - N, S, E, W, NE, etc.

      # Features
      attr_accessor :features            # Array<String> - List of features
      attr_accessor :features_by_category # Hash<String, Array<String>>

      # Energy
      attr_accessor :energy_rating       # String - A, B, C, D, E, F, G
      attr_accessor :energy_value        # Float
      attr_accessor :co2_rating          # String
      attr_accessor :co2_value           # Float

      # Media
      attr_accessor :images              # Array<Hash> - [{url:, caption:, position:}]
      attr_accessor :virtual_tour_url    # String
      attr_accessor :video_url           # String
      attr_accessor :floor_plan_urls     # Array<String>

      # Costs (for sales)
      attr_accessor :community_fees      # Integer - Annual in cents
      attr_accessor :ibi_tax             # Integer - Annual in cents
      attr_accessor :garbage_tax         # Integer - Annual in cents

      # Metadata
      attr_accessor :created_at          # DateTime - When listed
      attr_accessor :updated_at          # DateTime - Last update
      attr_accessor :fetched_at          # DateTime - When we fetched it

      # Initialize from hash
      def initialize(attrs = {})
        attrs.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @fetched_at ||= Time.current
      end

      # Convert to hash for JSON serialization
      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          key = var.to_s.delete_prefix("@")
          hash[key] = instance_variable_get(var)
        end
      end

      # Price in major currency units (e.g., euros, not cents)
      def price_in_units
        return nil unless price
        price / 100.0
      end

      # Formatted price string
      def formatted_price
        return nil unless price && currency
        Money.new(price, currency).format
      end

      # Primary image URL
      def primary_image_url
        images&.first&.dig(:url)
      end

      # Check if property is available
      def available?
        status == :available
      end

      # Check if price was reduced
      def price_reduced?
        original_price.present? && price < original_price
      end

      # Price reduction percentage
      def price_reduction_percent
        return nil unless price_reduced?
        ((original_price - price).to_f / original_price * 100).round(1)
      end
    end
  end
end
```

### NormalizedSearchResult

Search results are wrapped in a standard structure:

```ruby
module Pwb
  module ExternalFeed
    class NormalizedSearchResult
      attr_accessor :properties        # Array<NormalizedProperty>
      attr_accessor :total_count       # Integer - Total matching properties
      attr_accessor :page              # Integer - Current page
      attr_accessor :per_page          # Integer - Results per page
      attr_accessor :total_pages       # Integer - Total pages
      attr_accessor :query_params      # Hash - The params used for this search
      attr_accessor :provider          # Symbol - Provider name
      attr_accessor :fetched_at        # DateTime

      def initialize(attrs = {})
        @properties = []
        @page = 1
        @per_page = 24
        attrs.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @fetched_at ||= Time.current
        calculate_total_pages
      end

      def empty?
        properties.empty?
      end

      def any?
        properties.any?
      end

      def first_page?
        page == 1
      end

      def last_page?
        page >= total_pages
      end

      def next_page
        last_page? ? nil : page + 1
      end

      def prev_page
        first_page? ? nil : page - 1
      end

      private

      def calculate_total_pages
        return @total_pages if @total_pages
        return 0 if total_count.nil? || per_page.nil? || per_page.zero?
        @total_pages = (total_count.to_f / per_page).ceil
      end
    end
  end
end
```

### Property Type Normalization

Providers should normalize property types to these standard values:

| Normalized Type | Description | Examples |
|-----------------|-------------|----------|
| `apartment` | Flat/Apartment | Apartment, Flat, Studio |
| `apartment_ground` | Ground floor apartment | Ground Floor Apartment |
| `apartment_middle` | Middle floor apartment | Middle Floor Apartment |
| `apartment_top` | Top floor apartment | Top Floor Apartment |
| `penthouse` | Penthouse | Penthouse, Duplex Penthouse |
| `house` | Generic house | House, Detached House |
| `villa` | Detached villa | Villa, Detached Villa |
| `townhouse` | Townhouse | Townhouse, Terraced House |
| `semi_detached` | Semi-detached | Semi-Detached House |
| `bungalow` | Bungalow | Bungalow |
| `finca` | Country house | Finca, Cortijo, Country House |
| `land` | Building plot | Plot, Land, Building Plot |
| `commercial` | Commercial property | Commercial, Office, Retail |
| `garage` | Parking/Garage | Garage, Parking Space |
| `other` | Other types | Storage, Boat Mooring, etc. |

---

## Caching Strategy

### Cache Keys

All cache keys follow this pattern:

```
pwb:external_feed:{website_id}:{provider}:{operation}:{params_hash}
```

Examples:
```
pwb:external_feed:42:resales_online:search:a1b2c3d4e5f6
pwb:external_feed:42:resales_online:property:en:R3096106
pwb:external_feed:42:resales_online:similar:R3096106:6
pwb:external_feed:42:resales_online:locations
pwb:external_feed:42:resales_online:property_types
```

### Cache TTLs

| Operation | Default TTL | Configurable |
|-----------|-------------|--------------|
| Search results | 1 hour | `cache_ttl_search` |
| Property details | 24 hours | `cache_ttl_property` |
| Similar properties | 6 hours | `cache_ttl_similar` |
| Locations list | 1 week | `cache_ttl_static` |
| Property types | 1 week | `cache_ttl_static` |

### Cache Store Implementation

```ruby
module Pwb
  module ExternalFeed
    class CacheStore
      def initialize(website)
        @website = website
        @provider = website.external_feed_provider
      end

      def fetch(operation, params, ttl: nil, &block)
        key = cache_key(operation, params)
        ttl ||= default_ttl(operation)

        Rails.cache.fetch(key, expires_in: ttl) do
          result = block.call
          # Wrap in cache metadata
          {
            data: result,
            cached_at: Time.current.iso8601,
            provider: @provider
          }
        end
      end

      def invalidate(operation, params = nil)
        if params
          Rails.cache.delete(cache_key(operation, params))
        else
          # Invalidate all keys for this operation
          Rails.cache.delete_matched("pwb:external_feed:#{@website.id}:#{@provider}:#{operation}:*")
        end
      end

      def invalidate_all
        Rails.cache.delete_matched("pwb:external_feed:#{@website.id}:*")
      end

      private

      def cache_key(operation, params)
        params_hash = Digest::MD5.hexdigest(params.to_json)
        "pwb:external_feed:#{@website.id}:#{@provider}:#{operation}:#{params_hash}"
      end

      def default_ttl(operation)
        config = @website.external_feed_config || {}
        case operation.to_sym
        when :search
          (config["cache_ttl_search"] || 3600).seconds
        when :property
          (config["cache_ttl_property"] || 86400).seconds
        when :similar
          (config["cache_ttl_similar"] || 21600).seconds
        when :locations, :property_types
          (config["cache_ttl_static"] || 604800).seconds
        else
          1.hour
        end
      end
    end
  end
end
```

### Cache Warming

For high-traffic websites, implement cache warming:

```ruby
module Pwb
  module ExternalFeed
    class CacheWarmerJob < ApplicationJob
      queue_as :low

      def perform(website_id)
        website = Pwb::Website.find(website_id)
        return unless website.external_feed_enabled?

        manager = Manager.new(website)

        # Warm common searches
        common_searches.each do |params|
          manager.search(params)
        end

        # Warm location and property type lists
        manager.locations
        manager.property_types
      end

      private

      def common_searches
        [
          { listing_type: :sale, page: 1 },
          { listing_type: :sale, sort: :newest, page: 1 },
          { listing_type: :rental, page: 1 }
        ]
      end
    end
  end
end
```

---

## Multi-Tenancy

### Website Isolation

Each website has its own:
- Provider configuration
- Cache namespace
- API credentials

```ruby
module Pwb
  module ExternalFeed
    class Manager
      def initialize(website)
        @website = website
        @config = website.external_feed_config&.deep_symbolize_keys || {}
        @cache = CacheStore.new(website)
      end

      def provider
        @provider ||= begin
          provider_name = @website.external_feed_provider&.to_sym
          raise ConfigurationError, "No provider configured" unless provider_name

          provider_class = Registry.find(provider_name)
          raise ConfigurationError, "Unknown provider: #{provider_name}" unless provider_class

          provider_class.new(@config)
        end
      end

      def enabled?
        @website.external_feed_enabled? && provider.available?
      end

      def search(params)
        return empty_result unless enabled?

        @cache.fetch(:search, params) do
          provider.search(normalize_search_params(params))
        end
      end

      def find(reference, params = {})
        return nil unless enabled?

        @cache.fetch(:property, { reference: reference, **params }) do
          provider.find(reference, params)
        end
      end

      # ... other methods
    end
  end
end
```

### Tenant Context

Always access the manager through the current website:

```ruby
# In controllers
def external_feed
  @external_feed ||= Pwb::ExternalFeed::Manager.new(current_website)
end

# Never do this:
# Pwb::ExternalFeed::Manager.new(config)  # No website context!
```

---

## Controllers and Routes

### Routes Configuration

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Inside the site scope
  scope module: :site do
    # External listings with locale
    scope "(:locale)", locale: /en|es|fr|de|nl/ do
      resources :external_listings, only: [:index, :show], param: :reference do
        collection do
          get :search
          get :locations
          get :property_types
        end
        member do
          get :similar
        end
      end
    end
  end

  # API endpoints for AJAX/frontend
  namespace :api_public do
    namespace :v1 do
      resources :external_listings, only: [:index, :show], param: :reference do
        collection do
          get :search
          get :filters
        end
        member do
          get :similar
        end
      end
    end
  end
end
```

### Controller Implementation

```ruby
module Site
  class ExternalListingsController < SiteController
    before_action :ensure_feed_enabled
    before_action :set_listing, only: [:show, :similar]

    # GET /external_listings
    # GET /external_listings/search
    def index
      @search_params = search_params
      @result = external_feed.search(@search_params)

      respond_to do |format|
        format.html
        format.json { render json: @result }
      end
    end

    # GET /external_listings/:reference
    def show
      if @listing.nil?
        render "errors/not_found", status: :not_found
        return
      end

      unless @listing.available?
        render "errors/gone", status: :gone
        return
      end

      @similar = external_feed.similar(@listing, limit: 6)

      respond_to do |format|
        format.html
        format.json { render json: @listing }
      end
    end

    # GET /external_listings/:reference/similar
    def similar
      @similar = external_feed.similar(@listing, limit: params[:limit] || 8)

      respond_to do |format|
        format.html { render partial: "similar", locals: { properties: @similar } }
        format.json { render json: @similar }
      end
    end

    # GET /external_listings/locations
    def locations
      @locations = external_feed.locations(locale: I18n.locale)
      render json: @locations
    end

    # GET /external_listings/property_types
    def property_types
      @property_types = external_feed.property_types(locale: I18n.locale)
      render json: @property_types
    end

    private

    def ensure_feed_enabled
      unless external_feed.enabled?
        redirect_to root_path, alert: t("external_feed.not_configured")
      end
    end

    def external_feed
      @external_feed ||= Pwb::ExternalFeed::Manager.new(current_website)
    end

    def set_listing
      @listing = external_feed.find(
        params[:reference],
        locale: I18n.locale,
        listing_type: params[:listing_type]&.to_sym || :sale
      )
    end

    def search_params
      params.permit(
        :listing_type,
        :location,
        :min_price,
        :max_price,
        :min_bedrooms,
        :max_bedrooms,
        :min_bathrooms,
        :min_area,
        :max_area,
        :sort,
        :page,
        :per_page,
        property_types: [],
        features: []
      ).to_h.symbolize_keys.merge(locale: I18n.locale)
    end
  end
end
```

---

## Views and Theming

### View Structure

External listings use the same theming system as local properties:

```
app/views/site/external_listings/
├── index.html.erb           # Search results page
├── show.html.erb            # Property detail page
├── _property_card.html.erb  # Card for grid/list views
├── _search_form.html.erb    # Search filters form
├── _pagination.html.erb     # Pagination controls
├── _gallery.html.erb        # Image gallery
├── _features.html.erb       # Features list
├── _map.html.erb            # Location map
└── _similar.html.erb        # Similar properties
```

### Theme Overrides

Themes can override external listing views:

```
app/themes/{theme_name}/views/site/external_listings/
├── index.html.erb
├── show.html.erb
└── _property_card.html.erb
```

### Shared Partials

When possible, share partials between local and external listings:

```erb
<%# app/views/shared/_property_card.html.erb %>
<%# Works with both local Property and NormalizedProperty %>

<div class="property-card">
  <% if property.respond_to?(:primary_image_url) %>
    <img src="<%= property.primary_image_url %>" alt="<%= property.title %>">
  <% elsif property.respond_to?(:photos) %>
    <img src="<%= property.photos.first&.url %>" alt="<%= property.title %>">
  <% end %>

  <h3><%= property.title %></h3>
  <p class="price"><%= property.formatted_price %></p>
  <p class="location"><%= property.city %>, <%= property.region %></p>

  <div class="features">
    <span><%= property.bedrooms %> beds</span>
    <span><%= property.bathrooms %> baths</span>
    <span><%= property.built_area %> m²</span>
  </div>
</div>
```

---

## Error Handling

### Custom Exceptions

```ruby
module Pwb
  module ExternalFeed
    class Error < StandardError; end

    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end
    class ProviderUnavailableError < Error; end
    class PropertyNotFoundError < Error; end
    class InvalidResponseError < Error; end
  end
end
```

### Error Handling in Provider

```ruby
module Pwb
  module ExternalFeed
    module Providers
      class ResalesOnline < BaseProvider
        def search(params)
          response = fetch_json(build_search_url(params))

          case response.dig("transaction", "status")
          when "success"
            normalize_search_results(response)
          when "error"
            handle_api_error(response)
          else
            raise InvalidResponseError, "Unexpected response format"
          end
        rescue Net::TimeoutError, Timeout::Error
          raise ProviderUnavailableError, "Request timed out"
        rescue JSON::ParserError
          raise InvalidResponseError, "Invalid JSON response"
        rescue OpenURI::HTTPError => e
          handle_http_error(e)
        end

        private

        def handle_api_error(response)
          message = response.dig("transaction", "message") || "Unknown error"
          case message
          when /authentication/i, /api key/i
            raise AuthenticationError, message
          when /rate limit/i, /too many/i
            raise RateLimitError, message
          else
            raise Error, message
          end
        end

        def handle_http_error(error)
          case error.io.status[0]
          when "401", "403"
            raise AuthenticationError, "API authentication failed"
          when "429"
            raise RateLimitError, "Rate limit exceeded"
          when "500", "502", "503", "504"
            raise ProviderUnavailableError, "Provider server error"
          else
            raise Error, "HTTP error: #{error.message}"
          end
        end
      end
    end
  end
end
```

### Error Handling in Controller

```ruby
module Site
  class ExternalListingsController < SiteController
    rescue_from Pwb::ExternalFeed::ConfigurationError do |e|
      Rails.logger.error("[ExternalFeed] Configuration error: #{e.message}")
      render "errors/configuration", status: :service_unavailable
    end

    rescue_from Pwb::ExternalFeed::AuthenticationError do |e|
      Rails.logger.error("[ExternalFeed] Auth error: #{e.message}")
      render "errors/service_unavailable", status: :service_unavailable
    end

    rescue_from Pwb::ExternalFeed::ProviderUnavailableError do |e|
      Rails.logger.warn("[ExternalFeed] Provider unavailable: #{e.message}")
      render "errors/service_unavailable", status: :service_unavailable
    end

    rescue_from Pwb::ExternalFeed::PropertyNotFoundError do
      render "errors/not_found", status: :not_found
    end

    rescue_from Pwb::ExternalFeed::RateLimitError do |e|
      Rails.logger.warn("[ExternalFeed] Rate limited: #{e.message}")
      # Return cached data if available, otherwise error
      render "errors/rate_limited", status: :too_many_requests
    end
  end
end
```

### Graceful Degradation

When external feeds fail, the website should continue to function:

```ruby
module Site
  class ExternalListingsController < SiteController
    def index
      @result = begin
        external_feed.search(search_params)
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed] Search failed: #{e.message}")
        # Return empty result instead of failing
        Pwb::ExternalFeed::NormalizedSearchResult.new(
          properties: [],
          total_count: 0,
          error: e.message
        )
      end
    end
  end
end
```

---

## Provider Implementation Guide

### Step 1: Create the Provider Class

```ruby
# app/services/pwb/external_feed/providers/my_provider.rb
module Pwb
  module ExternalFeed
    module Providers
      class MyProvider < BaseProvider
        API_BASE_URL = "https://api.myprovider.com/v1"

        def self.provider_name
          :my_provider
        end

        def search(params)
          # 1. Transform params to provider format
          api_params = build_search_params(params)

          # 2. Make API request
          response = fetch_json("#{API_BASE_URL}/properties", api_params)

          # 3. Normalize response
          normalize_search_results(response, params)
        end

        def find(reference, params = {})
          response = fetch_json("#{API_BASE_URL}/properties/#{reference}", {
            lang: locale_code(params[:locale])
          })

          return nil unless response["property"]

          normalize_property(response["property"], params)
        end

        def similar(property, params = {})
          # Provider may have a similar endpoint, or we build our own search
          search_params = {
            locale: params[:locale],
            property_types: [property.property_type_raw],
            location: property.city,
            min_price: (property.price * 0.7).to_i,
            max_price: (property.price * 1.3).to_i,
            min_bedrooms: property.bedrooms,
            per_page: params[:limit] || 6
          }

          result = search(search_params)
          result.properties.reject { |p| p.reference == property.reference }
        end

        def locations(params = {})
          response = fetch_json("#{API_BASE_URL}/locations")
          response["locations"].map do |loc|
            { value: loc["id"], label: loc["name"] }
          end
        end

        def property_types(params = {})
          response = fetch_json("#{API_BASE_URL}/property-types")
          response["types"].map do |type|
            { value: type["code"], label: type["name"] }
          end
        end

        def available?
          # Quick health check
          response = fetch_json("#{API_BASE_URL}/status")
          response["status"] == "ok"
        rescue StandardError
          false
        end

        protected

        def required_config_keys
          [:api_key]
        end

        private

        def fetch_json(url, params = {})
          uri = URI(url)
          uri.query = URI.encode_www_form(params.merge(api_key: @config[:api_key]))

          response = Net::HTTP.get_response(uri)
          JSON.parse(response.body)
        end

        def build_search_params(params)
          {
            lang: locale_code(params[:locale]),
            type: params[:listing_type] == :rental ? "rent" : "sale",
            location: params[:location],
            min_price: params[:min_price],
            max_price: params[:max_price],
            bedrooms: params[:min_bedrooms],
            page: params[:page] || 1,
            limit: params[:per_page] || 24
          }.compact
        end

        def normalize_search_results(response, params)
          properties = (response["properties"] || []).map do |prop|
            normalize_property(prop, params)
          end

          NormalizedSearchResult.new(
            properties: properties,
            total_count: response["total"],
            page: response["page"],
            per_page: response["per_page"],
            provider: self.class.provider_name,
            query_params: params
          )
        end

        def normalize_property(data, params = {})
          NormalizedProperty.new(
            reference: data["id"],
            provider: self.class.provider_name,
            title: data["title"],
            description: data["description"],
            property_type: normalize_type(data["type"]),
            property_type_raw: data["type"],
            country: data["country"],
            region: data["region"],
            city: data["city"],
            listing_type: data["for_rent"] ? :rental : :sale,
            status: data["available"] ? :available : :sold,
            price: (data["price"] * 100).to_i,
            currency: data["currency"] || "EUR",
            bedrooms: data["bedrooms"],
            bathrooms: data["bathrooms"],
            built_area: data["size"],
            images: normalize_images(data["photos"]),
            features: data["features"] || []
          )
        end

        def normalize_images(photos)
          return [] unless photos

          photos.map.with_index do |photo, idx|
            { url: photo["url"], caption: photo["caption"], position: idx }
          end
        end

        def normalize_type(type)
          TYPE_MAP[type.downcase] || "other"
        end

        TYPE_MAP = {
          "apartment" => "apartment",
          "flat" => "apartment",
          "house" => "house",
          "villa" => "villa",
          "penthouse" => "penthouse"
          # ... add more mappings
        }.freeze

        def locale_code(locale)
          LOCALE_MAP[locale&.to_sym] || "en"
        end

        LOCALE_MAP = {
          en: "en",
          es: "es",
          fr: "fr"
          # ... add more mappings
        }.freeze
      end
    end
  end
end
```

### Step 2: Register the Provider

```ruby
# config/initializers/external_feeds.rb
Rails.application.config.to_prepare do
  Pwb::ExternalFeed::Registry.register(
    Pwb::ExternalFeed::Providers::ResalesOnline
  )

  Pwb::ExternalFeed::Registry.register(
    Pwb::ExternalFeed::Providers::MyProvider
  )
end
```

### Step 3: Configure for a Website

```ruby
# In rails console or via admin UI
website = Pwb::Website.find(1)
website.update!(
  external_feed_enabled: true,
  external_feed_provider: "my_provider",
  external_feed_config: {
    "api_key" => "your_api_key",
    "cache_ttl_search" => 3600,
    "cache_ttl_property" => 86400
  }
)
```

---

## Resales Online Provider

### Complete Implementation

```ruby
# app/services/pwb/external_feed/providers/resales_online.rb
module Pwb
  module ExternalFeed
    module Providers
      class ResalesOnline < BaseProvider
        # API Endpoints
        SEARCH_URL_V6 = "https://webapi.resales-online.com/WebApi/V6/SearchProperties.php"
        SEARCH_URL_V5 = "https://webapi.resales-online.com/WebApi/V5-2/SearchProperties.php"
        DETAILS_URL = "https://webapi.resales-online.com/WebApi/V6/PropertyDetails.php"

        # Language codes
        LANG_CODES = {
          en: "1", es: "2", de: "3", fr: "4", nl: "5",
          da: "6", ru: "7", sv: "8", pl: "9", no: "10", tr: "11"
        }.freeze

        # Sort options
        SORT_OPTIONS = {
          price_asc: "0",
          price_desc: "1",
          location: "2",
          newest: "3",
          oldest: "4",
          listed_newest: "5",
          listed_oldest: "6"
        }.freeze

        def self.provider_name
          :resales_online
        end

        def search(params)
          listing_type = params[:listing_type] || :sale
          url = listing_type == :rental ? SEARCH_URL_V5 : SEARCH_URL_V6
          api_id = listing_type == :rental ? @config[:api_id_rentals] : @config[:api_id_sales]

          query_params = build_search_query(params, api_id)
          response = fetch_json("#{url}?#{query_params}")

          normalize_search_results(response, params)
        end

        def find(reference, params = {})
          listing_type = params[:listing_type] || :sale
          api_id = listing_type == :rental ? @config[:api_id_rentals] : @config[:api_id_sales]
          lang_code = LANG_CODES[params[:locale]&.to_sym] || "1"

          query = URI.encode_www_form({
            p1: @config[:p1_constant] || "1014359",
            p2: @config[:api_key],
            P_Lang: lang_code,
            p_agency_filterid: api_id == "4069" ? "1" : "2",
            P_RefId: reference
          })

          response = fetch_json("#{DETAILS_URL}?#{query}")

          return nil unless response.dig("Property")

          # Check status
          status = response.dig("Property", "Status", "system")
          if ["Off Market", "Sold"].include?(status)
            prop = normalize_property(response["Property"], params)
            prop.status = status == "Sold" ? :sold : :unavailable
            return prop
          end

          normalize_property(response["Property"], params)
        end

        def similar(property, params = {})
          search_params = {
            locale: params[:locale] || :en,
            listing_type: property.listing_type,
            property_types: [property.property_type_raw],
            location: property.city,
            min_price: (property.price * 0.7).to_i,
            max_price: (property.price * 1.3).to_i,
            min_bedrooms: property.bedrooms,
            sort: :newest,
            per_page: (params[:limit] || 8) + 1  # +1 to exclude current
          }

          result = search(search_params)
          result.properties
                .reject { |p| p.reference == property.reference }
                .first(params[:limit] || 8)
        end

        def locations(params = {})
          # Resales Online doesn't have a locations endpoint
          # Return configured locations or fetch from search
          @config[:locations] || default_costa_del_sol_locations
        end

        def property_types(params = {})
          # Return configured property types
          @config[:property_types] || default_property_types
        end

        def available?
          # Quick test query
          response = fetch_json("#{SEARCH_URL_V6}?p1=#{@config[:p1_constant]}&p2=#{@config[:api_key]}&p_apiid=#{@config[:api_id_sales]}&p_PageSize=1")
          response.dig("transaction", "status") == "success"
        rescue StandardError
          false
        end

        protected

        def required_config_keys
          [:api_key, :api_id_sales]
        end

        private

        def build_search_query(params, api_id)
          lang_code = LANG_CODES[params[:locale]&.to_sym] || "1"

          query = {
            p1: @config[:p1_constant] || "1014359",
            p2: @config[:api_key],
            p_apiid: api_id,
            p_PageSize: params[:per_page] || 24,
            P_Lang: lang_code,
            P_Country: @config[:default_country] || "Spain",
            P_Images: @config[:image_count] || 0,
            p_MustHaveFeatures: "2",
            p_new_devs: "include"
          }

          # Pagination
          query[:p_PageNo] = params[:page] if params[:page]

          # Sort
          if params[:sort]
            query[:p_SortType] = SORT_OPTIONS[params[:sort].to_sym] || "0"
          end

          # Property types
          if params[:property_types]&.any?
            query[:p_PropertyTypes] = params[:property_types].join(",")
          end

          # Location
          query[:p_Location] = params[:location] if params[:location]

          # Bedrooms (use "Nx" format for "at least N")
          if params[:min_bedrooms]
            query[:p_Beds] = "#{params[:min_bedrooms]}x"
          end

          # Bathrooms
          if params[:min_bathrooms]
            query[:p_Baths] = "#{params[:min_bathrooms]}x"
          end

          # Price range
          query[:p_Min] = params[:min_price] if params[:min_price]
          query[:p_Max] = params[:max_price] if params[:max_price]

          # Features
          if params[:features]&.any?
            params[:features].each do |feature|
              query[feature] = "1"
            end
          end

          URI.encode_www_form(query)
        end

        def fetch_json(url)
          require "addressable/uri"
          require "open-uri"

          uri = URI.parse(Addressable::URI.escape(url))
          response = uri.open(redirect: false, read_timeout: 30)
          JSON.parse(response.read)
        rescue OpenURI::HTTPRedirect => redirect
          URI.parse(redirect.uri.to_s).open(redirect: false) { |r| JSON.parse(r.read) }
        rescue OpenURI::HTTPError => e
          handle_http_error(e)
        rescue JSON::ParserError
          raise InvalidResponseError, "Invalid JSON from Resales API"
        rescue StandardError => e
          Rails.logger.error("[ResalesOnline] Error: #{e.message}")
          raise ProviderUnavailableError, e.message
        end

        def handle_http_error(error)
          code = error.io.status[0]
          case code
          when "401", "403"
            raise AuthenticationError, "Resales API authentication failed"
          when "429"
            raise RateLimitError, "Resales API rate limit exceeded"
          else
            raise ProviderUnavailableError, "Resales API error: #{code}"
          end
        end

        def normalize_search_results(response, params)
          unless response.dig("transaction", "status") == "success"
            raise Error, response.dig("transaction", "message") || "Search failed"
          end

          properties_data = response["Property"]
          properties_data = [] if properties_data.nil?
          properties_data = [properties_data] if properties_data.is_a?(Hash)

          properties = properties_data.map do |prop|
            normalize_property(prop, params)
          end

          NormalizedSearchResult.new(
            properties: properties,
            total_count: response.dig("QueryInfo", "PropertyCount").to_i,
            page: response.dig("QueryInfo", "CurrentPage").to_i,
            per_page: response.dig("QueryInfo", "PropertiesPerPage").to_i,
            provider: self.class.provider_name,
            query_params: params
          )
        end

        def normalize_property(data, params = {})
          listing_type = params[:listing_type] || :sale

          NormalizedProperty.new(
            reference: data["Reference"],
            provider: self.class.provider_name,
            provider_url: nil,

            title: extract_title(data),
            description: data["Description"],
            property_type: normalize_type(data["Type"]),
            property_type_raw: data.dig("PropertyType", "SubtypeId1") || data["TypeId"],
            property_subtype: data.dig("PropertyType", "Subtype1") || data["Type"],

            country: data["Country"],
            region: data["Province"],
            area: data["Area"],
            city: data["Location"],
            latitude: data.dig("GeoData", "Latitude")&.to_f,
            longitude: data.dig("GeoData", "Longitude")&.to_f,

            listing_type: listing_type,
            status: normalize_status(data.dig("Status", "system")),
            price: (data["Price"].to_f * 100).to_i,
            price_raw: data["Price"].to_s,
            currency: data["Currency"] || "EUR",
            original_price: data["OriginalPrice"] ? (data["OriginalPrice"].to_f * 100).to_i : nil,

            bedrooms: data["Bedrooms"].to_i,
            bathrooms: data["Bathrooms"].to_f,
            built_area: data["Built"].to_i,
            plot_area: data["GardenPlot"].to_i,
            terrace_area: data["Terrace"].to_i,

            features: extract_features(data),
            features_by_category: extract_features_by_category(data),

            energy_rating: data.dig("EnergyRating", "EnergyRated"),
            energy_value: data.dig("EnergyRating", "EnergyValue")&.to_f,
            co2_rating: data.dig("EnergyRating", "CO2Rated"),

            images: normalize_images(data),
            virtual_tour_url: data["VirtualTour"],

            community_fees: data["Community_Fees_Year"] ? (data["Community_Fees_Year"].to_f * 100).to_i : nil,
            ibi_tax: data["IBI_Fees_Year"] ? (data["IBI_Fees_Year"].to_f * 100).to_i : nil
          )
        end

        def extract_title(data)
          # Build title from available data
          type = data["Type"] || "Property"
          location = data["Location"]
          bedrooms = data["Bedrooms"]

          parts = []
          parts << "#{bedrooms} Bedroom" if bedrooms && bedrooms.to_i > 0
          parts << type
          parts << "in #{location}" if location

          parts.join(" ")
        end

        def normalize_type(type)
          return "other" if type.blank?

          type_lower = type.to_s.downcase
          case type_lower
          when /penthouse/
            "penthouse"
          when /top floor|top-floor/
            "apartment_top"
          when /ground floor|ground-floor/
            "apartment_ground"
          when /middle floor|middle-floor/
            "apartment_middle"
          when /apartment|flat/
            "apartment"
          when /villa|detached/
            "villa"
          when /townhouse|town house|terraced/
            "townhouse"
          when /semi-detached|semi detached/
            "semi_detached"
          when /bungalow/
            "bungalow"
          when /finca|cortijo|country/
            "finca"
          when /plot|land/
            "land"
          when /commercial|office|retail/
            "commercial"
          else
            "other"
          end
        end

        def normalize_status(status)
          case status
          when "Available"
            :available
          when "Reserved"
            :reserved
          when "Sold"
            :sold
          when "Off Market"
            :unavailable
          else
            :available
          end
        end

        def normalize_images(data)
          pictures = data.dig("Pictures", "Picture")
          return [] unless pictures

          pictures = [pictures] if pictures.is_a?(Hash)

          pictures.map.with_index do |pic, idx|
            {
              url: pic["PictureURL"],
              caption: nil,
              position: idx
            }
          end
        end

        def extract_features(data)
          categories = data.dig("PropertyFeatures", "Category")
          return [] unless categories

          categories = [categories] if categories.is_a?(Hash)

          categories.flat_map do |cat|
            values = cat["Value"]
            values.is_a?(Array) ? values : [values]
          end.compact
        end

        def extract_features_by_category(data)
          categories = data.dig("PropertyFeatures", "Category")
          return {} unless categories

          categories = [categories] if categories.is_a?(Hash)

          categories.each_with_object({}) do |cat, hash|
            category_name = cat.dig("@attributes", "Type") || "Other"
            values = cat["Value"]
            values = values.is_a?(Array) ? values : [values]
            hash[category_name] = values.compact
          end
        end

        def default_costa_del_sol_locations
          [
            { value: "Marbella", label: "Marbella" },
            { value: "Estepona", label: "Estepona" },
            { value: "Benahavis", label: "Benahavís" },
            { value: "Mijas", label: "Mijas" },
            { value: "Fuengirola", label: "Fuengirola" },
            { value: "Benalmadena", label: "Benalmádena" },
            { value: "Torremolinos", label: "Torremolinos" },
            { value: "Malaga", label: "Málaga" },
            { value: "Nerja", label: "Nerja" },
            { value: "Casares", label: "Casares" },
            { value: "Manilva", label: "Manilva" },
            { value: "Sotogrande", label: "Sotogrande" }
          ]
        end

        def default_property_types
          [
            { value: "1-1", label: "Apartment", subtypes: [
              { value: "1-2", label: "Ground Floor Apartment" },
              { value: "1-4", label: "Middle Floor Apartment" },
              { value: "1-5", label: "Top Floor Apartment" },
              { value: "1-6", label: "Penthouse" }
            ]},
            { value: "2-1", label: "House", subtypes: [
              { value: "2-2", label: "Detached Villa" },
              { value: "2-4", label: "Semi-Detached House" },
              { value: "2-5", label: "Townhouse" },
              { value: "2-6", label: "Finca/Country House" }
            ]},
            { value: "3-1", label: "Plot/Land" },
            { value: "4-1", label: "Commercial" }
          ]
        end
      end
    end
  end
end
```

### Configuration Example

```ruby
# Complete Resales Online configuration for a website
website.update!(
  external_feed_enabled: true,
  external_feed_provider: "resales_online",
  external_feed_config: {
    # Required credentials
    "api_key" => "your_api_key",
    "api_id_sales" => "1234",
    "api_id_rentals" => "5678",
    "p1_constant" => "1014359",

    # Optional settings
    "default_country" => "Spain",
    "default_locale" => "en",
    "supported_locales" => ["en", "es", "fr", "de", "nl"],
    "image_count" => 0,  # 0 = all, or limit number

    # Cache TTLs (seconds)
    "cache_ttl_search" => 3600,
    "cache_ttl_property" => 86400,
    "cache_ttl_similar" => 21600,
    "cache_ttl_static" => 604800,

    # Search defaults
    "results_per_page" => 24,
    "default_sort" => "newest",

    # Custom locations (optional - overrides defaults)
    "locations" => [
      { "value" => "Marbella", "label" => "Marbella" },
      { "value" => "Estepona", "label" => "Estepona" }
    ],

    # Custom property types (optional)
    "property_types" => [
      { "value" => "1-1,1-6", "label" => "Apartments & Penthouses" },
      { "value" => "2-1,2-2", "label" => "Villas & Houses" }
    ],

    # Feature mappings for search filters
    "features" => {
      "pool" => { "param" => "1Pool1", "label" => "Swimming Pool" },
      "sea_views" => { "param" => "1Views1", "label" => "Sea Views" },
      "golf" => { "param" => "1Setting2", "label" => "Frontline Golf" }
    }
  }
)
```

---

## Future Providers

### Planned Providers

| Provider | Region | Status | Notes |
|----------|--------|--------|-------|
| Resales Online | Spain (Costa del Sol) | Implemented | First provider |
| Kyero | Spain, Portugal | Planned | XML feed |
| ThinkSpain | Spain | Planned | XML/JSON feed |
| Idealista | Spain, Portugal, Italy | Planned | API partnership required |
| Rightmove | UK | Planned | BLM/Rightmove Data Feed |
| Generic XML | Any | Planned | Configurable XML parser |
| Generic JSON | Any | Planned | Configurable JSON parser |

### Adding a New Provider Checklist

1. [ ] Create provider class inheriting from `BaseProvider`
2. [ ] Implement all required methods (`search`, `find`, `similar`, etc.)
3. [ ] Add property type normalization mapping
4. [ ] Add locale/language code mapping
5. [ ] Implement proper error handling
6. [ ] Register provider in initializer
7. [ ] Add configuration documentation
8. [ ] Write tests for provider
9. [ ] Test with real API credentials
10. [ ] Document any provider-specific quirks

---

## Testing

### Unit Tests

```ruby
# spec/services/pwb/external_feed/providers/resales_online_spec.rb
require "rails_helper"

RSpec.describe Pwb::ExternalFeed::Providers::ResalesOnline do
  let(:config) do
    {
      api_key: "test_key",
      api_id_sales: "1234",
      api_id_rentals: "5678"
    }
  end

  subject { described_class.new(config) }

  describe "#search" do
    it "returns normalized search results" do
      stub_resales_search_request

      result = subject.search(locale: :en, listing_type: :sale)

      expect(result).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
      expect(result.properties).to all(be_a(Pwb::ExternalFeed::NormalizedProperty))
    end
  end

  describe "#find" do
    it "returns normalized property" do
      stub_resales_property_request("R123456")

      result = subject.find("R123456", locale: :en)

      expect(result).to be_a(Pwb::ExternalFeed::NormalizedProperty)
      expect(result.reference).to eq("R123456")
    end
  end

  # ... more tests
end
```

### Integration Tests

```ruby
# spec/requests/site/external_listings_spec.rb
require "rails_helper"

RSpec.describe "External Listings", type: :request do
  let(:website) { create(:pwb_website, :with_external_feed) }

  before do
    host! "#{website.subdomain}.test.host"
    stub_external_feed_requests
  end

  describe "GET /external_listings" do
    it "displays search results" do
      get external_listings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("property-card")
    end
  end

  describe "GET /external_listings/:reference" do
    it "displays property details" do
      get external_listing_path("R123456")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("R123456")
    end
  end
end
```

---

## Appendix: API Response Examples

### Resales Online Search Response

```json
{
  "transaction": {
    "status": "success",
    "datetime": "01-01-2025 12:00:00"
  },
  "QueryInfo": {
    "ApiId": "1195",
    "PropertyCount": 150,
    "CurrentPage": 1,
    "PropertiesPerPage": 24
  },
  "Property": [
    {
      "Reference": "R3096106",
      "AgencyRef": "AM134",
      "Country": "Spain",
      "Province": "Malaga",
      "Area": "Costa del Sol",
      "Location": "Marbella",
      "Type": "Penthouse",
      "PropertyType": {
        "SubtypeId1": "1-6",
        "Subtype1": "Penthouse"
      },
      "Bedrooms": 3,
      "Bathrooms": 2,
      "Currency": "EUR",
      "Price": 450000,
      "Built": 120,
      "Terrace": 30,
      "Status": {
        "system": "Available"
      },
      "Pictures": {
        "Picture": [
          { "PictureURL": "https://media.resales-online.com/..." }
        ]
      }
    }
  ]
}
```

### Resales Online Property Details Response

```json
{
  "transaction": {
    "status": "success",
    "service": "Property Details"
  },
  "Property": {
    "Reference": "R3096106",
    "Country": "Spain",
    "Province": "Malaga",
    "Location": "Marbella",
    "Type": "Penthouse",
    "Bedrooms": 3,
    "Bathrooms": 2,
    "Price": 450000,
    "OriginalPrice": 500000,
    "Currency": "EUR",
    "Built": 120,
    "Terrace": 30,
    "Description": "Stunning penthouse with panoramic sea views...",
    "PropertyFeatures": {
      "Category": [
        {
          "@attributes": { "Type": "Views" },
          "Value": ["Sea Views", "Mountain Views"]
        },
        {
          "@attributes": { "Type": "Pool" },
          "Value": "Communal Pool"
        }
      ]
    },
    "EnergyRating": {
      "EnergyRated": "D",
      "EnergyValue": 95.5,
      "CO2Rated": "E"
    },
    "Pictures": {
      "Picture": [
        { "PictureURL": "https://media.resales-online.com/..." }
      ]
    }
  }
}
```
