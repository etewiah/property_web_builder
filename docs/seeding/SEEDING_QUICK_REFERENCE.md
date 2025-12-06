# PropertyWebBuilder Seeding - Quick Reference

## File Locations

| Category | Location | Purpose |
|----------|----------|---------|
| **Ruby Seeds** | `db/seeds/` | Ruby code that creates data |
| **YAML Seeds** | `db/yml_seeds/` | Configuration & data templates |
| **Translations** | `db/seeds/translations_*.rb` | 15 language translation seeds |
| **E2E Seeds** | `db/seeds/e2e_seeds.rb` | Multi-tenant test setup |
| **Seeder Classes** | `lib/pwb/seeder.rb`, `pages_seeder.rb`, `contents_seeder.rb` | Seeding logic |
| **Factories** | `spec/factories/pwb_*.rb` | Test data builders (22 files) |
| **I18n Config** | `config/initializers/i18n_globalise.rb` | Locale configuration |

---

## Quick Commands

```bash
# Seed the database
bin/rails app:pwb:db:seed

# Seed E2E test environment
RAILS_ENV=e2e bin/rails db:seed

# Update page parts from YAML
bin/rails pwb:db:update_page_parts

# Seed in Rails console
rails console
> Pwb::Seeder.seed!(website: Pwb::Website.first)
> Pwb::PagesSeeder.seed_page_basics!(website: website)
> Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

---

## Seeding Components at a Glance

### Pwb::Seeder (Main orchestrator)
```ruby
Pwb::Seeder.seed!(
  website: nil,              # Specific website to seed (optional)
  skip_properties: false     # Skip property seeding if true
)
```
**Seeds**: Translations, website config, agency, users, contacts, field keys, properties, links

### Pwb::PagesSeeder
```ruby
Pwb::PagesSeeder.seed_page_basics!(website: website)
Pwb::PagesSeeder.seed_page_parts!(website: website)
```
**Seeds**: Pages and page components

### Pwb::ContentsSeeder
```ruby
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```
**Seeds**: Page content in all 15 languages

---

## Supported Languages (15 Total)

```
🇸🇦 Arabic (ar)          🇧🇬 Bulgarian (bg)
🇪🇸 Spanish (es)         🇮🇹 Italian (it)
🇫🇷 French (fr)          🇳🇱 Dutch (nl)
🇩🇪 German (de)          🇵🇱 Polish (pl)
🇬🇧 English (en) ← Default  🇵🇹 Portuguese (pt)
🇷🇴 Romanian (ro)        🇷🇺 Russian (ru)
🇰🇷 Korean (ko)          🇹🇷 Turkish (tr)
🇻🇳 Vietnamese (vi)
```

All non-English locales fallback to English if translation missing.

---

## YAML Seed Files Overview

```
agency.yml              │ Agency/company info
website.yml             │ Website config, theme, colors, currency
users.yml               │ Admin & default user accounts
contacts.yml            │ Contact records
field_keys.yml          │ Property types, states, features, amenities
links.yml               │ Navigation links

pages/                  │ Page definitions (home, about, contact, etc.)
page_parts/             │ Page sections (hero, search, footer, etc.)
content_translations/   │ Page content for each language (14 locale files)

prop/                   │ Standard properties (6 properties)
prop_spain/             │ Spain-specific properties (4 properties)
```

---

## Property Data Model

```
RealtyAsset (Physical property)
├── reference, location, dimensions, year_built
├── prop_type_key (apartment, villa, house, etc.)
└── prop_state_key (excellent, good, needs_renovation, etc.)
    │
    ├─→ SaleListing
    │   ├── price_sale_current_cents
    │   ├── visible, highlighted, archived
    │   └── Translations: title_en/es/de/etc., description_en/es/de/etc.
    │
    ├─→ RentalListing
    │   ├── price_rental_monthly_current_cents
    │   ├── for_rent_long_term, for_rent_short_term
    │   └── Translations: title_en/es/de/etc., description_en/es/de/etc.
    │
    ├─→ PropPhoto (1+ images)
    └─→ Feature (amenities/features)

ListedProperty (Read-only materialized view)
└── Optimized view of RealtyAsset + Listing data
```

---

## E2E Test Data Structure

**Two test tenants created:**
- tenant-a (3 users, 8 properties, 3 messages)
- tenant-b (3 users, 8 properties, 2 messages)

**Test Credentials:**
```
admin@tenant-a.test / password123
user@tenant-a.test / password123
admin@tenant-b.test / password123
user@tenant-b.test / password123
```

**URLs:**
```
Tenant A: http://tenant-a.e2e.localhost:3001
Tenant B: http://tenant-b.e2e.localhost:3001
```

---

## Factory Patterns for Testing

```ruby
# Basic website
website = create(:pwb_website)

# Property with sale listing and photos
property = create(
  :pwb_realty_asset,
  :luxury,                    # 5 bed, 3 bath, villa
  :with_location,             # Madrid coordinates
  :with_sale_listing,         # Create sale listing
  :with_photos,               # 2 images
  :with_features,             # Pool + garden
  website: website
)

# Rental property, short-term
rental = create(
  :pwb_realty_asset,
  :with_short_term_rental,
  website: website
)

# User for website
user = create(:pwb_user, website: website, admin: true)
```

---

## Multi-Tenancy Pattern

All these are **website-scoped** (multi-tenant):
- Properties (RealtyAsset, SaleListing, RentalListing)
- Users
- Contacts
- Pages
- PageParts
- Links
- Agency

These are **NOT scoped** (shared across all websites):
- Translations (i18n)
- FieldKeys (property taxonomy)

---

## Common Seeding Scenarios

### Add new tenant with complete setup
```ruby
website = Pwb::Website.create!(
  subdomain: 'mycompany',
  slug: 'mycompany',
  company_display_name: 'My Company',
  theme_name: 'bristol'
)

Pwb::Seeder.seed!(website: website)
Pwb::PagesSeeder.seed_page_basics!(website: website)
Pwb::PagesSeeder.seed_page_parts!(website: website)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

### Add properties to existing tenant
```ruby
website = Pwb::Website.find_by(subdomain: 'mycompany')
Pwb::Seeder.seed!(website: website)  # Seeds properties if < 4 exist
```

### Create test data in RSpec
```ruby
let(:website) { create(:pwb_website) }
let(:property) do
  create(
    :pwb_realty_asset,
    :luxury,
    :with_sale_listing,
    :with_photos,
    website: website
  )
end
```

### Reload seeder in Rails console
```ruby
load "#{Rails.root}/lib/pwb/seeder.rb"
load "#{Rails.root}/lib/pwb/pages_seeder.rb"
load "#{Rails.root}/lib/pwb/contents_seeder.rb"

website = Pwb::Website.first
Pwb::Seeder.seed!(website: website)
```

---

## Field Keys Categories

Property taxonomy stored in field_keys.yml:

| Category | Prefix | Examples |
|----------|--------|----------|
| **Types** | `types.` | apartment, villa, house, studio, etc. |
| **States** | `states.` | new_build, excellent, good, needs_renovation |
| **Features** | `features.` | private_pool, private_garden, terrace, fireplace |
| **Amenities** | `amenities.` | air_conditioning, alarm_system, solar_energy |
| **Status** | `status.` | available, reserved, sold, rented |
| **Highlights** | `highlights.` | featured, new_listing, luxury, exclusive |
| **Origin** | `origin.` | direct, bank, mls_feed, partner |

---

## Important Gotchas

1. **ListedProperty is READ-ONLY**
   ```ruby
   # ❌ WRONG
   Pwb::ListedProperty.create!(...)
   
   # ✅ RIGHT
   asset = Pwb::RealtyAsset.create!(...)
   listing = Pwb::SaleListing.create!(realty_asset: asset)
   Pwb::ListedProperty.refresh
   ```

2. **Always refresh materialized view after property changes**
   ```ruby
   Pwb::ListedProperty.refresh
   ```

3. **Seeding is idempotent** - safe to run multiple times
   ```ruby
   Pwb::Seeder.seed!  # Can run 10 times, won't duplicate
   ```

4. **Translation table is global, not website-scoped**
   ```ruby
   # ❌ Don't try to scope translations to website
   # ✅ Translations are shared across all websites
   ```

5. **Use factories in tests, not seeds**
   ```ruby
   # In tests:
   let(:property) { create(:pwb_realty_asset) }  # Fast
   
   # Not:
   let(:property) { Pwb::Seeder.seed! }  # Slow
   ```

---

## Performance Tips

1. **Conditional translation loading**: Already implemented, only loads if <600 translations exist
2. **Database cleaner for tests**: Uses transaction strategy for non-JS tests, truncation for JS
3. **Refresh materialized view once**: Call `Pwb::ListedProperty.refresh` at end of bulk operations
4. **Cache page parts content**: Use `Rails.cache.clear` after updating
5. **Batch property creation**: Loop through YAML and create in one transaction if possible

---

## Debugging Seeding

```ruby
# View current website
website = Pwb::Website.first

# Check seeded data
Pwb::RealtyAsset.where(website: website).count
Pwb::User.where(website: website).count
Pwb::Page.where(website: website).count

# View translations
I18n::Backend::ActiveRecord::Translation.where(locale: 'es').count

# Check field keys
Pwb::FieldKey.where(tag: 'property-types').count

# Verify materialized view
Pwb::ListedProperty.count
Pwb::ListedProperty.refresh  # Rebuild view
```

---

## File Size Reference

- `translations_en.rb`: ~3,500 lines (100+ translation keys)
- `e2e_seeds.rb`: ~670 lines
- `field_keys.yml`: ~389 lines (70+ field keys)
- Property YAML files: 1,500-1,600 lines each
- Page part YAML files: Variable, few hundred lines each
- Content translation YAML: Variable by locale

---

## Related Documentation

- See `SEEDING_ARCHITECTURE.md` for detailed explanation
- See `docs/09_Field_Keys.md` for property taxonomy details
- See `spec/factories/` for factory examples
- See Rails guides for I18n and database seeding
