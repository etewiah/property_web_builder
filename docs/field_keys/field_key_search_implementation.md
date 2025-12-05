# Field Key Search Implementation Plan

## Executive Summary

This document outlines the implementation strategy for advanced field key-based property searching in PropertyWebBuilder. Field keys provide a flexible labeling system for properties, enabling categorization, filtering, and search functionality.

### Current Architecture

The property data model has been normalized:
- **RealtyAsset** - Physical property data (location, rooms, features)
- **SaleListing** - Sale transaction data (price, title, description)
- **RentalListing** - Rental transaction data (price, title, description)
- **ListedProperty** - Materialized view combining all data for optimized reads
- **Feature** - Many-to-many relationship for property features/amenities

Translations use **Mobility** gem with JSONB storage on listing models.

### Field Key Categories

| Tag | Purpose | Storage |
|-----|---------|---------|
| `property-types` | What the property is | `RealtyAsset.prop_type_key` |
| `property-states` | Physical condition | `RealtyAsset.prop_state_key` |
| `property-features` | Permanent physical attributes | `Feature` join table |
| `property-amenities` | Equipment & services | `Feature` join table |
| `property-status` | Transaction status | `Feature` join table or listing fields |
| `property-highlights` | Marketing flags | `Feature` join table or listing fields |
| `listing-origin` | Source of listing | `RealtyAsset.prop_origin_key` |

### Goals

1. Enable feature/amenity-based search with AND/OR logic
2. Support multi-select filtering in search UI
3. Provide faceted search with result counts
4. Maintain performance with large datasets
5. Support URL-friendly search parameters

---

## Current State Analysis

### What Works Today

**Basic Field Key Filtering:**
```ruby
# app/controllers/pwb/search_controller.rb
@properties = @current_website.listed_properties.visible
  .where(prop_type_key: params[:property_type])
  .where(prop_state_key: params[:property_state])
```

**Field Key Options for Dropdowns:**
```ruby
Pwb::FieldKey.get_options_by_tag("property-types")
# => [OpenStruct(value: "types.apartment", label: "Apartment"), ...]
```

### Current Limitations

1. Features/amenities cannot be used in search filters
2. No multi-select (can't search for "Pool AND Garden")
3. No faceted search counts ("42 properties with Pool")
4. No search by translated label (only by global_key)
5. Spanish-based legacy keys need migration to English

---

## Implementation Phases

### Phase 1: Foundation (High Priority) - 2-3 weeks
- Feature/amenity search scopes on ListedProperty
- Update search controller and views
- Database indexes for performance
- API endpoint updates

### Phase 2: Enhanced Search (Medium Priority) - 3-4 weeks
- Faceted search with counts
- URL-friendly search parameters
- Full-text search across translations

### Phase 3: Advanced Features (Low Priority) - 4-6 weeks
- Saved searches with notifications
- Search analytics dashboard
- Hierarchical field keys

---

## Phase 1: Foundation - Detailed Implementation

### 1.1 Add Feature Search Scopes to ListedProperty

**File:** `app/models/pwb/listed_property.rb`

```ruby
# Search properties that have ALL specified features (AND logic)
scope :with_features, ->(feature_keys) {
  return all if feature_keys.blank?

  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?

  joins(:features)
    .where(pwb_features: { feature_key: feature_array })
    .group("pwb_properties.id")
    .having("COUNT(DISTINCT pwb_features.feature_key) = ?", feature_array.length)
}

# Search properties that have ANY of the specified features (OR logic)
scope :with_any_features, ->(feature_keys) {
  return all if feature_keys.blank?

  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?

  joins(:features)
    .where(pwb_features: { feature_key: feature_array })
    .distinct
}

# Exclude properties that have specific features
scope :without_features, ->(feature_keys) {
  return all if feature_keys.blank?

  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?

  where.not(
    id: joins(:features)
      .where(pwb_features: { feature_key: feature_array })
      .select(:id)
  )
}
```

**Test Coverage:**

```ruby
# spec/models/pwb/listed_property_spec.rb
RSpec.describe Pwb::ListedProperty do
  describe '.with_features' do
    let(:pool_key) { 'features.private_pool' }
    let(:garden_key) { 'features.private_garden' }

    it 'finds properties with ALL specified features' do
      prop_with_both = create_property_with_features([pool_key, garden_key])
      prop_with_pool = create_property_with_features([pool_key])

      results = described_class.with_features([pool_key, garden_key])

      expect(results).to include(prop_with_both)
      expect(results).not_to include(prop_with_pool)
    end

    it 'returns all properties when given empty array' do
      expect(described_class.with_features([])).to eq(described_class.all)
    end
  end

  describe '.with_any_features' do
    it 'finds properties with ANY of the specified features' do
      prop_with_pool = create_property_with_features(['features.private_pool'])
      prop_with_garden = create_property_with_features(['features.private_garden'])
      prop_with_neither = create_property_with_features([])

      results = described_class.with_any_features(['features.private_pool', 'features.private_garden'])

      expect(results).to include(prop_with_pool, prop_with_garden)
      expect(results).not_to include(prop_with_neither)
    end
  end
end
```

**TODO:**
- [ ] Add `with_features` scope to `ListedProperty`
- [ ] Add `with_any_features` scope to `ListedProperty`
- [ ] Add `without_features` scope to `ListedProperty`
- [ ] Write specs for all feature scopes
- [ ] Test with various feature counts (1, 2, 5, 10+)

---

### 1.2 Update Search Controller

**File:** `app/controllers/pwb/search_controller.rb`

```ruby
module Pwb
  class SearchController < ApplicationController
    before_action :set_search_options

    def buy
      @operation_type = "for_sale"
      @properties = base_search_scope.for_sale

      apply_filters
      apply_feature_filters

      @properties = @properties.limit(45)
      set_map_markers
    end

    def rent
      @operation_type = "for_rent"
      @properties = base_search_scope.for_rent

      apply_filters
      apply_feature_filters

      @properties = @properties.limit(45)
      set_map_markers
    end

    def search_ajax_for_sale
      @operation_type = "for_sale"
      @properties = base_search_scope.for_sale

      apply_filters
      apply_feature_filters

      set_map_markers
      render "/pwb/search/search_ajax", layout: false
    end

    def search_ajax_for_rent
      @operation_type = "for_rent"
      @properties = base_search_scope.for_rent

      apply_filters
      apply_feature_filters

      set_map_markers
      render "/pwb/search/search_ajax", layout: false
    end

    private

    def base_search_scope
      @current_website.listed_properties.visible
    end

    def set_search_options
      @property_types = Pwb::FieldKey.get_options_by_tag("property-types")
      @property_states = Pwb::FieldKey.get_options_by_tag("property-states")
      @property_features = Pwb::FieldKey.get_options_by_tag("property-features")
      @property_amenities = Pwb::FieldKey.get_options_by_tag("property-amenities")
    end

    def apply_filters
      # Property type filter
      if search_params[:property_type].present?
        @properties = @properties.where(prop_type_key: search_params[:property_type])
      end

      # Property state filter
      if search_params[:property_state].present?
        @properties = @properties.where(prop_state_key: search_params[:property_state])
      end

      # Price filters
      apply_price_filters

      # Room filters
      @properties = @properties.bedrooms_from(search_params[:count_bedrooms]) if search_params[:count_bedrooms].present?
      @properties = @properties.bathrooms_from(search_params[:count_bathrooms]) if search_params[:count_bathrooms].present?
    end

    def apply_feature_filters
      return unless search_params[:features].present?

      feature_keys = parse_feature_params(search_params[:features])
      return if feature_keys.empty?

      if search_params[:features_match] == 'any'
        @properties = @properties.with_any_features(feature_keys)
      else
        # Default: ALL features required (AND logic)
        @properties = @properties.with_features(feature_keys)
      end
    end

    def parse_feature_params(features_param)
      case features_param
      when String
        features_param.split(',').map(&:strip).reject(&:blank?)
      when Array
        features_param.reject(&:blank?)
      else
        []
      end
    end

    def apply_price_filters
      currency = @current_website.default_currency || "usd"
      currency_obj = Money::Currency.find(currency)

      if @operation_type == "for_sale"
        if search_params[:for_sale_price_from].present?
          cents = search_params[:for_sale_price_from].gsub(/\D/, "").to_i * currency_obj.subunit_to_unit
          @properties = @properties.for_sale_price_from(cents)
        end
        if search_params[:for_sale_price_till].present?
          cents = search_params[:for_sale_price_till].gsub(/\D/, "").to_i * currency_obj.subunit_to_unit
          @properties = @properties.for_sale_price_till(cents)
        end
      else
        if search_params[:for_rent_price_from].present?
          cents = search_params[:for_rent_price_from].gsub(/\D/, "").to_i * currency_obj.subunit_to_unit
          @properties = @properties.for_rent_price_from(cents)
        end
        if search_params[:for_rent_price_till].present?
          cents = search_params[:for_rent_price_till].gsub(/\D/, "").to_i * currency_obj.subunit_to_unit
          @properties = @properties.for_rent_price_till(cents)
        end
      end
    end

    def search_params
      params.fetch(:search, {}).permit(
        :property_type,
        :property_state,
        :for_sale_price_from,
        :for_sale_price_till,
        :for_rent_price_from,
        :for_rent_price_till,
        :count_bedrooms,
        :count_bathrooms,
        :features_match,
        features: []
      )
    end

    def set_map_markers
      @map_markers = []
      @properties.each do |property|
        next unless property.show_map
        @map_markers.push(
          id: property.id,
          title: property.title,
          show_url: property.contextual_show_path(@operation_type),
          image_url: property.primary_image_url,
          display_price: property.contextual_price_with_currency(@operation_type),
          position: { lat: property.latitude, lng: property.longitude }
        )
      end
    end
  end
end
```

**TODO:**
- [ ] Refactor search controller to use new structure
- [ ] Add `apply_feature_filters` method
- [ ] Update `search_params` to permit features array
- [ ] Write controller specs

---

### 1.3 Update Search View - Feature Checkboxes

**File:** `app/views/pwb/search/_feature_filters.html.erb`

```erb
<div class="feature-filters">
  <h4><%= t('search.features') %></h4>

  <div class="feature-section">
    <h5><%= t('search.property_features') %></h5>
    <div class="checkbox-grid">
      <% @property_features.each do |feature| %>
        <label class="checkbox-item">
          <%= check_box_tag 'search[features][]',
              feature.value,
              params.dig(:search, :features)&.include?(feature.value),
              id: "feature_#{feature.value.parameterize}" %>
          <span><%= feature.label %></span>
        </label>
      <% end %>
    </div>
  </div>

  <div class="feature-section">
    <h5><%= t('search.property_amenities') %></h5>
    <div class="checkbox-grid">
      <% @property_amenities.each do |amenity| %>
        <label class="checkbox-item">
          <%= check_box_tag 'search[features][]',
              amenity.value,
              params.dig(:search, :features)&.include?(amenity.value),
              id: "amenity_#{amenity.value.parameterize}" %>
          <span><%= amenity.label %></span>
        </label>
      <% end %>
    </div>
  </div>

  <div class="features-match">
    <label><%= t('search.features_match') %></label>
    <%= select_tag 'search[features_match]',
        options_for_select([
          [t('search.match_all'), 'all'],
          [t('search.match_any'), 'any']
        ], params.dig(:search, :features_match) || 'all'),
        class: 'form-control' %>
  </div>
</div>

<style>
.checkbox-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 8px;
}
.checkbox-item {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}
.feature-section {
  margin-bottom: 16px;
}
</style>
```

**TODO:**
- [ ] Create `_feature_filters.html.erb` partial
- [ ] Add translations for feature labels
- [ ] Style checkboxes appropriately
- [ ] Add JavaScript for "Select All" / "Clear All"

---

### 1.4 Database Indexes

**File:** `db/migrate/YYYYMMDD_add_feature_search_indexes.rb`

```ruby
class AddFeatureSearchIndexes < ActiveRecord::Migration[8.0]
  def change
    # Index on feature_key for fast lookups
    unless index_exists?(:pwb_features, :feature_key)
      add_index :pwb_features, :feature_key
    end

    # Composite index for realty_asset + feature queries
    unless index_exists?(:pwb_features, [:realty_asset_id, :feature_key])
      add_index :pwb_features, [:realty_asset_id, :feature_key]
    end

    # Index on prop_state_key if missing
    unless index_exists?(:pwb_realty_assets, :prop_state_key)
      add_index :pwb_realty_assets, :prop_state_key
    end

    # Composite index for common search patterns
    unless index_exists?(:pwb_realty_assets, [:website_id, :prop_type_key])
      add_index :pwb_realty_assets, [:website_id, :prop_type_key]
    end
  end
end
```

**TODO:**
- [ ] Create migration for search indexes
- [ ] Run migration on development
- [ ] Test query performance with `EXPLAIN ANALYZE`
- [ ] Run on staging/production

---

### 1.5 Update API Endpoints

**REST API:**

**File:** `app/controllers/pwb/api/v1/properties_controller.rb`

```ruby
def index
  properties = Pwb::Current.website.listed_properties.visible

  # Apply field key filters
  properties = properties.where(prop_type_key: params[:property_type]) if params[:property_type].present?
  properties = properties.where(prop_state_key: params[:property_state]) if params[:property_state].present?

  # Apply feature filters
  if params[:features].present?
    feature_keys = params[:features].split(',')
    if params[:features_match] == 'any'
      properties = properties.with_any_features(feature_keys)
    else
      properties = properties.with_features(feature_keys)
    end
  end

  render jsonapi: properties, include: ['features']
end
```

**GraphQL API:**

**File:** `app/graphql/types/query_type.rb`

```ruby
field :search_properties, [Types::PropertyType], null: false do
  argument :property_type, String, required: false
  argument :property_state, String, required: false
  argument :features, [String], required: false
  argument :features_match, String, required: false, default_value: 'all'
  argument :bedrooms_from, Int, required: false
  argument :bathrooms_from, Int, required: false
  argument :for_sale, Boolean, required: false
  argument :for_rent, Boolean, required: false
end

def search_properties(**args)
  properties = Pwb::Current.website.listed_properties.visible

  properties = properties.where(prop_type_key: args[:property_type]) if args[:property_type]
  properties = properties.where(prop_state_key: args[:property_state]) if args[:property_state]
  properties = properties.for_sale if args[:for_sale]
  properties = properties.for_rent if args[:for_rent]
  properties = properties.bedrooms_from(args[:bedrooms_from]) if args[:bedrooms_from]
  properties = properties.bathrooms_from(args[:bathrooms_from]) if args[:bathrooms_from]

  if args[:features].present?
    if args[:features_match] == 'any'
      properties = properties.with_any_features(args[:features])
    else
      properties = properties.with_features(args[:features])
    end
  end

  properties
end
```

**TODO:**
- [ ] Update REST API controller
- [ ] Update GraphQL query type
- [ ] Write API specs
- [ ] Update API documentation

---

## Phase 2: Enhanced Search

### 2.1 Faceted Search Service

**File:** `app/services/pwb/search_facets_service.rb`

```ruby
module Pwb
  class SearchFacetsService
    def self.calculate(scope, website)
      {
        property_types: calculate_by_field(:prop_type_key, scope, "property-types", website),
        property_states: calculate_by_field(:prop_state_key, scope, "property-states", website),
        features: calculate_features(scope, website),
        amenities: calculate_amenities(scope, website)
      }
    end

    private

    def self.calculate_by_field(field, scope, tag, website)
      counts = scope.group(field).count

      Pwb::FieldKey.by_tag(tag).visible.map do |fk|
        {
          global_key: fk.global_key,
          label: I18n.t(fk.global_key),
          count: counts[fk.global_key] || 0
        }
      end.sort_by { |f| -f[:count] }
    end

    def self.calculate_features(scope, website)
      counts = scope.joins(:features)
        .where(pwb_features: { feature_key: feature_keys_for_tag("property-features") })
        .group('pwb_features.feature_key')
        .count

      build_facet_list("property-features", counts)
    end

    def self.calculate_amenities(scope, website)
      counts = scope.joins(:features)
        .where(pwb_features: { feature_key: feature_keys_for_tag("property-amenities") })
        .group('pwb_features.feature_key')
        .count

      build_facet_list("property-amenities", counts)
    end

    def self.feature_keys_for_tag(tag)
      Pwb::FieldKey.by_tag(tag).pluck(:global_key)
    end

    def self.build_facet_list(tag, counts)
      Pwb::FieldKey.by_tag(tag).visible.map do |fk|
        {
          global_key: fk.global_key,
          label: I18n.t(fk.global_key),
          count: counts[fk.global_key] || 0
        }
      end.sort_by { |f| -f[:count] }
    end
  end
end
```

**Controller Update:**

```ruby
def buy
  # ... existing code ...

  # Calculate facets for UI
  if params[:include_facets]
    @facets = SearchFacetsService.calculate(@properties, @current_website)
  end
end
```

**View Update:**

```erb
<% if @facets %>
  <div class="search-facets">
    <h4>Property Type</h4>
    <% @facets[:property_types].each do |facet| %>
      <% next if facet[:count] == 0 %>
      <label>
        <%= check_box_tag 'search[property_type]', facet[:global_key],
            params.dig(:search, :property_type) == facet[:global_key] %>
        <%= facet[:label] %> (<%= facet[:count] %>)
      </label>
    <% end %>

    <h4>Features</h4>
    <% @facets[:features].each do |facet| %>
      <% next if facet[:count] == 0 %>
      <label>
        <%= check_box_tag 'search[features][]', facet[:global_key],
            params.dig(:search, :features)&.include?(facet[:global_key]) %>
        <%= facet[:label] %> (<%= facet[:count] %>)
      </label>
    <% end %>
  </div>
<% end %>
```

**TODO:**
- [ ] Create `SearchFacetsService`
- [ ] Add facet calculation to controller
- [ ] Update views to display facet counts
- [ ] Add caching for facet counts
- [ ] Write specs

---

### 2.2 URL-Friendly Search Parameters

**Goal:** Enable SEO-friendly, bookmarkable search URLs.

**Current:** `/buy?search[features][]=features.private_pool&search[features][]=features.sea_views`

**Target:** `/buy?features=pool,sea-views&type=apartment`

**Helper Methods:**

**File:** `app/helpers/search_url_helper.rb`

```ruby
module SearchUrlHelper
  # Convert global_key to URL-friendly slug
  def feature_to_slug(global_key)
    # "features.private_pool" => "private-pool"
    global_key.split('.').last.tr('_', '-')
  end

  # Convert URL slug back to global_key
  def slug_to_feature(slug, tag)
    # "private-pool" => "features.private_pool"
    key = "#{tag_prefix(tag)}.#{slug.tr('-', '_')}"
    Pwb::FieldKey.find_by(global_key: key)&.global_key
  end

  def tag_prefix(tag)
    case tag
    when 'property-features' then 'features'
    when 'property-amenities' then 'amenities'
    when 'property-types' then 'types'
    when 'property-states' then 'states'
    else tag.split('-').last
    end
  end

  # Build SEO-friendly search URL
  def search_url_with_features(base_path:, features: [], type: nil, **params)
    url_params = params.dup

    if features.present?
      url_params[:features] = features.map { |f| feature_to_slug(f) }.join(',')
    end

    if type.present?
      url_params[:type] = feature_to_slug(type)
    end

    "#{base_path}?#{url_params.to_query}"
  end
end
```

**Controller Update:**

```ruby
before_action :normalize_url_params

private

def normalize_url_params
  # Convert URL-friendly slugs to global_keys
  if params[:features].is_a?(String)
    slugs = params[:features].split(',')
    params[:search] ||= {}
    params[:search][:features] = slugs.map do |slug|
      slug_to_feature(slug, 'property-features') ||
        slug_to_feature(slug, 'property-amenities')
    end.compact
  end

  if params[:type].present?
    params[:search] ||= {}
    params[:search][:property_type] = slug_to_feature(params[:type], 'property-types')
  end
end
```

**TODO:**
- [ ] Create `SearchUrlHelper`
- [ ] Add URL normalization to controller
- [ ] Update view links to use friendly URLs
- [ ] Add specs for URL conversion

---

## Phase 3: Advanced Features

### 3.1 Saved Searches

**Migration:**

```ruby
class CreateSavedSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_saved_searches do |t|
      t.references :user, null: true
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :name, null: false
      t.jsonb :search_params, default: {}, null: false
      t.integer :result_count
      t.datetime :last_run_at
      t.boolean :notify_on_new_results, default: false

      t.timestamps
    end

    add_index :pwb_saved_searches, :search_params, using: :gin
  end
end
```

**Model:**

```ruby
module Pwb
  class SavedSearch < ApplicationRecord
    belongs_to :user, optional: true
    belongs_to :website

    validates :name, presence: true
    validates :search_params, presence: true

    def execute
      scope = website.listed_properties.visible
      # Apply saved search params...
      scope
    end

    def new_results_available?
      return false if last_run_at.nil?
      execute.count > (result_count || 0)
    end
  end
end
```

**TODO:**
- [ ] Create migration
- [ ] Create SavedSearch model
- [ ] Create controller and views
- [ ] Add email notifications
- [ ] Write specs

---

### 3.2 Search Analytics

**Migration:**

```ruby
class CreateSearchAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_search_analytics do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.jsonb :search_params, default: {}, null: false
      t.integer :result_count
      t.string :session_id

      t.timestamps
    end

    add_index :pwb_search_analytics, :search_params, using: :gin
    add_index :pwb_search_analytics, :created_at
  end
end
```

**Service:**

```ruby
module Pwb
  class SearchAnalyticsService
    def self.track(website:, params:, result_count:, session_id:)
      SearchAnalytic.create!(
        website: website,
        search_params: sanitize_params(params),
        result_count: result_count,
        session_id: session_id
      )
    end

    def self.popular_features(website:, days: 30)
      SearchAnalytic
        .where(website: website)
        .where('created_at > ?', days.days.ago)
        .pluck(:search_params)
        .flat_map { |p| Array(p['features']) }
        .tally
        .sort_by { |_, count| -count }
        .to_h
    end
  end
end
```

**TODO:**
- [ ] Create migration
- [ ] Create analytics model and service
- [ ] Add tracking to search controller
- [ ] Create admin dashboard
- [ ] Add data retention policy

---

## Field Key Migration: Spanish to English

### Migration Script

```ruby
# lib/tasks/migrate_field_keys.rake
namespace :field_keys do
  desc "Migrate Spanish field keys to English"
  task migrate_to_english: :environment do
    MAPPINGS = {
      # Property Types
      'propertyTypes.apartamento' => 'types.apartment',
      'propertyTypes.chaletIndependiente' => 'types.house',
      'propertyTypes.bungalow' => 'types.bungalow',
      # ... add all mappings

      # Features (from extras)
      'extras.piscinaPrivada' => 'features.private_pool',
      'extras.piscinaComunitaria' => 'features.community_pool',
      'extras.jardinPrivado' => 'features.private_garden',
      'extras.vistasAlMar' => 'features.sea_views',
      # ... add all mappings

      # Amenities (from extras)
      'extras.aireAcondicionado' => 'amenities.air_conditioning',
      'extras.alarma' => 'amenities.alarm',
      'extras.ascensor' => 'amenities.elevator',
      # ... add all mappings
    }

    ActiveRecord::Base.transaction do
      MAPPINGS.each do |old_key, new_key|
        # Update FieldKey
        fk = Pwb::FieldKey.find_by(global_key: old_key)
        if fk
          new_tag = new_key.split('.').first == 'features' ? 'property-features' :
                    new_key.split('.').first == 'amenities' ? 'property-amenities' :
                    new_key.split('.').first == 'types' ? 'property-types' :
                    new_key.split('.').first == 'states' ? 'property-states' : fk.tag

          fk.update!(global_key: new_key, tag: new_tag)
          puts "Updated FieldKey: #{old_key} -> #{new_key}"
        end

        # Update Features
        Pwb::Feature.where(feature_key: old_key).update_all(feature_key: new_key)

        # Update RealtyAssets
        Pwb::RealtyAsset.where(prop_type_key: old_key).update_all(prop_type_key: new_key)
        Pwb::RealtyAsset.where(prop_state_key: old_key).update_all(prop_state_key: new_key)
        Pwb::RealtyAsset.where(prop_origin_key: old_key).update_all(prop_origin_key: new_key)
      end

      # Refresh materialized view
      Pwb::ListedProperty.refresh
    end

    puts "Migration complete!"
  end
end
```

**TODO:**
- [ ] Complete key mapping for all 44 extras
- [ ] Complete key mapping for property types
- [ ] Complete key mapping for property states
- [ ] Test migration on development
- [ ] Backup production database
- [ ] Run migration on production
- [ ] Update translations

---

## Testing Strategy

### Unit Tests

```ruby
# spec/models/pwb/listed_property_spec.rb
RSpec.describe Pwb::ListedProperty do
  describe 'feature scopes' do
    # Test with_features, with_any_features, without_features
  end
end

# spec/services/pwb/search_facets_service_spec.rb
RSpec.describe Pwb::SearchFacetsService do
  describe '.calculate' do
    # Test facet calculations
  end
end
```

### Integration Tests

```ruby
# spec/requests/pwb/search_spec.rb
RSpec.describe 'Property Search', type: :request do
  describe 'GET /buy' do
    it 'filters by features' do
      get '/buy', params: { search: { features: ['features.private_pool'] } }
      expect(response).to have_http_status(:success)
    end
  end
end
```

### System Tests

```ruby
# spec/system/property_search_spec.rb
RSpec.describe 'Property Search', type: :system do
  scenario 'User searches with features' do
    visit buy_path
    check 'Private Pool'
    click_button 'Search'
    expect(page).to have_content('properties found')
  end
end
```

---

## Performance Considerations

### Database Indexes

| Table | Columns | Purpose |
|-------|---------|---------|
| `pwb_features` | `feature_key` | Fast feature lookups |
| `pwb_features` | `[realty_asset_id, feature_key]` | JOIN optimization |
| `pwb_realty_assets` | `prop_state_key` | State filtering |
| `pwb_realty_assets` | `[website_id, prop_type_key]` | Multi-tenant type queries |

### Caching Strategy

```ruby
# Cache field key options (15 minutes)
Rails.cache.fetch("field_keys/#{website_id}/#{tag}/#{I18n.locale}", expires_in: 15.minutes) do
  Pwb::FieldKey.get_options_by_tag(tag)
end

# Cache facet counts (5 minutes)
Rails.cache.fetch("facets/#{website_id}/#{search_digest}", expires_in: 5.minutes) do
  SearchFacetsService.calculate(scope, website)
end
```

### Query Optimization

```ruby
# Use includes to prevent N+1
@properties = @properties.includes(:features, :prop_photos)

# Use pluck for count queries
feature_counts = scope.joins(:features).group('feature_key').pluck('feature_key', 'COUNT(*)')
```

---

## Action Plan Summary

### Immediate (Phase 1) - 2-3 weeks

1. **Week 1: Model & Database**
   - Add feature scopes to ListedProperty
   - Create database indexes migration
   - Write model specs

2. **Week 2: Controller & Views**
   - Update search controller
   - Create feature filter partial
   - Update API endpoints

3. **Week 3: Testing & Polish**
   - Write integration tests
   - Performance optimization
   - Documentation

### Short-term (Phase 2) - 3-4 weeks

4. **Week 4-5: Faceted Search**
   - Create SearchFacetsService
   - Update UI with counts
   - Add caching

5. **Week 6-7: URL Enhancement**
   - Implement friendly URLs
   - Update all links
   - SEO testing

### Long-term (Phase 3) - 4-6 weeks

6. **Week 8-10: Saved Searches**
7. **Week 11-13: Analytics**

---

**Document Version:** 2.0
**Last Updated:** 2024-12-05
**Status:** Ready for Implementation
