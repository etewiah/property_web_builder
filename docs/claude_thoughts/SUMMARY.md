# PropertyWebBuilder Property Model Exploration - SUMMARY

## What I Found

I've completed a comprehensive exploration of the PropertyWebBuilder codebase to understand the property model architecture and existing import/export functionality. Three detailed analysis documents have been created in `/docs/claude_thoughts/`:

1. **property_model_analysis.md** - Complete model architecture and design patterns
2. **property_files_reference.md** - Quick reference guide for all relevant files
3. **property_schema_diagram.md** - Database schema and ER diagrams

---

## Key Findings

### 1. Property Model Architecture: Normalized Design

PropertyWebBuilder uses a **normalized, multi-model architecture** separating physical property data from transaction data:

```
RealtyAsset (Physical Property)
  ├── SaleListing (Sale transaction - price, marketing text)
  ├── RentalListing (Rental transaction - seasonal pricing, rental type)
  ├── PropPhoto (Images/gallery)
  └── Feature (Amenities/features)

ListedProperty (Materialized View for read optimization)
```

**This design allows:**
- One property listed for both sale AND rent simultaneously
- Multiple historical listings (archived versions)
- Clean separation of physical data from marketing/transaction data

### 2. RealtyAsset Model Structure

**Primary Key:** UUID  
**Tenant Scoped:** By website_id

**Key Field Groups:**
- **Location:** street_address, city, region, postal_code, country, latitude, longitude, slug
- **Dimensions:** count_bedrooms, count_bathrooms, count_garages, count_toilets, constructed_area, plot_area, year_construction
- **Energy:** energy_rating, energy_performance
- **Classification:** prop_type_key, prop_state_key, prop_origin_key, reference
- **Marketing:** title, description (JSONB translations via Mobility)
- **Auto-Generated:** slug (unique, from address/reference), geocoding (lat/lng)

**Associations:**
```ruby
has_many :sale_listings
has_many :rental_listings  
has_many :prop_photos
has_many :features
belongs_to :website (optional)
```

### 3. SaleListing & RentalListing Models

Both are **transaction models** (not physical property):

**SaleListing:**
- price_sale_current_cents, commission
- title, description, seo_title, meta_description (multi-locale)
- visible, highlighted, archived, reserved, furnished, noindex
- Unique constraint: only 1 active per RealtyAsset

**RentalListing:**
- price_rental_monthly_current (with low/high season variants)
- for_rent_short_term, for_rent_long_term
- title, description, seo_title, meta_description (multi-locale)
- visible, highlighted, archived, reserved, furnished, noindex
- Unique constraint: only 1 active per RealtyAsset

Both inherit website scoping through RealtyAsset and delegate common fields to it.

### 4. PropPhoto Model

- Stores images with sort_order for gallery ordering
- Supports both ActiveStorage (normal mode) and external URLs (external_image_mode)
- Has optional sort_order for predictable display order
- Supports legacy prop_id and new realty_asset_id

### 5. Feature Model

- Represents amenities/features (pool, garden, garage, etc.)
- feature_key references FieldKey system for localization
- No direct website_id (inherits through RealtyAsset)
- Used for filtering and display

### 6. ListedProperty (Materialized View)

- Read-only denormalized view combining RealtyAsset + Listings
- Optimized for search queries and property listings
- Includes combined fields (for_sale boolean, combined visible, etc.)
- Must call `Pwb::ListedProperty.refresh` after creating/updating properties
- Used by PropsController index/show actions

---

## Existing Import/Export Functionality (Partial)

### What Exists:

1. **ImportProperties Service** (`/app/services/pwb/import_properties.rb`)
   - Methods: `import_csv`, `import_mls_tsv`
   - **Status:** Incomplete - only parsing, no actual property creation
   - **Limitations:** No images, features, or transaction data handling

2. **ImportMapper Service** (`/app/services/pwb/import_mapper.rb`)
   - Maps external data fields to PWB fields
   - Uses JSON configuration files for mapping definitions
   - Handles direct and nested field mappings
   - Applies defaults if fields are empty

3. **Import Mappings** (`/config/import_mappings/*.json`)
   - 5 predefined mappings: api_pwb, mls_interealty, mls_mris, mls_csv_jon, mls_olr
   - **Recommended for bulk import:** `api_pwb.json` (PWB native format)
   - Each mapping defines: source field → target field + default value

4. **PropsController** (`/app/controllers/site_admin/props_controller.rb`)
   - Has photo upload/management methods
   - Handles feature sync, sale/rental listing updates
   - No bulk import UI or CSV handling

### What's Missing:

- **No actual property creation** from CSV/imported data
- **No image download/attachment** from URLs
- **No feature/amenity import** handling
- **No transaction data creation** (SaleListing/RentalListing)
- **No export functionality** (no CSV/JSON export of properties)
- **No batch operation support** (progress tracking, error recovery)
- **No duplicate detection** or merge logic
- **No custom mapping UI** (mappings are hardcoded JSON files)
- **No subscription limit enforcement** during bulk import
- **No async job support** (would be needed for large batches)

---

## Database Schema Overview

### Core Tables:

| Table | Type | PK | Key Fields | Constraints |
|-------|------|----|----|-----------|
| pwb_realty_assets | Physical Property | UUID | location, dimensions, classification | unique(slug), fk(website_id) |
| pwb_sale_listings | Sale Transaction | UUID | price, title, visible | unique(realty_asset_id, active) where active |
| pwb_rental_listings | Rental Transaction | UUID | seasonal prices, rental type | unique(realty_asset_id, active) where active |
| pwb_prop_photos | Images | INT | image, sort_order, external_url | fk(realty_asset_id) |
| pwb_features | Amenities | INT | feature_key | fk(realty_asset_id), unique(asset_id, key) |
| pwb_properties | Materialized View | UUID | combined data (RO) | indices for search |

**Multi-Tenancy:** All tables filtered by website_id (directly or through RealtyAsset)

**Internationalization:** SaleListing/RentalListing have JSONB translations column for multi-locale support

---

## Import/Export Strategy

### For Bulk Import:

1. **Extend ImportProperties Service**
   - Handle complete property creation (not just parsing)
   - Create RealtyAsset + optional SaleListing/RentalListing in transaction

2. **Create BulkImporter Service**
   - Orchestrates the import process
   - Uses ImportMapper for field mapping
   - Creates properties atomically (all-or-nothing per row)
   - Downloads and attaches images
   - Creates features from array

3. **Create PropertyBuilder Service**
   - Builds RealtyAsset + Listings + Features from mapped hash
   - Handles validation and error reporting
   - Respects subscription limits

4. **Add Controller Actions**
   - GET/POST for import form + file upload
   - Start async job (Sidekiq/SolidQueue)
   - Progress tracking and completion notification

5. **Create Async Job**
   - Process bulk import in background
   - Track progress and errors
   - Refresh materialized view when complete

### For Export:

1. **Create BulkExporter Service**
   - Serialize RealtyAsset + Listings + Features + Photos
   - Support CSV, JSON, XML formats
   - Include filtering (by date, type, status)

2. **Add Export Controller Actions**
   - GET for export options form
   - POST to generate and download file

---

## Files to Reference

**Absolute Paths for Implementation:**

```
Core Models:
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/realty_asset.rb (277 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/sale_listing.rb (71 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/rental_listing.rb (83 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/prop_photo.rb (40 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/feature.rb (44 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/listed_property.rb (243 lines)

Import Services:
  /Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_properties.rb (51 lines)
  /Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/import_mapper.rb (51 lines)

Controller (Reference for structure):
  /Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/props_controller.rb (280 lines)

Import Mappings:
  /Users/etewiah/dev/sites-older/property_web_builder/config/import_mappings/api_pwb.json (162 lines, RECOMMENDED)
  /Users/etewiah/dev/sites-older/property_web_builder/config/import_mappings/mls_olr.json

Models & Config:
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/import_mapping.rb
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/import_source.rb
  /Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb
```

---

## Key Implementation Tips

1. **Use Transactions:** Wrap RealtyAsset + SaleListing + RentalListing creation in `ActiveRecord::Base.transaction`

2. **Handle Slug Conflicts:** Slug is auto-generated and must be unique; the model handles uniqueness with counters

3. **Validate Subscription Limits:** Check `website.can_add_property?` before creating

4. **Refresh Materialized View:** Call `Pwb::ListedProperty.refresh` after bulk creates

5. **Multi-Locale Support:** Use Mobility gem accessors (title_en, description_es) for setting translations

6. **Image Handling:** Either upload files or use external URLs (if external_image_mode enabled)

7. **Feature Mapping:** feature_key must exist in FieldKey system; use feature lookups

8. **Active Listing Uniqueness:** Only one SaleListing/RentalListing can be active per asset; archive old ones if updating

9. **Tenant Scoping:** Always filter by website_id in queries

10. **Error Recovery:** Log detailed error info (row number, field, value) for user feedback

---

## Next Steps for Implementation

The foundation is in place. To implement bulk import/export:

1. **Phase 1 - Core Import:**
   - Extend ImportProperties with property creation logic
   - Create PropertyBuilder for atomic asset + listing creation
   - Add image download/attachment support
   - Write tests

2. **Phase 2 - UI & Async:**
   - Add import form and controller actions
   - Create Sidekiq/SolidQueue job
   - Add progress tracking

3. **Phase 3 - Export:**
   - Create BulkExporter service
   - Add export controller actions
   - Support CSV/JSON formats

4. **Phase 4 - Polish:**
   - Duplicate detection/merge
   - Custom mapping UI
   - Validation and error messages
   - Documentation

---

## Documentation Location

Three comprehensive documents created in `/docs/claude_thoughts/`:

1. **property_model_analysis.md** - 500+ line detailed analysis
2. **property_files_reference.md** - Quick reference and signatures
3. **property_schema_diagram.md** - ER diagrams and schema details

These documents provide everything needed to implement bulk import/export functionality.
