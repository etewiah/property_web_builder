# Field Key Search Implementation Plan

## Executive Summary

This document outlines a comprehensive strategy for implementing advanced field key-based property searching in PropertyWebBuilder. Currently, field keys are used for simple dropdown filtering (exact matches on `prop_type_key`, `prop_state_key`). This plan extends search capabilities to include:

- Full-text search across field key translations
- Multi-select filtering (e.g., "Show properties with Pool AND Garden")
- Feature-based search with fuzzy matching
- URL-friendly search parameters
- API endpoints with field key search support
- Performance optimization for large datasets

---

## Current State Analysis

### What Works Today

**Basic Field Key Filtering:**
```ruby
# app/controllers/pwb/search_controller.rb
@properties = Pwb::Prop.visible
  .property_type(params[:property_type])    # Exact match on prop_type_key
  .property_state(params[:property_state])  # Exact match on prop_state_key
```

**Available Field Key Categories:**
- `property-types`: Apartment, Villa, Warehouse, etc. (stored in `prop_type_key`)
- `property-states`: New, Needs Renovation, etc. (stored in `prop_state_key`)
- `extras` (features): Pool, Garden, Alarm, etc. (many-to-many via `features` table)
- `property-labels`: Sold, Reserved, Featured, etc. (no direct storage yet)

**Current Limitations:**
1. ❌ Can only search by exact `global_key` (user must know: `propertyTypes.apartamento`)
2. ❌ No search by translated label (can't search for "Apartment" → finds matching key)
3. ❌ Features can't be used in search filters
4. ❌ No multi-select (can't search for "Pool OR Garden")
5. ❌ No full-text search across field key values
6. ❌ No faceted search counts ("Show 42 properties with Pool")

---

## Implementation Strategy

### Phase 1: Foundation (High Priority)
**Goal:** Enable feature-based search and improve field key lookup

### Phase 2: Enhanced Search (Medium Priority)
**Goal:** Add full-text search, multi-select, and faceted search

### Phase 3: Advanced Features (Low Priority)
**Goal:** Hierarchical search, saved searches, and search analytics

---

## Phase 1: Foundation - Detailed Implementation

### 1.1 Add Feature Search to Property Model

**File:** `app/models/pwb/prop.rb`

**Current State:**
```ruby
# Features are associated but not searchable
has_many :features, dependent: :destroy
```

**New Implementation:**
```ruby
# Add scope for searching by features
scope :with_features, ->(feature_keys) {
  return all if feature_keys.blank?

  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?

  joins(:features)
    .where(pwb_features: { feature_key: feature_array })
    .group(:id)
    .having("COUNT(DISTINCT pwb_features.feature_key) = ?", feature_array.length)
}

# Alternative: ANY of the features (OR logic)
scope :with_any_features, ->(feature_keys) {
  return all if feature_keys.blank?

  feature_array = Array(feature_keys).reject(&:blank?)
  return all if feature_array.empty?

  joins(:features)
    .where(pwb_features: { feature_key: feature_array })
    .distinct
}
```

**Test Coverage:**
```ruby
# spec/models/pwb/prop_spec.rb
describe '.with_features' do
  let(:pool_key) { 'extras.piscina' }
  let(:garden_key) { 'extras.jardin' }

  it 'finds properties with ALL specified features' do
    prop_with_both = create(:prop)
    prop_with_both.features.create(feature_key: pool_key)
    prop_with_both.features.create(feature_key: garden_key)

    prop_with_pool = create(:prop)
    prop_with_pool.features.create(feature_key: pool_key)

    results = Prop.with_features([pool_key, garden_key])
    expect(results).to include(prop_with_both)
    expect(results).not_to include(prop_with_pool)
  end
end

describe '.with_any_features' do
  it 'finds properties with ANY of the specified features' do
    # Test OR logic
  end
end
```

**TODO:**
- [ ] Add `with_features` scope to `app/models/pwb/prop.rb`
- [ ] Add `with_any_features` scope to `app/models/pwb/prop.rb`
- [ ] Write comprehensive specs in `spec/models/pwb/prop_spec.rb`
- [ ] Test with 1, 2, 5, and 10+ features
- [ ] Add database indexes for performance (see section 1.5)

---

### 1.2 Field Key Lookup by Translation

**Problem:** Users want to search using human-readable labels, not internal keys.

**Example:**
```
User searches: "Apartment"
System should find: prop_type_key = "propertyTypes.apartamento" (if locale is :es)
                    OR prop_type_key = "propertyTypes.apartment" (if locale is :en)
```

**New Service Class:**

**File:** `app/services/pwb/field_key_lookup_service.rb`

```ruby
module Pwb
  class FieldKeyLookupService
    # Find global_keys by matching translated labels
    # @param label [String] The search term (e.g., "Apartment", "Pool")
    # @param tag [String] The field key category (e.g., "property-types", "extras")
    # @param locale [Symbol] The locale to search in (default: I18n.locale)
    # @param exact [Boolean] Exact match vs fuzzy match (default: false)
    # @return [Array<String>] Array of matching global_keys
    def self.find_keys_by_label(label:, tag:, locale: I18n.locale, exact: false)
      return [] if label.blank?

      field_keys = FieldKey.visible
        .for_website(Pwb::Current.website.id)
        .by_tag(tag)

      matches = []
      field_keys.each do |field_key|
        translated_label = I18n.t(field_key.global_key, locale: locale, default: '')
        next if translated_label.blank?

        if exact
          matches << field_key.global_key if translated_label.casecmp?(label)
        else
          # Fuzzy match: case-insensitive substring
          matches << field_key.global_key if translated_label.downcase.include?(label.downcase)
        end
      end

      matches
    end

    # Find keys across multiple locales (useful for multi-language sites)
    def self.find_keys_by_label_multi_locale(label:, tag:, locales: I18n.available_locales, exact: false)
      locales.flat_map do |locale|
        find_keys_by_label(label: label, tag: tag, locale: locale, exact: exact)
      end.uniq
    end

    # Get all translations for a given key
    def self.get_translations(global_key:, locales: I18n.available_locales)
      locales.each_with_object({}) do |locale, hash|
        hash[locale] = I18n.t(global_key, locale: locale, default: nil)
      end.compact
    end
  end
end
```

**Usage Example:**
```ruby
# Controller
search_term = params[:property_type_name] # User typed "Apartment"
matching_keys = FieldKeyLookupService.find_keys_by_label(
  label: search_term,
  tag: 'property-types',
  locale: I18n.locale
)

# matching_keys = ["propertyTypes.apartment", "propertyTypes.apartamento"]
@properties = Prop.where(prop_type_key: matching_keys)
```

**Caching Strategy:**
```ruby
# Add to FieldKey model (app/models/pwb/field_key.rb)
def self.translation_cache_key(tag, locale, website_id)
  "field_keys/translations/#{website_id}/#{tag}/#{locale}/#{maximum(:updated_at).to_i}"
end

def self.cached_translations_for_tag(tag:, locale:, website_id:)
  Rails.cache.fetch(translation_cache_key(tag, locale, website_id), expires_in: 1.hour) do
    by_tag(tag).for_website(website_id).visible.map do |fk|
      {
        global_key: fk.global_key,
        label: I18n.t(fk.global_key, locale: locale, default: fk.global_key),
        props_count: fk.props_count
      }
    end
  end
end
```

**TODO:**
- [ ] Create `app/services/pwb/field_key_lookup_service.rb`
- [ ] Implement `find_keys_by_label` method
- [ ] Implement `find_keys_by_label_multi_locale` method
- [ ] Add translation caching to `FieldKey` model
- [ ] Write specs in `spec/services/pwb/field_key_lookup_service_spec.rb`
- [ ] Test edge cases: empty strings, special characters, accents (e.g., "Almacén")
- [ ] Add performance benchmarks for 100+ field keys

---

### 1.3 Update Search Controller

**File:** `app/controllers/pwb/search_controller.rb`

**Current Implementation:**
```ruby
def search
  @property_types = FieldKey.get_options_by_tag("property-types")
  @properties = Pwb::Current.website.props.properties_search(search_params)
end
```

**Enhanced Implementation:**
```ruby
def search
  # Populate dropdown options
  @property_types = FieldKey.cached_translations_for_tag(
    tag: 'property-types',
    locale: I18n.locale,
    website_id: Pwb::Current.website.id
  )
  @property_states = FieldKey.cached_translations_for_tag(
    tag: 'property-states',
    locale: I18n.locale,
    website_id: Pwb::Current.website.id
  )
  @features = FieldKey.cached_translations_for_tag(
    tag: 'extras',
    locale: I18n.locale,
    website_id: Pwb::Current.website.id
  )

  # Build search query
  @properties = Pwb::Current.website.props.visible

  # Handle property type search (by key OR by label)
  if search_params[:property_type].present?
    if search_params[:property_type].starts_with?('propertyTypes.')
      # Exact key provided
      @properties = @properties.property_type(search_params[:property_type])
    else
      # Label provided - look up keys
      matching_keys = FieldKeyLookupService.find_keys_by_label(
        label: search_params[:property_type],
        tag: 'property-types'
      )
      @properties = @properties.where(prop_type_key: matching_keys) if matching_keys.any?
    end
  end

  # Handle property state search
  if search_params[:property_state].present?
    if search_params[:property_state].starts_with?('propertyStates.')
      @properties = @properties.property_state(search_params[:property_state])
    else
      matching_keys = FieldKeyLookupService.find_keys_by_label(
        label: search_params[:property_state],
        tag: 'property-states'
      )
      @properties = @properties.where(prop_state_key: matching_keys) if matching_keys.any?
    end
  end

  # Handle feature search (NEW!)
  if search_params[:features].present?
    feature_keys = parse_feature_params(search_params[:features])

    if search_params[:features_match] == 'any'
      @properties = @properties.with_any_features(feature_keys)
    else
      # Default: ALL features required
      @properties = @properties.with_features(feature_keys)
    end
  end

  # Apply other filters (price, bedrooms, etc.)
  @properties = apply_standard_filters(@properties, search_params)

  # Faceted counts (for UI feedback)
  @facets = calculate_facets(@properties) if search_params[:include_facets]

  @properties = @properties.page(params[:page]).per(20)
end

private

def parse_feature_params(features_param)
  case features_param
  when String
    # Comma-separated string: "extras.piscina,extras.jardin"
    features_param.split(',').map(&:strip).reject(&:blank?)
  when Array
    features_param.reject(&:blank?)
  else
    []
  end
end

def apply_standard_filters(scope, params)
  # Price, bedrooms, bathrooms, etc.
  scope = scope.properties_search(params.except(:features, :features_match))
  scope
end

def calculate_facets(scope)
  {
    property_types: scope.group(:prop_type_key).count,
    property_states: scope.group(:prop_state_key).count,
    features: scope.joins(:features).group('pwb_features.feature_key').count
  }
end

def search_params
  params.permit(
    :property_type,
    :property_state,
    :sale_or_rental,
    :for_sale_price_from,
    :for_sale_price_till,
    :for_rent_price_from,
    :count_bedrooms,
    :count_bathrooms,
    :features_match,
    :include_facets,
    features: []
  )
end
```

**TODO:**
- [ ] Update `search` method in `app/controllers/pwb/search_controller.rb`
- [ ] Add `parse_feature_params` helper method
- [ ] Add `apply_standard_filters` helper method
- [ ] Add `calculate_facets` helper method (optional, for Phase 2)
- [ ] Update `search_params` to permit `features` array
- [ ] Write controller specs in `spec/controllers/pwb/search_controller_spec.rb`
- [ ] Test various search combinations (type + features, state + features, etc.)

---

### 1.4 Update Search View

**File:** `app/views/pwb/search/index.html.erb` (or similar)

**New Feature Search UI:**
```erb
<div class="search-form">
  <%= form_with url: search_path, method: :get, local: true do |f| %>
    <!-- Existing fields -->
    <div class="form-group">
      <%= f.label :property_type, "Property Type" %>
      <%= f.select :property_type,
          options_for_select(@property_types.map { |t| [t[:label], t[:global_key]] }, params[:property_type]),
          { include_blank: "Any" },
          class: 'form-control' %>
    </div>

    <div class="form-group">
      <%= f.label :property_state, "Property State" %>
      <%= f.select :property_state,
          options_for_select(@property_states.map { |s| [s[:label], s[:global_key]] }, params[:property_state]),
          { include_blank: "Any" },
          class: 'form-control' %>
    </div>

    <!-- NEW: Feature Search -->
    <div class="form-group">
      <%= f.label :features, "Features" %>
      <div class="feature-checkboxes">
        <% @features.each do |feature| %>
          <label class="checkbox-inline">
            <%= check_box_tag 'features[]',
                feature[:global_key],
                params[:features]&.include?(feature[:global_key]),
                id: "feature_#{feature[:global_key].parameterize}" %>
            <%= feature[:label] %>
            <% if feature[:props_count] > 0 %>
              <span class="badge"><%= feature[:props_count] %></span>
            <% end %>
          </label>
        <% end %>
      </div>
    </div>

    <!-- NEW: Feature Match Logic -->
    <div class="form-group">
      <%= f.label :features_match, "Match" %>
      <%= f.select :features_match,
          options_for_select([['All selected features', 'all'], ['Any selected feature', 'any']], params[:features_match]),
          {},
          class: 'form-control' %>
    </div>

    <!-- Existing fields: price, bedrooms, etc. -->
    <%= f.submit "Search", class: 'btn btn-primary' %>
  <% end %>
</div>

<!-- Results -->
<div class="search-results">
  <p><%= pluralize(@properties.total_count, 'property') %> found</p>

  <% @properties.each do |property| %>
    <div class="property-card">
      <h3><%= property.title %></h3>
      <p>Type: <%= I18n.t(property.prop_type_key) %></p>
      <p>State: <%= I18n.t(property.prop_state_key) %></p>
      <p>Features:
        <%= property.get_features.keys.map { |k| I18n.t(k) }.join(', ') %>
      </p>
    </div>
  <% end %>

  <%= paginate @properties %>
</div>
```

**TODO:**
- [ ] Update search form view to include feature checkboxes
- [ ] Add `features_match` selector (all vs any)
- [ ] Style feature checkboxes with CSS
- [ ] Add JavaScript for "Select All" / "Clear All" buttons
- [ ] Display active filters with remove buttons
- [ ] Show result counts next to each feature option (if facets enabled)

---

### 1.5 Database Optimization

**Performance Considerations:**

**Current Indexes:**
```sql
-- Existing indexes (from schema.rb)
index_pwb_field_keys_on_global_key (unique)
index_pwb_field_keys_on_website_and_tag [pwb_website_id, tag]
index_pwb_props_on_prop_type_key
index_pwb_features_on_prop_id
```

**New Migration:**

**File:** `db/migrate/YYYYMMDD_add_field_key_search_indexes.rb`

```ruby
class AddFieldKeySearchIndexes < ActiveRecord::Migration[7.0]
  def change
    # Speed up feature searches (JOIN on features table)
    add_index :pwb_features, :feature_key unless index_exists?(:pwb_features, :feature_key)

    # Composite index for feature + prop queries
    add_index :pwb_features, [:prop_id, :feature_key] unless index_exists?(:pwb_features, [:prop_id, :feature_key])

    # Speed up prop_state_key searches (if missing)
    add_index :pwb_props, :prop_state_key unless index_exists?(:pwb_props, :prop_state_key)

    # Speed up visibility + type queries
    add_index :pwb_props, [:visible, :prop_type_key] unless index_exists?(:pwb_props, [:visible, :prop_type_key])

    # Speed up field key visibility + website queries
    add_index :pwb_field_keys, [:pwb_website_id, :visible] unless index_exists?(:pwb_field_keys, [:pwb_website_id, :visible])
  end
end
```

**TODO:**
- [ ] Create migration `db/migrate/YYYYMMDD_add_field_key_search_indexes.rb`
- [ ] Run migration on development: `rails db:migrate`
- [ ] Test query performance with `EXPLAIN ANALYZE`
- [ ] Run migration on staging/production
- [ ] Document index rationale in migration comments

---

### 1.6 API Updates (REST & GraphQL)

#### REST API

**File:** `app/controllers/pwb/api/v1/properties_controller.rb`

**Update Index Action:**
```ruby
def index
  properties = Pwb::Current.website.props.visible

  # Apply field key filters
  properties = apply_field_key_filters(properties, params)

  # Apply feature filters
  if params[:features].present?
    properties = properties.with_features(params[:features].split(','))
  end

  # Existing filters
  properties = properties.properties_search(search_params)

  render jsonapi: properties, include: ['features']
end

private

def apply_field_key_filters(scope, params)
  scope = scope.where(prop_type_key: params[:property_type]) if params[:property_type].present?
  scope = scope.where(prop_state_key: params[:property_state]) if params[:property_state].present?
  scope
end

def search_params
  params.permit(:property_type, :property_state, :sale_or_rental, :features, :features_match, ...)
end
```

#### GraphQL API

**File:** `app/graphql/types/query_type.rb`

**Update search_properties Field:**
```ruby
field :search_properties, [Types::PropertyType], null: false do
  argument :property_type, String, required: false
  argument :property_state, String, required: false
  argument :features, [String], required: false, description: "Array of feature global_keys"
  argument :features_match, String, required: false, description: "'all' or 'any' (default: 'all')"
  argument :bedrooms_from, Int, required: false
  argument :bathrooms_from, Int, required: false
  # ... other arguments
end

def search_properties(**args)
  properties = Pwb::Current.website.props.visible

  # Property type
  properties = properties.where(prop_type_key: args[:property_type]) if args[:property_type]

  # Property state
  properties = properties.where(prop_state_key: args[:property_state]) if args[:property_state]

  # Features
  if args[:features].present?
    if args[:features_match] == 'any'
      properties = properties.with_any_features(args[:features])
    else
      properties = properties.with_features(args[:features])
    end
  end

  # Other filters
  properties.properties_search(args.except(:features, :features_match))
end
```

**GraphQL Query Example:**
```graphql
query SearchProperties {
  searchProperties(
    propertyType: "propertyTypes.apartamento"
    features: ["extras.piscina", "extras.jardin"]
    featuresMatch: "all"
    bedroomsFrom: 2
  ) {
    id
    title
    propTypeKey
    features {
      featureKey
      label
    }
  }
}
```

**TODO:**
- [ ] Update `app/controllers/pwb/api/v1/properties_controller.rb` index action
- [ ] Update `app/graphql/types/query_type.rb` search_properties field
- [ ] Add feature filtering to both APIs
- [ ] Update API documentation with feature search examples
- [ ] Write API specs in `spec/requests/pwb/api/v1/properties_spec.rb`
- [ ] Test GraphQL queries in `spec/graphql/queries/search_properties_spec.rb`

---

### 1.7 Public API Select Values Enhancement

**File:** `app/controllers/api_public/v1/select_values_controller.rb`

**Current Implementation:**
```ruby
def index
  # Returns options for dropdowns
  # GET /api_public/v1/select_values?field_names=property-types,extras
end
```

**Enhancement: Add Search Parameter**
```ruby
def index
  field_name_ids = params[:field_names]&.split(',') || []
  search_term = params[:search] # NEW!

  result_hash = {}
  field_name_ids.each do |field_name_id|
    options = if search_term.present?
      # Filter options by search term
      all_options = Pwb::FieldKey.get_options_by_tag(field_name_id)
      all_options.select do |option|
        option.label.downcase.include?(search_term.downcase)
      end
    else
      Pwb::FieldKey.get_options_by_tag(field_name_id)
    end

    result_hash[field_name_id] = options
  end

  render json: result_hash
end
```

**Usage Example:**
```javascript
// Frontend: Autocomplete for features
fetch('/api_public/v1/select_values?field_names=extras&search=pool')
  .then(res => res.json())
  .then(data => {
    // data = { "extras": [{ value: "extras.piscina", label: "Pool" }] }
  });
```

**TODO:**
- [ ] Add `search` parameter to `api_public/v1/select_values_controller.rb`
- [ ] Implement filtering logic
- [ ] Add specs for search functionality
- [ ] Update API documentation
- [ ] Test with various search terms

---

## Phase 2: Enhanced Search

### 2.1 Full-Text Search with PostgreSQL

**Goal:** Enable searching properties by any field key value using PostgreSQL full-text search.

**Migration:**

**File:** `db/migrate/YYYYMMDD_add_full_text_search_to_props.rb`

```ruby
class AddFullTextSearchToProps < ActiveRecord::Migration[7.0]
  def up
    # Add tsvector column for full-text search
    add_column :pwb_props, :searchable_field_keys, :tsvector

    # Create GIN index for fast full-text search
    add_index :pwb_props, :searchable_field_keys, using: :gin

    # Create trigger to auto-update tsvector on changes
    execute <<-SQL
      CREATE FUNCTION pwb_props_searchable_field_keys_trigger() RETURNS trigger AS $$
      DECLARE
        type_label text;
        state_label text;
        feature_labels text;
      BEGIN
        -- Get translated labels for prop_type_key
        type_label := COALESCE(
          (SELECT string_agg(value, ' ')
           FROM json_each_text(
             (SELECT translations FROM i18n_translations
              WHERE key = NEW.prop_type_key LIMIT 1)
           )),
          ''
        );

        -- Get translated labels for prop_state_key
        state_label := COALESCE(
          (SELECT string_agg(value, ' ')
           FROM json_each_text(
             (SELECT translations FROM i18n_translations
              WHERE key = NEW.prop_state_key LIMIT 1)
           )),
          ''
        );

        -- Get feature labels (simplified - adjust based on your schema)
        feature_labels := COALESCE(
          (SELECT string_agg(feature_key, ' ')
           FROM pwb_features
           WHERE prop_id = NEW.id),
          ''
        );

        -- Build searchable text
        NEW.searchable_field_keys :=
          setweight(to_tsvector('simple', type_label), 'A') ||
          setweight(to_tsvector('simple', state_label), 'B') ||
          setweight(to_tsvector('simple', feature_labels), 'C');

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER pwb_props_searchable_field_keys_update
        BEFORE INSERT OR UPDATE ON pwb_props
        FOR EACH ROW
        EXECUTE FUNCTION pwb_props_searchable_field_keys_trigger();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS pwb_props_searchable_field_keys_update ON pwb_props"
    execute "DROP FUNCTION IF EXISTS pwb_props_searchable_field_keys_trigger()"
    remove_index :pwb_props, :searchable_field_keys
    remove_column :pwb_props, :searchable_field_keys
  end
end
```

**Note:** This requires `i18n-active_record` gem to be installed for database-persisted translations. See section 2.2.

**Model Update:**

**File:** `app/models/pwb/prop.rb`

```ruby
# Add full-text search scope
scope :search_field_keys, ->(query) {
  return all if query.blank?

  where("searchable_field_keys @@ plainto_tsquery('simple', ?)", query)
    .order(Arel.sql("ts_rank(searchable_field_keys, plainto_tsquery('simple', ?)) DESC"), query)
}
```

**TODO:**
- [ ] Install `i18n-active_record` gem (see Phase 2.2)
- [ ] Create migration for tsvector column and trigger
- [ ] Test migration thoroughly on development database
- [ ] Add `search_field_keys` scope to Prop model
- [ ] Write specs for full-text search
- [ ] Benchmark performance vs. Ruby-based search
- [ ] Document limitations (only works with persisted translations)

---

### 2.2 Persistent I18n Translations

**Current Issue:** Translations stored in memory (lost on restart).

**Solution:** Use `i18n-active_record` gem.

**Gemfile:**
```ruby
gem 'i18n-active_record'
```

**Setup:**
```bash
bundle install
rails i18n:active_record:setup
rails db:migrate
```

**Migration Generated:**
```ruby
create_table :i18n_translations do |t|
  t.string :locale, null: false
  t.string :key, null: false
  t.text :value
  t.text :interpolations
  t.boolean :is_proc, default: false
  t.timestamps
end

add_index :i18n_translations, [:locale, :key], unique: true
```

**Configuration:**

**File:** `config/initializers/i18n.rb`

```ruby
# Store translations in database
I18n.backend = I18n::Backend::ActiveRecord.new

# Fall back to YAML files for non-field-key translations
I18n::Backend::ActiveRecord.include(I18n::Backend::Fallbacks)
I18n::Backend::ActiveRecord.include(I18n::Backend::Memoize)

# Cache translations in production
if Rails.env.production?
  I18n.backend = I18n::Backend::Chain.new(
    I18n::Backend::ActiveRecord.new,
    I18n.backend
  )
end
```

**Update FieldKey Model:**

**File:** `app/models/pwb/field_key.rb`

```ruby
# After creating/updating field_key, save translations to database
after_save :persist_translations

def update_translations(translations_hash)
  # translations_hash = { en: "Warehouse", es: "Almacén", fr: "Entrepôt", ... }
  translations_hash.each do |locale, label|
    I18n.backend.store_translations(locale.to_sym, { global_key => label })
  end

  persist_translations
end

private

def persist_translations
  return unless I18n.backend.is_a?(I18n::Backend::ActiveRecord)

  # Save to database
  I18n.available_locales.each do |locale|
    translation = I18n.t(global_key, locale: locale, default: nil)
    next if translation.nil?

    I18n::Backend::ActiveRecord::Translation.find_or_create_by!(
      locale: locale.to_s,
      key: global_key
    ) do |record|
      record.value = translation
    end
  end
end
```

**Data Migration:**

**File:** `db/migrate/YYYYMMDD_migrate_field_key_translations_to_db.rb`

```ruby
class MigrateFieldKeyTranslationsToDb < ActiveRecord::Migration[7.0]
  def up
    # Load all field keys from YAML seeds
    field_keys_data = YAML.load_file(Rails.root.join('db/yml_seeds/field_keys.yml'))

    field_keys_data.each do |global_key, translations|
      translations.each do |locale, label|
        I18n::Backend::ActiveRecord::Translation.find_or_create_by!(
          locale: locale.to_s,
          key: global_key
        ) do |record|
          record.value = label
        end
      end
    end

    puts "Migrated #{field_keys_data.keys.count} field key translations to database"
  end

  def down
    # Remove field key translations
    I18n::Backend::ActiveRecord::Translation
      .where("key LIKE 'propertyTypes.%' OR key LIKE 'extras.%' OR key LIKE 'propertyStates.%'")
      .delete_all
  end
end
```

**TODO:**
- [ ] Add `i18n-active_record` to Gemfile and run bundle install
- [ ] Run setup: `rails i18n:active_record:setup`
- [ ] Configure I18n backend in `config/initializers/i18n.rb`
- [ ] Update FieldKey model with `persist_translations` method
- [ ] Create data migration to move existing translations to database
- [ ] Run migration on development
- [ ] Test that translations persist after server restart
- [ ] Update field_keys management UI to save to database
- [ ] Run on staging/production with careful testing

---

### 2.3 Faceted Search (Result Counts)

**Goal:** Show how many properties match each filter option.

**Example UI:**
```
Property Type:
☐ Apartment (42)
☐ Villa (18)
☐ Warehouse (7)

Features:
☐ Pool (23)
☐ Garden (35)
☐ Garage (41)
```

**Implementation:**

**File:** `app/services/pwb/search_facets_service.rb`

```ruby
module Pwb
  class SearchFacetsService
    # Calculate facet counts for a given scope
    # @param scope [ActiveRecord::Relation] The base query (already filtered)
    # @return [Hash] Facet data with counts
    def self.calculate(scope)
      {
        property_types: calculate_property_types(scope),
        property_states: calculate_property_states(scope),
        features: calculate_features(scope)
      }
    end

    private

    def self.calculate_property_types(scope)
      counts = scope.group(:prop_type_key).count

      FieldKey.by_tag('property-types').visible.map do |fk|
        {
          global_key: fk.global_key,
          label: I18n.t(fk.global_key),
          count: counts[fk.global_key] || 0
        }
      end.sort_by { |f| -f[:count] }
    end

    def self.calculate_property_states(scope)
      counts = scope.group(:prop_state_key).count

      FieldKey.by_tag('property-states').visible.map do |fk|
        {
          global_key: fk.global_key,
          label: I18n.t(fk.global_key),
          count: counts[fk.global_key] || 0
        }
      end.sort_by { |f| -f[:count] }
    end

    def self.calculate_features(scope)
      counts = scope.joins(:features).group('pwb_features.feature_key').count

      FieldKey.by_tag('extras').visible.map do |fk|
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

**File:** `app/controllers/pwb/search_controller.rb`

```ruby
def search
  # ... existing search logic ...

  # Calculate facets if requested (opt-in to avoid performance hit)
  if params[:include_facets] == 'true'
    @facets = SearchFacetsService.calculate(@properties)
  end

  @properties = @properties.page(params[:page]).per(20)
end
```

**View Update:**
```erb
<% if @facets %>
  <div class="search-facets">
    <h4>Property Type</h4>
    <% @facets[:property_types].each do |facet| %>
      <label>
        <%= check_box_tag 'property_type', facet[:global_key] %>
        <%= facet[:label] %> (<%= facet[:count] %>)
      </label>
    <% end %>

    <h4>Features</h4>
    <% @facets[:features].each do |facet| %>
      <label>
        <%= check_box_tag 'features[]', facet[:global_key] %>
        <%= facet[:label] %> (<%= facet[:count] %>)
      </label>
    <% end %>
  </div>
<% end %>
```

**TODO:**
- [ ] Create `app/services/pwb/search_facets_service.rb`
- [ ] Implement facet calculation methods
- [ ] Add caching for facet counts (15-minute expiry)
- [ ] Update search controller to calculate facets
- [ ] Update search view to display facets
- [ ] Add AJAX for dynamic facet updates (without page reload)
- [ ] Write specs for facet calculations
- [ ] Test performance with large datasets

---

### 2.4 URL-Friendly Search Parameters

**Goal:** Enable bookmarkable, shareable search URLs.

**Current URL:**
```
/search?property_type=propertyTypes.apartamento&features[]=extras.piscina&features[]=extras.jardin
```

**Improved URL:**
```
/search?type=apartment&features=pool,garden
```

**Router Enhancement:**

**File:** `config/routes.rb`

```ruby
# Add custom route with slug-based parameters
get 'search/:type/:location', to: 'pwb/search#search', as: :search_with_type
get 'search/:type', to: 'pwb/search#search', as: :search_with_type_only
```

**Controller Enhancement:**

**File:** `app/controllers/pwb/search_controller.rb`

```ruby
before_action :normalize_search_params

private

def normalize_search_params
  # Convert friendly slugs to global_keys

  # Property type: "apartment" → "propertyTypes.apartment"
  if params[:type].present? && !params[:type].starts_with?('propertyTypes.')
    matching_keys = FieldKeyLookupService.find_keys_by_label(
      label: params[:type],
      tag: 'property-types'
    )
    params[:property_type] = matching_keys.first if matching_keys.any?
  end

  # Features: "pool,garden" → ["extras.piscina", "extras.jardin"]
  if params[:features].is_a?(String)
    feature_names = params[:features].split(',')
    params[:features] = feature_names.flat_map do |name|
      FieldKeyLookupService.find_keys_by_label(
        label: name.strip,
        tag: 'extras'
      )
    end
  end
end
```

**Helper Methods:**

**File:** `app/helpers/search_helper.rb`

```ruby
module SearchHelper
  # Generate SEO-friendly search URL
  def search_url_for(property_type: nil, features: [], **options)
    type_slug = property_type.present? ? slugify_field_key(property_type) : nil
    feature_slugs = features.map { |f| slugify_field_key(f) }.join(',')

    if type_slug && feature_slugs.present?
      search_path(type: type_slug, features: feature_slugs, **options)
    elsif type_slug
      search_with_type_only_path(type: type_slug, **options)
    else
      search_path(**options)
    end
  end

  def slugify_field_key(global_key)
    # "propertyTypes.apartment" → "apartment"
    # "extras.piscina" → "pool" (using translation)
    label = I18n.t(global_key, default: global_key)
    label.parameterize
  end
end
```

**TODO:**
- [ ] Add custom routes for slug-based URLs
- [ ] Implement `normalize_search_params` in controller
- [ ] Create `search_url_for` helper method
- [ ] Update all search form `action` attributes to use helper
- [ ] Add specs for URL parameter normalization
- [ ] Test with various language locales
- [ ] Update sitemap to include search pages

---

## Phase 3: Advanced Features

### 3.1 Hierarchical Field Keys

**Goal:** Support parent-child relationships (e.g., "Residential" → "Apartment" → "Studio").

**Migration:**

**File:** `db/migrate/YYYYMMDD_add_hierarchy_to_field_keys.rb`

```ruby
class AddHierarchyToFieldKeys < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_field_keys, :parent_key, :string
    add_index :pwb_field_keys, :parent_key

    add_column :pwb_field_keys, :level, :integer, default: 0
    add_column :pwb_field_keys, :path, :string # Store full path for queries
  end
end
```

**Model Update:**

**File:** `app/models/pwb/field_key.rb`

```ruby
# Self-referential association
belongs_to :parent, class_name: 'FieldKey', foreign_key: :parent_key, primary_key: :global_key, optional: true
has_many :children, class_name: 'FieldKey', foreign_key: :parent_key, primary_key: :global_key

scope :top_level, -> { where(parent_key: nil) }
scope :with_children, -> { where('parent_key IS NULL OR level = 0') }

def ancestors
  return [] if parent_key.nil?

  ancestors = []
  current = parent
  while current
    ancestors.unshift(current)
    current = current.parent
  end
  ancestors
end

def descendants
  # Get all descendants recursively
  children.flat_map { |child| [child] + child.descendants }
end

def full_path
  ([parent&.full_path, I18n.t(global_key)].compact.join(' > '))
end
```

**Search Enhancement:**

```ruby
scope :with_property_type_hierarchy, ->(type_key) {
  field_key = FieldKey.find_by(global_key: type_key)
  return where(prop_type_key: type_key) if field_key.nil?

  # Include properties with this type OR any child types
  descendant_keys = [type_key] + field_key.descendants.pluck(:global_key)
  where(prop_type_key: descendant_keys)
}
```

**TODO:**
- [ ] Design hierarchy structure (max depth? limits?)
- [ ] Create migration for parent_key, level, path columns
- [ ] Update FieldKey model with associations and methods
- [ ] Update management UI to support parent selection
- [ ] Add `with_property_type_hierarchy` scope to Prop model
- [ ] Update search controller to use hierarchical search
- [ ] Write comprehensive specs for hierarchy
- [ ] Create seed data with example hierarchies
- [ ] Document hierarchy limitations and best practices

---

### 3.2 Saved Searches

**Goal:** Allow users to save and retrieve their search criteria.

**Migration:**

**File:** `db/migrate/YYYYMMDD_create_saved_searches.rb`

```ruby
class CreateSavedSearches < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_saved_searches do |t|
      t.references :user, foreign_key: { to_table: :users }, null: true
      t.references :pwb_website, foreign_key: true, null: false
      t.string :name, null: false
      t.jsonb :search_params, default: {}, null: false
      t.string :url
      t.integer :result_count
      t.datetime :last_searched_at
      t.boolean :notify_on_new_results, default: false
      t.timestamps
    end

    add_index :pwb_saved_searches, :search_params, using: :gin
  end
end
```

**Model:**

**File:** `app/models/pwb/saved_search.rb`

```ruby
module Pwb
  class SavedSearch < ApplicationRecord
    belongs_to :user, optional: true # Allow anonymous saves (via session)
    belongs_to :website, foreign_key: :pwb_website_id

    validates :name, presence: true
    validates :search_params, presence: true

    # Execute the saved search
    def execute
      Prop.visible.properties_search(**search_params.symbolize_keys)
    end

    # Check if results have changed since last search
    def new_results?
      return false if last_searched_at.nil?

      current_count = execute.count
      current_count > (result_count || 0)
    end

    def update_result_count!
      update!(
        result_count: execute.count,
        last_searched_at: Time.current
      )
    end
  end
end
```

**Controller:**

**File:** `app/controllers/pwb/saved_searches_controller.rb`

```ruby
class Pwb::SavedSearchesController < ApplicationController
  before_action :authenticate_user!, except: [:show]

  def create
    @saved_search = current_website.saved_searches.build(saved_search_params)
    @saved_search.user = current_user if user_signed_in?

    if @saved_search.save
      redirect_to @saved_search, notice: 'Search saved successfully'
    else
      render :new
    end
  end

  def show
    @saved_search = SavedSearch.find(params[:id])
    @properties = @saved_search.execute.page(params[:page])

    # Update result count in background
    @saved_search.update_result_count! if @saved_search.user == current_user
  end

  def index
    @saved_searches = current_user.saved_searches.where(website: current_website)
  end

  private

  def saved_search_params
    params.require(:saved_search).permit(:name, :notify_on_new_results, search_params: {})
  end
end
```

**TODO:**
- [ ] Create migration for `saved_searches` table
- [ ] Create `SavedSearch` model with execute method
- [ ] Create `SavedSearchesController` with CRUD actions
- [ ] Add routes for saved searches
- [ ] Create views for saved search management
- [ ] Add "Save this search" button to search results page
- [ ] Implement email notifications for new results (background job)
- [ ] Write specs for SavedSearch model and controller
- [ ] Add user dashboard with saved searches list

---

### 3.3 Search Analytics

**Goal:** Track popular searches and suggest filters.

**Migration:**

**File:** `db/migrate/YYYYMMDD_create_search_analytics.rb`

```ruby
class CreateSearchAnalytics < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_search_analytics do |t|
      t.references :pwb_website, foreign_key: true, null: false
      t.jsonb :search_params, default: {}, null: false
      t.integer :result_count
      t.integer :click_count, default: 0
      t.string :session_id
      t.string :user_agent
      t.string :ip_address
      t.timestamps
    end

    add_index :pwb_search_analytics, :search_params, using: :gin
    add_index :pwb_search_analytics, :created_at
  end
end
```

**Service:**

**File:** `app/services/pwb/search_analytics_service.rb`

```ruby
module Pwb
  class SearchAnalyticsService
    def self.track_search(website:, params:, result_count:, session_id:, request:)
      SearchAnalytic.create!(
        pwb_website: website,
        search_params: sanitize_params(params),
        result_count: result_count,
        session_id: session_id,
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      )
    end

    def self.popular_searches(website:, days: 30, limit: 10)
      SearchAnalytic
        .where(pwb_website: website)
        .where('created_at > ?', days.days.ago)
        .group(:search_params)
        .order('COUNT(*) DESC')
        .limit(limit)
        .count
    end

    def self.popular_field_keys(website:, tag:, days: 30)
      # Find most searched field keys by tag
      SearchAnalytic
        .where(pwb_website: website)
        .where('created_at > ?', days.days.ago)
        .where("search_params ? 'property_type' OR search_params ? 'features'")
        .pluck(:search_params)
        .flat_map { |params| extract_field_keys(params, tag) }
        .group_by(&:itself)
        .transform_values(&:count)
        .sort_by { |k, v| -v }
        .to_h
    end

    private

    def self.sanitize_params(params)
      # Remove sensitive data
      params.except(:authenticity_token, :commit, :controller, :action, :format)
    end

    def self.extract_field_keys(params, tag)
      case tag
      when 'property-types'
        [params['property_type']].compact
      when 'extras'
        Array(params['features']).compact
      else
        []
      end
    end
  end
end
```

**Admin Dashboard:**

**File:** `app/controllers/site_admin/analytics_controller.rb`

```ruby
def search_analytics
  @popular_searches = SearchAnalyticsService.popular_searches(
    website: current_website,
    days: params[:days]&.to_i || 30
  )

  @popular_types = SearchAnalyticsService.popular_field_keys(
    website: current_website,
    tag: 'property-types',
    days: 30
  )

  @popular_features = SearchAnalyticsService.popular_field_keys(
    website: current_website,
    tag: 'extras',
    days: 30
  )
end
```

**TODO:**
- [ ] Create migration for `search_analytics` table
- [ ] Create `SearchAnalytic` model
- [ ] Create `SearchAnalyticsService` with tracking methods
- [ ] Add tracking call to search controller
- [ ] Create admin dashboard for analytics
- [ ] Add charts/visualizations for popular searches
- [ ] Implement privacy compliance (GDPR - IP anonymization)
- [ ] Add data retention policy (delete old analytics)
- [ ] Write specs for analytics service

---

## Testing Strategy

### Unit Tests

**File:** `spec/models/pwb/prop_spec.rb`

```ruby
describe Pwb::Prop do
  describe '.with_features' do
    context 'with multiple features required (AND logic)' do
      it 'returns only properties with ALL specified features'
      it 'returns empty when no properties match'
      it 'handles empty feature array'
    end
  end

  describe '.with_any_features' do
    context 'with multiple features optional (OR logic)' do
      it 'returns properties with ANY specified feature'
      it 'returns unique properties (no duplicates)'
    end
  end

  describe '.search_field_keys' do
    it 'finds properties by translated type labels'
    it 'finds properties by translated feature labels'
    it 'ranks results by relevance'
  end
end
```

### Integration Tests

**File:** `spec/requests/pwb/search_spec.rb`

```ruby
describe 'Property Search', type: :request do
  let(:website) { create(:website) }
  let(:pool_key) { 'extras.piscina' }
  let(:garden_key) { 'extras.jardin' }

  before do
    host! "#{website.subdomain}.localhost"
  end

  describe 'GET /search' do
    context 'with feature filters' do
      it 'filters by single feature' do
        get '/search', params: { features: [pool_key] }
        expect(response).to have_http_status(:success)
        # Assert properties have pool
      end

      it 'filters by multiple features (AND logic)' do
        get '/search', params: { features: [pool_key, garden_key] }
        # Assert properties have both pool AND garden
      end

      it 'filters by multiple features (OR logic)' do
        get '/search', params: { features: [pool_key, garden_key], features_match: 'any' }
        # Assert properties have pool OR garden
      end
    end

    context 'with property type filter' do
      it 'filters by global_key'
      it 'filters by translated label'
    end

    context 'with combined filters' do
      it 'combines type + features + price + bedrooms'
    end
  end
end
```

### System Tests (End-to-End)

**File:** `spec/system/property_search_spec.rb`

```ruby
describe 'Property Search', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  scenario 'User searches for properties with specific features' do
    visit search_path

    # Select features
    check 'Pool'
    check 'Garden'
    select 'All selected features', from: 'Match'

    # Select property type
    select 'Apartment', from: 'Property Type'

    click_button 'Search'

    # Verify results
    expect(page).to have_content('3 properties found')
    expect(page).to have_selector('.property-card', count: 3)

    # Verify each result has required features
    within('.property-card', match: :first) do
      expect(page).to have_content('Pool')
      expect(page).to have_content('Garden')
    end
  end

  scenario 'User saves a search' do
    # Login required
    sign_in user

    # Perform search
    visit search_path(property_type: 'apartment', features: ['extras.piscina'])

    # Save search
    click_button 'Save this search'
    fill_in 'Name', with: 'Apartments with Pool'
    check 'Notify me of new results'
    click_button 'Save'

    # Verify saved
    expect(page).to have_content('Search saved successfully')

    # Access saved search
    visit saved_searches_path
    expect(page).to have_link('Apartments with Pool')
  end
end
```

**TODO:**
- [ ] Write comprehensive unit tests for all new scopes
- [ ] Write integration tests for API endpoints
- [ ] Write system tests for user workflows
- [ ] Add performance tests (benchmark 1000+ properties)
- [ ] Test with multiple tenants (ensure isolation)
- [ ] Test with all supported locales
- [ ] Add edge case tests (special characters, long strings, etc.)

---

## Performance Optimization

### Database Indexes (Summary)

| Table | Column(s) | Purpose |
|-------|-----------|---------|
| `pwb_features` | `feature_key` | Speed up feature lookups |
| `pwb_features` | `[prop_id, feature_key]` | Optimize JOIN queries |
| `pwb_props` | `prop_state_key` | Filter by property state |
| `pwb_props` | `[visible, prop_type_key]` | Combined visibility + type filter |
| `pwb_props` | `searchable_field_keys` (GIN) | Full-text search |
| `pwb_field_keys` | `[pwb_website_id, visible]` | Tenant + visibility filter |
| `i18n_translations` | `[locale, key]` | Fast translation lookups |

### Caching Strategy

**Cache Keys:**
```ruby
# Field key options (15 minutes)
"field_keys/#{website_id}/#{tag}/#{locale}/#{updated_at}"

# Search facets (5 minutes)
"search_facets/#{website_id}/#{search_params_digest}"

# Popular searches (1 hour)
"search_analytics/popular/#{website_id}/#{days}"
```

**Implementation:**
```ruby
# In FieldKey model
def self.cached_options_by_tag(tag:, website_id:)
  Rails.cache.fetch(
    "field_keys/#{website_id}/#{tag}/#{I18n.locale}/#{maximum(:updated_at).to_i}",
    expires_in: 15.minutes
  ) do
    get_options_by_tag(tag)
  end
end
```

### N+1 Query Prevention

```ruby
# BAD: N+1 queries
@properties.each do |property|
  property.features.each do |feature|
    puts I18n.t(feature.feature_key)
  end
end

# GOOD: Eager loading
@properties = @properties.includes(:features)
```

**TODO:**
- [ ] Add all recommended database indexes
- [ ] Implement caching for field key options
- [ ] Implement caching for search facets
- [ ] Add `bullet` gem to detect N+1 queries in development
- [ ] Use `rack-mini-profiler` to monitor query performance
- [ ] Run `EXPLAIN ANALYZE` on complex search queries
- [ ] Benchmark before/after optimization (target: <100ms search)
- [ ] Set up database connection pooling for production

---

## API Documentation

### REST API Endpoints

#### Search Properties with Features

**Request:**
```http
GET /api/v1/properties?features=extras.piscina,extras.jardin&features_match=all HTTP/1.1
Host: tenant-a.propertywebbuilder.com
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
  "data": [
    {
      "id": "123",
      "type": "properties",
      "attributes": {
        "title": "Luxury Apartment",
        "prop_type_key": "propertyTypes.apartamento",
        "prop_state_key": "propertyStates.nuevo",
        "price_sale_current_cents": 25000000
      },
      "relationships": {
        "features": {
          "data": [
            { "id": "extras.piscina", "type": "features" },
            { "id": "extras.jardin", "type": "features" }
          ]
        }
      }
    }
  ],
  "included": [
    {
      "id": "extras.piscina",
      "type": "features",
      "attributes": {
        "feature_key": "extras.piscina",
        "label": "Pool"
      }
    }
  ]
}
```

#### Get Field Key Options

**Request:**
```http
GET /api_public/v1/select_values?field_names=extras&search=pool HTTP/1.1
Host: tenant-a.propertywebbuilder.com
```

**Response:**
```json
{
  "extras": [
    {
      "value": "extras.piscina",
      "label": "Pool"
    },
    {
      "value": "extras.piscinaInterior",
      "label": "Indoor Pool"
    }
  ]
}
```

### GraphQL API

#### Search Query

```graphql
query SearchPropertiesWithFeatures {
  searchProperties(
    propertyType: "propertyTypes.apartamento"
    features: ["extras.piscina", "extras.jardin"]
    featuresMatch: "all"
    bedroomsFrom: 2
    saleOrRental: "sale"
  ) {
    id
    title
    propTypeKey
    propStateKey
    priceSaleCurrentCents
    features {
      featureKey
      label
    }
  }
}
```

#### Field Keys Query

```graphql
query GetFieldKeys {
  fieldKeys(tag: "extras", visible: true) {
    globalKey
    tag
    visible
    propsCount
    translations {
      locale
      label
    }
  }
}
```

**TODO:**
- [ ] Document all new API endpoints
- [ ] Add OpenAPI/Swagger specification
- [ ] Create Postman collection with examples
- [ ] Document rate limits and authentication
- [ ] Add API versioning strategy
- [ ] Create GraphQL schema documentation
- [ ] Write API integration guide for developers

---

## Migration Plan

### Phase 1 Timeline: 2-3 weeks

**Week 1: Foundation**
- Day 1-2: Implement feature scopes (`with_features`, `with_any_features`)
- Day 3: Write unit tests for scopes
- Day 4-5: Create `FieldKeyLookupService`
- Day 5: Write service tests

**Week 2: Integration**
- Day 1-2: Update search controller
- Day 3: Update search views
- Day 4: Add database indexes
- Day 5: Update API endpoints

**Week 3: Testing & Polish**
- Day 1-2: Write integration tests
- Day 3: Write system tests
- Day 4: Performance optimization
- Day 5: Code review & documentation

### Phase 2 Timeline: 3-4 weeks

**Week 1: Database Setup**
- Install and configure `i18n-active_record`
- Migrate existing translations
- Test persistence

**Week 2: Full-Text Search**
- Implement tsvector column
- Create triggers
- Test search relevance

**Week 3: Faceted Search**
- Create `SearchFacetsService`
- Update UI with facet counts
- Add caching

**Week 4: URL Enhancement**
- Implement slug-based URLs
- Update helpers
- Test SEO impact

### Phase 3 Timeline: 4-6 weeks (Optional)

**Week 1-2: Hierarchical Field Keys**
- Design hierarchy structure
- Implement parent-child relationships
- Update management UI

**Week 3-4: Saved Searches**
- Create database schema
- Implement CRUD operations
- Add email notifications

**Week 5-6: Analytics**
- Create tracking system
- Build admin dashboard
- Implement privacy compliance

---

## Risk Assessment

### High Risk

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Performance degradation with feature search** | High | Add database indexes, implement caching, paginate results |
| **Translation migration data loss** | High | Backup database, test migration thoroughly, have rollback plan |
| **N+1 queries on search page** | Medium | Use `includes` for eager loading, monitor with `bullet` gem |

### Medium Risk

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Complex multi-feature queries slow** | Medium | Optimize SQL, consider materialized views, cache results |
| **Full-text search inaccuracy** | Low | Tune PostgreSQL search configuration, allow fuzzy matching |
| **URL slug collisions** | Low | Add unique suffixes, fall back to ID-based URLs |

### Low Risk

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Saved search spam** | Low | Rate limiting, require authentication |
| **Analytics storage growth** | Low | Implement data retention policy, aggregate old data |

---

## Success Metrics

### Key Performance Indicators

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Search response time** | < 200ms | New Relic, log analysis |
| **Feature filter usage** | > 30% of searches | Google Analytics, search analytics table |
| **Search refinement rate** | < 40% | Track searches with modified params |
| **Zero-result searches** | < 10% | Count searches with result_count = 0 |
| **Saved search conversions** | > 5% of logged-in searches | Count saved_searches created |

### User Experience Metrics

- Time to first result interaction
- Search abandonment rate
- Property detail page views from search
- Contact form submissions from search

---

## TODO Checklist

### Phase 1: Foundation (High Priority)

#### Model Layer
- [ ] Add `with_features` scope to `app/models/pwb/prop.rb`
- [ ] Add `with_any_features` scope to `app/models/pwb/prop.rb`
- [ ] Write specs in `spec/models/pwb/prop_spec.rb` for feature scopes
- [ ] Test with 1, 2, 5, and 10+ features

#### Service Layer
- [ ] Create `app/services/pwb/field_key_lookup_service.rb`
- [ ] Implement `find_keys_by_label` method
- [ ] Implement `find_keys_by_label_multi_locale` method
- [ ] Implement `get_translations` method
- [ ] Write specs in `spec/services/pwb/field_key_lookup_service_spec.rb`
- [ ] Test edge cases (empty strings, special characters, accents)
- [ ] Add performance benchmarks for 100+ field keys

#### Caching
- [ ] Add `cached_translations_for_tag` to `FieldKey` model
- [ ] Add `translation_cache_key` to `FieldKey` model
- [ ] Test cache invalidation on field key updates

#### Controller Layer
- [ ] Update `search` method in `app/controllers/pwb/search_controller.rb`
- [ ] Add `parse_feature_params` helper method
- [ ] Add `apply_standard_filters` helper method
- [ ] Update `search_params` to permit `features` array and `features_match`
- [ ] Write controller specs in `spec/controllers/pwb/search_controller_spec.rb`
- [ ] Test various search combinations

#### View Layer
- [ ] Update search form to include feature checkboxes
- [ ] Add `features_match` selector (all vs any)
- [ ] Style feature checkboxes with CSS
- [ ] Add JavaScript for "Select All" / "Clear All" buttons
- [ ] Display active filters with remove buttons

#### Database
- [ ] Create migration `db/migrate/YYYYMMDD_add_field_key_search_indexes.rb`
- [ ] Run migration on development: `rails db:migrate`
- [ ] Test query performance with `EXPLAIN ANALYZE`
- [ ] Document index rationale in migration comments

#### API Layer
- [ ] Update `app/controllers/pwb/api/v1/properties_controller.rb` index action
- [ ] Update `app/graphql/types/query_type.rb` search_properties field
- [ ] Add feature filtering to both APIs
- [ ] Update API documentation with feature search examples
- [ ] Write API specs in `spec/requests/pwb/api/v1/properties_spec.rb`
- [ ] Test GraphQL queries in `spec/graphql/queries/search_properties_spec.rb`

#### Public API
- [ ] Add `search` parameter to `api_public/v1/select_values_controller.rb`
- [ ] Implement filtering logic
- [ ] Add specs for search functionality
- [ ] Update API documentation

### Phase 2: Enhanced Search (Medium Priority)

#### I18n Persistence
- [ ] Add `i18n-active_record` to Gemfile and run bundle install
- [ ] Run setup: `rails i18n:active_record:setup`
- [ ] Configure I18n backend in `config/initializers/i18n.rb`
- [ ] Update FieldKey model with `persist_translations` method
- [ ] Create data migration to move existing translations to database
- [ ] Run migration on development
- [ ] Test that translations persist after server restart
- [ ] Update field_keys management UI to save to database

#### Full-Text Search
- [ ] Create migration for tsvector column and trigger
- [ ] Test migration thoroughly on development database
- [ ] Add `search_field_keys` scope to Prop model
- [ ] Write specs for full-text search
- [ ] Benchmark performance vs. Ruby-based search
- [ ] Document limitations

#### Faceted Search
- [ ] Create `app/services/pwb/search_facets_service.rb`
- [ ] Implement `calculate_property_types` method
- [ ] Implement `calculate_property_states` method
- [ ] Implement `calculate_features` method
- [ ] Add caching for facet counts (15-minute expiry)
- [ ] Update search controller to calculate facets
- [ ] Update search view to display facets
- [ ] Add AJAX for dynamic facet updates
- [ ] Write specs for facet calculations
- [ ] Test performance with large datasets

#### URL Enhancement
- [ ] Add custom routes for slug-based URLs in `config/routes.rb`
- [ ] Implement `normalize_search_params` in controller
- [ ] Create `search_url_for` helper method in `app/helpers/search_helper.rb`
- [ ] Create `slugify_field_key` helper method
- [ ] Update all search form `action` attributes to use helper
- [ ] Add specs for URL parameter normalization
- [ ] Test with various language locales
- [ ] Update sitemap to include search pages

### Phase 3: Advanced Features (Low Priority)

#### Hierarchical Field Keys
- [ ] Design hierarchy structure (max depth, limits)
- [ ] Create migration for parent_key, level, path columns
- [ ] Update FieldKey model with associations and methods
- [ ] Update management UI to support parent selection
- [ ] Add `with_property_type_hierarchy` scope to Prop model
- [ ] Update search controller to use hierarchical search
- [ ] Write comprehensive specs for hierarchy
- [ ] Create seed data with example hierarchies
- [ ] Document hierarchy limitations and best practices

#### Saved Searches
- [ ] Create migration for `saved_searches` table
- [ ] Create `SavedSearch` model with execute method
- [ ] Create `SavedSearchesController` with CRUD actions
- [ ] Add routes for saved searches in `config/routes.rb`
- [ ] Create views for saved search management
- [ ] Add "Save this search" button to search results page
- [ ] Implement email notifications for new results (background job)
- [ ] Write specs for SavedSearch model and controller
- [ ] Add user dashboard with saved searches list

#### Search Analytics
- [ ] Create migration for `search_analytics` table
- [ ] Create `SearchAnalytic` model
- [ ] Create `SearchAnalyticsService` with tracking methods
- [ ] Add tracking call to search controller
- [ ] Create admin dashboard for analytics in `app/controllers/site_admin/analytics_controller.rb`
- [ ] Create views for analytics dashboard
- [ ] Add charts/visualizations for popular searches
- [ ] Implement privacy compliance (GDPR - IP anonymization)
- [ ] Add data retention policy (delete old analytics)
- [ ] Write specs for analytics service

### Testing
- [ ] Write comprehensive unit tests for all new scopes
- [ ] Write integration tests for API endpoints
- [ ] Write system tests for user workflows
- [ ] Add performance tests (benchmark 1000+ properties)
- [ ] Test with multiple tenants (ensure isolation)
- [ ] Test with all supported locales
- [ ] Add edge case tests (special characters, long strings)
- [ ] Add `bullet` gem to detect N+1 queries

### Performance
- [ ] Add all recommended database indexes
- [ ] Implement caching for field key options
- [ ] Implement caching for search facets
- [ ] Use `rack-mini-profiler` to monitor query performance
- [ ] Run `EXPLAIN ANALYZE` on complex search queries
- [ ] Benchmark before/after optimization (target: <100ms search)
- [ ] Set up database connection pooling for production

### Documentation
- [ ] Document all new API endpoints
- [ ] Add OpenAPI/Swagger specification
- [ ] Create Postman collection with examples
- [ ] Document rate limits and authentication
- [ ] Add API versioning strategy
- [ ] Create GraphQL schema documentation
- [ ] Write API integration guide for developers
- [ ] Update user documentation with feature search instructions
- [ ] Create video tutorial for feature search

### Deployment
- [ ] Create deployment checklist
- [ ] Test migrations on staging environment
- [ ] Run database backups before production deployment
- [ ] Deploy Phase 1 to production
- [ ] Monitor error logs and performance metrics
- [ ] Collect user feedback
- [ ] Iterate based on feedback

---

## Resources & References

### Internal Documentation
- `/docs/admin/properties_settings/README.md` - Field keys management overview
- `/docs/admin/properties_settings/user_guide.md` - User instructions
- `/docs/admin/properties_settings/developer_guide.md` - Technical reference
- `/docs/admin/properties_settings/admin_interface_documentation.md` - Vue.js admin docs

### External Resources
- [PostgreSQL Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [JSONAPI Specification](https://jsonapi.org/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [i18n-active_record gem](https://github.com/svenfuchs/i18n-active_record)

### Related Models
- `app/models/pwb/field_key.rb`
- `app/models/pwb/prop.rb`
- `app/models/pwb/feature.rb`
- `app/models/pwb/website.rb`

### Test Files
- `spec/models/pwb/field_key_spec.rb`
- `spec/models/pwb/prop_spec.rb`
- `spec/controllers/site_admin/properties/settings_controller_spec.rb`
- `spec/system/site_admin/properties_settings_spec.rb`

---

## Conclusion

This implementation plan provides a comprehensive roadmap for adding field key-based property search to PropertyWebBuilder. The phased approach allows for incremental delivery while managing technical complexity and risk.

**Recommended Starting Point:** Begin with **Phase 1 (Foundation)** as it provides immediate value to users (feature-based search) with minimal risk. Phase 2 and 3 can be implemented based on user feedback and business priorities.

**Estimated Total Effort:**
- Phase 1: 2-3 weeks (1 developer)
- Phase 2: 3-4 weeks (1 developer)
- Phase 3: 4-6 weeks (1 developer)
- **Total: 9-13 weeks** for complete implementation

**Next Steps:**
1. Review this plan with stakeholders
2. Prioritize features based on user needs
3. Set up development environment
4. Begin Phase 1 implementation
5. Iterate based on testing and feedback

---

**Document Version:** 1.0
**Last Updated:** 2024-12-04
**Author:** PropertyWebBuilder Development Team
**Status:** Ready for Implementation
