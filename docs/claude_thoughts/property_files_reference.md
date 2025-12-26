# PropertyWebBuilder: Property Model Files - Quick Reference

## Critical Files for Bulk Import/Export Implementation

### Core Property Models

| Model | File | Lines | Purpose |
|-------|------|-------|---------|
| **RealtyAsset** | `/app/models/pwb/realty_asset.rb` | 277 | Physical property (building/land) - PRIMARY MODEL |
| **SaleListing** | `/app/models/pwb/sale_listing.rb` | 71 | Sale transaction data |
| **RentalListing** | `/app/models/pwb/rental_listing.rb` | 83 | Rental transaction data |
| **PropPhoto** | `/app/models/pwb/prop_photo.rb` | 40 | Property images/photos |
| **Feature** | `/app/models/pwb/feature.rb` | 44 | Property amenities/features |
| **ListedProperty** | `/app/models/pwb/listed_property.rb` | 243 | Read-only materialized view |

### Import/Export Services & Utilities

| Service | File | Lines | Purpose |
|---------|------|-------|---------|
| **ImportProperties** | `/app/services/pwb/import_properties.rb` | 51 | CSV/TSV parsing (INCOMPLETE) |
| **ImportMapper** | `/app/services/pwb/import_mapper.rb` | 51 | Maps external fields to PWB fields |
| **ImportSource** | `/app/models/pwb/import_source.rb` | 44 | Static RETS source definitions |
| **ImportMapping** | `/app/models/pwb/import_mapping.rb` | 14 | JSON-based field mapping config |
| **ScraperMapping** | `/app/models/pwb/scraper_mapping.rb` | 14 | Scraper field mappings |

### Controllers

| Controller | File | Purpose |
|-----------|------|---------|
| **PropsController** | `/app/controllers/site_admin/props_controller.rb` | CRUD operations for properties |

### Related Models

| Model | File | Purpose |
|-------|------|---------|
| Website | `/app/models/pwb/website.rb` | Multi-tenancy anchor, subscription limits |
| Address | `/app/models/pwb/address.rb` | Address reference (used by Agency) |

### Import Configuration Files

| Config | File | Purpose |
|--------|------|---------|
| PWB Native API Format | `/config/import_mappings/api_pwb.json` | **BEST FOR BULK IMPORT** |
| InterRealty MLS | `/config/import_mappings/mls_interealty.json` | InterRealty format mapping |
| MRIS MLS | `/config/import_mappings/mls_mris.json` | MRIS format mapping |
| Jon's CSV | `/config/import_mappings/mls_csv_jon.json` | Custom CSV format |
| OLR MLS | `/config/import_mappings/mls_olr.json` | OLR format mapping |

### Database Migrations

| Migration | File | Purpose |
|-----------|------|---------|
| Realty Asset ID Addition | `/db/migrate/20251204181516_add_realty_asset_id_to_related_tables.rb` | Added realty_asset_id to photos/features |
| Translations Addition | `/db/migrate/20251204220001_add_translations_to_listings_and_realty_assets.rb` | Added JSONB translations |
| Slug Addition | `/db/migrate/20251205163544_add_slug_to_realty_assets.rb` | Added slug field |

---

## Key Data Structures

### RealtyAsset Field Groups

**Location Fields:**
- `street_number`, `street_name`, `street_address`
- `city`, `region`, `postal_code`, `country`
- `latitude`, `longitude` (geocoded automatically)
- `slug` (unique URL identifier, auto-generated)

**Property Dimensions:**
- `count_bedrooms` (integer)
- `count_bathrooms` (float)
- `count_garages` (integer)
- `count_toilets` (integer)
- `constructed_area` (float)
- `plot_area` (float)
- `year_construction` (integer)

**Energy/Performance:**
- `energy_rating` (integer)
- `energy_performance` (float)

**Classification:**
- `prop_type_key` (e.g., "property.type.apartment")
- `prop_state_key` (e.g., "property.state.active")
- `prop_origin_key` (data source origin)
- `reference` (external ID)

**Marketing:**
- `title`, `description` (JSONB translations via Mobility)

**Multi-Tenancy:**
- `website_id` (FK to Pwb::Website)

---

## Enumerable/Key Fields

### prop_type_key Format
```
property.type.apartment
property.type.house
property.type.land
property.type.commercial
...
```

### prop_state_key Format
```
property.state.active
property.state.inactive
property.state.sold
property.state.archived
...
```

### Feature Keys
```
property.feature.pool
property.feature.garden
property.feature.garage
property.feature.balcony
property.feature.air_conditioning
...
```

See **FieldKey model** for complete list of valid keys per category.

---

## Import/Export Workflow Elements

### api_pwb.json Mapping (Recommended for Import)

**Key Import Fields:**
```
reference                           → reference (external ID)
price-sale-current-cents            → price_sale_current_cents
price-rental-monthly-current-cents  → price_rental_monthly_current_cents
price-rental-monthly-low-season-cents
price-rental-monthly-high-season-cents
title-en, title-es, ...            → title_<locale>
description-en, description-es, ...→ description_<locale>
for-sale                           → for_sale (creates SaleListing)
for-rent-long-term                 → for_rent_long_term (creates RentalListing)
for-rent-short-term                → for_rent_short_term
constructed-area                   → constructed_area
count-bedrooms, count-bathrooms, etc
property-photos                    → [urls] (should download and attach)
extras                             → [feature_keys] (creates Features)
street-address, city, region, postal-code, country
latitude, longitude
```

Full mapping: `/config/import_mappings/api_pwb.json` (lines 1-162)

---

## Method Signatures for Import Implementation

### RealtyAsset Key Methods
```ruby
RealtyAsset.new(attributes)       # Create instance
.save                             # Persist
.geocode                          # Auto-geocode from address
.generate_slug                    # Auto-generate slug
.ensure_slug_uniqueness           # Ensure unique slug
.within_subscription_property_limit # Validate against limits

# Associations
.sale_listings.first_or_initialize    # Get/create sale listing
.rental_listings.first_or_initialize  # Get/create rental listing
.prop_photos.build(attributes)        # Create photo
.features.find_or_create_by(feature_key: key)  # Create feature
```

### SaleListing Key Methods
```ruby
SaleListing.new(realty_asset: asset, attributes)
.save
.monetize :price_sale_current_cents  # Handle currency conversion
.update!(attributes)  # Update with validation
```

### RentalListing Key Methods
```ruby
RentalListing.new(realty_asset: asset, attributes)
.save
.monetize :price_rental_monthly_current_cents
.update!(attributes)
```

### PropPhoto Key Methods
```ruby
PropPhoto.new(realty_asset: asset, sort_order: 1)
.image.attach(file)  # ActiveStorage attachment
.save
```

### Feature Key Methods
```ruby
Feature.find_or_create_by(realty_asset: asset, feature_key: key)
```

### ImportMapper Key Methods
```ruby
mapper = ImportMapper.new("api_pwb")  # Load mapping
mapped = mapper.map_property(row)     # Map external data → PWB fields
```

---

## Database Connection Points

### Create Property Flow
```ruby
ActiveRecord::Base.transaction do
  asset = RealtyAsset.create!(asset_params)
  asset.sale_listings.create!(sale_params) if sale_params.present?
  asset.rental_listings.create!(rental_params) if rental_params.present?
  asset.features.create!(feature_params) if feature_params.present?
  asset.prop_photos.each { |photo| photo.image.attach(file) }
end

Pwb::ListedProperty.refresh  # Update materialized view
```

### Update Property Flow
```ruby
asset = RealtyAsset.find(id)
asset.update!(asset_params)
asset.sale_listings.first_or_initialize.update!(sale_params)
asset.rental_listings.first_or_initialize.update!(rental_params)
# Refresh on after_commit hook
```

### Read Property Flow
```ruby
# For listing/search (use ListedProperty)
properties = Pwb::ListedProperty.where(website_id: website.id)

# For single property details (can use either, but ListedProperty is read-only)
property = Pwb::ListedProperty.find(id)
realty_asset = property.realty_asset  # Get writable version
```

---

## Important Constraints & Validations

### Unique Constraints
```sql
-- Only one active sale listing per property
UNIQUE (realty_asset_id, active) WHERE active = true

-- Only one active rental listing per property
UNIQUE (realty_asset_id, active) WHERE active = true

-- Only one slug in system
UNIQUE (slug)
```

### Required Fields
```
RealtyAsset:
  - slug (auto-generated, must be unique)

SaleListing:
  - realty_asset_id

RentalListing:
  - realty_asset_id
```

### Validations (from models)
```ruby
validates :slug, presence: true, uniqueness: true
validate :within_subscription_property_limit  # Checks website.can_add_property?
```

---

## Important Notes for Implementation

1. **Always use transactions** when creating asset + listings together
2. **slug is auto-generated** from address/reference, ensure uniqueness
3. **website_id is required** for multi-tenancy scoping
4. **ListedProperty must be refreshed** after bulk creates
5. **Only one SaleListing can be active** per RealtyAsset (archive others)
6. **Only one RentalListing can be active** per RealtyAsset (archive others)
7. **Features** require feature_key from FieldKey system
8. **Images** require ActiveStorage and may need external URL download
9. **Translations** use Mobility gem (title_en, description_es, etc.)
10. **Subscription limits** enforced via website.property_limit validation

---

## Quick File Dependency Chart

```
RealtyAsset (core model)
  ├── belongs_to Website
  ├── has_many SaleListing
  ├── has_many RentalListing
  ├── has_many PropPhoto
  └── has_many Feature

SaleListing
  ├── belongs_to RealtyAsset
  └── delegates to RealtyAsset (reference, website, etc.)

RentalListing
  ├── belongs_to RealtyAsset
  └── delegates to RealtyAsset

PropPhoto
  ├── belongs_to RealtyAsset (or Prop for legacy)
  └── has_one_attached :image (ActiveStorage)

Feature
  ├── belongs_to RealtyAsset (or Prop for legacy)
  └── belongs_to FieldKey (via feature_key)

ListedProperty (view)
  ├── read-only view of RealtyAsset + Sales/Rentals combined
  └── includes PropPhotos and Features via associations

ImportProperties (service)
  └── uses ImportMapper

ImportMapper (service)
  └── loads ImportMapping (JSON files)

Website (tenant)
  ├── has_many RealtyAsset
  └── subscription/limit rules
```

---

## Development Checklist for Bulk Import

- [ ] Extend ImportProperties service
- [ ] Create BulkImporter orchestrator
- [ ] Create PropertyBuilder for atomic creation
- [ ] Implement image download/attach
- [ ] Add feature mapping
- [ ] Handle sale/rental listing creation
- [ ] Add bulk import controller actions
- [ ] Create async job (Sidekiq/SolidQueue)
- [ ] Add error tracking and logging
- [ ] User notification system
- [ ] Write comprehensive specs
- [ ] Document CSV/JSON format
- [ ] Create export service
- [ ] Add export controller actions
- [ ] Handle multi-locale fields
- [ ] Validate against subscription limits
