# Schema Migration Walkthrough: pwb_props → Normalized Architecture

## Overview

Successfully migrated the PropertyWebBuilder database from a monolithic `pwb_props` table to a normalized architecture separating physical assets from transactional listings.

## What Was Accomplished

### 1. Database Schema Creation ✅

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

**Migration File**: [20251204180440_create_normalized_property_tables.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/db/migrate/20251204180440_create_normalized_property_tables.rb)

### 2. Model Definitions ✅

Created three new ActiveRecord models under the `Pwb` namespace:

#### [Pwb::RealtyAsset](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/realty_asset.rb)
- **Associations**: 
  - `has_many :sale_listings, :rental_listings`
  - `has_many :prop_photos, :features, :translations`
  - `belongs_to :website`
- **Helper Methods**: `bedrooms`, `bathrooms`, `surface_area`, `location`, `price` for view compatibility

#### [Pwb::SaleListing](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/sale_listing.rb)
- **Monetization**: `price_sale_current_cents`
- **Scopes**: `visible`, `highlighted`, `archived`

#### [Pwb::RentalListing](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/rental_listing.rb)
- **Monetization**: `price_rental_monthly_current_cents`
- **Scopes**: `visible`, `highlighted`, `archived`, `for_rent_short_term`, `for_rent_long_term`

### 3. Data Migration ✅

**Rake Task**: [`pwb:migrate_props`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/lib/tasks/migrate_props.rake)

Successfully migrated **6 properties** from `pwb_props`:
- Created **6 `RealtyAsset` records**
- Created **3 `SaleListing` records** (for properties marked `for_sale`)
- Created **3 `RentalListing` records** (for properties marked for rent)

### 4. Association Linking ✅

**Migration File**: [20251204181516_add_realty_asset_id_to_related_tables.rb](file:///Users/etewiah/dev/sites-legacy/property_web_builder/db/migrate/20251204181516_add_realty_asset_id_to_related_tables.rb)

Added `realty_asset_id` (UUID foreign key) to:
- `pwb_prop_photos`
- `pwb_features`
- `pwb_prop_translations`

**Rake Task**: [`pwb:link_associations`](file:///Users/etewiah/dev/sites-legacy/property_web_builder/lib/tasks/link_associations.rake)

Successfully linked existing data:
- **Photos**: Migrated to `RealtyAsset` (verified: 2 photos per first asset)
- **Features**: Linked to `RealtyAsset`
- **Translations**: Linked via Globalize (`Pwb::Prop::Translation`) (verified: 2 translations per first asset)

### 5. Model Refactoring ✅

#### Updated [Pwb::Website](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/website.rb#L11-L14)
Added associations:
```ruby
has_many :realty_assets, class_name: 'Pwb::RealtyAsset', foreign_key: 'website_id'
has_many :sale_listings, through: :realty_assets
has_many :rental_listings, through: :realty_assets
```

**Verification Result**: ✅ Working correctly
- 6 assets accessible via `website.realty_assets`
- 3 sale listings via `website.sale_listings`
- 3 rental listings via `website.rental_listings`

### 6. Controller Refactoring (Partial) ✅

#### Updated [TenantAdmin::PropsController](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/tenant_admin/props_controller.rb)

Changed from `Pwb::Prop` to `Pwb::RealtyAsset`:
- `index` action: Lists `Pwb::RealtyAsset.includes(:website)`
- `set_prop`: Fetches `Pwb::RealtyAsset.find(params[:id])`

**Views Compatibility**: Existing views work without modification thanks to helper methods added to `Pwb::RealtyAsset`.

## Current State

### ✅ Complete
- Database tables created and migrated
- Models defined with associations and scopes
- Data successfully transferred (6 properties → 6 assets + 6 listings)
- Photos, features, translations linked to assets
- Website model integrated
- TenantAdmin controller updated

### ⏳ Remaining Work
- **API Controllers**: `Pwb::ApiExt::V1::PropsController` and others need refactoring
- **Public Search**: Search controllers need to query listings instead of props
- **Views**: Property detail pages, search results may need updates
- **Old Schema**: `pwb_props` table still exists (can be dropped after full migration)

## Verification Commands

```bash
# Verify data counts
rails runner "puts 'Assets: ' + Pwb::RealtyAsset.count.to_s; puts 'Sales: ' + Pwb::SaleListing.count.to_s; puts 'Rentals: ' + Pwb::RentalListing.count.to_s"

# Verify associations
rails runner "asset = Pwb::RealtyAsset.first; puts 'Photos: ' + asset.prop_photos.count.to_s; puts 'Features: ' + asset.features.count.to_s; puts 'Translations: ' + asset.translations.count.to_s"

# Verify website associations
rails runner "w = Pwb::Website.first; puts 'Assets: ' + w.realty_assets.count.to_s; puts 'Sale Listings: ' + w.sale_listings.count.to_s; puts 'Rental Listings: ' + w.rental_listings.count.to_s"
```

## Next Steps

1. **Analyze Public Search Controllers**: Update to query `SaleListing` and `RentalListing` with joins to `RealtyAsset`
2. **Update API Endpoints**: Refactor API controllers to work with new models
3. **View Updates**: Ensure property detail pages correctly display listing data
4. **Testing**: Create comprehensive tests for the new schema
5. **Cleanup**: After full migration verified, drop `pwb_props` table

## Documentation

- **Migration Guide**: [docs/architecture/migrations/pwb_props_normalization.md](file:///Users/etewiah/dev/sites-legacy/property_web_builder/docs/architecture/migrations/pwb_props_normalization.md)
- **Task Checklist**: [task.md](file:///Users/etewiah/.gemini/antigravity/brain/71e09c68-dec5-4be0-9f69-945099835876/task.md)
