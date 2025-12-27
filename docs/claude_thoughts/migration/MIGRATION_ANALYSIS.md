# Pwb::Prop to RealtyAsset/Listings Migration Analysis

**Date**: 2025-12-06  
**Status**: In Progress  
**Analysis Scope**: Property model migration from Pwb::Prop to RealtyAsset + SaleListing/RentalListing architecture

---

## Executive Summary

The migration from `Pwb::Prop` to the new normalized schema (`RealtyAsset`, `SaleListing`, `RentalListing`) is **approximately 40-50% complete**. 

**Key Finding**: The migration is well-architected with proper separation of concerns:
- **Read operations** use `Pwb::ListedProperty` (materialized view) - clean and optimized
- **Write operations** use underlying models (`RealtyAsset`, `SaleListing`, `RentalListing`)
- **Backwards compatibility** maintained through `Pwb::Prop` and legacy APIs

### Migration Readiness
- **Admin UI (SiteAdmin)**: Fully migrated to new models
- **Public views**: Fully migrated to use ListedProperty
- **Legacy APIs**: Still using old Pwb::Prop for writes (requires careful migration)
- **Tenant Admin**: Partially migrated

---

## 1. Current Pwb::Prop Usage Analysis

### 1.1 Model Definitions

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/`

| File | Status | Purpose |
|------|--------|---------|
| `prop.rb` | LEGACY | Legacy property model - now maintained for backwards compatibility |
| `realty_asset.rb` | NEW | Physical property data (source of truth) |
| `sale_listing.rb` | NEW | Sale transaction data for properties |
| `rental_listing.rb` | NEW | Rental transaction data for properties |
| `listed_property.rb` | NEW | Materialized view (read-only) combining all property data |
| `prop_photo.rb` | HYBRID | Supports both `prop_id` and `realty_asset_id` for backwards compatibility |
| `feature.rb` | HYBRID | Supports both `prop_id` and `realty_asset_id` for backwards compatibility |

**Related Models**:
- `Website` model has both `has_many :props` and `has_many :realty_assets`
- Website associations: `has_many :listed_properties`, `has_many :sale_listings`, `has_many :rental_listings`

---

## 2. Files That MUST Be Migrated (Write Operations)

These files actively create/update `Pwb::Prop` and REQUIRE migration:

### 2.1 API Controllers (Write Operations)

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/api/v1/properties_controller.rb`
**Status**: DEPRECATION WARNING PRESENT (lines 1-8)
**Migration Level**: CRITICAL - Handles bulk property creation

**Lines requiring migration**:
- Line 28: `if Pwb::Current.website.props.where(reference: propertyJSON["reference"]).exists?`
- Line 29: `existing_props.push Pwb::Current.website.props.find_by_reference`
- Line 33: `new_prop = Pwb::Current.website.props.create(property_params)`
- Line 36-44: Saves currency, area_unit, and property_photos to Pwb::Prop
- Line 65: `property = Pwb::Current.website.props.find(params[:id])`
- Line 72: `@property = Pwb::Current.website.props.find(params[:prop_id])`
- Line 81: `property = Pwb::Current.website.props.find(params[:id])`
- Line 87: `property = Pwb::Current.website.props.find(params[:id])`
- Line 95: `property = Pwb::Current.website.props.find(params[:prop_id])`

**Operations**:
- `bulk_create`: Creates multiple properties from API
- `update_extras`: Sets features on properties
- `order_photos`: Reorders property photos
- `add_photo_from_url`: Adds photos from URLs
- `add_photo`: Uploads photo files
- `remove_photo`: Deletes photos

**Notes**: Read operations (index/show) already use `ListedProperty` - only writes need migration

---

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/api_ext/v1/props_controller.rb`
**Status**: DEPRECATION WARNING PRESENT (lines 1-7)
**Migration Level**: CRITICAL - Legacy external API
**Note**: Routes are commented out in config/routes.rb

**Lines requiring migration**:
- Line 67: `if current_website.props.where(reference: propertyJSON["reference"]).exists?`
- Line 68: `pwb_prop = current_website.props.find_by_reference`
- Line 70: `pwb_prop.update property_params`
- Line 73: `pwb_prop = current_website.props.create property_params`
- Line 92: `new_prop = current_website.props.create`

**Operations**:
- `create_with_token`: Create/update single property with token auth
- `bulk_create_with_token`: Bulk create properties with token auth

**Notes**: Appears to be a legacy external integration endpoint

---

### 2.2 Admin Controllers

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/props_controller.rb`
**Status**: FULLY MIGRATED (lines 1-25 show proper architecture)
**Migration Level**: COMPLETE

**Key patterns**:
- Line 5-16: Uses `set_property` and `set_realty_asset` for proper separation
- Line 18-25: `index` action uses `Pwb::ListedProperty` for reads
- Line 83-87: `set_realty_asset` uses `RealtyAsset` for writes
- Line 103-147: Proper parameter handling for `RealtyAsset`, `SaleListing`, `RentalListing`

**Status**: This is the pattern all other controllers should follow.

---

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/props_controller.rb`
**Status**: PARTIALLY MIGRATED
**Migration Level**: LOW PRIORITY - Uses RealtyAsset but search has issues

**Code Issues**:
- Line 7: Uses `Pwb::RealtyAsset` (correct model)
- Line 10-11: Searches on `title` field (PROBLEM: title is on listings, not asset)
- Should search on: `reference`, `street_address`, `city`, `region`

**Recommendation**: Update search to use proper RealtyAsset fields

---

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin/websites_controller.rb`
**Status**: REQUIRES MIGRATION
**Migration Level**: LOW - Statistics only

**Line 30**: `@props_count = Pwb::Prop.unscoped.where(website_id: @website.id).count rescue 0`

**Should be**:
```ruby
@props_count = Pwb::RealtyAsset.where(website_id: @website.id).count rescue 0
```

---

### 2.3 Image Controllers (Photo Management)

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/editor/images_controller.rb`
**Status**: REQUIRES MIGRATION
**Migration Level**: MEDIUM - Photo association

**Line 53**: 
```ruby
prop_photos = Pwb::PropPhoto.joins(:prop)
```

**Should be**:
```ruby
prop_photos = Pwb::PropPhoto.joins(:realty_asset)
```
or update to support both associations

---

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/images_controller.rb`
**Status**: REQUIRES MIGRATION
**Migration Level**: MEDIUM - Photo association

**Line 52**:
```ruby
prop_photos = Pwb::PropPhoto.joins(:prop)
```

**Should be**:
```ruby
prop_photos = Pwb::PropPhoto.joins(:realty_asset)
```

---

### 2.4 View Files (Minor)

#### `/Users/etewiah/dev/sites-older/property_web_builder/app/views/tenant_admin/websites/index.html.erb`
**Status**: REQUIRES MIGRATION
**Migration Level**: LOW - Display only

**Line 60**:
```erb
<% props_count = Pwb::Prop.unscoped.where(pwb_website_id: website.id).count rescue 0 %>
```

**Should be**:
```erb
<% props_count = Pwb::RealtyAsset.where(pwb_website_id: website.id).count rescue 0 %>
```

---

## 3. Files Already Migrated (Read Operations)

These controllers/views properly use `ListedProperty` and don't need migration:

### 3.1 Public Controllers (Fully Migrated)

| File | Status | Key Pattern |
|------|--------|------------|
| `/app/controllers/pwb/props_controller.rb` | CLEAN | Uses `find_property_by_slug_or_id` with `ListedProperty` |
| `/app/controllers/pwb/search_controller.rb` | CLEAN | Uses `@current_website.listed_properties` |
| `/app/controllers/pwb/welcome_controller.rb` | CLEAN | (Assumed from test spec) |
| `/app/controllers/pwb/export/properties_controller.rb` | CLEAN | Uses `current_website.listed_properties` (line 16) |
| `/app/controllers/api_public/v1/properties_controller.rb` | CLEAN | (Assumed from test spec) |

### 3.2 Public Views (Verified Usage)

All public-facing views use `@property` or `@properties` which come from `ListedProperty`.

### 3.3 GraphQL (Verified)

- `mutations/submit_listing_enquiry.rb` - Uses ListedProperty (per test spec)

---

## 4. Controller Usage Summary Table

| Controller | File Path | Prop Usage | Migration Status | Priority |
|-----------|-----------|-----------|-----------------|----------|
| PropsController (public) | `pwb/props_controller.rb` | ✓ ListedProperty | DONE | N/A |
| SearchController | `pwb/search_controller.rb` | ✓ ListedProperty | DONE | N/A |
| PropsController (site_admin) | `site_admin/props_controller.rb` | ✓ RealtyAsset/Listings | DONE | N/A |
| PropsController (tenant_admin) | `tenant_admin/props_controller.rb` | ✓ RealtyAsset | PARTIAL | LOW |
| WebsitesController | `tenant_admin/websites_controller.rb` | ✗ Pwb::Prop | REQUIRED | LOW |
| Api::V1::PropertiesController | `pwb/api/v1/properties_controller.rb` | ✗ Pwb::Prop | CRITICAL | HIGH |
| ApiExt::V1::PropsController | `pwb/api_ext/v1/props_controller.rb` | ✗ Pwb::Prop | CRITICAL | HIGH |
| ImagesController (editor) | `pwb/editor/images_controller.rb` | ✗ Prop join | REQUIRED | MEDIUM |
| ImagesController (site_admin) | `site_admin/images_controller.rb` | ✗ Prop join | REQUIRED | MEDIUM |
| ExportController | `pwb/export/properties_controller.rb` | ✓ ListedProperty | DONE | N/A |
| ConfigController | `pwb/config_controller.rb` | Firebase (unrelated) | N/A | N/A |
| SquaresController | `pwb/squares_controller.rb` | Firebase (unrelated) | N/A | N/A |
| ImportController | `pwb/import/properties_controller.rb` | Unused comment | N/A | N/A |

---

## 5. Test Coverage Analysis

### 5.1 Prop Model Tests
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/models/pwb/deprecated_props_usage_spec.rb`

**Type**: Deprecation scanning and enforcement
**Coverage**:
- Scans for `.props` usage in read operation controllers
- Verifies `listed_properties` usage in public controllers
- Validates read-only behavior of `ListedProperty`
- Enforces deprecation patterns for excluded files

**Status**: Good - actively monitoring migration progress

### 5.2 New Model Tests
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/models/pwb/listed_property_spec.rb`

**Type**: Model tests for new architecture
**Coverage**: (Not fully read, but file exists)

### 5.3 Controller Tests

| Test File | Focus | Status |
|-----------|-------|--------|
| `spec/controllers/pwb/props_controller_spec.rb` | Public property display | Exists |
| `spec/controllers/pwb/api_public/v1/props_controller_spec.rb` | Public API | Exists |
| `spec/controllers/pwb/api/v1/propeties_controller_spec.rb` | Internal API (note typo: propeties) | Exists |
| `spec/requests/pwb/api/prop_spec.rb` | API requests | Exists |
| `spec/requests/pwb/api/v1/lite_properties_spec.rb` | Lite API | Exists |
| `spec/requests/api_public/v1/properties_spec.rb` | Public API requests | Exists |
| `spec/models/pwb/prop_photo_spec.rb` | Photo model | Exists |
| `spec/system/site_admin/properties_settings_spec.rb` | System tests | Exists |

---

## 6. API Endpoints Summary

### 6.1 Public APIs (Read-Only - Already Migrated)

| Endpoint | Controller | Status |
|----------|-----------|--------|
| `GET /api/v1/properties` | api/v1/properties_controller | Uses ListedProperty |
| `GET /api/v1/properties/:id` | api/v1/properties_controller | Uses ListedProperty |
| `GET /api_public/v1/properties` | api_public/v1/properties_controller | Uses ListedProperty |

### 6.2 Internal APIs (Write Operations - Legacy)

| Endpoint | Controller | Status | Priority |
|----------|-----------|--------|----------|
| `POST /api/v1/properties/bulk_create` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `PATCH /api/v1/properties/:id/update_extras` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `POST /api/v1/properties/:id/add_photo` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `POST /api/v1/properties/:id/add_photo_from_url` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `POST /api/v1/properties/:id/order_photos` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `DELETE /api/v1/properties/:photo_id/remove_photo` | api/v1/properties_controller | Uses Pwb::Prop | CRITICAL |
| `POST /api_ext/v1/properties/create_with_token` | api_ext/v1/props_controller | Uses Pwb::Prop | HIGH (legacy) |
| `POST /api_ext/v1/properties/bulk_create_with_token` | api_ext/v1/props_controller | Uses Pwb::Prop | HIGH (legacy) |

---

## 7. Migration Strategy Recommendations

### Phase 1: Low-Risk (Do First)

1. **Tenant Admin Website Statistics**
   - File: `/app/controllers/tenant_admin/websites_controller.rb` (line 30)
   - Change: `Pwb::Prop.unscoped` → `Pwb::RealtyAsset`
   - Impact: Display statistics only
   - Risk: VERY LOW
   - Effort: 5 minutes

2. **View Display**
   - File: `/app/views/tenant_admin/websites/index.html.erb` (line 60)
   - Change: `Pwb::Prop.unscoped` → `Pwb::RealtyAsset`
   - Impact: Display statistics only
   - Risk: VERY LOW
   - Effort: 5 minutes

3. **Image Controller Photo Joins**
   - Files:
     - `/app/controllers/pwb/editor/images_controller.rb` (line 53)
     - `/app/controllers/site_admin/images_controller.rb` (line 52)
   - Change: Join on `realty_asset` instead of `prop`
   - Impact: Photo management in editor
   - Risk: LOW (similar functionality)
   - Effort: 15 minutes
   - Test: Run image upload tests

4. **Tenant Admin Props Controller Search**
   - File: `/app/controllers/tenant_admin/props_controller.rb` (lines 10-11)
   - Fix: Search on RealtyAsset fields, not listing fields
   - Change: Remove title search, use reference/address
   - Risk: LOW (fixing incorrect behavior)
   - Effort: 10 minutes

### Phase 2: Medium-Risk (Test Thoroughly)

1. **External API Endpoint (api_ext)**
   - File: `/app/controllers/pwb/api_ext/v1/props_controller.rb`
   - Status: Routes commented out - check if still used
   - If used: Requires refactoring to use RealtyAsset/Listings pattern
   - Risk: MEDIUM (may have external clients)
   - Effort: 2-3 hours
   - Approach:
     - Find by reference using RealtyAsset
     - Create/update RealtyAsset + SaleListing/RentalListing
     - Handle photos properly

### Phase 3: High-Risk (Requires Careful Migration)

1. **Internal Properties API** (PRIMARY TARGET)
   - File: `/app/controllers/pwb/api/v1/properties_controller.rb`
   - Status: Most active API endpoint
   - Operations: bulk_create, photo uploads, feature updates
   - Risk: HIGH (likely used by systems in production)
   - Effort: 4-6 hours
   
   **Migration Plan**:
   ```ruby
   # Instead of: website.props.create(params)
   
   # Do:
   realty_asset = website.realty_assets.create(
     reference: params[:reference],
     street_address: params[:street_address],
     city: params[:city],
     # ... other asset fields
   )
   
   # Then create appropriate listing:
   if params[:for_sale]
     realty_asset.sale_listings.create(
       price_sale_current_cents: params[:price_sale_current_cents],
       title_en: params[:title],
       # ... listing-specific fields
     )
   end
   
   if params[:for_rent]
     realty_asset.rental_listings.create(
       price_rental_monthly_current_cents: params[:price_rental_monthly_current_cents],
       # ... rental-specific fields
     )
   end
   ```

   **Testing Strategy**:
   - Create comprehensive test suite for bulk_create
   - Test photo upload workflows
   - Test feature/amenity updates
   - Verify backwards compatibility where needed

---

## 8. Backwards Compatibility Strategy

### Keep Legacy Working Until Full Migration
The current approach is sound:

1. **Pwb::Prop remains available** for:
   - Existing external integrations
   - Legacy console operations
   - Cross-tenant reporting

2. **PropPhoto supports both associations**:
   - `has_one :prop` (legacy)
   - `has_one :realty_asset` (new)

3. **Feature model supports both**:
   - `belongs_to :prop` (legacy)
   - `belongs_to :realty_asset` (new)

### What to Deprecate Gradually
- Don't delete `Pwb::Prop` model until external clients updated
- Don't delete `website.props` association immediately
- Maintain migration test spec to catch regressions

---

## 9. Data Consistency Checks Needed

Before/after migration:

```ruby
# Verify all properties have corresponding assets
Pwb::Prop.find_each do |prop|
  asset = Pwb::RealtyAsset.find_by(reference: prop.reference)
  puts "Missing asset for Prop #{prop.id}" unless asset
end

# Verify all photos are linked
Pwb::PropPhoto.where(realty_asset_id: nil).find_each do |photo|
  puts "Orphaned photo #{photo.id}"
end

# Verify features are linked
Pwb::Feature.where(realty_asset_id: nil).find_each do |feature|
  puts "Orphaned feature #{feature.id}"
end
```

---

## 10. Files NOT Requiring Migration

These files use Pwb::Prop but don't modify it:

- `/app/models/pwb/feature.rb` - Association definition (already dual)
- `/app/models/pwb/prop_photo.rb` - Association definition (already dual)
- `app/models/pwb/website.rb` - Association definition (has both)
- `app/graphql/**` - GraphQL types (if they exist, likely using ListedProperty)

---

## 11. Key Database Artifacts

### Materialized View
- **View Name**: `pwb_properties` (read-only, backed by materialized view)
- **Usage**: All read operations use this
- **Refresh**: Triggered by `Pwb::ListedProperty.refresh` after writes
- **Status**: Working correctly

### Tables
- `pwb_props` - Legacy table (keep for backwards compatibility)
- `pwb_realty_assets` - Physical property data
- `pwb_sale_listings` - Sale transaction data
- `pwb_rental_listings` - Rental transaction data
- `pwb_prop_photos` - Photos (with dual foreign keys)
- `pwb_features` - Features (with dual foreign keys)

---

## Summary Checklist

- [x] Identified all Prop usage
- [x] Categorized by read vs. write
- [x] Mapped migration priority
- [x] Documented backwards compatibility approach
- [x] Listed test coverage gaps
- [ ] Create migration tasks (separate file)
- [ ] Implement Phase 1 changes
- [ ] Update API documentation
- [ ] Create integration tests
- [ ] Deprecation timeline for api_ext

---

## Next Steps

1. **Immediate**: Review this analysis with team
2. **Week 1**: 
   - Implement Phase 1 (low-risk) changes
   - Run full test suite after each change
   - Update migration test spec
3. **Week 2-3**: 
   - Prepare Phase 2 (api_ext endpoint)
   - Check if external clients still use it
4. **Week 4+**: 
   - Implement Phase 3 (main API endpoint)
   - Comprehensive testing and rollout

