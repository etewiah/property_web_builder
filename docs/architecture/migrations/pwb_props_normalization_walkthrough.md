# Schema Migration Walkthrough: pwb_props → Normalized Architecture

## Overview

Successfully migrated the PropertyWebBuilder database from a monolithic `pwb_props` table to a normalized architecture separating physical assets from transactional listings, **with a materialized view for optimized read operations**.

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                     WRITE PATH (Normalized)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐                                                │
│  │ Pwb::RealtyAsset│──────┬────────────────────────────────────────│
│  │ (Physical Data) │      │                                         │
│  └─────────────────┘      │                                         │
│           │               │                                         │
│           ▼               ▼                                         │
│  ┌─────────────────┐  ┌─────────────────┐                          │
│  │Pwb::SaleListing │  │Pwb::RentalListing│                          │
│  │ (Sale Data)     │  │ (Rental Data)   │                          │
│  └─────────────────┘  └─────────────────┘                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ after_commit triggers
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     READ PATH (Denormalized)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │             Pwb::Property (Materialized View)                │   │
│  │  - Joins RealtyAsset + SaleListing + RentalListing          │   │
│  │  - Indexed for fast queries                                  │   │
│  │  - Auto-refreshed after writes                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## What Was Accomplished

### Phase 1: Database Schema Creation ✅

Created three new tables to replace the monolithic `pwb_props`:

- **`pwb_realty_assets`**: Physical property data (UUID primary key)
  - Location, dimensions, features, construction details
  - Website scoping for multi-tenancy

- **`pwb_sale_listings`**: Sale transaction data (UUID primary key)
  - Price, commission, visibility flags
  - Foreign key to `pwb_realty_assets`

- **`pwb_rental_listings`**: Rental transaction data (UUID primary key)
  - Monthly/seasonal pricing, rental period flags
  - Foreign key to `pwb_realty_assets`

**Migration File**: `db/migrate/20251204180440_create_normalized_property_tables.rb`

### Phase 2: Model Definitions ✅

Created ActiveRecord models under the `Pwb` namespace:

#### Pwb::RealtyAsset (`app/models/pwb/realty_asset.rb`)
- **Associations**: `has_many :sale_listings, :rental_listings, :prop_photos, :features, :translations`
- **Callbacks**: `after_commit :refresh_properties_view`
- **Helper Methods**: `bedrooms`, `bathrooms`, `title`, `description`, `get_features`, `set_features=`

#### Pwb::SaleListing (`app/models/pwb/sale_listing.rb`)
- **Monetization**: `price_sale_current_cents`, `commission_cents`
- **Scopes**: `visible`, `highlighted`, `archived`, `active`
- **Callbacks**: `after_commit :refresh_properties_view`

#### Pwb::RentalListing (`app/models/pwb/rental_listing.rb`)
- **Monetization**: `price_rental_monthly_current_cents`, seasonal prices
- **Scopes**: `visible`, `highlighted`, `archived`, `for_rent_short_term`, `for_rent_long_term`, `active`
- **Callbacks**: `after_commit :refresh_properties_view`

### Phase 3: Materialized View Implementation ✅

Added the **Scenic gem** for database view management.

#### Created Materialized View: `pwb_properties`

**SQL Definition**: `db/views/pwb_properties_v01.sql`

The view joins all three tables and computes:
- Combined visibility (`for_sale`, `for_rent`, `visible`)
- Rental search price (lowest of seasonal prices)
- All physical and transactional attributes

**Migration File**: `db/migrate/20251204185426_create_pwb_properties_materialized_view.rb`

**Indexes created**:
- `id` (unique, required for concurrent refresh)
- `website_id`, `visible`, `for_sale`, `for_rent`, `highlighted`
- `reference`, `price_sale_current_cents`, `price_rental_monthly_current_cents`
- `latitude, longitude`, `count_bedrooms`, `count_bathrooms`, `prop_type_key`

#### Pwb::Property Model (`app/models/pwb/property.rb`)

**Read-only model** backed by the materialized view:

```ruby
class Pwb::Property < ApplicationRecord
  self.table_name = 'pwb_properties'

  def readonly?
    true  # Prevents accidental writes
  end

  def self.refresh(concurrently: true)
    Scenic.database.refresh_materialized_view(table_name, concurrently: concurrently)
  end
end
```

**Features**:
- Full `Pwb::Prop` interface compatibility
- Scopes: `visible`, `for_sale`, `for_rent`, `highlighted`, price ranges
- Associations: `prop_photos`, `features`, `translations` (via `realty_asset_id`)
- Methods: `title`, `description`, `contextual_price`, `primary_image_url`, etc.
- Monetization for all price fields

### Phase 4: Data Migration ✅

**Rake Tasks**:
- `pwb:migrate_props` - Migrated 6 properties to normalized tables
- `pwb:link_associations` - Linked photos, features, translations

**Results**:
- 6 `RealtyAsset` records
- 3 `SaleListing` records
- 3 `RentalListing` records
- 6 `Property` records in materialized view

### Phase 5: Controller Refactoring ✅

Updated all controllers to use `Pwb::Property` for reads and `Pwb::RealtyAsset` for writes:

| Controller | Read Model | Write Model |
|------------|------------|-------------|
| `Pwb::PropsController` | `Pwb::Property` | - |
| `SiteAdmin::PropsController` | `Pwb::Property` | `Pwb::RealtyAsset` |
| `SiteAdmin::DashboardController` | `Pwb::Property` | - |
| `TenantAdmin::PropsController` | `Pwb::RealtyAsset` | `Pwb::RealtyAsset` |
| `TenantAdmin::DashboardController` | `Pwb::Property` | - |

### Phase 6: JSONAPI Resources Update ✅

Updated all JSONAPI resources to use `Pwb::Property`:

- `Pwb::Api::V1::PropertyResource` → `model_name 'Pwb::Property'`
- `Pwb::Api::V1::LitePropertyResource` → `model_name 'Pwb::Property'`
- `Pwb::ApiExt::V1::PropResource` → `model_name 'Pwb::Property'`

**Note**: These resources are now read-only. Write operations should use the underlying models directly via custom API endpoints.

## Current State

### ✅ Complete
- Database tables created and migrated
- Materialized view created with indexes
- Models defined with associations, scopes, and refresh triggers
- Data successfully transferred (6 properties → 6 assets + 6 listings)
- Photos, features, translations linked to assets
- All controllers updated to use new models
- JSONAPI resources updated
- Auto-refresh after writes

### ⏳ Remaining Work
- **Testing**: Create comprehensive tests for the new schema
- **Old Schema**: `pwb_props` table can be dropped after full verification

## Verification Commands

```bash
# Verify materialized view
rails runner "puts 'Properties in view: ' + Pwb::Property.count.to_s"

# Verify all counts
rails runner "
  puts 'Properties: ' + Pwb::Property.count.to_s
  puts 'Assets: ' + Pwb::RealtyAsset.count.to_s
  puts 'Sales: ' + Pwb::SaleListing.count.to_s
  puts 'Rentals: ' + Pwb::RentalListing.count.to_s
"

# Verify Property model features
rails runner "
  p = Pwb::Property.first
  puts 'ID: ' + p.id.to_s
  puts 'Title: ' + p.title.to_s
  puts 'For Sale: ' + p.for_sale.to_s
  puts 'For Rent: ' + p.for_rent.to_s
  puts 'Photos: ' + p.prop_photos.count.to_s
  puts 'Readonly: ' + p.readonly?.to_s
"

# Test refresh
rails runner "Pwb::Property.refresh; puts 'Refresh successful'"
```

## Usage Guide

### Reading Properties (use Pwb::Property)

```ruby
# List visible properties
Pwb::Property.visible

# Filter by type
Pwb::Property.for_sale.where(website_id: 1)
Pwb::Property.for_rent.highlighted

# Search
Pwb::Property.properties_search(
  sale_or_rental: 'sale',
  count_bedrooms: 2,
  for_sale_price_till: 500000
)

# Single property
property = Pwb::Property.find(uuid)
property.title
property.contextual_price('for_sale')
property.prop_photos
```

### Writing Properties (use RealtyAsset + Listings)

```ruby
# Create new property
asset = Pwb::RealtyAsset.create!(
  reference: 'NEW-001',
  count_bedrooms: 3,
  street_address: '123 Main St',
  website_id: 1
)

# Add sale listing
asset.sale_listings.create!(
  visible: true,
  price_sale_current_cents: 25000000,
  price_sale_current_currency: 'EUR'
)

# Add rental listing
asset.rental_listings.create!(
  visible: true,
  for_rent_long_term: true,
  price_rental_monthly_current_cents: 150000
)

# View auto-refreshes after commit
```

### Manual Refresh (if needed)

```ruby
# Synchronous refresh (locks view briefly)
Pwb::Property.refresh

# Concurrent refresh (no lock, requires unique index)
Pwb::Property.refresh(concurrently: true)
```

## Files Changed

### New Files
- `app/models/pwb/property.rb` - Materialized view model
- `db/views/pwb_properties_v01.sql` - View SQL definition
- `db/migrate/20251204185426_create_pwb_properties_materialized_view.rb`

### Modified Files
- `Gemfile` - Added `scenic` gem
- `app/models/pwb/realty_asset.rb` - Added refresh trigger, methods
- `app/models/pwb/sale_listing.rb` - Added refresh trigger, monetization
- `app/models/pwb/rental_listing.rb` - Added refresh trigger, monetization
- `app/controllers/pwb/props_controller.rb` - Use Property view
- `app/controllers/site_admin/props_controller.rb` - Use Property/RealtyAsset
- `app/controllers/site_admin/dashboard_controller.rb` - Use Property
- `app/controllers/tenant_admin/dashboard_controller.rb` - Use Property
- `app/resources/pwb/api/v1/property_resource.rb` - Use Property
- `app/resources/pwb/api/v1/lite_property_resource.rb` - Use Property
- `app/resources/pwb/api_ext/v1/prop_resource.rb` - Use Property

## Next Steps

1. **Add Tests**: Create specs for Property model and refresh functionality
2. **Performance Testing**: Verify refresh performance with larger datasets
3. **Cleanup**: After full verification, drop `pwb_props` table
4. **Documentation**: Update API documentation for read-only resources
