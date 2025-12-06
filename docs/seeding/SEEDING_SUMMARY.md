# PropertyWebBuilder Seeding Architecture - Executive Summary

## What is Seeding?

Seeding initializes a Rails application with sample data needed for development, testing, and production. This project uses a sophisticated system to support:

- **Multi-tenancy**: Each website/tenant gets isolated seed data
- **15 languages**: Complete translation infrastructure
- **Normalized data**: Properties split into asset data + listing data
- **E2E testing**: Complete test environments with realistic data
- **FactoryBot patterns**: Flexible test data generation

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PropertyWebBuilder Seeding                    │
└─────────────────────────────────────────────────────────────────┘

ENTRY POINTS:
├─ bin/rails app:pwb:db:seed         ← Main production seeding
├─ RAILS_ENV=e2e bin/rails db:seed   ← E2E test setup
└─ FactoryBot in RSpec tests          ← Test-specific data

         │
         ▼

┌─────────────────────────────────────────────────────────────────┐
│              SEEDER ORCHESTRATOR CLASSES (lib/pwb/)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Pwb::Seeder                                        │       │
│  │  ├─ Translations (15 languages)                     │       │
│  │  ├─ Website Config                                 │       │
│  │  ├─ Agency                                         │       │
│  │  ├─ Users & Contacts                               │       │
│  │  ├─ Field Keys (Property Taxonomy)                 │       │
│  │  ├─ Properties (RealtyAsset + Listings)            │       │
│  │  └─ Links                                          │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Pwb::PagesSeeder                                  │       │
│  │  ├─ Page Basics (home, about, buy, rent, etc.)     │       │
│  │  └─ Page Parts (hero, search, footer, etc.)        │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Pwb::ContentsSeeder                               │       │
│  │  └─ Page Content (14 locale-specific YAML files)   │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

         │
         ▼

┌─────────────────────────────────────────────────────────────────┐
│               DATA SOURCE FILES (db/yml_seeds/ & db/seeds/)      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  YAML Files:                    Ruby Files:                     │
│  ├─ agency.yml                  ├─ translations_en.rb           │
│  ├─ website.yml                 ├─ translations_es.rb           │
│  ├─ users.yml                   ├─ translations_de.rb           │
│  ├─ contacts.yml                ├─ ... (15 language files)      │
│  ├─ field_keys.yml              ├─ e2e_seeds.rb                │
│  ├─ links.yml                   └─ spain/translations.rb        │
│  ├─ pages/*.yml (8 pages)                                       │
│  ├─ page_parts/*.yml (13 parts)                                 │
│  ├─ content_translations/*.yml (14 locales)                     │
│  ├─ prop/*.yml (6 properties)                                   │
│  └─ prop_spain/*.yml (4 properties)                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

         │
         ▼

┌─────────────────────────────────────────────────────────────────┐
│            DATABASE MODELS & RELATIONSHIPS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Website (Tenant)                                              │
│  ├─→ Agency                                                    │
│  ├─→ Users                                                     │
│  ├─→ Contacts                                                  │
│  ├─→ Pages                                                     │
│  ├─→ PageParts                                                 │
│  ├─→ Links                                                     │
│  ├─→ FieldKeys                                                 │
│  └─→ RealtyAsset (Properties)                                  │
│      ├─→ SaleListing (Translations: title_*, description_*) │
│      ├─→ RentalListing (Translations: title_*, description_*) │
│      ├─→ PropPhoto (ActiveStorage images)                      │
│      └─→ Feature (Amenities/Features)                          │
│                                                                 │
│  Global (Shared):                                              │
│  ├─→ I18n::Translation (15 languages of field key labels)      │
│  └─→ FieldKey (Taxonomy: types, states, features, etc.)       │
│                                                                 │
│  View (Read-only):                                             │
│  └─→ ListedProperty (Optimized view of RealtyAsset + Listing)  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Components Explained

### 1. Seeding Classes (lib/pwb/)

**Pwb::Seeder** - The main orchestrator
- Loads 15 language translation files
- Seeds website configuration, agency, users
- Creates properties using normalized models (RealtyAsset + Listings)
- Refreshes materialized view for optimized queries
- **Multi-tenant aware**: Each website gets its own data

**Pwb::PagesSeeder** - Creates page structure
- Seeds 8 core pages (home, about, buy, rent, sell, contact, legal, privacy)
- Attaches page components (page_parts)
- **Website-scoped**: Each tenant gets their own pages

**Pwb::ContentsSeeder** - Populates page content
- Loads content for 14 different locales
- Creates page content records from YAML templates
- Associates content with page components
- **Website-scoped**: Content per tenant, per locale

---

### 2. Language & Translation System

```
┌──────────────────────────────────────────────┐
│        15 Supported Languages               │
├──────────────────────────────────────────────┤
│ English (en) ← DEFAULT                      │
│ Spanish (es), French (fr), German (de)      │
│ Italian (it), Portuguese (pt), Dutch (nl)   │
│ Polish (pl), Romanian (ro), Russian (ru)    │
│ Turkish (tr), Korean (ko), Bulgarian (bg)   │
│ Arabic (ar), Vietnamese (vi)                │
└──────────────────────────────────────────────┘

TRANSLATION LAYERS:

Layer 1: I18n ActiveRecord Backend
┌────────────────────────────────────────┐
│ Translations Table (Global)             │
├────────────────────────────────────────┤
│ Types: "types.apartment" → "Apartment" │
│ States: "states.excellent" → "Good"    │
│ Features: "features.pool" → "Pool"     │
│ Amenities: "amenities.ac" → "AC"       │
│ Status: "status.available" → "Available"│
│ Highlights: "highlights.new" → "New"   │
│ Origin: "origin.direct" → "Direct"     │
└────────────────────────────────────────┘

Layer 2: Mobility JSONB Backend
┌────────────────────────────────────────┐
│ Listing.title_en = "Beautiful villa"   │
│ Listing.title_es = "Villa hermosa"     │
│ Listing.title_de = "Schöne Villa"      │
│ Listing.description_en = "..."         │
│ ... etc for 15 languages               │
└────────────────────────────────────────┘

LOCALE FALLBACK CHAIN:
Any non-English locale → English (if translation missing)

ACCESSOR PATTERN (from Mobility):
listing.title_en      # English title
listing.title_es      # Spanish title
listing.description_de # German description
... locale_en, _es, _de, _fr, etc.
```

---

### 3. Property Data Model

```
ONE PROPERTY = RealtyAsset + Listing(s)

RealtyAsset
├─ Physical Data (immutable)
│  ├─ Location (street, city, region, country, lat/long)
│  ├─ Dimensions (bedrooms, bathrooms, garages, area)
│  ├─ Year Built
│  ├─ Type Key (villa, apartment, house, etc.)
│  ├─ State Key (excellent, good, needs renovation)
│  └─ Photos (PropPhoto records)
│
└─ ONE-TO-MANY Relationships:
   │
   ├─→ SaleListing (Multiple sales possible in different currencies)
   │   ├─ Price (in cents, currency separate)
   │   ├─ Visibility flags (visible, archived, highlighted)
   │   ├─ Transaction flags (reserved, sold)
   │   └─ Translations: title_en/es/de/fr/..., description_en/es/...
   │
   ├─→ RentalListing (Multiple rental periods possible)
   │   ├─ Monthly Price
   │   ├─ Rental Type (long_term, short_term, furnished)
   │   ├─ Visibility flags (similar to Sale)
   │   └─ Translations: title_en/es/de/fr/..., description_en/es/...
   │
   ├─→ Feature (Permanent amenities)
   │   ├─ Pool, Garden, Terrace, Balcony
   │   ├─ Heating, AC, Security, etc.
   │   └─ feature_key references Field Key
   │
   └─→ PropPhoto (Multiple images)
       └─ ActiveStorage attachment

ListedProperty (Materialized View)
├─ Optimized query view
├─ Combines RealtyAsset + Listing data
├─ READ-ONLY (for queries only)
└─ Auto-refreshes when assets/listings change
```

---

### 4. Multi-Tenancy Pattern

```
┌─────────────────────────────────────────┐
│   Website A              Website B       │
│   ├─ Property 1         ├─ Property 5   │
│   ├─ Property 2         └─ Property 6   │
│   ├─ User: admin        └─ User: admin  │
│   ├─ Pages              └─ Pages        │
│   └─ Contacts           └─ Contacts     │
└─────────────────────────────────────────┘

SCOPED TO WEBSITE (multi-tenant):
✓ RealtyAsset, SaleListing, RentalListing
✓ User, Contact, Message
✓ Page, PagePart, PageContent
✓ Link, Agency, FieldKey

SHARED ACROSS WEBSITES (global):
✓ I18n::Translation (field key labels in 15 languages)
✓ Some FieldKeys (if configuration type)
```

---

### 5. E2E Test Setup

```
┌────────────────────────────────────────────────┐
│   E2E Test Environment (db/seeds/e2e_seeds.rb) │
├────────────────────────────────────────────────┤
│                                               │
│  Tenant A (tenant-a.e2e.localhost:3001)      │
│  ├─ Users                                    │
│  │  ├─ admin@tenant-a.test (password123)    │
│  │  └─ user@tenant-a.test (password123)     │
│  ├─ Contacts (2)                            │
│  ├─ Messages (3 sample emails)              │
│  └─ Properties (8)                          │
│     ├─ 4 For Sale (house, apt, villa, town) │
│     └─ 4 For Rent (apt, home, studio, pent) │
│                                             │
│  Tenant B (tenant-b.e2e.localhost:3001)     │
│  ├─ Users                                   │
│  │  ├─ admin@tenant-b.test (password123)   │
│  │  └─ user@tenant-b.test (password123)    │
│  ├─ Contacts (2)                           │
│  ├─ Messages (2 sample emails)             │
│  └─ Properties (8)                         │
│     ├─ 4 For Sale                          │
│     └─ 4 For Rent                          │
│                                            │
└────────────────────────────────────────────────┘
```

---

### 6. Test Data with FactoryBot

```
spec/factories/ (22 factory files)

FACTORY HIERARCHY:

Website Factory
├─ Sequence: subdomain (tenant1, tenant2, ...)
├─ After create: Creates associated Agency
└─ Traits: (extensible)

RealtyAsset Factory
├─ Sequence: reference (ASSET-1, ASSET-2, ...)
├─ Association: website (belongs_to)
├─ Traits:
│  ├─ :with_location → Sets lat/long (Madrid)
│  ├─ :luxury → 5bd, 3ba, villa
│  ├─ :with_sale_listing → Creates SaleListing
│  ├─ :with_rental_listing → Creates long-term RentalListing
│  ├─ :with_short_term_rental → Short-term rental
│  ├─ :with_photos → 2 images
│  ├─ :with_features → Pool + Garden
│  └─ :with_translations → Title & description in EN/ES/DE
│
└─ Composable: create(:pwb_realty_asset, :luxury, :with_photos, :with_sale_listing)

User Factory
├─ Association: website
├─ Traits:
│  ├─ :admin → admin: true
│  └─ :staff → admin: false

SaleListing & RentalListing Factories
├─ Association: realty_asset
└─ Traits:
   ├─ :visible → visible: true
   ├─ :highlighted → highlighted: true
   └─ :with_translations → Populates title/description for all locales

[Additional factories: Page, PagePart, Contact, Agency, Address, etc.]
```

---

## Data Seeding Flow

```
┌─────────────────────────────┐
│  Start Seeding Process      │
│  bin/rails app:pwb:db:seed │
└────────┬────────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Load Translations          │
    │ (15 language files)        │
    │ ↓ Save to translations DB  │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Website Config      │
    │ (from website.yml)         │
    │ ↓ Sets theme, currency, etc.
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Agency              │
    │ (from agency.yml)          │
    │ ↓ Company info & address   │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Users               │
    │ (from users.yml)           │
    │ ↓ Admin + default accounts │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Contacts            │
    │ (from contacts.yml)        │
    │ ↓ Contact records          │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Field Keys          │
    │ (from field_keys.yml)      │
    │ ↓ Property taxonomy        │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Properties          │
    │ (from prop/*.yml)          │
    │ ├─ Create RealtyAsset      │
    │ ├─ Create Listing(s)       │
    │ ├─ Attach Photos           │
    │ ├─ Add Features            │
    │ └─ Set Translations        │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Refresh Materialized View  │
    │ ListedProperty.refresh     │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Navigation Links    │
    │ (from links.yml)           │
    │ ↓ Navbar, footer links     │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Pages               │
    │ (from pages/*.yml)         │
    │ ↓ home, about, contact...  │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Create Page Parts          │
    │ (from page_parts/*.yml)    │
    │ ↓ hero, search, footer...  │
    └─────────┬──────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Populate Page Content      │
    │ (from content_*.yml)       │
    │ ↓ For each of 14 locales   │
    └────────┬────────────────────┘

         │
         ▼
    ┌────────────────────────────┐
    │ Seeding Complete!          │
    │ Database ready to use      │
    └────────────────────────────┘
```

---

## Quick Stats

| Item | Count | Location |
|------|-------|----------|
| **Languages** | 15 | config/initializers/i18n_globalise.rb |
| **Translation Seed Files** | 15 | db/seeds/translations_*.rb |
| **YAML Seed Files** | 30+ | db/yml_seeds/ |
| **Page Definitions** | 8 | pages/ |
| **Page Components** | 13+ | page_parts/ |
| **Sample Properties** | 10 | prop/ + prop_spain/ |
| **Seeder Classes** | 3 | lib/pwb/ |
| **Factory Files** | 22 | spec/factories/ |
| **Supported Property Types** | 19 | field_keys.yml |
| **Supported Property States** | 7 | field_keys.yml |
| **Property Features** | 26+ | field_keys.yml |
| **Property Amenities** | 18+ | field_keys.yml |
| **Translation Keys** | 100+ | translations table |

---

## Most Important Concepts

### 1. **Idempotent Seeding**
All seeds use `find_or_create_by`, safe to run multiple times.

### 2. **Website-Scoped Data**
Properties, pages, users are scoped to website for true multi-tenancy.

### 3. **Normalized Property Model**
- RealtyAsset = physical data (immutable)
- Listings = sale/rental-specific data (editable)
- This separation allows properties to have multiple listings simultaneously

### 4. **Translation Layers**
- Layer 1: I18n (field key labels in 15 languages)
- Layer 2: Mobility (listing titles/descriptions in 15 languages)

### 5. **Factory Pattern for Tests**
Use FactoryBot traits to compose test data, not seeds.

### 6. **Materialized View for Performance**
ListedProperty optimizes property queries, auto-updates via trigger.

---

## Common Tasks

```bash
# Full seed from scratch
bin/rails db:seed

# Seed single tenant
rails console
> website = Pwb::Website.find_by(subdomain: 'mysite')
> Pwb::Seeder.seed!(website: website)

# Seed for E2E testing
RAILS_ENV=e2e bin/rails db:seed

# Update page parts
bin/rails pwb:db:update_page_parts

# Create test data in RSpec
let(:property) { create(:pwb_realty_asset, :luxury, :with_sale_listing, :with_photos, website: website) }
```

---

## File Organization Philosophy

```
SEPARATION OF CONCERNS:

db/seeds/
├─ Ruby code (translations, e2e specific logic)
└─ Static assets (images for seeding)

db/yml_seeds/
├─ Configuration files (website, users, agency)
├─ Taxonomy files (field_keys)
├─ Page definitions (pages/, page_parts/)
├─ Content templates (content_translations/)
└─ Data files (prop/, prop_spain/)

lib/pwb/
├─ Seeder logic (orchestration)
└─ Helper classes (PagesSeeder, ContentsSeeder)

config/initializers/
├─ I18n configuration (locales, backends)
├─ Mobility configuration (translation storage)
└─ Other Rails config

spec/factories/
└─ Test data builders (22 factory files)
```

---

## Next Steps for Developers

1. **Read SEEDING_ARCHITECTURE.md** for comprehensive details
2. **Read SEEDING_QUICK_REFERENCE.md** for commands & examples
3. **Review a sample YAML file** to understand data structure
4. **Run `bin/rails app:pwb:db:seed`** to see seeding in action
5. **Check `spec/factories/`** for test data patterns
6. **Experiment in Rails console** with Seeder classes

---

## Key Files Reference

| Purpose | File | Lines |
|---------|------|-------|
| Main Seeder | `lib/pwb/seeder.rb` | 476 |
| Pages Seeder | `lib/pwb/pages_seeder.rb` | 114 |
| Contents Seeder | `lib/pwb/contents_seeder.rb` | 99 |
| E2E Seeds | `db/seeds/e2e_seeds.rb` | 670 |
| English Translations | `db/seeds/translations_en.rb` | 3,500+ |
| Website Config | `db/yml_seeds/website.yml` | 40 |
| Field Keys | `db/yml_seeds/field_keys.yml` | 389 |
| Properties | `db/yml_seeds/prop/villa_for_sale.yml` | 60 |

---

This seeding system provides a robust, scalable foundation for initializing PropertyWebBuilder instances with realistic data across multiple languages and multiple tenants.
