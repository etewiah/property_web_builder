# PropertyWebBuilder: Property Model Architecture & Import/Export Analysis

## Overview

PropertyWebBuilder uses a **normalized, multi-model architecture** for properties:
- **RealtyAsset** - Physical property data (the "building itself")
- **SaleListing** - Sale transaction data (for properties being sold)
- **RentalListing** - Rental transaction data (for properties being rented)
- **PropPhoto** - Property images
- **Feature** - Property features/amenities
- **ListedProperty** - Read-only materialized view (denormalized for queries)

This design separates the physical property (RealtyAsset) from transaction data (Listings), allowing one property to be listed for both sale and rent simultaneously.

---

## 1. Core Property Models

### 1.1 RealtyAsset (Physical Property)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/realty_asset.rb`

**Table:** `pwb_realty_assets` (UUID primary key)

**Key Fields:**
```
Physical Location:
  - street_number, street_name, street_address
  - city, region, postal_code, country
  - latitude, longitude (geocoded)
  - slug (unique, URL-friendly identifier)

Building Characteristics:
  - title, description (JSON translations via Mobility)
  - constructed_area (float, in sqm or sqft)
  - plot_area (float)
  - count_bedrooms (integer)
  - count_bathrooms (float)
  - count_garages (integer)
  - count_toilets (integer)
  - year_construction (integer)
  - energy_rating, energy_performance

Classification:
  - reference (external property ID)
  - prop_type_key (e.g., "property.type.apartment")
  - prop_state_key (e.g., "property.state.active")
  - prop_origin_key (data source origin)

Multi-tenancy:
  - website_id (tenant scoping)

Metadata:
  - translations (JSONB, Mobility translations)
  - created_at, updated_at
```

**Key Associations:**
```ruby
has_many :sale_listings
has_many :rental_listings
has_many :prop_photos
has_many :features
belongs_to :website (optional)
```

**Key Methods:**
```ruby
# Listing Status
for_sale?           # Check if has active sale listing
for_rent?           # Check if has active rental listing
visible?            # for_sale? || for_rent?
active_sale_listing # Get the single active sale listing
active_rental_listing # Get the single active rental listing

# Features
get_features        # Returns hash of {feature_key => true}
set_features=       # Set features from hash

# Photos
ordered_photo(n)    # Get nth photo
primary_image_url   # URL to first photo

# Display
price               # Returns formatted price from listings
location, geocodeable_address  # Formatted address strings
bedrooms, bathrooms, surface_area  # Aliases for counts
```

**Validations & Callbacks:**
```ruby
# Validations
validates :slug, presence: true, uniqueness: true
validate :within_subscription_property_limit (on create)

# Callbacks
before_validation :generate_slug (on create)
before_validation :ensure_slug_uniqueness
after_commit :refresh_properties_view  # Updates materialized view
```

---

### 1.2 SaleListing (Sale Transaction)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/sale_listing.rb`

**Table:** `pwb_sale_listings` (UUID primary key)

**Key Fields:**
```
Pricing:
  - price_sale_current_cents, price_sale_current_currency
  - commission_cents, commission_currency

Marketing:
  - title_*, description_* (multi-locale via Mobility)
  - seo_title_*, meta_description_* (SEO fields, multi-locale)
  - visible (boolean)
  - highlighted (boolean)

Status:
  - active (boolean, unique constraint: only one per realty_asset)
  - archived (boolean)
  - reserved (boolean)
  - furnished (boolean)

Other:
  - reference (override reference from asset)
  - realty_asset_id (FK to parent property)
  - noindex (boolean, for SEO)
```

**Key Associations:**
```ruby
belongs_to :realty_asset
# Delegates to realty_asset:
delegate :reference, :website, :website_id,
         :count_bedrooms, :count_bathrooms, 
         :street_address, :city,
         :prop_photos, :features
```

**Key Includes:**
```ruby
include ListingStateable         # Manages active/archived states
include SeoValidatable          # SEO field validation
include RefreshesPropertiesView  # Updates materialized view
include NtfyListingNotifications # Notification support
```

---

### 1.3 RentalListing (Rental Transaction)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/rental_listing.rb`

**Table:** `pwb_rental_listings` (UUID primary key)

**Key Fields:**
```
Pricing (3 seasonal tiers):
  - price_rental_monthly_current_cents, price_rental_monthly_current_currency
  - price_rental_monthly_low_season_cents
  - price_rental_monthly_high_season_cents

Rental-Specific:
  - for_rent_short_term (boolean, vacation rentals)
  - for_rent_long_term (boolean)
  - furnished (boolean)

Marketing:
  - title_*, description_* (multi-locale via Mobility)
  - seo_title_*, meta_description_* (SEO fields)
  - visible (boolean)
  - highlighted (boolean)

Status:
  - active (boolean, unique constraint: only one per realty_asset)
  - archived (boolean)
  - reserved (boolean)

Other:
  - realty_asset_id (FK to parent property)
  - noindex (boolean)
```

**Key Methods:**
```ruby
vacation_rental?  # Returns for_rent_short_term?
```

**Scopes:**
```ruby
scope :for_rent_short_term  # Vacation rentals
scope :for_rent_long_term   # Long-term rentals
```

---

### 1.4 PropPhoto (Property Images)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/prop_photo.rb`

**Table:** `pwb_prop_photos` (integer primary key)

**Key Fields:**
```
- image (ActiveStorage attachment)
- external_url (for external image mode)
- description (text)
- sort_order (integer, for ordering)
- file_size (integer)

Foreign Keys (supports both old & new architecture):
  - prop_id (legacy, for old Pwb::Prop)
  - realty_asset_id (new, for Pwb::RealtyAsset)
```

**Key Associations:**
```ruby
has_one_attached :image
belongs_to :prop (optional)
belongs_to :realty_asset (optional)
```

**Features:**
- External image mode support (configurable via website.external_image_mode)
- Ordered by sort_order for predictable gallery display

---

### 1.5 Feature (Property Amenities)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/feature.rb`

**Table:** `pwb_features` (integer primary key)

**Key Fields:**
```
- feature_key (string, e.g., "property.feature.pool")
- prop_id (legacy)
- realty_asset_id (new)
```

**Associations:**
```ruby
belongs_to :prop (optional)
belongs_to :realty_asset (optional)
belongs_to :feature_field_key, 
           class_name: 'Pwb::FieldKey',
           foreign_key: :feature_key,
           primary_key: :global_key
```

**Notes:**
- No website_id column - inherits tenancy through parent property
- Features are localized via FieldKey translations
- Use PwbTenant::Feature for web requests (tenant-scoped)

---

### 1.6 ListedProperty (Materialized View)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/listed_property.rb`

**Table:** `pwb_properties` (denormalized, read-only view)

**Purpose:** Optimized, query-friendly view combining:
- RealtyAsset physical data
- SaleListing sale transaction data
- RentalListing rental transaction data

**Key Fields (combined from all sources):**
```
From RealtyAsset:
  - id (realty_asset_id)
  - street_address, city, region, postal_code, country
  - latitude, longitude
  - count_bedrooms, count_bathrooms, count_garages, count_toilets
  - constructed_area, plot_area
  - year_construction, energy_rating, energy_performance
  - slug, reference
  - prop_type_key, prop_state_key, prop_origin_key
  - website_id

From SaleListing (if exists):
  - for_sale (boolean)
  - sale_listing_id
  - price_sale_current_cents, price_sale_current_currency
  - commission_cents, commission_currency
  - sale_furnished, sale_highlighted, sale_reserved

From RentalListing (if exists):
  - for_rent (boolean)
  - for_rent_short_term, for_rent_long_term
  - rental_listing_id
  - price_rental_monthly_current_cents, price_rental_monthly_current_currency
  - price_rental_monthly_low_season_cents, price_rental_monthly_high_season_cents
  - rental_furnished, rental_highlighted, rental_reserved
```

**Key Methods:**
```ruby
# Read-only protection
readonly?  # Always returns true

# Underlying model access
realty_asset        # Fetch the RealtyAsset
sale_listing        # Fetch the SaleListing (if exists)
rental_listing      # Fetch the RentalListing (if exists)

# View refresh
self.refresh        # Refresh materialized view (concurrently: true)
self.refresh_async  # Async refresh via job (if available)
```

**Usage Pattern:**
- Use ListedProperty for **reads** (index, show, search)
- Use RealtyAsset for **writes** (create, update)

---

## 2. Related Models

### 2.1 Website (Multi-Tenancy Anchor)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb`

**Key Fields for Properties:**
```
default_currency (string, default: "EUR")
default_area_unit (enum: sqmt/sqft)
external_image_mode (boolean)  # Use external URLs instead of uploads

Configuration JSON:
  - imports_config
  - search_config_buy, search_config_rent, search_config_landing
  - style_variables_for_theme

Subscription/Limits:
  - subscription data (via concern)
  - property_limit (from subscription)
  - can_add_property? (method)
```

---

## 3. Existing Import/Export Functionality

### 3.1 ImportProperties Service

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_properties.rb`

**Current State:** Partial, CSV-focused implementation

**Methods:**
```ruby
def import_csv
  # Reads CSV with headers: title_en, title_es, etc.
  # Returns array of parsed property hashes
  # TODO: More robust validation

def import_mls_tsv
  # Reads MLS-format TSV (tab-separated)
  # Uses ImportMapper to map MLS fields to PWB fields
  # Returns array of mapped property hashes
```

**Limitations:**
- No actual property creation (just parsing)
- No image/photo handling
- No feature import
- No transaction data (sale/rental listing) handling
- Comments indicate this is a work-in-progress

---

### 3.2 ImportMapper Service

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_mapper.rb`

**Purpose:** Maps external data formats to PWB fields

**How It Works:**
1. Loads import mapping from JSON config files
2. Maps direct fields: MLS field → PWB field
3. Handles nested mappings: nested_key → flattened fields
4. Applies defaults if field is empty

**Mapping Structure:**
```json
{
  "name": "mapping_identifier",
  "mappings": {
    "ExternalField": {
      "fieldName": "pwb_field",
      "default": default_value
    }
  },
  "nested_mappings": {
    "key": "ParentFieldName",
    "mappings": { ... }
  }
}
```

---

### 3.3 Import Configuration Files

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/config/import_mappings/`

**Available Mappings:**
1. **mls_interealty.json** - InterRealty MLS format
2. **mls_mris.json** - MRIS MLS format
3. **mls_csv_jon.json** - Jon's custom CSV format
4. **mls_olr.json** - OLR MLS format
5. **api_pwb.json** - Native PWB API format

**Example: api_pwb.json**
```json
{
  "name": "api_pwb",
  "mappings": {
    "reference": { "fieldName": "reference", "default": null },
    "price-sale-current-cents": { "fieldName": "price_sale_current_cents", "default": 0 },
    "count-bedrooms": { "fieldName": "count_bedrooms", "default": 0 },
    "constructed-area": { "fieldName": "constructed_area", "default": "" },
    "property-photos": { "fieldName": "property_photos", "default": [] },
    "extras": { "fieldName": "extras", "default": [] },
    "title-en": { "fieldName": "title_en", "default": "" },
    "description-en": { "fieldName": "description_en", "default": "" },
    "for-sale": { "fieldName": "for_sale", "default": 0 },
    "for-rent-long-term": { "fieldName": "for_rent_long_term", "default": 0 },
    "for-rent-short-term": { "fieldName": "for_rent_short_term", "default": 0 },
    ...
  }
}
```

---

### 3.4 ImportSource & ImportMapping Models

**ImportSource** (`active_hash` base, static data):
- RETS sources (MRIS, InterRealty)
- Each source has login details, version, import mapper name

**ImportMapping** (`active_json` base, JSON files):
- Multi-file support
- Loads from `config/import_mappings/*.json`
- Used by ImportMapper service

---

### 3.5 PropsController - Photo Upload/Import

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/props_controller.rb`

**Relevant Methods:**
```ruby
def upload_photos
  # Handle external URLs (if external_image_mode)
  # Handle file uploads
  # Create PropPhoto records with sort_order

def remove_photo
  # Delete a specific photo

def reorder_photos
  # Update sort_order for multiple photos
```

**Relevant Update Params:**
```ruby
def asset_params
  # Fields from RealtyAsset

def sale_listing_params
  # Fields from SaleListing (including title/description/seo fields for all locales)

def rental_listing_params
  # Fields from RentalListing (including title/description/seo fields for all locales)

def update_features(features_param)
  # Sync features based on selected feature_keys
```

---

## 4. Database Schema Overview

### Key Tables

```sql
pwb_realty_assets
  - id (uuid, PK)
  - website_id (FK)
  - reference, slug
  - street_address, city, region, postal_code, country
  - latitude, longitude
  - count_bedrooms, count_bathrooms, count_garages, count_toilets
  - constructed_area, plot_area, year_construction
  - energy_rating, energy_performance
  - prop_type_key, prop_state_key, prop_origin_key
  - title, description (JSONB translations)
  - created_at, updated_at
  - Indexes: slug (unique), website_id, prop_type_key, translations (gin)

pwb_sale_listings
  - id (uuid, PK)
  - realty_asset_id (FK, uuid)
  - price_sale_current_cents, price_sale_current_currency
  - commission_cents, commission_currency
  - active, archived, reserved, furnished, highlighted
  - visible, noindex
  - reference (optional override)
  - title, description, seo_title, meta_description (JSONB translations)
  - created_at, updated_at
  - Unique Index: (realty_asset_id, active) where active=true

pwb_rental_listings
  - id (uuid, PK)
  - realty_asset_id (FK, uuid)
  - price_rental_monthly_current_cents, currency
  - price_rental_monthly_high_season_cents
  - price_rental_monthly_low_season_cents
  - for_rent_short_term, for_rent_long_term
  - active, archived, reserved, furnished, highlighted
  - visible, noindex
  - reference (optional override)
  - title, description, seo_title, meta_description (JSONB translations)
  - created_at, updated_at
  - Unique Index: (realty_asset_id, active) where active=true

pwb_prop_photos
  - id (integer, PK)
  - realty_asset_id (FK, uuid)
  - prop_id (FK, integer, legacy)
  - image (string, ActiveStorage attachment key)
  - external_url (string)
  - description, sort_order
  - file_size, folder
  - created_at, updated_at

pwb_features
  - id (integer, PK)
  - realty_asset_id (FK, uuid)
  - prop_id (FK, integer, legacy)
  - feature_key (string)
  - created_at, updated_at
  - Indexes: feature_key, realty_asset_id, (realty_asset_id, feature_key)

pwb_properties (Materialized View)
  - Denormalized view combining all three models
  - Used for optimized property listing/search queries
  - Read-only (INSTEAD OF triggers handle updates)
```

---

## 5. Data Relationships & Constraints

### Property Hierarchy:
```
RealtyAsset (physical property)
  ├── SaleListing (0-1 active, multiple archived)
  ├── RentalListing (0-1 active, multiple archived)
  ├── PropPhoto (0-many, ordered)
  └── Feature (0-many, keyed)
```

### Multi-Tenancy:
- RealtyAsset has `website_id` (scoped)
- SaleListing/RentalListing inherit tenancy through RealtyAsset
- PropPhoto/Feature inherit tenancy through RealtyAsset
- ListedProperty queries filtered by website_id

### Listing Uniqueness:
- Only **one** SaleListing can be `active=true` per RealtyAsset (unique constraint)
- Only **one** RentalListing can be `active=true` per RealtyAsset (unique constraint)
- Multiple listings can be archived (historical/draft versions)

### Multi-Locale Support:
- RealtyAsset: title, description (translations JSONB)
- SaleListing: title, description, seo_title, meta_description (all locales)
- RentalListing: title, description, seo_title, meta_description (all locales)
- Uses Mobility gem for easy access: `sale_listing.title_en`, `rental_listing.title_es`

---

## 6. Current Import/Export Gaps

### What's Missing for Bulk Import:

1. **Complete CSV Import**
   - Only parsing, no actual property creation
   - No nested transaction data handling (sale/rental listings)
   - No feature/amenity handling
   - No image URL/file import

2. **Export Functionality**
   - No property export (CSV, JSON, etc.)
   - No bulk download/extract features

3. **Batch Operations**
   - No transaction wrapper for atomic imports
   - No error recovery/partial import handling
   - No progress tracking
   - No duplicate detection/merge logic

4. **Image Handling**
   - No batch photo download from URLs
   - No photo URL validation
   - Limited external image mode support

5. **Mapping**
   - Hardcoded mappings in JSON files
   - No UI to create custom mappings
   - No validation of mapping targets

6. **Validation**
   - Minimal field validation during import
   - No required field checking
   - No subscription limit enforcement during bulk

---

## 7. Implementation Strategy for Bulk Import/Export

### For Import:

1. **Create ImportJob/Service** (Sidekiq or SolidQueue)
   - Accept CSV/JSON file
   - Use existing ImportMapper for field mapping
   - Create RealtyAsset + optional SaleListing/RentalListing in transaction
   - Handle features array
   - Download and attach images
   - Track progress/errors
   - Notify on completion

2. **Create ExportService**
   - Serialize RealtyAsset + listings + features + photo URLs
   - Support CSV, JSON, XML formats
   - Include filtering by date, type, status
   - Generate downloadable file

3. **Add Controller Actions**
   - `GET /site_admin/props/import` - Show upload form
   - `POST /site_admin/props/import` - Handle file upload, start job
   - `GET /site_admin/props/export` - Show export options form
   - `POST /site_admin/props/export` - Generate & download file

4. **Key Classes to Create**
   - `Pwb::BulkImporter` - Orchestrates import process
   - `Pwb::BulkExporter` - Orchestrates export process
   - `Pwb::PropertyBuilder` - Creates property + listings from hash
   - `Pwb::PhotoDownloader` - Downloads and attaches images
   - `BulkPropertyJob` - Sidekiq/SolidQueue async job

### Data Flow for Import:

```
CSV File Upload
  ↓
Parse CSV (ImportProperties.import_csv)
  ↓
For each row:
  - Map fields (ImportMapper.map_property)
  - Create RealtyAsset with valid fields
  - Create SaleListing if price/for_sale present
  - Create RentalListing if rental prices/for_rent_* present
  - Create Features from extras array
  - Download & attach PropPhotos from URLs
  - Log errors/skipped rows
  ↓
Refresh ListedProperty materialized view
  ↓
Notify user of results
```

---

## 8. File Structure Summary

### Core Models:
```
/app/models/pwb/
  ├── realty_asset.rb          # Physical property
  ├── sale_listing.rb          # Sale transaction
  ├── rental_listing.rb        # Rental transaction
  ├── prop_photo.rb            # Images
  ├── feature.rb               # Amenities
  ├── listed_property.rb       # Read-only view
  └── website.rb               # Tenant anchor

/app/models/pwb/
  ├── import_source.rb         # Static import source definitions
  ├── import_mapping.rb        # JSON-based field mappings
  └── scraper_mapping.rb       # Scraper field mappings
```

### Services:
```
/app/services/pwb/
  ├── import_properties.rb     # CSV/TSV parsing (partial)
  └── import_mapper.rb         # Field mapping orchestration
```

### Controllers:
```
/app/controllers/site_admin/
  └── props_controller.rb      # Property CRUD + photo management
```

### Configuration:
```
/config/import_mappings/
  ├── api_pwb.json            # Native PWB format
  ├── mls_interealty.json      # InterRealty MLS
  ├── mls_mris.json           # MRIS MLS
  ├── mls_csv_jon.json        # Jon's CSV format
  └── mls_olr.json            # OLR MLS format
```

### Database:
```
/db/migrate/
  ├── 20251204181516_add_realty_asset_id_to_related_tables.rb
  ├── 20251204220001_add_translations_to_listings_and_realty_assets.rb
  └── 20251205163544_add_slug_to_realty_assets.rb
```

---

## 9. Key Implementation Considerations

### Transaction Handling:
- Use `ActiveRecord::Base.transaction` for atomic imports
- Validate full property before creation (realty_asset + listings)
- Rollback on error

### Multi-Locale Support:
- Map import fields to specific locales (e.g., title → title_en, description_es)
- Use Mobility accessors for setting translations
- Validate against available locales

### Subscription Limits:
- Check `website.can_add_property?` before bulk import
- Batch size may need to respect limits
- Show user how many can be imported

### Materialized View:
- Call `Pwb::ListedProperty.refresh` after bulk operations
- Consider async refresh for large imports (performance)
- Or refresh per transaction for faster search availability

### Image Handling:
- Download from external URLs (if provided)
- Attach via ActiveStorage
- Handle failures gracefully (skip image, log error)
- Respect external_image_mode flag

### Error Handling:
- Log detailed errors (row number, field, value)
- Provide user-friendly summary
- Consider partial import (skip bad rows vs. all-or-nothing)

### Duplicate Detection:
- Check for existing properties by reference + website_id
- Allow update vs. skip vs. error options
- Handle slug conflicts

---

## Summary Table

| Model | Table | Key Fields | Purpose |
|-------|-------|-----------|---------|
| RealtyAsset | pwb_realty_assets | Location, dimensions, classification | Physical property core data |
| SaleListing | pwb_sale_listings | Price, title, visibility | Sale transaction data |
| RentalListing | pwb_rental_listings | Seasonal prices, rental type | Rental transaction data |
| PropPhoto | pwb_prop_photos | Image, sort_order, external_url | Property images |
| Feature | pwb_features | feature_key | Property amenities |
| ListedProperty | pwb_properties | Denormalized combo | Query-optimized view |

---

## Next Steps for Implementation

1. Extend `Pwb::ImportProperties` to handle full property creation
2. Create `Pwb::BulkImporter` service for orchestration
3. Create `Pwb::PropertyBuilder` to create asset + listings atomically
4. Add image download/attach functionality
5. Create export service with CSV/JSON support
6. Add controller actions for import/export forms
7. Create async job for bulk operations
8. Add error tracking and user notifications
9. Write specs for import/export with sample data
10. Document CSV format and mapping requirements
