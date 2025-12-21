# Field Keys System

## Overview

Field Keys provide a flexible labeling system for properties. They enable categorization, filtering, and search functionality across the application. Each field key has a `global_key` (used in code and as an i18n translation key) and belongs to a `tag` category.

## Architecture

### Database Schema

```
pwb_field_keys
├── global_key (primary key, string) - e.g., "features.private_pool"
├── tag (string) - Category grouping, e.g., "property-features"
├── visible (boolean) - Whether to show in UI dropdowns
├── pwb_website_id (foreign key, optional) - For website-specific keys
└── properties_count (integer) - Counter cache for properties using this key
```

### Related Tables

**pwb_realty_assets** - Physical property data
- `prop_type_key` - References a `property-types` field key
- `prop_state_key` - References a `property-states` field key

**pwb_features** - Many-to-many relationship for features/amenities
- `realty_asset_id` - The property
- `feature_key` - References a field key (features or amenities)

### Model Relationships

```ruby
# Pwb::FieldKey
has_many :realty_assets_with_state, foreign_key: "prop_state_key"
has_many :realty_assets_with_type, foreign_key: "prop_type_key"
has_many :features, foreign_key: "feature_key"

# Pwb::RealtyAsset
belongs_to :prop_type, class_name: "Pwb::FieldKey", foreign_key: "prop_type_key"
belongs_to :prop_state, class_name: "Pwb::FieldKey", foreign_key: "prop_state_key"
has_many :features

# Pwb::Feature
belongs_to :realty_asset
belongs_to :feature_field_key, class_name: "Pwb::FieldKey", foreign_key: "feature_key"
```

---

## Field Key Categories

### 1. `property-types` - What the property IS

Defines the type/category of the property.

| Key | Display Name |
|-----|--------------|
| `types.apartment` | Apartment |
| `types.house` | House |
| `types.villa` | Villa |
| `types.bungalow` | Bungalow |
| `types.penthouse` | Penthouse |
| `types.duplex` | Duplex |
| `types.studio` | Studio |
| `types.townhouse` | Townhouse |
| `types.farmhouse` | Farmhouse |
| `types.cottage` | Cottage |
| `types.land` | Land/Plot |
| `types.commercial` | Commercial |
| `types.office` | Office |
| `types.warehouse` | Warehouse |
| `types.retail` | Retail Space |
| `types.garage` | Garage |

**Usage:**
```ruby
# Set property type
realty_asset.prop_type_key = "types.apartment"

# Query by type
Pwb::ListedProperty.where(prop_type_key: "types.villa")

# Get dropdown options
Pwb::FieldKey.get_options_by_tag("property-types")
```

---

### 2. `property-states` - Physical condition

Describes the current physical state/condition of the property.

| Key | Display Name |
|-----|--------------|
| `states.new_build` | New Build |
| `states.under_construction` | Under Construction |
| `states.good_condition` | Good Condition |
| `states.needs_renovation` | Needs Renovation |
| `states.renovated` | Recently Renovated |
| `states.to_demolish` | To Demolish |

**Usage:**
```ruby
# Set property state
realty_asset.prop_state_key = "states.good_condition"

# Query by state
Pwb::ListedProperty.where(prop_state_key: "states.new_build")
```

---

### 3. `property-features` - Permanent physical attributes

Structural elements and outdoor spaces that are part of the property.

| Key | Display Name |
|-----|--------------|
| `features.balcony` | Balcony |
| `features.terrace` | Terrace |
| `features.patio` | Patio |
| `features.porch` | Porch |
| `features.private_garden` | Private Garden |
| `features.community_garden` | Community Garden |
| `features.private_pool` | Private Pool |
| `features.community_pool` | Community Pool |
| `features.heated_pool` | Heated Pool |
| `features.private_garage` | Private Garage |
| `features.community_garage` | Community Garage |
| `features.storage` | Storage Room |
| `features.laundry_room` | Laundry Room |
| `features.separate_kitchen` | Separate Kitchen |
| `features.fireplace` | Fireplace |
| `features.jacuzzi` | Jacuzzi |
| `features.sauna` | Sauna |
| `features.solarium` | Solarium |
| `features.barbecue` | Barbecue |
| `features.sea_views` | Sea Views |
| `features.mountain_views` | Mountain Views |
| `features.sports_area` | Sports Area |
| `features.play_area` | Children's Play Area |
| `features.wooden_floor` | Wooden Floor |
| `features.marble_floor` | Marble Floor |

**Usage:**
```ruby
# Add feature to property
realty_asset.features.create(feature_key: "features.private_pool")

# Check if property has feature
realty_asset.features.exists?(feature_key: "features.sea_views")

# Get all features for a property
realty_asset.get_features
# => { "features.private_pool" => true, "features.sea_views" => true }

# Search properties with specific feature
Pwb::ListedProperty.joins(:features).where(features: { feature_key: "features.private_pool" })
```

---

### 4. `property-amenities` - Equipment & services

Appliances, systems, and services that can be added or removed.

| Key | Display Name |
|-----|--------------|
| `amenities.air_conditioning` | Air Conditioning |
| `amenities.central_heating` | Central Heating |
| `amenities.electric_heating` | Electric Heating |
| `amenities.gas_heating` | Gas Heating |
| `amenities.oil_heating` | Oil Heating |
| `amenities.propane_heating` | Propane Heating |
| `amenities.solar_energy` | Solar Energy |
| `amenities.alarm` | Alarm System |
| `amenities.security` | Security Service |
| `amenities.video_intercom` | Video Intercom |
| `amenities.concierge` | Concierge Service |
| `amenities.elevator` | Elevator |
| `amenities.furnished` | Fully Furnished |
| `amenities.semi_furnished` | Semi Furnished |
| `amenities.refrigerator` | Refrigerator |
| `amenities.oven` | Oven |
| `amenities.microwave` | Microwave |
| `amenities.washing_machine` | Washing Machine |
| `amenities.tv` | TV |

**Usage:**
```ruby
# Add amenity to property
realty_asset.features.create(feature_key: "amenities.air_conditioning")

# Note: Both features and amenities use the same `features` association
# The distinction is purely categorical (by tag)
```

---

### 5. `property-status` - Transaction status

Current transaction/availability status of the listing.

| Key | Display Name |
|-----|--------------|
| `status.available` | Available |
| `status.reserved` | Reserved |
| `status.under_offer` | Under Offer |
| `status.sold` | Sold |
| `status.rented` | Rented |
| `status.off_market` | Off Market |

**Note:** Some status values (like `reserved`, `sold`) may also be stored as boolean fields on the listing models (`SaleListing`, `RentalListing`) for query performance.

---

### 6. `property-highlights` - Marketing flags

Special marketing labels to highlight properties.

| Key | Display Name |
|-----|--------------|
| `highlights.featured` | Featured |
| `highlights.new_listing` | New Listing |
| `highlights.price_reduced` | Price Reduced |
| `highlights.exclusive` | Exclusive |
| `highlights.luxury` | Luxury |
| `highlights.investment` | Investment Opportunity |
| `highlights.energy_efficient` | Energy Efficient |

**Note:** The `highlighted` boolean on listings provides a simpler way to feature properties. Use field keys for more granular highlight types.

---

### 7. `listing-origin` - Source of listing

Tracks where the property listing originated from.

| Key | Display Name |
|-----|--------------|
| `origin.direct` | Direct Entry |
| `origin.import` | Data Import |
| `origin.mls` | MLS Feed |
| `origin.api` | API Integration |
| `origin.partner` | Partner Agency |

**Usage:**
```ruby
# Track listing source
realty_asset.prop_origin_key = "origin.mls"
```

---

## Internationalization (i18n)

Field key `global_key` values serve as i18n translation keys. Translations are stored in the `translations` table (using `i18n-active_record`).

### Adding Translations

```ruby
# Via Rails console or seed file
I18n.backend.store_translations(:en, {
  features: {
    private_pool: "Private Pool",
    sea_views: "Sea Views"
  },
  amenities: {
    air_conditioning: "Air Conditioning"
  }
})

# Or directly in the translations table
Translation.create!(
  locale: "en",
  key: "features.private_pool",
  value: "Private Pool"
)
```

### Using Translations

```ruby
# In views
I18n.t("features.private_pool")  # => "Private Pool"

# FieldKey helper method returns translated labels
Pwb::FieldKey.get_options_by_tag("property-features")
# => [OpenStruct(value: "features.balcony", label: "Balcony"), ...]
```

---

## Search Implementation

### Filtering by Type/State

```ruby
# In controller
def search
  @properties = Pwb::ListedProperty.visible

  if params[:property_type].present?
    @properties = @properties.where(prop_type_key: params[:property_type])
  end

  if params[:property_state].present?
    @properties = @properties.where(prop_state_key: params[:property_state])
  end
end
```

### Filtering by Features/Amenities

```ruby
# Single feature filter
@properties = Pwb::ListedProperty
  .joins(:features)
  .where(features: { feature_key: "features.private_pool" })

# Multiple features (AND - must have all)
feature_keys = ["features.private_pool", "features.sea_views"]
@properties = Pwb::ListedProperty
  .joins(:features)
  .where(features: { feature_key: feature_keys })
  .group("pwb_properties.id")
  .having("COUNT(DISTINCT pwb_features.feature_key) = ?", feature_keys.length)

# Multiple features (OR - must have any)
@properties = Pwb::ListedProperty
  .joins(:features)
  .where(features: { feature_key: feature_keys })
  .distinct
```

### Building Search Dropdowns

```ruby
# In controller
def set_search_options
  @property_types = Pwb::FieldKey.get_options_by_tag("property-types")
  @property_states = Pwb::FieldKey.get_options_by_tag("property-states")
  @features = Pwb::FieldKey.get_options_by_tag("property-features")
  @amenities = Pwb::FieldKey.get_options_by_tag("property-amenities")
end
```

```erb
<!-- In view -->
<%= select_tag :property_type,
    options_from_collection_for_select(@property_types, :value, :label),
    include_blank: "Any Type" %>
```

---

## Migration from Legacy Keys

The system previously used Spanish-based keys (e.g., `extras.piscinaPrivada`). When migrating to English keys:

### Key Mapping Reference

| Old Key (Spanish) | New Key (English) | Category |
|-------------------|-------------------|----------|
| extras.piscinaPrivada | features.private_pool | property-features |
| extras.vistasAlMar | features.sea_views | property-features |
| extras.aireAcondicionado | amenities.air_conditioning | property-amenities |
| extras.alarma | amenities.alarm | property-amenities |
| propertyTypes.apartamento | types.apartment | property-types |
| propertyStates.nuevo | states.new_build | property-states |
| propertyLabels.sold | status.sold | property-status |

### Migration Script

```ruby
# Example migration for updating field keys
KEY_MAPPING = {
  "extras.piscinaPrivada" => { key: "features.private_pool", tag: "property-features" },
  "extras.vistasAlMar" => { key: "features.sea_views", tag: "property-features" },
  # ... add all mappings
}

KEY_MAPPING.each do |old_key, new_values|
  # Update FieldKey
  field_key = Pwb::FieldKey.find_by(global_key: old_key)
  if field_key
    field_key.update!(global_key: new_values[:key], tag: new_values[:tag])
  end

  # Update Features referencing old key
  Pwb::Feature.where(feature_key: old_key).update_all(feature_key: new_values[:key])

  # Update RealtyAssets referencing old key
  Pwb::RealtyAsset.where(prop_type_key: old_key).update_all(prop_type_key: new_values[:key])
  Pwb::RealtyAsset.where(prop_state_key: old_key).update_all(prop_state_key: new_values[:key])
end

# Refresh materialized view
Pwb::ListedProperty.refresh
```

---

## Website-Specific Field Keys

Field keys can be global (shared across all websites) or website-specific:

```ruby
# Global field key (pwb_website_id is NULL)
Pwb::FieldKey.create!(global_key: "features.pool", tag: "property-features")

# Website-specific field key
Pwb::FieldKey.create!(
  global_key: "features.ski_access",
  tag: "property-features",
  pwb_website_id: ski_resort_website.id
)
```

When querying, include both global and website-specific keys:

```ruby
def available_features(website)
  Pwb::FieldKey
    .where(tag: "property-features")
    .where("pwb_website_id IS NULL OR pwb_website_id = ?", website.id)
    .visible
end
```

---

## Best Practices

1. **Use English keys** - Keys should be English-based and descriptive (e.g., `features.private_pool` not `extras.piscinaPrivada`)

2. **Consistent naming** - Use snake_case for multi-word keys (e.g., `sea_views`, `air_conditioning`)

3. **Translations for display** - Always use I18n translations for user-facing labels

4. **Visibility control** - Set `visible: false` for deprecated keys to hide from UI while preserving data

5. **Counter cache** - The `properties_count` field can be used to show only "in use" options in search filters

6. **Refresh after changes** - After updating field keys, refresh the materialized view: `Pwb::ListedProperty.refresh`
