# PropertyWebBuilder Seeding System - Comprehensive Guide

This document provides a complete overview of the PropertyWebBuilder seeding infrastructure, including how seeds work, what gets seeded, and what needs to be updated for the new page part library.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture & Components](#architecture--components)
3. [Seeding Process Flow](#seeding-process-flow)
4. [Data Models & Relationships](#data-models--relationships)
5. [Seed Files & Directory Structure](#seed-files--directory-structure)
6. [Currently Seeded Page Parts](#currently-seeded-page-parts)
7. [Currently Seeded Pages & Content](#currently-seeded-pages--content)
8. [Seed Packs System](#seed-packs-system)
9. [SeedRunner Features](#seedrunner-features)
10. [Multi-Language & Locale System](#multi-language--locale-system)
11. [Updating Seeds for New Page Part Library](#updating-seeds-for-new-page-part-library)
12. [How to Add New Page Parts to Seeds](#how-to-add-new-page-parts-to-seeds)

---

## Overview

The PropertyWebBuilder seeding system is a sophisticated, multi-tenant infrastructure that:

- **Initializes databases** with realistic sample data
- **Supports 15 languages** with full translation infrastructure
- **Isolates data per tenant** (website) for multi-tenancy
- **Uses a normalized property model** (RealtyAsset + Listings) for flexibility
- **Provides scenario-based seeding** via Seed Packs
- **Enables E2E testing** with complete test environments
- **Uses FactoryBot patterns** for test data generation

### Key Principles

1. **Idempotent**: All seeds use `find_or_create_by`, safe to run multiple times
2. **Multi-tenant isolated**: Data scoped to website unless explicitly shared
3. **Normalized property model**: Physical data (asset) separate from transaction data (listings)
4. **Composable**: Seed packs inherit from base, pages have page parts with sections

---

## Architecture & Components

### Core Seeder Classes (in `lib/pwb/`)

#### 1. **Pwb::Seeder** (`lib/pwb/seeder.rb`) - Main Orchestrator
- **Responsibility**: Coordinates all seeding operations
- **Entry point**: `Pwb::Seeder.seed!(website: nil, skip_properties: false)`
- **Multi-tenant support**: Optional `website` parameter
- **Scope**: Handles translations, website config, agency, users, contacts, field keys, properties, links

**Key methods:**
- `seed_properties()` - Creates RealtyAsset + SaleListing/RentalListing records
- `create_normalized_property_records(prop_data, photos)` - Builds normalized property structure
- `set_listing_translations(listing, prop_data)` - Sets multi-language titles/descriptions

#### 2. **Pwb::PagesSeeder** (`lib/pwb/pages_seeder.rb`) - Page Structure
- **Responsibility**: Creates pages and page parts
- **Methods**:
  - `seed_page_basics!(website: website)` - Creates 8 core pages
  - `seed_page_parts!(website: website)` - Creates page parts from YAML

**Pages created:**
- home, about, buy, rent, sell, contact, legal_notice, privacy_policy

**Page parts created:** (from YAML files in `db/yml_seeds/page_parts/`)

#### 3. **Pwb::ContentsSeeder** (`lib/pwb/contents_seeder.rb`) - Page Content
- **Responsibility**: Populates page content from locale-specific YAML
- **Method**: `seed_page_content_translations!(website: website)`
- **Coverage**: 14 locales (en, es, it, nl, pt, tr, and others)
- **Structure**: Content nested by locale → container (website/page) → page_part → block → content

#### 4. **Pwb::SeedRunner** (`lib/pwb/seed_runner.rb`) - Enhanced Orchestrator
- **Responsibility**: Safe, interactive seed execution with user prompts
- **Modes**: interactive, create_only, force_update, upsert
- **Features**:
  - Dry-run preview
  - Existing data detection
  - User confirmation for updates
  - Progress logging
  - Statistics tracking

**Usage:**
```ruby
Pwb::SeedRunner.run(
  website: website,
  mode: :interactive,
  dry_run: false,
  skip_properties: false,
  verbose: true
)
```

#### 5. **Pwb::SeedPack** (`lib/pwb/seed_pack.rb`) - Scenario Bundles
- **Responsibility**: Pre-configured seed scenarios
- **Structure**: Each pack is a directory with pack.yml + data files
- **Features**:
  - Pack inheritance (`inherits_from: base`)
  - Composability
  - Scenario-specific customization

**Available packs:**
- `base` - Foundation pack with shared field keys, links, pages
- `spain_luxury` - Spanish luxury properties scenario

---

## Seeding Process Flow

```
Entry Point:
└─ Pwb::Seeder.seed!(website: website, skip_properties: false)
   │
   ├─ Load Translations (15 language files)
   │  └─ db/seeds/translations_*.rb → I18n::Backend::ActiveRecord::Translation table
   │
   ├─ Seed Agency
   │  └─ db/yml_seeds/agency.yml → Pwb::Agency
   │
   ├─ Seed Website Config
   │  └─ db/yml_seeds/website.yml → Pwb::Website (theme, currency, locales)
   │
   ├─ Seed Properties
   │  ├─ db/yml_seeds/prop/*.yml
   │  ├─ Create Pwb::RealtyAsset (physical property data)
   │  ├─ Create Pwb::SaleListing (if for_sale)
   │  │  └─ Set translations (title_en, title_es, description_en, etc.)
   │  ├─ Create Pwb::RentalListing (if for_rent)
   │  │  └─ Set translations
   │  ├─ Attach PropPhotos (via ActiveStorage)
   │  ├─ Add Features (amenities)
   │  └─ Refresh Pwb::ListedProperty materialized view
   │
   ├─ Seed Field Keys
   │  └─ db/yml_seeds/field_keys.yml → Pwb::FieldKey (property taxonomy)
   │
   ├─ Seed Users
   │  └─ db/yml_seeds/users.yml → Pwb::User
   │
   ├─ Seed Contacts
   │  └─ db/yml_seeds/contacts.yml → Pwb::Contact
   │
   └─ Seed Links
      └─ db/yml_seeds/links.yml → Pwb::Link

Separate processes:
├─ Pwb::PagesSeeder.seed_page_basics!(website: website)
│  └─ db/yml_seeds/pages/*.yml → Creates 8 pages
│
├─ Pwb::PagesSeeder.seed_page_parts!(website: website)
│  └─ db/yml_seeds/page_parts/*.yml → Creates page parts
│
└─ Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
   └─ db/yml_seeds/content_translations/*.yml → Creates PageContent records
      (for 14 locales: en, es, it, nl, pt, tr, and others)
```

---

## Data Models & Relationships

### Property Model Hierarchy

```
RealtyAsset (Physical property data - immutable)
├─ website_id (multi-tenant)
├─ reference (unique per website)
├─ Location: street_address, city, region, country, postal_code, lat/long
├─ Dimensions: bedrooms, bathrooms, garages, area, plot_area
├─ Year Built, Type Key, State Key
│
├─ Has Many: SaleListing (one or more sale listings possible)
│  ├─ price_sale_current_cents
│  ├─ price_sale_current_currency
│  ├─ visible, highlighted, archived, reserved
│  ├─ Translations (via Mobility):
│  │  ├─ title_en, title_es, title_de, title_fr, ...
│  │  └─ description_en, description_es, description_de, ...
│  └─ Created/Updated timestamps
│
├─ Has Many: RentalListing (long-term, short-term, or both)
│  ├─ price_rental_monthly_current_cents
│  ├─ price_rental_monthly_current_currency
│  ├─ furnished, for_rent_long_term, for_rent_short_term
│  ├─ visible, highlighted, archived, reserved
│  ├─ Translations (via Mobility):
│  │  ├─ title_en, title_es, title_de, title_fr, ...
│  │  └─ description_en, description_es, description_de, ...
│  └─ Created/Updated timestamps
│
├─ Has Many: PropPhoto (via ActiveStorage)
│  └─ image.attach(io: file, filename: "...", content_type: "image/jpeg")
│
└─ Has Many: Feature (Amenities/features)
   └─ feature_key (references FieldKey)

ListedProperty (Materialized View - READ ONLY)
├─ Combines RealtyAsset + Listing data
├─ Optimized for queries
├─ Auto-refreshes: Pwb::ListedProperty.refresh
└─ DO NOT use ListedProperty.create! (will raise ReadOnlyRecord error)
```

### Page/Content Hierarchy

```
Website
├─ Has Many: Page
│  ├─ slug (home, about, buy, rent, sell, contact, legal_notice, privacy_policy)
│  ├─ page_title_en, page_title_es, page_title_de, ...
│  ├─ setup_id, visible, details (JSON)
│  │
│  └─ Has Many: PagePart (page-specific components)
│     ├─ page_part_key (e.g., "landing_hero", "about_us_services")
│     ├─ order_in_editor
│     ├─ show_in_editor
│     ├─ template (Liquid template code)
│     │
│     └─ Has Many: PageContent
│        ├─ locale (en, es, de, etc.)
│        └─ content_blocks (JSON):
│           └─ label → content mapping
│
└─ Has Many: PagePart (website-level - not tied to specific page)
   └─ Can be used on footer, header, etc.
```

### Field Keys (Property Taxonomy)

```
Pwb::FieldKey
├─ global_key: "types.apartment"
├─ tag: "property-types"
├─ visible: true
├─ sort_order: 1
│
Categories:
├─ Property Types (19 types)
│  └─ apartment, villa, house, flat, townhouse, bungalow, studio, penthouse, etc.
│
├─ Property States (7 states)
│  └─ new_build, excellent, good, needs_renovation, renovated, second_hand, under_construction
│
├─ Property Features (26+ features)
│  └─ private_pool, heated_pool, private_garden, terrace, balcony, fireplace, etc.
│
├─ Property Amenities (18+ amenities)
│  └─ air_conditioning, central_heating, alarm_system, video_entry, security, solar_energy, etc.
│
├─ Property Status (5 statuses)
│  └─ available, reserved, under_offer, sold, rented
│
├─ Property Highlights (6 highlights)
│  └─ featured, new_listing, price_reduced, luxury, exclusive, investment_opportunity
│
└─ Listing Origin (5 origins)
   └─ direct, bank, private_seller, new_development, mls_feed
```

---

## Seed Files & Directory Structure

### Directory Tree

```
db/
├── seeds/
│   ├── e2e_seeds.rb                           # E2E test data (multi-tenant)
│   ├── translations_*.rb (15 files)           # Language translations
│   │   ├── translations_en.rb (3,500+ lines)
│   │   ├── translations_es.rb
│   │   ├── translations_de.rb
│   │   └── ... (12 more languages)
│   ├── images/                                # Shared property images (from Unsplash)
│   │   ├── house_family.jpg
│   │   ├── apartment_luxury.jpg
│   │   ├── villa_ocean.jpg
│   │   └── ... (8 images total)
│   ├── packs/                                 # Seed pack scenarios
│   │   ├── base/
│   │   │   ├── pack.yml
│   │   │   ├── field_keys.yml
│   │   │   └── links.yml
│   │   └── spain_luxury/
│   │       ├── pack.yml
│   │       ├── field_keys.yml
│   │       ├── properties/
│   │       │   └── *.yml
│   │       ├── images/
│   │       │   └── property_images.jpg
│   │       └── translations/
│   │           ├── es.yml
│   │           ├── en.yml
│   │           └── de.yml
│   │
│   └── spain/
│       └── translations.rb                    # Spanish-specific translations
│
└── yml_seeds/                                 # YAML configuration files
    ├── agency.yml                             # Agency/company info
    ├── agency_address.yml                     # Agency address
    ├── website.yml                            # Website/tenant settings
    ├── users.yml                              # User accounts
    ├── contacts.yml                           # Contact records
    ├── field_keys.yml                         # Property taxonomy
    ├── links.yml                              # Navigation links
    │
    ├── pages/                                 # 8 page definitions
    │   ├── home.yml
    │   ├── about.yml
    │   ├── buy.yml
    │   ├── rent.yml
    │   ├── sell.yml
    │   ├── contact.yml
    │   ├── privacy_policy.yml
    │   └── legal_notice.yml
    │
    ├── page_parts/                            # Page components (13 current)
    │   ├── home__landing_hero.yml
    │   ├── home__search_cmpt.yml
    │   ├── home__about_us_services.yml
    │   ├── home__content_html.yml
    │   ├── about-us__content_html.yml
    │   ├── about-us__our_agency.yml
    │   ├── contact-us__content_html.yml
    │   ├── contact-us__form_and_map.yml
    │   ├── legal__content_html.yml
    │   ├── privacy__content_html.yml
    │   ├── sell__content_html.yml
    │   ├── website__footer_content_html.yml
    │   └── website__footer_social_links.yml
    │
    ├── content_translations/                  # Page content (14 locales)
    │   ├── en.yml
    │   ├── es.yml
    │   ├── it.yml
    │   ├── nl.yml
    │   ├── pt.yml
    │   ├── tr.yml
    │   └── (8 more locale files)
    │
    ├── prop/                                  # 6 standard properties
    │   ├── villa_for_sale.yml
    │   ├── villa_for_rent.yml
    │   ├── flat_for_sale.yml
    │   ├── flat_for_sale_2.yml
    │   ├── flat_for_rent.yml
    │   └── flat_for_rent_2.yml
    │
    ├── prop_spain/                            # 4 Spain-specific properties
    │   ├── villa_for_sale.yml
    │   ├── villa_for_rent.yml
    │   ├── flat_for_sale.yml
    │   └── flat_for_rent.yml
    │
    └── page_parts_older_bootstrap/            # Legacy Bootstrap-based parts (deprecated)
```

---

## Currently Seeded Page Parts

### By File (13 Total)

| File | Page | Key | Type | Purpose |
|------|------|-----|------|---------|
| `home__landing_hero.yml` | home | landing_hero | Hero | Large banner with title, content, image |
| `home__search_cmpt.yml` | home | search_cmpt | Component | Property search form |
| `home__about_us_services.yml` | home | about_us_services | Features | 3-column services showcase |
| `home__content_html.yml` | home | content_html | HTML | Free-form HTML content |
| `about-us__content_html.yml` | about | content_html | HTML | About page HTML |
| `about-us__our_agency.yml` | about | our_agency | Section | Agency intro with image |
| `contact-us__content_html.yml` | contact | content_html | HTML | Contact page HTML |
| `contact-us__form_and_map.yml` | contact | form_and_map | Contact | Contact form + embedded map |
| `legal__content_html.yml` | legal_notice | content_html | HTML | Legal page HTML |
| `privacy__content_html.yml` | privacy_policy | content_html | HTML | Privacy page HTML |
| `sell__content_html.yml` | sell | content_html | HTML | Sell page HTML |
| `website__footer_content_html.yml` | (website-wide) | footer_content_html | HTML | Footer content |
| `website__footer_social_links.yml` | (website-wide) | footer_social_links | Social | Social media links |

### Page Part Attributes (from YAML)

Each page part YAML contains:

```yaml
- page_slug: home                    # Page association
  page_part_key: landing_hero        # Identifier
  block_contents: {}                 # Default content blocks
  order_in_editor: 1                 # Display order
  show_in_editor: true               # Visibility in CMS
  editor_setup:                      # CMS configuration
    tabTitleKey: "pageSections..."   # i18n key
    default_sort_order: 1
    default_visible_on_page: true
    editorBlocks:                    # Field definitions
      - [ { label: "...", isHtml: true }, ... ]
  template: >                        # Liquid template
    <div class="hero-section">
      {% if page_part["field_name"]["content"] %}
        {{ page_part["field_name"]["content"] }}
      {% endif %}
    </div>
```

---

## Currently Seeded Pages & Content

### Pages (8 Total)

| Slug | Name | Content Key (i18n) |
|------|------|-------------------|
| home | Home | navbar.home |
| about | About | navbar.about |
| buy | Buy | navbar.buy |
| rent | Rent | navbar.rent |
| sell | Sell | navbar.sell |
| contact | Contact | navbar.contact |
| legal_notice | Legal Notice | navbar.legal_notice |
| privacy_policy | Privacy Policy | navbar.privacy_policy |

### Content Structure (from content_translations/en.yml)

The content is organized as:

```yaml
---
en:                               # Locale
  website:                        # Global website content
    page_part_key:
      block_label: "HTML or text content"
  
  page_slug:                      # Page-specific content
    page_part_key:
      block_label: "HTML or text content"
```

### Example Content Sections

```
en:
  website:
    footer_content_html:
      main_content: "<p>We are proud to be registered...</p>"
  
  home:
    landing_hero:
      landing_title_a: "The best realtor in Springfield"
      landing_content_a: "<ul>...</ul>"
      landing_img: "db/example_images/carousel_villa_with_pool.jpg"
    
    about_us_services:
      title_a: "Find your home"
      content_a: "<p>Explain to us exactly...</p>"
      title_b: "Professional estate agents"
      content_b: "<p>We are professional...</p>"
      title_c: "Sell your property"
      content_c: "<p>If you need to sell...</p>"
  
  sell:
    content_html:
      main_content: "<h2>Sell Your Property with Us</h2>..."
```

### Locales with Content Translations (6 Files)

- English (en) - 7,012 bytes, 120+ content items
- Spanish (es) - 8,109 bytes
- Italian (it) - 6,424 bytes
- Dutch (nl) - 7,050 bytes
- Portuguese (pt) - 6,424 bytes
- Turkish (tr) - 7,573 bytes

*Note: Additional locale files may exist but are not listed in the directory*

---

## Seed Packs System

### What Are Seed Packs?

Seed Packs are pre-configured bundles of seed data representing real-world scenarios. Each pack contains everything needed to create a fully functional tenant website.

### Pack Structure

```
db/seeds/packs/[pack_name]/
├── pack.yml                    # Pack metadata and configuration
├── field_keys.yml              # Property taxonomy (optional)
├── links.yml                   # Navigation links (optional)
├── properties/                 # Property definitions (directory)
│   ├── villa_marbella.yml
│   └── penthouse_barcelona.yml
├── content/                    # Page content (directory)
│   └── home.yml
├── translations/               # Pack-specific translations
│   ├── es.yml
│   ├── en.yml
│   └── de.yml
└── images/                     # Property images
    ├── villa_marbella_1.jpg
    └── penthouse_barcelona_1.jpg
```

### Available Packs

#### 1. **base** Pack
**Purpose**: Foundation pack with shared configuration

**Contains:**
- `pack.yml` - Base configuration
- `field_keys.yml` - Core property taxonomy
- `links.yml` - Standard navigation structure

**Configuration:**
```yaml
name: base
display_name: "Base Pack"
description: "Base configuration for all packs"
version: "1.0"
```

**Inheritance**: None (root pack)

#### 2. **spain_luxury** Pack
**Purpose**: Spanish luxury property scenario

**Inherits from**: `base`

**Contains:**
- 7 properties (villas, penthouses, apartments, townhouse)
- Multi-language support (es, en, de)
- Spanish agency configuration
- Regional customizations

**Configuration:**
```yaml
name: spain_luxury
display_name: "Spanish Luxury Real Estate"
description: "Estate agent specializing in luxury properties"
version: "1.0"
inherits_from: base

website:
  theme_name: bristol
  default_client_locale: es
  supported_locales: [es, en, de]
  country: Spain
  currency: EUR

agency:
  display_name: "Costa Luxury Properties"
  email: "info@costaluxury.es"
  phone: "+34 952 123 456"
  address:
    city: Marbella
    region: Málaga
    country: Spain
```

### Using Seed Packs Programmatically

```ruby
# Find and apply a pack
pack = Pwb::SeedPack.find('spain_luxury')
website = Pwb::Website.create!(subdomain: 'costa-demo', theme_name: 'bristol')
pack.apply!(website: website)

# List available packs
Pwb::SeedPack.available

# Preview what a pack would create
pack.preview
# => { pack_name: "spain_luxury", properties: 7, users: 2, locales: ["es", "en", "de"] }
```

---

## SeedRunner Features

### What is SeedRunner?

`Pwb::SeedRunner` is an enhanced seeding orchestrator that wraps the basic `Pwb::Seeder` with safety features, user prompts, and detailed logging.

### Key Features

#### 1. **Interactive Mode** (default)
```ruby
Pwb::SeedRunner.run(
  website: website,
  mode: :interactive
)
```
- Detects existing data
- Warns user about what will be created
- Prompts for confirmation to update existing records
- Options: Create Only, Update All, or Quit

#### 2. **Create Only Mode**
```ruby
Pwb::SeedRunner.run(
  website: website,
  mode: :create_only
)
```
- Skips existing records
- Only creates new entries
- Safe for running multiple times

#### 3. **Force Update Mode**
```ruby
Pwb::SeedRunner.run(
  website: website,
  mode: :force_update
)
```
- Updates existing records with seed data
- No prompting
- Overwrites previous customizations

#### 4. **Dry Run Mode**
```ruby
Pwb::SeedRunner.run(
  website: website,
  dry_run: true
)
```
- Shows what would happen
- Makes NO database changes
- Validates seed files
- Useful for previewing

#### 5. **Selective Seeding**
```ruby
Pwb::SeedRunner.run(
  website: website,
  skip_properties: true,       # Don't seed properties
  skip_translations: true,     # Don't seed translations
  skip_users: true,            # Don't seed users
  verbose: false               # Minimal output
)
```

### Statistics Tracking

After running, `SeedRunner` tracks:
```ruby
{
  created: 42,    # Records created
  updated: 5,     # Records updated
  skipped: 12,    # Records skipped (already exist)
  errors: 0       # Records that failed
}
```

---

## Multi-Language & Locale System

### Supported Languages (15 Total)

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

### Translation Layers

#### Layer 1: I18n Backend (Field Key Labels)

Translations of property taxonomy labels (property types, states, features, amenities).

```ruby
# Access via I18n
I18n.t("types.apartment", locale: :es)  # => "Apartamento"
I18n.t("states.good", locale: :de)      # => "Gut"

# Stored in: I18n::Backend::ActiveRecord::Translation table
# Loaded from: db/seeds/translations_*.rb files (15 files, 100+ keys each)
```

**Translation Keys by Category:**
- `types.*` (19 property types)
- `states.*` (7 property conditions)
- `features.*` (26+ permanent features)
- `amenities.*` (18+ equipment/services)
- `status.*` (5 transaction statuses)
- `highlights.*` (6 marketing flags)
- `origin.*` (5 data sources)

#### Layer 2: Mobility JSONB Backend (Listing Translations)

Translations of property listings (titles and descriptions).

```ruby
# Accessing via Mobility locale accessors
listing.title_en      # => "Beautiful villa"
listing.title_es      # => "Villa hermosa"
listing.title_de      # => "Schöne Villa"
listing.description_en # => "..."
listing.description_es # => "..."

# Set translations
listing.title_en = "Beautiful villa"
listing.title_es = "Villa hermosa"
listing.save!

# Stored in: JSONB column in sale_listings/rental_listings tables
# Fallback chain: Any locale → English (if not found)
```

### Loading Translations

Translations are loaded during seeding:

```ruby
# From Pwb::Seeder.seed!
should_load_translations = ENV["RAILS_ENV"] == "test" || 
                           I18n::Backend::ActiveRecord::Translation.all.length <= 600

if should_load_translations
  load File.join(Rails.root, "db", "seeds", "translations_ca.rb")
  load File.join(Rails.root, "db", "seeds", "translations_en.rb")
  load File.join(Rails.root, "db", "seeds", "translations_es.rb")
  # ... 12 more language files
end
```

**Conditional Logic:**
- In **test environment**: Always reload (fresh database)
- In **other environments**: Only load if < 600 translations exist (avoid duplicates)

### Locale Fallback Chain

```ruby
# From config/initializers/i18n_globalise.rb
Globalize.fallbacks = {
  de: [:en],   # German falls back to English
  es: [:en],   # Spanish falls back to English
  pl: [:en],   # Polish falls back to English
  # ... all other locales fall back to English
}
```

**Behavior:**
- If a property title is missing in German, try English
- If English is also missing, use blank/null
- English is always the default/fallback for all locales

### Website Locale Configuration

Each website can configure:

```yaml
# From website.yml or pack.yml
default_client_locale: "en-US"      # Frontend language
default_admin_locale: "es"          # Admin interface language
supported_locales: ["en-US", "es-MX"]  # Available languages
```

---

## Updating Seeds for New Page Part Library

### Current State

The `PagePartLibrary` (in `lib/pwb/page_part_library.rb`) defines the new page part templates:

```ruby
DEFINITIONS = {
  # Heroes
  'heroes/hero_centered' => { ... },
  'heroes/hero_split' => { ... },
  'heroes/hero_search' => { ... },
  
  # Features
  'features/feature_grid_3col' => { ... },
  'features/feature_cards_icons' => { ... },
  
  # Testimonials
  'testimonials/testimonial_carousel' => { ... },
  
  # CTA
  'cta/cta_banner' => { ... },
  
  # Stats, Teams, Galleries, Pricing, FAQs
  # ... (20+ modern page parts)
  
  # Legacy (deprecated but still supported)
  'our_agency' => { legacy: true },
  'about_us_services' => { legacy: true },
  'content_html' => { legacy: true },
  # ... (9 legacy parts)
}
```

### What Needs to Be Updated

To fully support the new page part library in seeds, you need to:

#### 1. **Update Page Part YAML Files**

Change from legacy format (currently in `db/yml_seeds/page_parts/`):

```yaml
# OLD
- page_slug: home
  page_part_key: landing_hero        # Just a key
  template: >
    <div>...</div>
```

To reference new library definitions:

```yaml
# NEW
- page_slug: home
  page_part_key: heroes/hero_centered   # Categorized key
  # No longer need to store template in YAML
  # Template comes from app/views/pwb/page_parts/heroes/hero_centered.liquid
```

#### 2. **Create Liquid Template Files**

For each new page part, create the Liquid template:

```liquid
<!-- app/views/pwb/page_parts/heroes/hero_centered.liquid -->
<div class="hero hero-centered">
  {% if page_part.pretitle %}
    <div class="hero-pretitle">{{ page_part.pretitle }}</div>
  {% endif %}
  
  <h1 class="hero-title">{{ page_part.title }}</h1>
  
  {% if page_part.subtitle %}
    <p class="hero-subtitle">{{ page_part.subtitle }}</p>
  {% endif %}
  
  {% if page_part.background_image %}
    <img src="{{ page_part.background_image }}" alt="Hero background" class="hero-bg">
  {% endif %}
  
  {% if page_part.cta_text %}
    <a href="{{ page_part.cta_link }}" class="btn">{{ page_part.cta_text }}</a>
  {% endif %}
</div>
```

#### 3. **Create Content Translation Entries**

Add content for new page parts in `db/yml_seeds/content_translations/*.yml`:

```yaml
en:
  home:
    heroes/hero_centered:
      pretitle: "Welcome to"
      title: "Our Real Estate Agency"
      subtitle: "Find your perfect home today"
      cta_text: "Browse Properties"
      cta_link: "/properties"
      background_image: "https://..."
```

#### 4. **Update Page Seed YAML Files**

Assign new page parts to pages in `db/yml_seeds/page_parts/`:

```yaml
# NEW FILE: db/yml_seeds/page_parts/home__hero_centered.yml
- page_slug: home
  page_part_key: heroes/hero_centered
  order_in_editor: 1
  show_in_editor: true

# NEW FILE: db/yml_seeds/page_parts/home__feature_grid.yml
- page_slug: home
  page_part_key: features/feature_grid_3col
  order_in_editor: 2
  show_in_editor: true

# NEW FILE: db/yml_seeds/page_parts/home__cta_banner.yml
- page_slug: home
  page_part_key: cta/cta_banner
  order_in_editor: 3
  show_in_editor: true
```

#### 5. **Update Seed Packs**

Add new page parts to seed packs (e.g., `db/seeds/packs/spain_luxury/pack.yml`):

```yaml
pages:
  home:
    parts:
      - heroes/hero_centered
      - features/feature_grid_3col
      - cta/cta_banner
      - testimonials/testimonial_carousel
  
  properties:
    parts:
      - galleries/image_gallery
```

#### 6. **Migrate Legacy Content**

For existing page parts, map old content to new field names:

```ruby
# Migration or script to update page content
# From old structure:
#   landing_hero → landing_title_a, landing_content_a, landing_img
# To new structure:
#   heroes/hero_centered → title, subtitle, cta_text, cta_link, background_image
```

---

## How to Add New Page Parts to Seeds

### Step-by-Step Process

#### Step 1: Create the Liquid Template

```liquid
<!-- app/views/pwb/page_parts/[category]/[name].liquid -->
<div class="section">
  <!-- Use Liquid to render page_part fields -->
  {% if page_part.field_name %}
    <p>{{ page_part.field_name }}</p>
  {% endif %}
</div>
```

#### Step 2: Register in PagePartLibrary

Edit `lib/pwb/page_part_library.rb`:

```ruby
DEFINITIONS = {
  'category/name' => {
    category: :category,
    label: 'Display Name',
    description: 'Short description',
    fields: %w[field1 field2 field3],  # List all fields
    legacy: false  # Set to true if replacing old part
  }
}
```

#### Step 3: Create Seed YAML File

Create `db/yml_seeds/page_parts/[page]__[category]_[name].yml`:

```yaml
---
- page_slug: page_name           # Which page it goes on
  page_part_key: category/name   # Must match PagePartLibrary key
  order_in_editor: 2
  show_in_editor: true
```

#### Step 4: Add Content Translations

For each locale in `db/yml_seeds/content_translations/[locale].yml`:

```yaml
[locale]:
  page_name:
    category/name:
      field1: "Translated content"
      field2: "More content"
```

#### Step 5: Update Seed Packs (Optional)

If adding to seed packs, update `db/seeds/packs/[pack]/pack.yml`:

```yaml
pages:
  page_name:
    parts:
      - category/name
```

#### Step 6: Test Seeding

```bash
# Test that seeding works
bin/rails db:seed

# Or in console
Pwb::Seeder.seed!
Pwb::PagesSeeder.seed_page_parts!(website: Pwb::Website.first)
Pwb::ContentsSeeder.seed_page_content_translations!(website: Pwb::Website.first)
```

---

## Quick Reference: File Locations

| What | Where |
|------|-------|
| Main seeder | `lib/pwb/seeder.rb` |
| Pages seeder | `lib/pwb/pages_seeder.rb` |
| Contents seeder | `lib/pwb/contents_seeder.rb` |
| SeedRunner | `lib/pwb/seed_runner.rb` |
| SeedPack | `lib/pwb/seed_pack.rb` |
| PagePartLibrary | `lib/pwb/page_part_library.rb` |
| Seed YAML files | `db/yml_seeds/` |
| Translation files | `db/seeds/translations_*.rb` |
| Seed packs | `db/seeds/packs/` |
| Page templates | `app/views/pwb/page_parts/` |
| E2E seeds | `db/seeds/e2e_seeds.rb` |

---

## Common Tasks

### Seed a New Website

```ruby
website = Pwb::Website.create!(
  subdomain: 'my-agency',
  slug: 'my-agency',
  theme_name: 'bristol'
)

Pwb::Seeder.seed!(website: website)
```

### Apply a Seed Pack

```ruby
pack = Pwb::SeedPack.find('spain_luxury')
website = Pwb::Website.create!(subdomain: 'costa-demo', theme_name: 'bristol')
pack.apply!(website: website)
```

### Interactive Seeding with Prompts

```ruby
Pwb::SeedRunner.run(
  website: website,
  mode: :interactive
)
```

### Preview Changes Without Seeding

```ruby
Pwb::SeedRunner.run(
  website: website,
  dry_run: true,
  verbose: true
)
```

### Skip Specific Data Types

```ruby
Pwb::Seeder.seed!(
  website: website,
  skip_properties: true  # Don't seed properties
)
```

### Seed Only Pages & Content

```ruby
website = Pwb::Website.first
Pwb::PagesSeeder.seed_page_basics!(website: website)
Pwb::PagesSeeder.seed_page_parts!(website: website)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

### Load All E2E Test Data

```bash
RAILS_ENV=e2e bin/rails db:seed
```

---

## Summary

The PropertyWebBuilder seeding system is comprehensive and supports:

1. **Multiple seeders** for different concerns (Seeder, PagesSeeder, ContentsSeeder, SeedRunner)
2. **13 currently seeded page parts** across 8 pages
3. **30+ modern page parts** defined in the PagePartLibrary
4. **Multi-tenant isolation** ensuring data doesn't cross websites
5. **15-language support** with automatic fallback to English
6. **Seed packs** for scenario-based setup (base, spain_luxury)
7. **Safe execution** via SeedRunner with prompts and dry-run mode
8. **Idempotent operations** using find_or_create patterns

**To support the new page part library, the main updates needed are:**

- Creating Liquid templates for each new page part
- Updating YAML seed files to use new page part keys
- Adding content translations for new page parts
- Optionally updating seed packs with new page parts
- Migrating legacy content to new field structures

---

*Last Updated: December 6, 2025*
*PropertyWebBuilder v1.0+*
