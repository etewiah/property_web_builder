# PropertyWebBuilder Seeding Architecture

## Overview

The PropertyWebBuilder Rails application implements a sophisticated multi-tenant seeding system that supports:
- **Multi-tenancy**: Each website/tenant gets its own scoped seed data
- **Multiple languages**: 15 languages configured with fallback to English
- **Normalized data models**: Properties are split into RealtyAsset (physical data) and Listings (sale/rental/translations)
- **Flexible seed sources**: YAML files, translation files, and programmatic seeders
- **E2E testing support**: Dedicated seed data for end-to-end testing

---

## Directory Structure

```
db/
├── seeds/                           # Ruby seed files & static assets
│   ├── e2e_seeds.rb                # E2E test data (multi-tenant setup)
│   ├── translations_*.rb            # Language translation seeds (15 files)
│   ├── spain/                       # Region-specific seeds (currently Spain only)
│   │   └── translations.rb
│   └── images/                      # Property images for seeding
│       ├── house_family.jpg
│       ├── apartment_luxury.jpg
│       ├── villa_ocean.jpg
│       └── ... (8 total images from Unsplash)
│
├── yml_seeds/                       # YAML configuration files
│   ├── agency.yml                   # Agency/company information
│   ├── agency_address.yml           # Agency address details
│   ├── website.yml                  # Website/tenant configuration
│   ├── users.yml                    # Default user accounts
│   ├── contacts.yml                 # Contact records
│   ├── field_keys.yml               # Property taxonomy (types, states, features, amenities)
│   ├── links.yml                    # Navigation links
│   │
│   ├── pages/                       # Page definitions
│   │   ├── home.yml
│   │   ├── about.yml
│   │   ├── buy.yml
│   │   ├── rent.yml
│   │   ├── sell.yml
│   │   ├── contact.yml
│   │   ├── privacy_policy.yml
│   │   └── legal_notice.yml
│   │
│   ├── page_parts/                  # Page components/sections
│   │   ├── home__landing_hero.yml
│   │   ├── home__search_cmpt.yml
│   │   ├── home__about_us_services.yml
│   │   ├── home__content_html.yml
│   │   ├── about-us__*.yml
│   │   ├── contact-us__*.yml
│   │   ├── sell__content_html.yml
│   │   ├── website__footer_*.yml
│   │   └── ... (other page parts)
│   │
│   ├── content_translations/        # Page content by locale
│   │   ├── en.yml
│   │   ├── es.yml
│   │   ├── ca.yml
│   │   ├── de.yml
│   │   ├── fr.yml
│   │   ├── it.yml
│   │   ├── nl.yml
│   │   ├── pl.yml
│   │   ├── pt.yml
│   │   ├── ro.yml
│   │   ├── ru.yml
│   │   ├── ko.yml
│   │   ├── tr.yml
│   │   ├── bg.yml
│   │   └── vi.yml
│   │
│   ├── prop/                        # Standard property seeds
│   │   ├── villa_for_sale.yml
│   │   ├── villa_for_rent.yml
│   │   ├── flat_for_sale.yml
│   │   ├── flat_for_sale_2.yml
│   │   ├── flat_for_rent.yml
│   │   └── flat_for_rent_2.yml
│   │
│   ├── prop_spain/                  # Region-specific property seeds
│   │   ├── villa_for_sale.yml
│   │   ├── villa_for_rent.yml
│   │   ├── flat_for_sale.yml
│   │   └── flat_for_rent.yml
│   │
│   └── page_parts_older_bootstrap/  # Legacy page parts (Bootstrap)
│
└── migrate/                         # Database migrations
```

---

## Seeding Architecture Components

### 1. Main Seeder Classes (in `lib/pwb/`)

#### **Pwb::Seeder** (`lib/pwb/seeder.rb`)
- **Primary responsibility**: Orchestrates all seeding operations
- **Multi-tenancy support**: Accepts optional `website` parameter
- **Main method**: `Pwb::Seeder.seed!(website: nil, skip_properties: false)`

**Key features:**
- Seeds translations from 15 language files
- Creates/updates website configuration
- Seeds agency information
- Seeds users and contacts
- Seeds field keys (property taxonomy)
- Seeds navigation links
- Seeds properties with proper multi-tenant isolation
- Handles both legacy properties (YAML) and normalized properties (RealtyAsset + Listings)

**Multi-tenancy details:**
```ruby
# Seeds are scoped to the current website
Pwb::Seeder.seed!(website: website)

# If no website provided, uses first website or creates one
# Data scoped to website: properties, agency, users, contacts, links
# Global data (not website-specific): translations, field_keys
```

**Property seeding flow:**
1. Loads YAML files from `db/yml_seeds/prop/`
2. Extracts asset data (physical property info)
3. Creates `Pwb::RealtyAsset` record
4. Creates associated `Pwb::SaleListing` or `Pwb::RentalListing` with translations
5. Attaches photos via ActiveStorage
6. Adds features/amenities to asset
7. Refreshes materialized view `Pwb::ListedProperty`

#### **Pwb::PagesSeeder** (`lib/pwb/pages_seeder.rb`)
- **Purpose**: Seeds pages and page structure
- **Multi-tenancy**: Each website gets its own pages

**Key methods:**
- `seed_page_basics!(website: website)`: Creates page records (home, about, buy, rent, sell, contact, legal, privacy)
- `seed_page_parts!(website: website)`: Creates page sections/components associated with a website

**Page association:**
- Pages are owned by a website
- PageParts are also scoped to website for multi-tenant isolation
- Each page can have multiple page_parts

#### **Pwb::ContentsSeeder** (`lib/pwb/contents_seeder.rb`)
- **Purpose**: Seeds actual page content and translations
- **Multi-tenancy**: Content is seeded for each website's pages

**Key method:**
- `seed_page_content_translations!(website: website)`: Loads content from locale-specific YAML files

**Content structure:**
```yaml
# From content_translations/en.yml
locale:
  website:          # Global website-level content
    page_part_key:
      content: ...
  page_slug:        # Page-specific content
    page_part_key:
      content: ...
```

---

### 2. Locale & Language Configuration

#### **Configured Locales** (from `config/initializers/i18n_globalise.rb`)
```ruby
I18n.available_locales = [
  :ar,  # Arabic
  :ca,  # Catalan
  :de,  # German
  :en,  # English (default)
  :es,  # Spanish
  :fr,  # French
  :it,  # Italian
  :nl,  # Dutch
  :pl,  # Polish
  :pt,  # Portuguese
  :ro,  # Romanian
  :ru,  # Russian
  :tr,  # Turkish
  :vi,  # Vietnamese
  :ko,  # Korean
  :bg   # Bulgarian
]
```

#### **Translation Backend** (`config/initializers/i18n_backend.rb`)
- Uses `I18n::Backend::ActiveRecord` when database is available
- Falls back to `I18n::Backend::Simple` for YAML files
- Implements a **chain backend** combining both sources

#### **Fallback Configuration** (`config/initializers/i18n_globalise.rb`)
```ruby
Globalize.fallbacks = {
  de: [:en], es: [:en], pl: [:en], ro: [:en], 
  ru: [:en], ko: [:en], bg: [:en]
  # All non-English locales fall back to English
}
```

#### **Mobility Configuration** (`config/initializers/mobility.rb`)
- Uses **Container backend** (JSONB storage)
- Provides **locale accessors**: `title_en`, `title_es`, `title_de`, etc.
- Implements **fallback chain**: All locales fall back to English
- Cache plugin for performance

---

### 3. Translation Seeds

Translation seed files live in `db/seeds/translations_*.rb` (one per language).

#### **Structure of Translation Files**
Each file contains `I18n::Backend::ActiveRecord::Translation.create!` calls:

```ruby
# Example from translations_en.rb
{locale: "en", key: "types.apartment", value: "Apartment"},
{locale: "en", key: "types.villa", value: "Villa"},
{locale: "en", key: "states.excellent", value: "Excellent Condition"},
{locale: "en", key: "features.private_pool", value: "Private Pool"},
{locale: "en", key: "amenities.air_conditioning", value: "Air Conditioning"},
```

#### **Translation Categories**
1. **Property Types** (`types.*`): What the property IS
   - apartment, flat, villa, detached_house, townhouse, bungalow, studio, penthouse, etc.

2. **Property States** (`states.*`): Physical condition
   - new_build, excellent, good, needs_renovation, renovated, second_hand, under_construction

3. **Property Features** (`features.*`): Permanent physical attributes
   - private_pool, heated_pool, private_garden, terrace, balcony, private_garage, fireplace, etc.

4. **Property Amenities** (`amenities.*`): Equipment & services
   - air_conditioning, central_heating, alarm_system, video_entry, security, solar_energy, etc.

5. **Property Status** (`status.*`): Transaction/listing status
   - available, reserved, under_offer, sold, rented, off_market

6. **Property Highlights** (`highlights.*`): Marketing flags
   - featured, new_listing, price_reduced, luxury, exclusive, investment_opportunity

7. **Listing Origin** (`origin.*`): Data source
   - direct, bank, private_seller, new_development, mls_feed, partner

#### **Conditional Translation Loading**
```ruby
# From Pwb::Seeder
should_load_translations = ENV["RAILS_ENV"] == "test" || 
                           I18n::Backend::ActiveRecord::Translation.all.length <= 600

if should_load_translations
  load File.join(Rails.root, "db", "seeds", "translations_en.rb")
  load File.join(Rails.root, "db", "seeds", "translations_es.rb")
  # ... etc
end
```

---

### 4. YAML Seed Files

#### **Website Configuration** (`website.yml`)
```yaml
company_display_name: Example Real Estate
theme_name: bristol
default_currency: USD
default_client_locale: "en-US"
default_admin_locale: "en-US"
supported_locales: ["en-US", "es-MX"]
default_area_unit: 0  # 0=sqmt, 1=sqft
style_variables_for_theme:
  default:
    primary_color: "#008000"
    secondary_color: "#8ec449"
    # ... more theme config
```

#### **User Configuration** (`users.yml`)
```yaml
---
- email: admin@example.com
  password: pwb123456
  admin: true
  first_names: Admin
  last_names: Example
  website_id: [website_id]  # Optional, for multi-tenancy
- email: non_admin@example.com
  password: pwb123456
  admin: false
  # ...
```

#### **Field Keys** (`field_keys.yml`)
```yaml
---
- global_key: types.apartment
  tag: property-types
  visible: true
  sort_order: 1
- global_key: states.excellent
  tag: property-states
  visible: true
  sort_order: 1
```

#### **Property YAML** (`prop/villa_for_sale.yml`)
```yaml
---
- reference: re-s1
  prop_type_key: types.villa
  prop_state_key: states.good
  for_sale: true
  for_rent_long_term: false
  for_rent_short_term: false
  price_sale_current_cents: 30000000
  currency: USD
  count_bedrooms: 2
  count_bathrooms: 2
  count_garages: 1
  constructed_area: 190.0
  plot_area: 550.0
  year_construction: 2015
  street_address: Providence Boulevard
  city: South Brunswick Township
  region: New Jersey
  postal_code: 08824
  country: United States
  latitude: 40.4076591
  longitude: -74.5798604
  title_en: Example country house for sale
  title_es: Ejemplo de villa para vender
  description_en: Description text...
  description_es: Descripción...
  photo_files:
    - db/example_images/new_villa.jpg
    - db/example_images/kitchen_modern.jpg
  visible: true
  highlighted: false
```

#### **Page Configuration** (`pages/home.yml`)
```yaml
---
- slug: home
  setup_id: home
  visible: true
  page_title_en: Home
  page_title_es: Inicio
  page_title_fr: Accueil
  details: {}
```

#### **Page Parts** (`page_parts/home__landing_hero.yml`)
```yaml
---
- page_part_key: home__landing_hero
  page_slug: home
  setup_id: home__landing_hero
  # ... more configuration
```

---

### 5. Property Data Models

#### **RealtyAsset** (normalized physical property data)
- Stores: reference, location, dimensions, year built, property type/state
- Has many: SaleListings, RentalListings, Features, PropPhotos
- Website association: `belongs_to :website`

#### **SaleListing** (sale-specific data with translations)
- Stores: price, visibility, highlighted status, archived, reserved
- Translations: title_en, title_es, description_en, description_es, etc. (via Mobility)
- Belongs to: RealtyAsset
- Currency: Stored separately per listing

#### **RentalListing** (rental-specific data with translations)
- Stores: monthly price, furnished status, long_term/short_term flags
- Translations: Same as SaleListing
- Belongs to: RealtyAsset

#### **ListedProperty** (read-only materialized view)
- Optimized view combining RealtyAsset + Listing data
- **READ-ONLY**: Use RealtyAsset/Listing for writes
- Automatically refreshed after property modifications
- Used for fast property searches and listings

**Example refresh:**
```ruby
Pwb::ListedProperty.refresh
```

---

### 6. E2E Testing Seeds

#### **E2E Seeds File** (`db/seeds/e2e_seeds.rb`)
Purpose: Create complete, isolated test environments for Playwright E2E tests

**What it creates:**
1. **Multi-tenant setup**:
   - tenant-a: Admin & regular user
   - tenant-b: Admin & regular user

2. **Users** (test credentials):
   - admin@tenant-a.test / password123
   - user@tenant-a.test / password123
   - admin@tenant-b.test / password123
   - user@tenant-b.test / password123

3. **Contacts & Messages**:
   - Sample contacts for each tenant
   - 3 messages for tenant-a (property inquiry, general, urgent)
   - 2 messages for tenant-b (investment, rental)

4. **Properties** (8 properties per tenant):
   - **For Sale**: 4 properties (family home, apartment, villa, townhouse)
   - **For Rent**: 4 properties (downtown apartment, family home, studio, penthouse)

5. **Property Details**:
   - Full location data with coordinates
   - Bedroom/bathroom counts
   - Price in USD
   - Features and amenities
   - Images from Unsplash
   - Translations (sales listings in English)

#### **Usage**:
```bash
# Seed for E2E testing
RAILS_ENV=e2e bin/rails db:seed:replant
# Then load the specific E2E seeds
bin/rails db:seed:e2e
```

---

### 7. Factory Patterns

**Location**: `spec/factories/pwb_*.rb` (22 factory files)

**Key factories:**
- `pwb_website`: With agency creation in after(:create)
- `pwb_realty_asset`: With traits for location, luxury, listings, photos, features
- `pwb_sale_listing`: With traits for visibility, translations
- `pwb_rental_listing`: With traits for long_term, short_term, furnished
- `pwb_page`: Page factory for testing
- `pwb_page_part`: Page part factory
- `pwb_user`: User factory with website association
- `pwb_contact`: Contact factory
- `pwb_agency`: Agency factory

**Example trait usage**:
```ruby
# From pwb_realty_assets.rb
factory :pwb_realty_asset do
  trait :with_sale_listing do
    after(:create) { |asset| create(:pwb_sale_listing, :visible, realty_asset: asset) }
  end
  
  trait :with_features do
    after(:create) do |asset|
      create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'pool')
      create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'garden')
    end
  end
end

# Usage in tests:
build(:pwb_realty_asset, :luxury, :with_location, :with_sale_listing, :with_photos)
```

---

### 8. Rake Tasks

#### **Main Seeding Task**
```bash
# Standard seed
bin/rails app:pwb:db:seed

# Seed specific website
# (Called programmatically: Pwb::Seeder.seed!(website: website_instance))

# Seed pages
bin/rails app:pwb:db:seed_pages
```

#### **Update Page Parts Task** (`lib/tasks/pwb_update_seeds.rake`)
```bash
bin/rails pwb:db:update_page_parts
```
- Updates page part definitions from YAML
- Rebuilds content for all locales
- Clears cache

---

### 9. Test Environment Setup

#### **Test Configuration** (`spec/spec_helper.rb`)
- Uses **FactoryBot** for test data (no fixtures)
- **DatabaseCleaner** for test isolation
  - Transactional strategy for non-JS tests
  - Truncation strategy for JS tests
- **SimpleCov** for code coverage
- **VCR** for HTTP mocking
- Capybara with Apparition (headless Chrome)

#### **Test Database Seeding**
- Tests create data via FactoryBot, NOT seeds
- Translation loading is skipped in test env to speed up tests
- Database is cleaned between test runs

---

## Data Flow Diagram

```
Entry Points:
├── bin/rails app:pwb:db:seed
├── Pwb::Seeder.seed!(website: website, skip_properties: false)
└── db/seeds/e2e_seeds.rb

Seeder Classes:
├── Pwb::Seeder
│   ├── Loads translations (translations_*.rb)
│   ├── Creates website config (website.yml)
│   ├── Creates agency (agency.yml)
│   ├── Creates users (users.yml)
│   ├── Creates contacts (contacts.yml)
│   ├── Creates field keys (field_keys.yml)
│   ├── Creates properties (prop/*.yml)
│   │   └── Creates RealtyAsset + SaleListing/RentalListing
│   │       └── Refreshes ListedProperty view
│   └── Creates links (links.yml)
│
├── Pwb::PagesSeeder
│   ├── seed_page_basics!(website: website)
│   │   └── Loads pages/*.yml → Creates Page records
│   └── seed_page_parts!(website: website)
│       └── Loads page_parts/*.yml → Creates PagePart records
│
└── Pwb::ContentsSeeder
    └── seed_page_content_translations!(website: website)
        └── Loads content_translations/*.yml → Creates PageContent records
            └── Associates content with PageParts

Locale Resolution:
I18n.available_locales (15 languages)
├── Each locale falls back to English if translation missing
├── Mobility provides locale_accessors (title_en, title_es, etc.)
└── Container backend stores translations in JSONB

Multi-tenancy Scoping:
├── Website (tenant)
│   ├── Properties (RealtyAsset)
│   ├── Users
│   ├── Contacts
│   ├── Pages
│   ├── PageParts
│   ├── Links
│   └── Agency
└── Shared across tenants:
    ├── Translations
    ├── FieldKeys
    └── TranslationBackend data
```

---

## Key Design Patterns

### 1. **Multi-Tenancy Pattern**
- Website ID association for all scoped models
- Separate seeds per website possible
- Shared global data (translations, field keys)

### 2. **Normalized Data Pattern**
- RealtyAsset: Core property data (immutable)
- SaleListing/RentalListing: Listing-specific data (can be edited)
- Proper separation of concerns

### 3. **Translation Strategy**
- I18n for UI labels (translations table)
- Mobility for model translations (JSONB in listings)
- Fallback chain to English

### 4. **Idempotent Seeding**
- Seeds use `find_or_create_by` pattern
- Safe to run multiple times
- Conditional translation loading to avoid duplicates

### 5. **Testing with Factories**
- No YAML fixtures in test suite
- FactoryBot builds objects with traits
- Faster than loading seed data
- More flexible for test scenarios

---

## Common Seeding Scenarios

### Scenario 1: Seed a New Tenant
```ruby
website = Pwb::Website.create!(
  subdomain: 'newcompany',
  slug: 'newcompany',
  company_display_name: 'New Company Real Estate',
  theme_name: 'bristol'
)

Pwb::Seeder.seed!(website: website)
Pwb::PagesSeeder.seed_page_basics!(website: website)
Pwb::PagesSeeder.seed_page_parts!(website: website)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

### Scenario 2: Add Properties to Existing Tenant
```ruby
website = Pwb::Website.find_by(subdomain: 'mycompany')
Pwb::Seeder.seed!(website: website, skip_properties: false)
```

### Scenario 3: Create Test Data in RSpec
```ruby
# In spec:
let(:website) { create(:pwb_website, :with_pages) }
let(:property) { create(:pwb_realty_asset, :luxury, :with_sale_listing, :with_photos, website: website) }
```

### Scenario 4: E2E Testing with Multiple Tenants
```bash
# Use dedicated E2E seeds
RAILS_ENV=e2e bin/rails db:seed
```

---

## Locale & Language Specifics

### Supported Locales
| Code | Language | Fallback |
|------|----------|----------|
| ar | Arabic | English |
| bg | Bulgarian | English |
| ca | Catalan | English |
| de | German | English |
| en | English | (default) |
| es | Spanish | English |
| fr | French | English |
| it | Italian | English |
| ko | Korean | English |
| nl | Dutch | English |
| pl | Polish | English |
| pt | Portuguese | English |
| ro | Romanian | English |
| ru | Russian | English |
| tr | Turkish | English |
| vi | Vietnamese | English |

### Website Configuration
Each website can configure:
- `default_client_locale`: Frontend language
- `default_admin_locale`: Admin interface language
- `supported_locales`: Array of available locales for that site

### Translation Accessibility
```ruby
# Via I18n (system translations)
I18n.t("types.apartment", locale: :es)  # From translations table

# Via Mobility (model translations)
listing.title_en   # English title
listing.title_es   # Spanish title
listing.description_de  # German description
```

---

## Important Notes

1. **Do NOT create ListedProperty directly**: It's a read-only materialized view
2. **Always refresh ListedProperty after property changes**: `Pwb::ListedProperty.refresh`
3. **Seed idempotency**: All seed operations are safe to run multiple times
4. **Translation table is global**: Not website-scoped
5. **FieldKeys are shared**: Available across all websites
6. **Multi-tenant isolation**: Properties, Pages, Users, Contacts are website-scoped
7. **Test performance**: Use factories in tests, not seeds

---

## Future Expansion Points

1. **Region-specific seeds**: Currently minimal Spain support, can expand
2. **Additional property types**: Easily add via field_keys.yml
3. **More languages**: Add translation files and update i18n_globalise.rb
4. **Bulk import**: CSV/JSON import functionality
5. **Property photos**: Can load from URLs or files (currently supports both)
6. **Advanced seeding**: Parametric property generation for load testing
