# Pwb::Prop Migration Quick Reference

**Last Updated**: 2025-12-06  
**Status**: Analysis Complete - Ready for Implementation

---

## Quick Facts

| Metric | Value |
|--------|-------|
| Total Files Analyzed | 35+ |
| Files Needing Migration | 9 |
| Controllers with Prop Usage | 11 |
| Test Files | 15+ |
| Estimated Total Effort | 16-24 hours |
| Migration Phases | 5 |
| Expected Completion | 3-4 weeks |

---

## Files That Need Changes (Quick Summary)

### CRITICAL (Do These First - ~4 hours)
```
✗ app/controllers/pwb/api/v1/properties_controller.rb    (Lines 28-121) - BULK API
✗ app/controllers/pwb/api_ext/v1/props_controller.rb     (Lines 67-92)  - LEGACY API
```

### MEDIUM (Do Second - ~1 hour)
```
✗ app/controllers/pwb/editor/images_controller.rb        (Line 53)  - Photo join
✗ app/controllers/site_admin/images_controller.rb        (Line 52)  - Photo join
```

### EASY (Do First - ~20 minutes)
```
✗ app/controllers/tenant_admin/websites_controller.rb    (Line 30)  - Statistics
✗ app/views/tenant_admin/websites/index.html.erb       (Line 60)  - View
✗ app/controllers/tenant_admin/props_controller.rb      (Lines 10-11) - Search
```

### ALREADY DONE
```
✓ app/controllers/site_admin/props_controller.rb        - FULLY MIGRATED
✓ app/controllers/pwb/props_controller.rb               - FULLY MIGRATED
✓ app/controllers/pwb/search_controller.rb              - FULLY MIGRATED
✓ app/controllers/pwb/export/properties_controller.rb   - FULLY MIGRATED
✓ app/controllers/api_public/v1/properties_controller.rb - FULLY MIGRATED
```

---

## Architecture Summary

### Old Model (Deprecated)
```ruby
Website → has_many :props → Pwb::Prop (single monolithic model)
         → has_many :prop_photos → Pwb::PropPhoto
         → has_many :features → Pwb::Feature
```

### New Model (Normalized)
```ruby
Website → has_many :realty_assets → Pwb::RealtyAsset (physical property)
        ├→ has_many :sale_listings → Pwb::SaleListing (transaction data)
        └→ has_many :rental_listings → Pwb::RentalListing (transaction data)
        → has_many :listed_properties → Pwb::ListedProperty (materialized view - READ ONLY)

Pwb::RealtyAsset → has_many :prop_photos → Pwb::PropPhoto
                → has_many :features → Pwb::Feature
```

---

## Code Patterns

### Finding Properties (READS)
```ruby
# ❌ OLD - Don't use
website.props
website.props.find(id)
website.props.visible
website.props.for_sale

# ✓ NEW - Use this
website.listed_properties                    # Materialized view
Pwb::ListedProperty.visible
Pwb::ListedProperty.for_sale
```

### Creating Properties (WRITES)
```ruby
# ❌ OLD - Don't do
prop = website.props.create(title: "...", price: 100)

# ✓ NEW - Do this
asset = website.realty_assets.create(
  reference: "REF-001",
  street_address: "123 Main",
  city: "Boston"
)

# Then add listing data:
asset.sale_listings.create(
  title_en: "Beautiful Home",
  price_sale_current_cents: 100_000_00,
  price_sale_current_currency: "USD"
)

# Refresh view for searches
Pwb::ListedProperty.refresh
```

### Updating Properties (WRITES)
```ruby
# ❌ OLD - Don't do
prop = website.props.find(id)
prop.update(price: 200)

# ✓ NEW - Do this
# Update physical data:
asset = website.realty_assets.find(id)
asset.update(street_address: "456 Oak")

# Update listing data:
listing = asset.sale_listings.first
listing.update(price_sale_current_cents: 200_000_00)

# Refresh
Pwb::ListedProperty.refresh
```

### Working with Photos
```ruby
# ❌ OLD
prop.prop_photos.create(image: file)

# ✓ NEW
asset = website.realty_assets.find(id)
photo = Pwb::PropPhoto.create(realty_asset_id: asset.id)
photo.image.attach(file)
```

### Working with Features
```ruby
# ❌ OLD
prop.set_features = { "feature.pool" => true }

# ✓ NEW
asset = website.realty_assets.find(id)
asset.features.find_or_create_by(feature_key: "feature.pool")
```

---

## Backwards Compatibility Notes

### What Still Works
- `Pwb::Prop` model still exists (not deleted)
- `website.props` association still works
- Old factory builders still work
- Console operations still supported

### What to Avoid
- Creating new Pwb::Prop instances in new code
- Using .props in new controllers
- Relying on Pwb::Prop for any new features

### Deprecation Path
```
2025-12 → Phase 1-2: Easy wins (statistics, views)
2026-01 → Phase 3: Core API migration
2026-02 → Phase 4-5: Testing & deployment
2026-03 → Optional: Remove Pwb::Prop if no external users
```

---

## API Endpoint Status

### Read Endpoints (Already Using ListedProperty)
```
GET /api/v1/properties                  ✓ Done
GET /api/v1/properties/:id              ✓ Done
GET /api_public/v1/properties           ✓ Done
```

### Write Endpoints (Need Migration)
```
POST /api/v1/properties/bulk_create         ✗ Critical
PATCH /api/v1/properties/:id/update_extras  ✗ Critical
POST /api/v1/properties/:id/add_photo       ✗ Critical
POST /api/v1/properties/:id/order_photos    ✗ Critical
DELETE /api/v1/properties/:id/remove_photo  ✗ Critical
```

### Legacy Endpoints
```
POST /api_ext/v1/properties/create_with_token       ? Check usage
POST /api_ext/v1/properties/bulk_create_with_token  ? Check usage
(Routes commented out - may be deprecated)
```

---

## Testing Checklist

### Before Changes
- [ ] `bin/rspec spec/` - All tests passing
- [ ] Note baseline test times

### After Phase 1 (Easy Changes)
- [ ] `bin/rspec spec/controllers/tenant_admin/` ✓
- [ ] `bin/rspec spec/models/pwb/deprecated_props_usage_spec.rb` ✓

### After Phase 2 (Image Controllers)
- [ ] `bin/rspec spec/controllers/pwb/editor/` ✓
- [ ] `bin/rspec spec/controllers/site_admin/images_controller_spec.rb` ✓

### After Phase 3 (API Migration)
- [ ] `bin/rspec spec/controllers/pwb/api/` ✓
- [ ] `bin/rspec spec/requests/pwb/api/` ✓
- [ ] Create migration integration tests ✓
- [ ] Test backwards compatibility ✓

### Performance Tests
- [ ] Compare API response times (should be similar)
- [ ] Load test bulk_create with 1000+ properties
- [ ] Check database query counts

---

## Common Issues & Solutions

### Issue: "title is not a field on RealtyAsset"
**Solution**: Title is on SaleListing/RentalListing. Get it from there:
```ruby
asset.sale_listings.first&.title || asset.rental_listings.first&.title
```

### Issue: Photos not showing up
**Solution**: Check that PropPhoto has realty_asset_id set:
```ruby
Pwb::PropPhoto.where(realty_asset_id: nil).count  # Should be 0
```

### Issue: Search not returning results
**Solution**: ListedProperty is a materialized view - must be refreshed:
```ruby
Pwb::ListedProperty.refresh  # Call after any writes
```

### Issue: "Cannot delete active listing" error
**Solution**: Must deactivate before deleting:
```ruby
listing.deactivate!
listing.destroy
# Or activate a different listing first
```

### Issue: Features not updating
**Solution**: Use find_or_create_by pattern:
```ruby
feature.find_or_create_by(feature_key: key)
```

---

## Git Workflow

```bash
# Start migration work
git checkout -b migration/prop-to-realty-asset

# After each phase
git add -A
git commit -m "Phase N: Description of changes

- List specific changes
- Tests verified
- Backwards compatible

Related to: Pwb::Prop to RealtyAsset migration"

# When ready for review
git push origin migration/prop-to-realty-asset
# Create PR with reference to this analysis
```

---

## Key Files Reference

### Models
- `/app/models/pwb/prop.rb` - Legacy (keep for backwards compat)
- `/app/models/pwb/realty_asset.rb` - New source of truth
- `/app/models/pwb/sale_listing.rb` - Sale data
- `/app/models/pwb/rental_listing.rb` - Rental data
- `/app/models/pwb/listed_property.rb` - Materialized view (use for reads)

### Controllers (Already Done)
- `/app/controllers/site_admin/props_controller.rb` - Example of proper migration
- `/app/controllers/pwb/props_controller.rb` - Uses ListedProperty
- `/app/controllers/pwb/search_controller.rb` - Uses ListedProperty

### Controllers (Need Migration)
- `/app/controllers/pwb/api/v1/properties_controller.rb` - CRITICAL
- `/app/controllers/pwb/api_ext/v1/props_controller.rb` - CRITICAL
- `/app/controllers/tenant_admin/websites_controller.rb` - EASY
- `/app/controllers/tenant_admin/props_controller.rb` - EASY
- `/app/controllers/site_admin/images_controller.rb` - MEDIUM
- `/app/controllers/pwb/editor/images_controller.rb` - MEDIUM

### Views
- `/app/views/tenant_admin/websites/index.html.erb` - EASY

### Tests
- `/spec/models/pwb/deprecated_props_usage_spec.rb` - Migration monitoring
- `/spec/models/pwb/listed_property_spec.rb` - New model tests
- `/spec/controllers/pwb/api/v1/propeties_controller_spec.rb` - Note: typo in filename

---

## Commands for Quick Checks

```bash
# Find all .props usage
grep -r "\.props\b" app/ --include="*.rb" | grep -v "listed_properties\|prop_photos\|props_controller"

# Find all Pwb::Prop references
grep -r "Pwb::Prop\b" app/ --include="*.rb" | grep -v "ListedProperty\|PropPhoto"

# Run migration tests
bin/rspec spec/models/pwb/deprecated_props_usage_spec.rb -v

# Check for orphaned data
bin/rails runner "puts 'Orphaned photos: ' + Pwb::PropPhoto.where(realty_asset_id: nil).count.to_s"

# Refresh materialized view
bin/rails runner "Pwb::ListedProperty.refresh"

# Count properties in each model
bin/rails runner "
puts 'Pwb::Prop count: ' + Pwb::Prop.count.to_s
puts 'Pwb::RealtyAsset count: ' + Pwb::RealtyAsset.count.to_s
puts 'Pwb::ListedProperty count: ' + Pwb::ListedProperty.count.to_s
"
```

---

## Document Cross-References

**For detailed analysis**: See `MIGRATION_ANALYSIS.md`
**For action items**: See `MIGRATION_ACTION_ITEMS.md`
**For model details**: Check individual model files in `/app/models/pwb/`

