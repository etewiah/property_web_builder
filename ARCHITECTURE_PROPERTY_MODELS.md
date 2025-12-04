# Property Models Architecture - PropertyWebBuilder

## Executive Summary

The PropertyWebBuilder application has undergone a significant schema migration from a monolithic `pwb_props` table to a **normalized architecture** that separates physical property data from transactional listings. To optimize read-heavy operations, a **materialized view** (`pwb_properties`) was introduced that denormalizes the normalized data back into a single queryable interface.

### Current Architecture Pattern
- **WRITE**: Normalized tables (`RealtyAsset`, `SaleListing`, `RentalListing`)
- **READ**: Denormalized materialized view (`Property`)
- **TRANSLATIONS**: JSONB column in `Prop` model via Mobility gem

---

## 1. Source of Truth for Property Data

### Primary Write Path (Normalized)

The **normalized schema** is the authoritative source for all property data:

```
Pwb::RealtyAsset (Physical Asset)
├── Pwb::SaleListing (Sale Transaction)
└── Pwb::RentalListing (Rental Transaction)
```

#### Pwb::RealtyAsset (UUID Primary Key)
**Location**: `/app/models/pwb/realty_asset.rb`

Represents the physical property itself - the building, land, and its immutable characteristics:

| Category | Fields |
|----------|--------|
| **Reference** | `reference` (unique property identifier) |
| **Physical Attributes** | `year_construction`, `count_bedrooms`, `count_bathrooms`, `count_toilets`, `count_garages`, `plot_area`, `constructed_area`, `energy_rating`, `energy_performance` |
| **Location** | `street_number`, `street_name`, `street_address`, `postal_code`, `city`, `region`, `country`, `latitude`, `longitude` |
| **Classification** | `prop_origin_key`, `prop_state_key`, `prop_type_key` |
| **Multi-tenancy** | `website_id` |
| **Timestamps** | `created_at`, `updated_at` |

**Associations**:
```ruby
has_many :sale_listings
has_many :rental_listings
has_many :prop_photos, foreign_key: 'realty_asset_id'
has_many :features, foreign_key: 'realty_asset_id'
belongs_to :website, optional: true
```

**Automatic Behaviors**:
- After any change, automatically refreshes the `pwb_properties` materialized view
- Delegates to `Pwb::Prop` for `title` and `description` via Mobility translations

#### Pwb::SaleListing (UUID Primary Key)
**Location**: `/app/models/pwb/sale_listing.rb`

Represents a property listed for sale - the commercial transaction data:

| Category | Fields |
|----------|--------|
| **Reference** | `reference` (can differ from asset reference) |
| **Status Flags** | `visible`, `highlighted`, `archived`, `reserved`, `furnished` |
| **Financials** | `price_sale_current_cents`, `price_sale_current_currency`, `commission_cents`, `commission_currency` |
| **Foreign Key** | `realty_asset_id` (UUID) |

**Key Feature**: A property can have multiple sale listings (though typically one active).

**Automatic Behaviors**:
- Monetizes price fields for currency handling
- After any change, refreshes the materialized view
- Delegates physical/common data to `realty_asset`

#### Pwb::RentalListing (UUID Primary Key)
**Location**: `/app/models/pwb/rental_listing.rb`

Represents a property listed for rent - the rental transaction data:

| Category | Fields |
|----------|--------|
| **Reference** | `reference` |
| **Status Flags** | `visible`, `highlighted`, `archived`, `reserved`, `furnished` |
| **Rental Type** | `for_rent_short_term`, `for_rent_long_term` |
| **Financials** | `price_rental_monthly_current_cents`, `price_rental_monthly_low_season_cents`, `price_rental_monthly_high_season_cents`, `price_rental_monthly_current_currency` |
| **Foreign Key** | `realty_asset_id` (UUID) |

**Key Feature**: Supports multiple pricing seasons (short-term vacation rentals vs. long-term leases).

**Automatic Behaviors**:
- Monetizes all price fields
- After any change, refreshes the materialized view
- Includes `vacation_rental?` helper method

---

## 2. Where Translations Are Stored (Post-Prop Deprecation)

### Current Translation Storage

Translations are **NOT** stored in the new normalized tables. Instead, they remain in the legacy `Pwb::Prop` table using **Mobility JSONB backend**:

```ruby
# In Pwb::Prop model (app/models/pwb/prop.rb)
extend Mobility
translates :title, :description
```

**Database Structure**:
```sql
CREATE TABLE pwb_props (
  id SERIAL PRIMARY KEY,
  reference VARCHAR,
  translations JSONB,  -- Stores all locale translations
  ...
);

-- Index on JSONB for fast lookups
CREATE INDEX index_pwb_props_on_translations USING gin (translations);
```

### JSONB Translation Format

```json
{
  "en": {
    "title": "Beautiful Villa with Pool",
    "description": "Stunning 3-bed villa..."
  },
  "es": {
    "title": "Hermosa Villa con Piscina",
    "description": "Espectacular villa de 3 dormitorios..."
  }
}
```

### Accessing Translations

**Via RealtyAsset** (recommended for normalized context):
```ruby
asset = Pwb::RealtyAsset.find(uuid)
asset.prop.title              # Returns localized title
asset.prop.title_en           # English title
asset.prop.description_es     # Spanish description
```

**Via Property View** (for read operations):
```ruby
property = Pwb::Property.find(uuid)
property.title                # Delegates to prop.title
property.description          # Delegates to prop.description
property.title_fr             # Locale-specific accessor
```

**Direct via Prop**:
```ruby
prop = Pwb::Prop.find_by(reference: 'REF-001')
prop.title                    # Uses Mobility to return current locale title
prop.title_de                 # German translation
prop.update(title: "New Title") # Updates translations JSONB
```

### Mobility Gem Integration

The `Mobility` gem was recently migrated from `Globalize` to use a JSONB backend. Migration details:

- **Migration File**: `db/migrate/20251204205742_add_mobility_translations_columns.rb`
- **Data Migration**: `db/migrate/20251204205743_migrate_globalize_to_mobility.rb`
- **Affected Models**: `Pwb::Prop`, `Pwb::Page`, `Pwb::Content`, `Pwb::Link`

**Configuration** (in `Pwb::Prop`):
```ruby
# Uses container backend (JSONB) configured globally
translates :title, :description

# Provides locale accessors:
prop.title_en   # English
prop.title_es   # Spanish
prop.title_de   # German
# etc. for all I18n.available_locales
```

---

## 3. Relationship Between RealtyAsset and Property

### The Two Models Serve Different Purposes

```
┌─────────────────────────────────────────────────────────────┐
│                   WRITE PATH (Writes)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Pwb::RealtyAsset (UUID)        Pwb::SaleListing (UUID)    │
│  - Physical attributes          - Sale-specific data       │
│  - Location/dimensions          - Visibility flags         │
│  - Classification keys          - Price & commission       │
│                                                             │
│  Pwb::RentalListing (UUID)                                 │
│  - Rental-specific data                                    │
│  - Rental period flags                                     │
│  - Seasonal pricing                                        │
│                                                             │
│  ↓ after_commit callbacks                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  READ PATH (Materialized View)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Pwb::Property (Denormalized View, UUID Primary Key)       │
│  - Combines all attributes from asset + listings           │
│  - Indexed for fast queries                                │
│  - Read-only (readonly? returns true)                      │
│  - Auto-refreshed after writes                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Model Comparison

| Aspect | RealtyAsset | SaleListing | RentalListing | Property |
|--------|-------------|------------|---------------|----------|
| **Purpose** | Physical asset | Sale transaction | Rental transaction | Unified read view |
| **Primary Key** | UUID | UUID | UUID | UUID (same as asset) |
| **Writable** | YES | YES | YES | NO (read-only) |
| **Indexed** | Basic indexes | Basic indexes | Basic indexes | Extensive indexes |
| **Query Performance** | Moderate | Moderate | Moderate | Excellent (optimized) |
| **Use Case** | Admin editing | Sale management | Rental management | Frontend searches |

### The Separation Enables

1. **Multi-transaction Properties**: A property can be For Sale AND For Rent simultaneously:
   ```ruby
   asset = Pwb::RealtyAsset.find(uuid)
   asset.sale_listings.active      # Sales
   asset.rental_listings.active    # Rentals
   ```

2. **Independent Listings**: Each listing has its own visibility, pricing, and status:
   ```ruby
   sale = asset.sale_listings.first
   rental = asset.rental_listings.first
   
   sale.visible = true    # Listed for sale
   rental.visible = false # Not currently for rent
   ```

3. **Multiple Listing Statuses**: Can have multiple versions of the same listing:
   - Different pricing over time (via multiple records)
   - Different target markets
   - Seasonal adjustments

### How Pwb::Property Provides Backward Compatibility

The `Property` model mimics the old `Prop` interface through the materialized view:

```ruby
# Old code using Prop still works with Property
properties = Pwb::Property.visible.for_sale.where(count_bedrooms: 3)

# All familiar methods are present
property.title
property.description
property.bedrooms
property.bathrooms
property.contextual_price('for_sale')
property.prop_photos
property.features
property.get_features
```

**Under the hood**, `Property` delegates to the underlying models:
```ruby
def realty_asset
  Pwb::RealtyAsset.find(id)
end

def sale_listing
  Pwb::SaleListing.find_by(sale_listing_id)
end

def prop  # Finds associated Prop for translations
  Pwb::Prop.find_by(reference: reference)
end
```

---

## 4. Migration Path from Prop to RealtyAsset

### Historical Context

The application originally used a monolithic `Pwb::Prop` model that mixed physical properties with transactional listing data.

**Recent Commits**:
- `1f82e17e` - Normalize property tables into assets and listings
- `a3e6d367` - Add scenic gem and Pwb::Property materialized view

### Current Migration Status

#### Completed ✅
1. **Schema Creation** (Dec 4, 2025, migration 20251204180440)
   - Created `pwb_realty_assets`, `pwb_sale_listings`, `pwb_rental_listings` tables
   - Used UUIDs for new tables (vs. serial for old `pwb_props`)

2. **Model Creation** (Dec 4, 2025)
   - Defined `RealtyAsset`, `SaleListing`, `RentalListing`, `Property` models
   - Added associations and callbacks

3. **Data Migration** (Dec 4, 2025)
   - Migrated properties from `pwb_props` to normalized tables
   - Created corresponding sale/rental listings
   - Linked photos, features, translations to assets

4. **View Creation** (Dec 4, 2025, migration 20251204185426)
   - Created materialized view `pwb_properties` using Scenic gem
   - Added 13 indexes for query optimization
   - Implemented auto-refresh via callbacks

5. **Controller Updates**
   - Updated `SiteAdmin::PropsController` to use `Property` for reads, `RealtyAsset` for writes
   - Updated other controllers to use new models
   - Controllers now follow the pattern:
     ```ruby
     before_action :set_property, only: [:show, :index]        # Read from Property view
     before_action :set_realty_asset, only: [:edit_*, :update] # Write to RealtyAsset
     ```

#### Remaining Work ⏳
1. **Testing**: Comprehensive specs for new models and materialized view refresh
2. **Legacy Code**: The `pwb_props` table still exists and is kept in sync via Prop model
3. **Deprecation**: Once confident, drop `pwb_props` table and `Prop` model

### Migration Pattern Used

```ruby
# PHASE 1: Read from old model
class OldController
  @properties = Pwb::Prop.visible.for_sale
end

# PHASE 2: Read from new view, write to normalized tables
class PropsController
  def index
    @properties = Pwb::Property.visible.for_sale  # Reads from view
  end
  
  def update
    asset = Pwb::RealtyAsset.find(params[:id])    # Writes to asset
    asset.update!(asset_params)                     # Materialized view auto-refreshes
  end
end

# PHASE 3 (Future): Remove Prop entirely
# - Delete pwb_props table
# - Remove Prop model
# - Update any remaining references
```

### Key Design Decision: Why a Materialized View?

**Problem**: The normalized schema requires JOINs for every query:
```sql
SELECT * FROM pwb_realty_assets
LEFT JOIN pwb_sale_listings ON sale_listings.realty_asset_id = realty_assets.id
LEFT JOIN pwb_rental_listings ON rental_listings.realty_asset_id = realty_assets.id
WHERE realty_assets.visible = true
```

**Solution**: Pre-compute and cache the joined result as a materialized view:
```sql
CREATE MATERIALIZED VIEW pwb_properties AS
  [Complex join logic]
```

**Benefits**:
- No application-level JOINs required
- Indexes on materialized view columns
- Atomic read consistency
- Backend handles refresh after writes

**Trade-off**:
- View is eventually consistent (updated after commits)
- View size increases with data volume
- Refresh is a manual operation (though automated via callbacks)

---

## 5. Database Tables Reference

### pwb_realty_assets
```sql
CREATE TABLE pwb_realty_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference VARCHAR,
  year_construction INTEGER,
  count_bedrooms INTEGER,
  count_bathrooms FLOAT,
  ... [physical attributes]
  street_address VARCHAR,
  city VARCHAR,
  region VARCHAR,
  country VARCHAR,
  latitude FLOAT,
  longitude FLOAT,
  prop_origin_key VARCHAR,
  prop_state_key VARCHAR,
  prop_type_key VARCHAR,
  website_id INTEGER,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### pwb_sale_listings
```sql
CREATE TABLE pwb_sale_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realty_asset_id UUID REFERENCES pwb_realty_assets(id),
  reference VARCHAR,
  visible BOOLEAN DEFAULT FALSE,
  highlighted BOOLEAN DEFAULT FALSE,
  archived BOOLEAN DEFAULT FALSE,
  reserved BOOLEAN DEFAULT FALSE,
  furnished BOOLEAN DEFAULT FALSE,
  price_sale_current_cents BIGINT,
  price_sale_current_currency VARCHAR,
  commission_cents BIGINT,
  commission_currency VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### pwb_rental_listings
```sql
CREATE TABLE pwb_rental_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realty_asset_id UUID REFERENCES pwb_realty_assets(id),
  reference VARCHAR,
  visible BOOLEAN DEFAULT FALSE,
  highlighted BOOLEAN DEFAULT FALSE,
  archived BOOLEAN DEFAULT FALSE,
  reserved BOOLEAN DEFAULT FALSE,
  furnished BOOLEAN DEFAULT FALSE,
  for_rent_short_term BOOLEAN DEFAULT FALSE,
  for_rent_long_term BOOLEAN DEFAULT FALSE,
  price_rental_monthly_current_cents BIGINT,
  price_rental_monthly_current_currency VARCHAR,
  price_rental_monthly_low_season_cents BIGINT,
  price_rental_monthly_high_season_cents BIGINT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### pwb_properties (Materialized View)
```sql
CREATE MATERIALIZED VIEW pwb_properties AS
SELECT
  a.id,
  a.reference,
  a.website_id,
  -- [all physical attributes from asset]
  -- [sale listing fields with computed for_sale flag]
  -- [rental listing fields with computed for_rent flag]
  COALESCE(sl.visible, false) OR COALESCE(rl.visible, false) AS visible,
  a.created_at,
  a.updated_at
FROM pwb_realty_assets a
LEFT JOIN pwb_sale_listings sl ON sl.realty_asset_id = a.id AND sl.archived = false
LEFT JOIN pwb_rental_listings rl ON rl.realty_asset_id = a.id AND rl.archived = false;
```

---

## 6. Usage Guidelines

### For Reading Properties (Use Pwb::Property)

```ruby
# List visible properties
visible_props = Pwb::Property.visible

# Filter by type and website
sale_props = Pwb::Property.for_sale.where(website_id: 1)

# Search with multiple filters
results = Pwb::Property.properties_search(
  sale_or_rental: 'sale',
  count_bedrooms: 2,
  for_sale_price_from: 100000,
  for_sale_price_till: 500000
)

# Specific property
property = Pwb::Property.find(uuid)
puts property.title
puts property.contextual_price('for_sale')
puts property.prop_photos.map(&:image_url)
```

### For Writing Properties (Use RealtyAsset + Listings)

```ruby
# Create new property
asset = Pwb::RealtyAsset.create!(
  reference: 'PROP-001',
  count_bedrooms: 3,
  count_bathrooms: 2.0,
  street_address: '123 Main St',
  city: 'Barcelona',
  postal_code: '08001',
  country: 'Spain',
  website_id: 1
)

# Create sale listing
sale = asset.sale_listings.create!(
  visible: true,
  price_sale_current_cents: 50000000,
  price_sale_current_currency: 'EUR'
)

# Create rental listing
rental = asset.rental_listings.create!(
  visible: true,
  for_rent_long_term: true,
  price_rental_monthly_current_cents: 150000,
  price_rental_monthly_current_currency: 'EUR'
)

# View automatically refreshes after each commit
```

### For Managing Translations

```ruby
# Access via Prop model
prop = Pwb::Prop.find_by(reference: 'PROP-001')

# Get current locale translation
prop.title                  # In current I18n.locale

# Get specific locale
prop.title_es              # Spanish
prop.title_en              # English

# Update translation (updates JSONB column)
I18n.with_locale(:es) do
  prop.update(title: "Nueva Propiedad", description: "Descripción...")
end

# Access from RealtyAsset
asset = Pwb::RealtyAsset.find(uuid)
asset.prop.title           # Via association to Prop

# Access from Property view
property = Pwb::Property.find(uuid)
property.title             # Delegates to associated Prop
```

### For Refreshing the Materialized View

```ruby
# Automatic (happens after every write via after_commit callbacks)
asset.update!(count_bedrooms: 4)  # View auto-refreshes

# Manual refresh if needed
Pwb::Property.refresh                  # Locks view briefly
Pwb::Property.refresh(concurrently: true)  # No lock (requires unique index)

# Async refresh (if job defined)
Pwb::Property.refresh_async
```

---

## 7. Important Notes

### Pwb::Prop is Still Present but Secondary

- `Pwb::Prop` still exists and is **not deprecated in the codebase yet**
- It's maintained primarily for **translations storage**
- Each `RealtyAsset` has a corresponding `Prop` record (linked via `reference`)
- The `Prop` model can be completely removed once translations are migrated elsewhere

### The Materialized View is Essential

- Removing the materialized view would require application-level JOIN logic
- Frontend searches must use `Pwb::Property`, not the underlying tables
- The view is read-only (writes to underlying tables trigger refreshes)

### Multi-tenancy Scope

- `RealtyAsset` has `website_id` to scope properties to specific websites
- The materialized view includes `website_id` for filtering
- All queries should filter by `website_id` to maintain tenant isolation

### Transaction Support

- Writing property data uses `ActiveRecord::Base.transaction` blocks
- The `after_commit` hooks ensure view refresh happens after transaction commits
- Multiple simultaneous writes are safe (sequential refresh calls don't corrupt data)

---

## 8. Files Reference

### Models
- `/app/models/pwb/realty_asset.rb` - Physical property model (writable)
- `/app/models/pwb/sale_listing.rb` - Sale transaction model (writable)
- `/app/models/pwb/rental_listing.rb` - Rental transaction model (writable)
- `/app/models/pwb/property.rb` - Materialized view model (read-only)
- `/app/models/pwb/prop.rb` - Legacy model (translations storage)

### Migrations
- `db/migrate/20251204180440_create_normalized_property_tables.rb` - Schema creation
- `db/migrate/20251204185426_create_pwb_properties_materialized_view.rb` - View creation
- `db/migrate/20251204205742_add_mobility_translations_columns.rb` - Add JSONB columns
- `db/migrate/20251204205743_migrate_globalize_to_mobility.rb` - Data migration to JSONB

### View Definition
- `/db/views/pwb_properties_v01.sql` - Materialized view SQL

### Controllers
- `/app/controllers/site_admin/props_controller.rb` - Uses Property + RealtyAsset pattern
- `/app/controllers/pwb/props_controller.rb` - Uses Property for reads

### Documentation
- `/docs/architecture/migrations/pwb_props_normalization.md` - Migration guide
- `/docs/architecture/migrations/pwb_props_normalization_walkthrough.md` - Implementation details

---

## 9. Quick Decision Tree

```
Need to READ properties? → Use Pwb::Property
Need to WRITE properties? → Use Pwb::RealtyAsset + SaleListing/RentalListing
Need property TRANSLATIONS? → Use Pwb::Prop (via Mobility)
Need to SEARCH across websites? → Use Pwb::Property with website_id scope
Need FAST queries? → Use Pwb::Property (indexed materialized view)
View seems stale? → Call Pwb::Property.refresh
```

---

**Last Updated**: December 4, 2025  
**Migration Status**: Complete ✅  
**Next Phase**: Testing & Optional Prop Model Removal
