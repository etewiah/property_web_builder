# Schema Migration Guide: Monolithic `pwb_props` to Normalized Architecture

This guide details the steps to migrate the PropertyWebBuilder database from a single "God Table" (`pwb_props`) to a normalized architecture separating the physical asset (`realty_assets`) from its business transactions (`sale_listings`, `rental_listings`).

## 1. Overview of Changes

| Concept | Old Architecture | New Architecture |
| :--- | :--- | :--- |
| **Physical Property** | `pwb_props` (mixed with listing data) | `pwb_realty_assets` table |
| **For Sale Listing** | `pwb_props` (flags: `for_sale`) | `pwb_sale_listings` table |
| **For Rent Listing** | `pwb_props` (flags: `for_rent`) | `pwb_rental_listings` table |

## 2. Pre-Migration Checklist

- [ ] **Backup Database**: Create a full dump of the production database.
- [ ] **Code Freeze**: Ensure no new features are being deployed during migration.
- [ ] **Maintenance Mode**: Plan for downtime as this is a major structural change.

## 3. Execution Steps

### Step 1: Create New Tables

Generate a migration to create the three new tables.

```bash
rails g migration CreateNormalizedPropertyTables
```

**Migration File Content:**

```ruby
class CreateNormalizedPropertyTables < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # 1. Realty Assets (The Physical Property)
    create_table :pwb_realty_assets, id: :uuid do |t|
      t.string :reference
      t.string :title
      t.text :description
      
      # Physical Attributes
      t.integer :year_construction, default: 0
      t.integer :count_bedrooms, default: 0
      t.float :count_bathrooms, default: 0.0
      t.integer :count_toilets, default: 0
      t.integer :count_garages, default: 0
      t.float :plot_area, default: 0.0
      t.float :constructed_area, default: 0.0
      t.integer :energy_rating
      t.float :energy_performance
      
      # Address / Location
      t.string :street_number
      t.string :street_name
      t.string :street_address
      t.string :postal_code
      t.string :city
      t.string :region
      t.string :country
      t.float :latitude
      t.float :longitude
      
      # Keys/Metadata
      t.string :prop_origin_key
      t.string :prop_state_key
      t.string :prop_type_key
      t.integer :website_id, index: true
      
      t.timestamps
    end

    # 2. Sale Listings (The Transaction)
    create_table :pwb_sale_listings, id: :uuid do |t|
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
      t.string :reference # Can be different from asset reference
      
      # Status Flags
      t.boolean :visible, default: false
      t.boolean :highlighted, default: false
      t.boolean :archived, default: false
      t.boolean :reserved, default: false
      t.boolean :furnished, default: false
      
      # Financials
      t.bigint :price_sale_current_cents, default: 0
      t.string :price_sale_current_currency, default: 'EUR'
      t.bigint :commission_cents, default: 0
      t.string :commission_currency, default: 'EUR'
      
      t.timestamps
    end

    # 3. Rental Listings (The Transaction)
    create_table :pwb_rental_listings, id: :uuid do |t|
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
      t.string :reference
      
      # Status Flags
      t.boolean :visible, default: false
      t.boolean :highlighted, default: false
      t.boolean :archived, default: false
      t.boolean :reserved, default: false
      t.boolean :furnished, default: false
      
      # Rental Specifics
      t.boolean :for_rent_short_term, default: false
      t.boolean :for_rent_long_term, default: false
      
      # Financials
      t.bigint :price_rental_monthly_current_cents, default: 0
      t.string :price_rental_monthly_current_currency, default: 'EUR'
      t.bigint :price_rental_monthly_low_season_cents, default: 0
      t.bigint :price_rental_monthly_high_season_cents, default: 0
      
      t.timestamps
    end
  end
end
```

### Step 2: Define Temporary Models

To facilitate data migration, define the new models (you can place these in `app/models` immediately).

**`app/models/pwb/realty_asset.rb`**
```ruby
module Pwb
  class RealtyAsset < ApplicationRecord
    self.table_name = 'pwb_realty_assets'
    has_many :sale_listings, class_name: 'Pwb::SaleListing', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :rental_listings, class_name: 'Pwb::RentalListing', foreign_key: 'realty_asset_id', dependent: :destroy
    belongs_to :website, class_name: 'Pwb::Website'
  end
end
```

**`app/models/pwb/sale_listing.rb`**
```ruby
module Pwb
  class SaleListing < ApplicationRecord
    self.table_name = 'pwb_sale_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency
  end
end
```

**`app/models/pwb/rental_listing.rb`**
```ruby
module Pwb
  class RentalListing < ApplicationRecord
    self.table_name = 'pwb_rental_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_rental_monthly_current_cents, with_model_currency: :price_rental_monthly_current_currency
  end
end
```

### Step 3: Data Migration Script

Create a rake task `lib/tasks/migrate_props.rake` to move the data.

```ruby
namespace :pwb do
  desc "Migrate pwb_props to normalized tables"
  task migrate_props: :environment do
    puts "Starting migration..."
    
    Pwb::Prop.find_each do |prop|
      ActiveRecord::Base.transaction do
        # 1. Create Realty Asset (Physical Attributes)
        asset = Pwb::RealtyAsset.create!(
          reference: prop.reference,
          year_construction: prop.year_construction,
          count_bedrooms: prop.count_bedrooms,
          count_bathrooms: prop.count_bathrooms,
          count_toilets: prop.count_toilets,
          count_garages: prop.count_garages,
          plot_area: prop.plot_area,
          constructed_area: prop.constructed_area,
          energy_rating: prop.energy_rating,
          energy_performance: prop.energy_performance,
          street_number: prop.street_number,
          street_name: prop.street_name,
          street_address: prop.street_address,
          postal_code: prop.postal_code,
          city: prop.city,
          region: prop.region,
          country: prop.country,
          latitude: prop.latitude,
          longitude: prop.longitude,
          prop_origin_key: prop.prop_origin_key,
          prop_state_key: prop.prop_state_key,
          prop_type_key: prop.prop_type_key,
          website_id: prop.website_id
        )

        # 2. Create Sale Listing (if applicable)
        if prop.for_sale
          Pwb::SaleListing.create!(
            realty_asset: asset,
            reference: "#{prop.reference}-SALE",
            visible: prop.visible,
            highlighted: prop.highlighted,
            archived: prop.archived,
            reserved: prop.reserved,
            furnished: prop.furnished,
            price_sale_current_cents: prop.price_sale_current_cents,
            price_sale_current_currency: prop.price_sale_current_currency,
            commission_cents: prop.commission_cents,
            commission_currency: prop.commission_currency
          )
        end

        # 3. Create Rental Listing (if applicable)
        if prop.for_rent_short_term || prop.for_rent_long_term
          Pwb::RentalListing.create!(
            realty_asset: asset,
            reference: "#{prop.reference}-RENT",
            visible: prop.visible,
            highlighted: prop.highlighted,
            archived: prop.archived,
            reserved: prop.reserved,
            furnished: prop.furnished,
            for_rent_short_term: prop.for_rent_short_term,
            for_rent_long_term: prop.for_rent_long_term,
            price_rental_monthly_current_cents: prop.price_rental_monthly_current_cents,
            price_rental_monthly_current_currency: prop.price_rental_monthly_current_currency,
            price_rental_monthly_low_season_cents: prop.price_rental_monthly_low_season_cents,
            price_rental_monthly_high_season_cents: prop.price_rental_monthly_high_season_cents
          )
        end
      end
    end
    puts "Migration complete. Processed #{Pwb::Prop.count} properties."
  end
end
```

**Run the migration:**
```bash
bundle exec rake pwb:migrate_props
```

### Step 4: Codebase Refactoring (The Hard Part)

This is where the bulk of the work lies. You must update the application to use the new models.

#### 1. Update Associations
- **Photos**: `Pwb::PropPhoto` currently belongs to `prop`. You need to migrate these to belong to `RealtyAsset` (since photos usually depict the physical asset).
- **Features**: `Pwb::Feature` belongs to `prop`. Migrate to `RealtyAsset`.
- **Translations**: `Pwb::PropTranslation` belongs to `prop`. Migrate to `RealtyAsset` (for description/title) or Listings (if you have specific transaction text).

#### 2. Update Controllers
- **Search Controller**: Instead of `Pwb::Prop.where(...)`, you will need to search Listings joined with Assets.
  - *Example*: `SaleListing.joins(:realty_asset).where(realty_assets: { count_bedrooms: 3 })`
- **Admin Controller**: The property editor needs to be split.
  - Tab 1: "Property Details" (edits `RealtyAsset`)
  - Tab 2: "Sale Settings" (edits `SaleListing`)
  - Tab 3: "Rental Settings" (edits `RentalListing`)

#### 3. Update Views / API Serializers
- **Property Cards**: Update to accept a `Listing` object (Sale or Rental) and delegate physical attributes to `listing.realty_asset`.
- **Property Details Page**: Needs to handle fetching data from both the Listing and the associated Asset.

### Step 5: Cleanup

Once you are 100% confident and have verified the new system:
1.  Drop the `pwb_props` table.
2.  Remove `Pwb::Prop` model.
3.  Rename `RealtyAsset` to `Prop` (optional, if you want to keep the old naming convention, but `RealtyAsset` is more accurate).

## 4. Rollback Plan

If the migration fails or critical bugs are found:
1.  The `pwb_props` table is **untouched** by the migration script (it only reads).
2.  Simply revert the code changes to point back to `Pwb::Prop`.
3.  Drop the new tables `realty_assets`, `sale_listings`, `rental_listings` to clean up.

## 5. Pros & Cons Summary

**Pros:**
- **Correct Modeling**: Separates physical object from business intent.
- **Flexibility**: Allows a property to be For Sale and For Rent simultaneously with different statuses.
- **Data Integrity**: Specific validations for sale vs. rental data.

**Cons:**
- **Complexity**: Queries become more complex (joins required).
- **Effort**: Significant refactoring of controllers, views, and forms required.
