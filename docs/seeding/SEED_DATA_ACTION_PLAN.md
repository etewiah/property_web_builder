# Seed Data - Action Plan

## Overview

This document provides a prioritized action plan for addressing seed data issues in PropertyWebBuilder.

---

## Priority 1: CRITICAL (Fix Immediately - Blocking Issues)

### P1.1: Remove Early-Return Guard in Provisioning

**Issue**: Cannot re-seed navigation links once created (4+ links exist)

**File**: `lib/pwb/provisioning_service.rb` (line 340)

**Current Code**:
```ruby
def create_links_for_website(website)
  return if website.links.count >= 3  # ← PROBLEM
  
  begin_seed_pack_step(website, :links)
  # ... seeding code
end
```

**Problem**: 
- Once fallback links are created, seeding never runs again
- Prevents fresh seeding from pack
- Blocks ability to switch seed packs

**Fix Option A** (Remove Guard):
```ruby
def create_links_for_website(website)
  # Remove the early return entirely
  # Allow idempotent reseeding
  
  # Clear existing links first if re-seeding
  website.links.delete_all if website.provisioning_state == 'reseed'
  
  begin_seed_pack_step(website, :links)
  # ... seeding code
end
```

**Fix Option B** (Check for Pack-Based Seeding):
```ruby
def create_links_for_website(website)
  # Only skip if properly seeded from a pack
  return if website.links.count >= 3 && website.seed_pack_name.present?
  
  begin_seed_pack_step(website, :links)
end
```

**Effort**: 5 minutes  
**Risk**: Low  
**Testing**: Verify re-seeding works, check link counts

---

### P1.2: Integrate Content Seeding into Provisioning

**Issue**: Content (translatable text) never gets seeded during provisioning

**File**: `app/services/pwb/provisioning_service.rb`

**Current Status**:
```ruby
def provision_website(website:, progress_block: nil)
  # Current steps:
  configure_as_pending          # ✅
  create_agency_for_website     # ✅
  create_links_for_website      # ✅
  create_field_keys_for_website # ✅
  create_pages_for_website      # ✅
  seed_properties_for_website   # ✅
  # Missing:
  # seed_content_for_website    # ❌
end
```

**Impact**:
- Websites lack page content after provisioning
- Content must be manually seeded separately
- Incomplete provisioning workflow

**Fix Option A** (Add Content Seeding Step):
```ruby
def provision_website(website:, progress_block: nil)
  # ... existing steps ...
  
  # NEW STEP: Seed content
  seed_content_for_website(website, progress_block)
  report_progress(progress_block, website, 'content_seeded', 80)
end

private

def seed_content_for_website(website, progress_block)
  begin_seed_pack_step(website, :content)
rescue StandardError => e
  log_error("Failed to seed content: #{e.message}")
  # Don't fail provisioning if content fails
end
```

**Fix Option B** (Use Full SeedPack.apply!):
```ruby
def provision_website(website:, progress_block: nil)
  # More comprehensive approach
  pack = Pwb::SeedPack.find(website.seed_pack_name)
  
  # Instead of individual steps, use full apply with options
  pack.apply!(
    website: website,
    options: {
      skip_website: true,  # Don't override config
      skip_agency: false,  # Create/update agency
      skip_properties: ENV['SKIP_PROPERTIES'].present?,
      verbose: false
    }
  )
end
```

**Recommended**: Option A (gradual approach, less breaking)

**Effort**: 30 minutes  
**Risk**: Medium (impacts provisioning flow)  
**Testing**: Provision website, verify content exists

---

### P1.3: Fix Spain Pack Image References

**Issue**: Spain pack properties reference images that don't exist

**File**: `db/seeds/packs/spain_luxury/properties/*.yml`

**Examples**:
```yaml
# villa_marbella.yml
image: villa_ocean.jpg  # NOT FOUND in pack/images/

# apartment_marbella.yml
image: apartment_beach.jpg  # NOT FOUND

# penthouse_puerto_banus.yml
image: penthouse_luxury.jpg  # NOT FOUND
```

**Root Cause**: Properties reference images but files aren't in pack or external URLs

**Fix Option A** (Add Image Files to Pack):
1. Acquire copyright-free real estate images for Spanish properties
2. Add to `db/seeds/packs/spain_luxury/images/`
3. Update property YAML to use correct filenames
4. Test that images render

**Cost**: Need image files (can use Unsplash, Pexels, etc.)  
**Effort**: 2 hours  
**Result**: Images load locally

**Fix Option B** (Configure External URLs):
```yaml
# Updated villa_marbella.yml
image_url: "https://r2.property-web-builder.com/packs/spain_luxury/villa_marbella_1.jpg"
```

Then ensure SeedImages is configured:
```ruby
# config/seed_images.yml
base_url: https://r2.property-web-builder.com
bucket: property-seed-images
```

**Cost**: R2/S3 bucket configuration  
**Effort**: 1 hour  
**Result**: Images load from external CDN

**Fix Option C** (Use Shared Example Images):
```yaml
# Reference existing images
image: carousel_villa_with_pool.jpg  # From db/example_images/
```

**Cost**: None  
**Effort**: 30 minutes  
**Result**: Works immediately

**Recommended**: Option C for now, Option B for production

---

## Priority 2: HIGH (Improve Data Quality - Affects Testing)

### P2.1: Update Legacy Property Descriptions

**Issue**: Placeholder descriptions like "Example country house for sale."

**File**: `db/yml_seeds/prop/villa_for_sale.yml` (and 5 others)

**Examples**:
```yaml
# Current (bad)
title_en: "Example country house for sale."
description_en: "Description of the amazing country house for sale."

# Target (good)
title_en: "Charming Country Estate with Modern Updates"
description_en: "Spacious country home situated on 5.5 acres with mature 
  landscaping. Recent updates include new roof, HVAC system, and kitchen 
  appliances. 4 bedrooms, 2.5 bathrooms, barn and storage facilities. 
  Perfect for families seeking rural living with access to town amenities."
```

**Decision Required**:
- Keep and improve legacy seeds, OR
- Remove and deprecate in favor of seed packs

**Option A** (Improve):
1. Replace with realistic property descriptions
2. Add proper features to each property
3. Update pricing to current market rates
4. Consider moving to seed pack format

**Option B** (Deprecate):
1. Move `db/yml_seeds/prop/` → `db/yml_seeds_archive/prop/`
2. Update seeders to use only seed packs
3. Cleaner codebase, no legacy tech debt

**Recommended**: Option B (deprecate legacy)

**Effort**: 2 hours  
**Impact**: Cleaner seed data, less confusion

---

### P2.2: Add Features to All Properties

**Issue**: Legacy properties have empty features arrays

**File**: `db/yml_seeds/prop/villa_for_sale.yml` (and others)

**Current**:
```yaml
# No features defined!
features: []
```

**Target**:
```yaml
features:
  - features.private_pool
  - features.private_garden
  - features.terrace
  - features.private_garage
  - amenities.air_conditioning
  - amenities.central_heating
  - features.fireplace
  - features.sea_views
```

**Effort**: 1 hour  
**Impact**: Complete test data, enables feature filtering tests

**Steps**:
1. For each property, identify realistic features
2. Add to features array
3. Test that features display in UI

---

### P2.3: Add Energy Rating Data

**Issue**: No energy ratings or sustainability data anywhere

**Files to Update**:
- `db/yml_seeds/prop/*.yml`
- `db/seeds/packs/spain_luxury/properties/*.yml`
- `db/seeds/packs/netherlands_urban/properties/*.yml`

**Why**: EU Energy Performance Directive requires this

**Add to each property**:
```yaml
energy_rating: "B"              # A-G scale (EU standard)
energy_performance: 45          # kWh/m²/year
energy_cert_date: "2024-01-15"  # Date of certification
heating_type: "heat_pump"       # renewable option
hot_water: "solar"              # renewable option
```

**Effort**: 2 hours  
**Impact**: Modern, compliant seed data

---

## Priority 3: MEDIUM (Enhancements - Nice to Have)

### P3.1: Create UK Residential Seed Pack

**New Pack**: `db/seeds/packs/uk_residential/`

**Scenario**: UK estate agency with residential properties

**Structure**:
```
uk_residential/
├── pack.yml
├── agency.yml (UK agency)
├── properties/
│   ├── london_townhouse.yml
│   ├── cotswolds_cottage.yml
│   ├── bristol_flat.yml
│   └── ...
├── images/
│   ├── london_townhouse_1.jpg
│   └── ...
└── translations/
    └── en.yml
```

**Properties** (6-8):
- London townhouse (£750k-£1.5M)
- Cotswolds cottage (£500k-£800k)
- Lake District country home (£650k-£1M)
- Bristol modern flat (£250k-£400k)

**Effort**: 4-6 hours  
**Impact**: Additional market coverage

---

### P3.2: Create USA Commercial Seed Pack

**New Pack**: `db/seeds/packs/usa_commercial/`

**Scenario**: US commercial real estate brokerage

**Properties** (6-8):
- Office building (Manhattan, $2M+)
- Retail space (Chicago, $500k-$1M)
- Warehouse (Houston, $1M-$3M)
- Medical office (San Francisco, $1.5M-$3M)

**Effort**: 4-6 hours  
**Impact**: Commercial market coverage

---

### P3.3: Implement Property Generator

**Purpose**: Auto-generate realistic properties for testing

**Location**: `lib/pwb/seed_pack/property_generator.rb`

**Usage**:
```ruby
generator = Pwb::SeedPack::PropertyGenerator.new(
  count: 100,
  types: { villa: 50, apartment: 30, townhouse: 20 },
  locations: ['Barcelona', 'Madrid', 'Valencia'],
  price_range: [200_000, 2_000_000]
)

properties = generator.generate!  # Creates 100 realistic properties
```

**Benefits**:
- Easy to generate large test datasets
- Realistic pricing, locations, features
- Support property type distribution

**Effort**: 8 hours  
**Impact**: Testing flexibility

---

### P3.4: Unified Image Management System

**Purpose**: Simplify image handling (local vs. external)

**Current Approach**:
- Some properties use local files: `db/example_images/`
- Some use external URLs: `https://r2.../`
- Spain pack has broken references

**Improved Approach**:
```yaml
# In pack.yml
images:
  source: r2  # or 'local'
  base_url: "https://cdn.example.com/packs/spain_luxury/"
  fallback: local  # Use local if remote fails

# In properties
images:
  - filename: villa_marbella_1.jpg
    sort_order: 1
  - filename: villa_marbella_2.jpg
    sort_order: 2
```

**Effort**: 4 hours  
**Impact**: Cleaner configuration, consistent handling

---

## Priority 4: LOW (Future Improvements)

### P4.1: Data Quality Dashboard
Create admin UI showing seed data completeness

### P4.2: Automated Seed Data Validation
Extend `pwb:db:validate_seeds` with comprehensive checks

### P4.3: Seed Data Versioning
Track changes to seed files over time

### P4.4: Multi-Pack Inheritance
Allow packs to inherit from multiple parents

---

## Implementation Timeline

### Week 1 (Critical Fixes)
- [ ] P1.1: Remove early-return guard (5 min)
- [ ] P1.2: Add content seeding (30 min)
- [ ] P1.3: Fix Spain pack images (1 hour)

**Total**: ~1.5 hours

### Week 2 (Quality Improvements)
- [ ] P2.1: Deprecate/improve legacy properties (2 hours)
- [ ] P2.2: Add features to properties (1 hour)
- [ ] P2.3: Add energy rating data (2 hours)

**Total**: ~5 hours

### Week 3-4 (New Packs)
- [ ] P3.1: UK residential pack (4-6 hours)
- [ ] P3.2: USA commercial pack (4-6 hours)

**Total**: ~10 hours

---

## Testing Checklist

After implementing fixes:

### P1 Verification
```ruby
# Test re-seeding works
website.links.delete_all
service.send(:create_links_for_website, website)
expect(website.links.count).to be >= 3  # ✅ Should pass

# Test content exists after provisioning
website = create_website
expect(website.contents.count).to be > 0  # ✅ Should pass

# Test Spain images
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
expect(website.prop_photos.count).to be > 0  # ✅ Should pass
```

### P2 Verification
```ruby
# Test features exist
property = Pwb::RealtyAsset.first
expect(property.features.count).to be > 0  # ✅ Should pass

# Test energy data
expect(property.energy_rating).to be_present  # ✅ Should pass
expect(property.energy_performance).to be_present  # ✅ Should pass
```

---

## Code Review Checklist

Before committing changes:

- [ ] Early-return guard removed (no unintended side effects)
- [ ] Content seeding properly integrated (no duplicate calls)
- [ ] Image paths verified (all files exist or URLs work)
- [ ] Test coverage added for new code
- [ ] Documentation updated
- [ ] Multi-tenancy scoping preserved (website_id still set)
- [ ] Backwards compatibility maintained (old seeds still work)

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| **Re-seedable websites** | 0% | 100% |
| **Legacy properties quality** | ⭐⭐ | ⭐⭐⭐⭐ or deprecated |
| **Properties with features** | 15% | 100% |
| **Properties with energy data** | 0% | 100% |
| **Seed packs** | 3 | 5+ |
| **Available images** | 17 | 50+ |

---

## Questions & Decisions Needed

1. **Legacy Properties**: Keep and improve, or deprecate in favor of seed packs?
   - Recommendation: **Deprecate** (cleaner, less tech debt)

2. **Spain Pack Images**: Add local files, configure R2/S3, or use shared images?
   - Recommendation: **Use shared images** (immediate fix), then **configure R2** (long-term)

3. **UK Residential Pack**: Create immediately or defer?
   - Recommendation: **Defer** (not blocking, lower priority)

4. **Property Generator**: Implement before or after new packs?
   - Recommendation: **After** (packs are more useful initially)

---

## Success Criteria

Implementation is complete when:

✅ P1.1 - Re-seeding navigation links works  
✅ P1.2 - Content is seeded during provisioning  
✅ P1.3 - Spain pack images render correctly  
✅ P2.1 - Legacy seeds improved or deprecated  
✅ P2.2 - All properties have features  
✅ P2.3 - All properties have energy data  

Additional packs and enhancements can be added incrementally.

---

## See Also

- Full analysis: `/docs/SEED_DATA_ANALYSIS.md`
- Summary: `/docs/SEED_DATA_SUMMARY.md`
- Seeding guide: `/docs/seeding/seeding.md`
