# Seed Data - Quick Reference Guide

## File Locations

### Core Files (What to Know)
```
lib/pwb/seed_pack.rb              ← Main implementation (800+ lines)
lib/pwb/seeder.rb                 ← Basic seeding
db/seeds.rb                       ← Entry point
```

### Data Files
```
db/seeds/packs/base/              ← Shared foundation
db/seeds/packs/spain_luxury/      ← ✅ High quality (7 props)
db/seeds/packs/netherlands_urban/ ← ✅ High quality (8 props)
db/yml_seeds/prop/                ← ❌ Placeholder (6 props)
db/yml_seeds/field_keys.yml       ← 100+ property attributes
```

### Documentation
```
docs/seeding/seeding.md           ← Comprehensive guide
docs/seeding/seed_packs_plan.md   ← Architecture & design
docs/SEED_DATA_ANALYSIS.md        ← Full analysis
docs/SEED_DATA_SUMMARY.md         ← Executive summary
docs/SEED_DATA_ACTION_PLAN.md     ← Implementation plan
```

---

## Key Stats

| Item | Count |
|------|-------|
| **Total Properties** | 21 |
| **Seed Packs** | 3 |
| **Field Keys** | 100+ |
| **Languages** | 13 |
| **YAML Files** | 68 |
| **Example Images** | 17 |

---

## Properties Breakdown

### Legacy (db/yml_seeds/prop/) - ❌ Low Quality
```
re-s1:     Villa for sale (New Jersey)
re-s2:     Flat for sale (New Jersey)
re-r2:     Flat for rent (New Jersey)
re-r3:     Penthouse for rent (New Jersey)
pwb-r1:    Villa for rent (New Jersey)
flat_for_sale_2: Flat for sale
```
**Issue**: All placeholder, generic locations, no features, empty descriptions

### Spain Luxury (db/seeds/packs/spain_luxury/) - ✅ Excellent
```
ES-VILLA-001:     6-bed villa Marbella (€3.95M)
ES-PENT-001:      4-bed penthouse Puerto Banús (€2.85M)
ES-APT-001:       3-bed apartment Marbella (€895k)
ES-TOWN-001:      4-bed townhouse Estepona (€725k)
ES-APT-FUEN-001:  2-bed apartment Fuengirola (€385k)
ES-VILLA-BENA-001: 5-bed villa Benahavis (€2.4M)
ES-VILLA-RENT-001: 4-bed villa rental Mijas (€4,500/mo)
```
**Quality**: Professional descriptions, realistic pricing, complete features

### Netherlands Urban (db/seeds/packs/netherlands_urban/) - ✅ Excellent
```
NL-GRA-001:      Canal house Amsterdam (€2.495M)
NL-APT-DH-001:   Apartment Den Haag (€450k)
NL-HOUSE-001:    Herenhuis Utrecht (€725k)
NL-CORNER-001:   Corner house Haarlem (€395k)
NL-LOFT-001:     Loft Amsterdam Oost (€575k)
NL-NEWBUILD-001: New build Eindhoven (€425k)
NL-PENT-001:     Penthouse Rotterdam (€895k)
NL-RNT-001:      Rental apartment Amsterdam (€2,950/mo)
```
**Quality**: Real addresses, realistic Dutch market pricing, professional translations

---

## Critical Issues (Must Fix)

### 1. Early-Return Guard
**File**: `lib/pwb/provisioning_service.rb:340`
**Issue**: Can't re-seed navigation links
**Fix**: Remove `return if website.links.count >= 3`
**Time**: 5 minutes

### 2. Missing Content Seeding
**File**: `app/services/pwb/provisioning_service.rb`
**Issue**: Content never seeded during provisioning
**Fix**: Add `seed_content_for_website` step
**Time**: 30 minutes

### 3. Spain Pack Images
**File**: `db/seeds/packs/spain_luxury/properties/`
**Issue**: References missing images (villa_ocean.jpg, etc.)
**Fix**: Add image files or configure R2/S3 URLs
**Time**: 1-2 hours

---

## Quick Commands

```bash
# List available seed packs
rake pwb:seed_packs:list

# Preview a seed pack
rake pwb:seed_packs:preview[spain_luxury]

# Apply seed pack to website
rake pwb:seed_packs:apply[spain_luxury,my-website]

# Seed with all properties
rake pwb:db:seed

# Seed without properties
SKIP_PROPERTIES=true rake pwb:db:seed

# Validate seed files
rake pwb:db:validate_seeds
```

---

## Field Key Categories (100+ total)

```yaml
# Property Types (20)
types.apartment, villa, penthouse, townhouse, detached_house,
semi_detached, bungalow, country_house, land, commercial,
office, retail, warehouse, garage, storage, hotel, 
residential_building, grachtenpand, ...

# States (7)
states.new_build, under_construction, excellent, good,
needs_renovation, renovated, second_hand

# Features (26+)
features.private_pool, heated_pool, private_garden, terrace,
balcony, porch, solarium, fireplace, jacuzzi, sauna,
sea_views, mountain_views, elevator, parquet_flooring, ...

# Amenities (18+)
amenities.air_conditioning, central_heating, solar_energy,
alarm_system, video_entry, security, furnished, washing_machine,
refrigerator, oven, microwave, tv, ...

# Status (6)
status.available, reserved, under_offer, sold, rented, off_market

# Highlights (7)
highlights.featured, new_listing, price_reduced, luxury,
exclusive, investment_opportunity, energy_efficient

# Origin (6)
origin.direct, bank, private_seller, new_development,
mls_feed, partner
```

---

## Data Quality Scorecard

| Aspect | Legacy | Spain | Netherlands | Target |
|--------|--------|-------|-------------|--------|
| **Descriptions** | ❌ Generic | ✅ Professional | ✅ Professional | ✅ Professional |
| **Locations** | ❌ Fake | ✅ Real | ✅ Real | ✅ Real |
| **Pricing** | ⚠️ Low | ✅ Realistic | ✅ Realistic | ✅ Realistic |
| **Features** | ❌ None | ✅ Complete | ✅ Complete | ✅ Complete |
| **Images** | ⚠️ Generic | ❌ Missing | ✅ Included | ✅ Complete |
| **Energy Data** | ❌ None | ❌ None | ❌ None | ✅ Included |

---

## Languages Supported (13)

```
en (English)      es (Spanish)      de (German)       fr (French)
nl (Dutch)        pt (Portuguese)   it (Italian)      ca (Catalan)
ro (Romanian)     ru (Russian)      ko (Korean)       bg (Bulgarian)
tr (Turkish)
```

---

## Multi-Tenancy Notes

✅ Properly Scoped (per website_id/pwb_website_id):
- Links
- Properties
- Pages
- Page Parts
- Field Keys
- Content

⚠️ Shared Globally:
- Translations (I18n table)
- Themes (ActiveHash)

---

## Testing Properties

**To test seed packs**:
```ruby
pack = Pwb::SeedPack.find('spain_luxury')
website = create(:pwb_website)

# Preview without applying
pack.preview
# => { pack_name: 'spain_luxury', properties: 7, locales: 3, ... }

# Apply (creates all data)
pack.apply!(website: website)

# Verify data
expect(website.properties.count).to eq(7)
expect(website.field_keys.count).to be > 0
expect(website.links.count).to be >= 3
```

**To test properties**:
```ruby
property = website.realty_assets.first
expect(property.reference).to be_present
expect(property.bedrooms).to be > 0
expect(property.sale_listings.any? || property.rental_listings.any?).to be true
```

---

## Recommended Reading Order

1. **Quick Start**: This file (you are here)
2. **Summary**: `docs/SEED_DATA_SUMMARY.md` (2 min)
3. **Action Plan**: `docs/SEED_DATA_ACTION_PLAN.md` (5 min)
4. **Full Analysis**: `docs/SEED_DATA_ANALYSIS.md` (30 min)
5. **Seeding Guide**: `docs/seeding/seeding.md` (reference)

---

## Most Important Files to Know

1. **lib/pwb/seed_pack.rb** - The whole system (800 lines)
2. **db/seeds/packs/spain_luxury/properties/villa_marbella.yml** - Quality example
3. **db/yml_seeds/field_keys.yml** - Property taxonomy (1,400 lines)
4. **docs/SEED_DATA_ANALYSIS.md** - Full details (500+ lines)

---

## Success Metrics

| Goal | Current | Target |
|------|---------|--------|
| Properties with features | 15% | 100% |
| Re-seedable websites | 0% | 100% |
| Content after provisioning | ❌ No | ✅ Yes |
| Spain pack images | ❌ Missing | ✅ Working |
| Energy data coverage | 0% | 100% |

---

## Next Steps

1. Read full analysis (`docs/SEED_DATA_ANALYSIS.md`)
2. Review action plan (`docs/SEED_DATA_ACTION_PLAN.md`)
3. Fix P1 critical issues (1.5 hours)
4. Improve data quality (P2, 5 hours)
5. Add new seed packs (P3, 8-10 hours)

---

For details, see the full analysis documents in the docs/ folder.
