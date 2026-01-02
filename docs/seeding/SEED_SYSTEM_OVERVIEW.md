# Seed Data System Overview

PropertyWebBuilder has a sophisticated, modular seed data system designed for multi-tenancy and scenario-based setup. This document explains how the seed system works and the patterns used.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Seed Packs System](#seed-packs-system)
3. [Directory Structure](#directory-structure)
4. [Configuration Files](#configuration-files)
5. [Seeding Patterns](#seeding-patterns)
6. [Usage Examples](#usage-examples)
7. [Multi-Tenancy Support](#multi-tenancy-support)

---

## Architecture Overview

The seed system is built on three layers:

### Layer 1: Core Seeding Classes

Located in `lib/pwb/`:

- **`SeedPack`** - Main orchestrator for seed packs. Loads and applies pre-configured scenario bundles to websites.
- **`Seeder`** - Legacy seeder for individual data types (agencies, properties, users, translations).
- **`SeedRunner`** - Interactive wrapper around `Seeder` with enhanced safety features (dry-run, mode selection).
- **`PagesSeeder`** - Handles page and page_part creation from YAML templates.
- **`ContentsSeeder`** - Seeds page content translations from YAML.
- **`SeedImages`** - Manages external image URLs for seed data.

### Layer 2: Rake Tasks

Located in `lib/tasks/`:

- **`seed_packs.rake`** - Primary interface for applying seed packs
  - `pwb:seed_packs:list` - List available packs
  - `pwb:seed_packs:preview[pack_name]` - Preview pack without applying
  - `pwb:seed_packs:apply[pack_name,website_id]` - Apply pack to website
  - `pwb:seed_packs:reset_and_apply[pack_name]` - Destructive reset + apply

- **`pwb_update_seeds.rake`** - Run base seeder
- **`pwb_seed_with_onboarding.rake`** - Seeding with onboarding flow
- **`seed_images.rake`** - Manage seed images in R2/cloud storage

### Layer 3: Seed Data

Located in `db/seeds/`:

```
db/seeds/
├── packs/                    # Scenario-based seed packs
│   ├── base/                # Inherited by all packs
│   ├── netherlands_urban/    # Example pack: Dutch agency
│   └── spain_luxury/         # Example pack: Luxury agency
├── images/                   # Shared seed images
├── yml_seeds/               # Legacy YAML seeds (deprecated, fallback only)
└── translations_*.rb        # Multi-language translations
```

---

## Seed Packs System

Seed Packs are **self-contained, pre-configured bundles** representing real-world scenarios. Each pack includes everything needed to set up a complete, functional tenant website.

### What Each Pack Contains

```yaml
pack.yml                    # Pack metadata and configuration
├── field_keys.yml         # Property types, states, features
├── links.yml              # Navigation links
├── pages/                 # Page definitions (if custom)
├── page_parts/            # Page part templates (if custom)
├── properties/            # Sample property listings
│   ├── property1.yml
│   ├── property2.yml
│   └── ...
├── content/               # Page content translations
│   ├── home.yml
│   ├── about-us.yml
│   ├── sell.yml
│   └── contact-us.yml
├── content_translations/  # Alternative: content in translation format
└── images/                # Pack-specific images
    ├── property1.jpg
    ├── property2.jpg
    └── ...
```

### Pack Configuration (pack.yml)

Each pack has a `pack.yml` file that defines its structure and inherits from parent packs:

```yaml
name: netherlands_urban
display_name: "Dutch Urban Real Estate"
description: "Popular estate agent specializing in city apartments..."
version: "1.0"

# Inheritance - inherit field keys, links, etc. from parent
inherits_from: base

# Website-level configuration
website:
  theme_name: bologna              # Theme to use
  selected_palette: modern_slate   # Color palette
  default_client_locale: nl        # Primary language
  supported_locales:
    - nl
    - en
  currency: EUR
  area_unit: sqmt                  # Square meters

# Agency details
agency:
  display_name: "Van der Berg Makelaars"
  email: "info@vanderbergmakelaars.nl"
  phone: "+31 20 123 4567"
  address:
    street_address: "Herengracht 450"
    city: Amsterdam
    region: Noord-Holland
    country: Netherlands
    postal_code: "1017 CA"

# Page parts - which templates to use on each page
page_parts:
  home:
    - key: heroes/hero_centered
      order: 1
    - key: features/feature_grid_3col
      order: 2
    # ...

# Users for this pack
users:
  - email: admin@vanderbergmakelaars.nl
    role: admin
    password: demo123
  - email: agent@vanderbergmakelaars.nl
    role: agent
    password: demo123
```

### Pack Inheritance

Packs can inherit from parent packs to share common configuration:

- **`base` pack** - Contains shared field keys, navigation links, and common page structures
- **`netherlands_urban`** - Inherits from `base`, adds Dutch-specific agency, properties, and content
- **`spain_luxury`** - Inherits from `base`, adds Spanish luxury market focus

When a child pack is applied:
1. Parent pack is applied first (with limited options to avoid overwriting)
2. Child pack's data is applied, overriding parent where appropriate
3. Only website, agency, and content from parent are skipped in child application

---

## Directory Structure

### Packs Directory

```
db/seeds/packs/
├── base/
│   ├── pack.yml              # Root configuration
│   ├── field_keys.yml        # Property types, states, features, amenities
│   ├── links.yml             # Navigation links
│   └── (no properties - base is abstract)
│
├── netherlands_urban/
│   ├── pack.yml              # Dutch agency scenario
│   ├── field_keys.yml        # Optional overrides of base field keys
│   ├── links.yml             # Optional overrides
│   ├── properties/           # 8 sample properties
│   │   ├── grachtenpand_amsterdam.yml
│   │   ├── apartment_denhaag.yml
│   │   ├── hoekwoning_haarlem.yml
│   │   └── ...
│   ├── content/              # Page content for home, about, sell, contact
│   │   ├── home.yml
│   │   ├── about-us.yml
│   │   ├── sell.yml
│   │   └── contact-us.yml
│   └── images/               # Pack-specific images (JPG + WebP variants)
│       ├── amsterdam_canal_house.jpg
│       ├── amsterdam_canal_house.webp
│       └── ...
│
└── spain_luxury/
    ├── pack.yml
    ├── properties/           # 7 luxury properties
    ├── content/              # Luxury-focused content
    └── images/
```

### Legacy Seeds Directory (Fallback)

```
db/yml_seeds/                 # Legacy seeds (used as fallback)
├── agency.yml
├── agency_address.yml
├── website.yml
├── field_keys.yml
├── users.yml
├── contacts.yml
├── links.yml
├── pages/                    # Page definitions
├── page_parts/               # Page part templates
├── content_translations/     # Content by locale
├── prop/                     # Sample properties
└── ...
```

---

## Configuration Files

### 1. pack.yml - Pack Metadata

**Purpose**: Define pack identity, configuration, and what it contains.

**Key Fields**:
- `name` - Machine name (must match directory)
- `display_name` - Human-readable name
- `description` - What the pack represents
- `inherits_from` - Parent pack (null for root)
- `website` - Website-level config (theme, locales, currency)
- `agency` - Agency details (name, contact, address)
- `page_parts` - Which templates to use (key + order)
- `users` - Admin/agent accounts for this pack

**Example**:
```yaml
name: netherlands_urban
display_name: "Dutch Urban Real Estate"
inherits_from: base
website:
  theme_name: bologna
  supported_locales: [nl, en]
  currency: EUR
```

### 2. field_keys.yml - Configuration Metadata

**Purpose**: Define property types, states, features, amenities that can be tagged on properties.

**Format** (hierarchical):
```yaml
types:
  villa:
    en: Villa
    es: Villa
    nl: Villa
  apartment:
    en: Apartment
    es: Apartamento
    nl: Appartement

states:
  excellent:
    en: Excellent
    es: Excelente
    nl: Uitstekend
  needs_renovation:
    en: Needs Renovation
    es: A reformar
    nl: Renovatiebehoefte

features:
  private_pool:
    en: Private Pool
    es: Piscina privada
    nl: Privé zwembad
  garden:
    en: Garden
    es: Jardín
    nl: Tuin

amenities:
  heating:
    en: Heating
    es: Calefacción
    nl: Verwarming
```

**Database Storage**: Creates `Pwb::FieldKey` records with:
- `global_key` - Machine key (e.g., "villa", "private_pool")
- `tag` - Category ("property-types", "property-states", "property-features")
- `label` - Translated display name (via Mobility gem)
- `pwb_website_id` - Tenant scope

### 3. links.yml - Navigation Links

**Purpose**: Define navigation menu links.

**Format**:
```yaml
- slug: home
  link_path: home_path
  link_path_params: {}
  placement: navbar
  link_title: "Home"
  page_slug: home

- slug: buy
  link_path: search_path
  link_path_params:
    scope: buy
  placement: navbar
  link_title: "Buy"
  page_slug: buy
```

**Fields**:
- `slug` - Unique identifier
- `link_path` - Rails path helper
- `link_path_params` - Route parameters
- `placement` - Where in navigation (navbar, footer)
- `page_slug` - Associated page (for title translation lookup)

### 4. Property YAML Files (properties/*.yml)

**Purpose**: Define individual property listings with full details.

**Format**:
```yaml
reference: NL-GRA-001          # Unique identifier
prop_type: types.grachtenpand  # Links to field key
prop_state: states.gerenoveerd # Links to field key

# Location
address: "Keizersgracht 324"
city: Amsterdam
region: Noord-Holland
country: Netherlands
postal_code: "1016 EZ"
latitude: 52.3702
longitude: 4.8872

# Physical Details
bedrooms: 5
bathrooms: 3
garages: 0
constructed_area: 280
plot_area: 0
year_built: 1685

# Sale Listing
sale:
  highlighted: true
  price_cents: 249500000  # Stored in cents
  title:
    nl: "Monumentaal grachtenpand aan de Keizersgracht"
    en: "Monumental Canal House on Keizersgracht"
  description:
    nl: "Prachtig gerestaureerd grachtenpand..."
    en: "Beautifully restored canal house..."

# Rental Listing (alternative to sale)
rental:
  highlighted: false
  monthly_price_cents: 450000
  long_term: true
  short_term: true
  furnished: true

# Features (links to field keys)
features:
  - features.grachtzicht        # Canal view
  - features.dakterras          # Roof terrace
  - features.originele_details  # Original details
  - amenities.cv_ketel          # Central heating
  - labels.centrum              # Central location

# Image
image: amsterdam_canal_house.jpg  # References db/seeds/packs/pack_name/images/
```

**Database Storage**: Creates:
- `Pwb::RealtyAsset` - Physical property data
- `Pwb::SaleListing` or `Pwb::RentalListing` - Listing details with translations
- `Pwb::PropPhoto` - Images (external URLs or local attachments)
- `Pwb::RealtyAssetFeature` - Property features

### 5. Content YAML Files (content/*.yml)

**Purpose**: Define page content for each page part template.

**Format** (for home.yml):
```yaml
# Each key matches a page part template key

heroes/hero_centered:
  pretitle:
    nl: "Welkom bij Van der Berg Makelaars"
    en: "Welcome to Van der Berg Real Estate"
  title:
    nl: "Uw droomhuis in Nederland"
    en: "Your Dream Home in the Netherlands"
  subtitle:
    nl: "Al meer dan 25 jaar helpen wij..."
    en: "For over 25 years, we have been..."
  cta_text:
    nl: "Bekijk woningen"
    en: "View Properties"
  cta_link: "/search/buy"
  background_image: "db/seeds/packs/netherlands_urban/images/hero_amsterdam_canal.jpg"

features/feature_grid_3col:
  section_title:
    nl: "Wat wij voor u kunnen betekenen"
    en: "What We Can Do For You"
  feature_1_title:
    nl: "Kopen"
    en: "Buying"
  feature_1_description:
    nl: "Van eerste bezichtiging tot sleuteloverdracht..."
    en: "From first viewing to key handover..."
  feature_1_link: "/search/buy"
  # ... more features
```

**Database Storage**: Creates `Pwb::PagePart` records with:
- `page_part_key` - Template type
- `page_slug` - Associated page
- `block_contents` - Content data as JSON
- `editor_setup` - Template configuration

---

## Seeding Patterns

### Pattern 1: Seed Pack Application Flow

The `Pwb::SeedPack.apply!` method follows this sequence:

```ruby
pack.apply!(website: website, options: {})
  ├─ Validate pack configuration
  ├─ Apply parent pack (if inherits_from specified)
  ├─ seed_website        # Theme, locales, currency
  ├─ seed_agency         # Agency name, contact, address
  ├─ seed_field_keys     # Property types, states, features
  ├─ seed_links          # Navigation menu links
  ├─ seed_pages          # Page definitions
  ├─ seed_page_parts     # Page templates
  ├─ seed_properties     # Sample properties
  ├─ seed_content        # Page content translations
  ├─ seed_users          # Admin/agent accounts
  ├─ seed_translations   # I18n strings (if pack has translations/)
  └─ Refresh materialized views
```

Each step is:
- **Skippable** - `skip_*` options for selective seeding
- **Idempotent** - Won't duplicate existing data (checks by slug, reference, email)
- **Transactional** - Errors roll back properly
- **Verbose** - Logs what was created

### Pattern 2: Field Key Seeding

Field keys are stored with translations using the Mobility gem:

```ruby
def seed_field_keys
  field_keys_file = @path.join('field_keys.yml')
  data = YAML.safe_load(File.read(field_keys_file), symbolize_names: true)

  data.each do |category, keys|
    tag = category_map[category]  # types → property-types
    
    keys.each do |key_name, translations|
      field_key = Pwb::FieldKey.create!(
        global_key: key_name.to_s,
        tag: tag,
        pwb_website_id: @website.id,
        visible: true
      )
      
      # Set translations using Mobility
      translations.each do |locale, label|
        Mobility.with_locale(locale.to_sym) do
          field_key.label = label
        end
      end
      field_key.save!
    end
  end
end
```

### Pattern 3: Multi-Language Property Seeding

Properties can have titles and descriptions in multiple languages:

```ruby
def create_property(data)
  asset = Pwb::RealtyAsset.create!(
    website_id: @website.id,
    reference: data[:reference],
    # ... location and physical details
  )
  
  if data[:sale]
    listing = Pwb::SaleListing.create!(
      realty_asset: asset,
      visible: true,
      price_sale_current_cents: data[:sale][:price_cents]
    )
    
    # Set translations for each locale
    config.dig(:website, :supported_locales).each do |locale|
      title = data[:sale].dig(:title, locale.to_sym)
      desc = data[:sale].dig(:description, locale.to_sym)
      
      listing.send("title_#{locale}=", title)
      listing.send("description_#{locale}=", desc)
    end
    listing.save!
  end
end
```

### Pattern 4: Page Part Content Seeding

Page parts are populated with content from content/*.yml files:

```ruby
def seed_pack_content(content_dir)
  Dir.glob(content_dir.join('*.yml')).each do |content_file|
    content_data = YAML.safe_load(File.read(content_file), symbolize_names: true)
    
    content_data.each do |key, translations|
      content = @website.contents.find_or_initialize_by(key: key.to_s)
      
      # Set value for each locale
      translations.each do |locale, value|
        content.send("raw_#{locale}=", value)
      end
      content.save!
    end
  end
end
```

### Pattern 5: Image Handling

Images are attached with external URLs to avoid storage bloat:

```ruby
def attach_property_image(asset, image_filename)
  if Pwb::SeedImages.enabled?
    # Use external URL from R2/cloud storage
    external_url = build_image_url(image_filename)
    Pwb::PropPhoto.create!(
      realty_asset: asset,
      sort_order: 1,
      external_url: external_url
    )
  else
    # Fall back to local file attachment
    image_path = @path.join('images', image_filename)
    photo = Pwb::PropPhoto.create!(realty_asset: asset, sort_order: 1)
    photo.image.attach(
      io: File.open(image_path),
      filename: image_filename,
      content_type: 'image/jpeg'
    )
  end
end

# Image URL construction respects pack structure:
# - Pack images: /packs/{pack_name}/{filename}
# - Shared images: /seeds/{filename}
# - Example images: /example/{filename}
```

### Pattern 6: Deduplication

All seeding operations check for duplicates before creating:

```ruby
# By slug (links, pages)
existing = @website.links.find_by(slug: link_data[:slug])
next if existing

# By reference (properties)
existing = Pwb::RealtyAsset.exists?(website_id: @website.id, reference: reference)
next if property_exists?

# By email (users)
existing = Pwb::User.find_by(email: user_data[:email])

# By global_key (field keys)
existing = Pwb::FieldKey.find_by(global_key: global_key, pwb_website_id: @website.id)
```

---

## Usage Examples

### List Available Packs

```bash
rails pwb:seed_packs:list
```

Output:
```
Available Seed Packs:
==================================================

Base Pack (base)
  Foundation pack with common field keys, pages, and navigation structure
  Version: 1.0
  Inherits from: none
  Theme: default

Dutch Urban Real Estate (netherlands_urban)
  Popular estate agent specializing in city apartments across the Netherlands
  Version: 1.0
  Inherits from: base
  Theme: bologna
  Locales: nl, en
  Currency: EUR
```

### Preview a Pack (Dry Run)

```bash
rails pwb:seed_packs:preview[netherlands_urban]
```

Shows what would be created without making changes.

### Apply a Pack to a Website

```bash
# Apply to default website
rails pwb:seed_packs:apply[netherlands_urban]

# Apply to specific website
rails pwb:seed_packs:apply[netherlands_urban,5]

# With selective options
rails pwb:seed_packs:apply_with_options[spain_luxury,'skip_properties,skip_translations']
```

### From Rails Console

```ruby
# Find and apply a pack
pack = Pwb::SeedPack.find('netherlands_urban')
website = Pwb::Website.first
pack.apply!(website: website)

# Dry run preview
pack.apply!(website: website, options: { dry_run: true })

# Skip specific sections
pack.apply!(
  website: website,
  options: {
    skip_properties: true,  # Don't seed sample properties
    skip_users: true,       # Don't seed demo accounts
    verbose: false          # Quiet mode
  }
)

# Get pack metadata
pack.preview
# => { pack_name: "netherlands_urban", properties: 8, users: 2, ... }
```

---

## Multi-Tenancy Support

The seed system is designed for multi-tenancy with each website being an isolated tenant.

### Tenant Scoping

All seeded data is automatically scoped to the website:

```ruby
@website.field_keys.create!        # Scoped to website
@website.links.create!             # Scoped to website
@website.pages.create!             # Scoped to website
@website.realty_assets.create!     # Scoped to website
@website.agency                    # 1:1 relationship
```

### Locale Support

Each website has its own supported locales:

```yaml
website:
  supported_locales:
    - nl      # Dutch
    - en      # English
  default_client_locale: nl
```

Content, translations, and field keys are all locale-aware.

### Isolation

Seeds from one pack/website do NOT affect others:

```ruby
# Seeds are per-website
website1 = Pwb::Website.find(1)
website2 = Pwb::Website.find(2)

pack.apply!(website: website1)  # Only website1 gets data
pack.apply!(website: website2)  # website2 gets its own copy

website1.field_keys.count  # >= 0
website2.field_keys.count  # >= 0 (independent)
```

---

## Advanced Patterns

### Creating a Custom Pack

1. Create directory: `db/seeds/packs/my_custom_pack/`
2. Add `pack.yml` with configuration
3. Create subdirectories:
   - `properties/` - Property YAML files
   - `content/` - Page content by page slug
   - `images/` - Property and content images
4. Add `field_keys.yml` if extending base keys
5. List and apply: `rails pwb:seed_packs:list` then `rails pwb:seed_packs:apply[my_custom_pack]`

### Conditionally Seeding Data

```ruby
pack.apply!(
  website: website,
  options: {
    skip_properties: ENV['SKIP_PROPERTIES'] == 'true',
    skip_users: Rails.env.production?,
    dry_run: Rails.env.test?
  }
)
```

### Extending Base Pack

```yaml
name: my_regional_pack
display_name: "My Regional Real Estate"
inherits_from: base  # Inherits field keys, links from base

website:
  theme_name: custom_theme
  # ... override other settings
```

When applied, base pack runs first, then your pack adds/overrides.

---

## Configuration Data Patterns

The system seeds several types of configuration data:

| Data Type | Storage | Scope | Patterns |
|-----------|---------|-------|----------|
| **Field Keys** | `pwb_field_keys` | Per-Website | Hierarchical YAML, Mobility translations |
| **Links** | `pwb_links` | Per-Website | Slug-based deduplication, page associations |
| **Pages** | `pwb_pages` | Per-Website | Slug-based deduplication, page parts |
| **Page Parts** | `pwb_page_parts` | Per-Website | Block-based content structure |
| **Properties** | `pwb_realty_assets`, `pwb_*_listings` | Per-Website | Reference-based deduplication |
| **Users** | `pwb_users` | Platform-wide but website-scoped | Email-based deduplication |
| **Translations** | `i18n_backend_active_record_translations` | Platform-wide | Locale key pairs |
| **Agency** | `pwb_agencies` | Per-Website | 1:1 with website |

---

## Summary

The seed data system provides:

- **Modular packs** for scenario-based setup (base, netherlands_urban, spain_luxury)
- **Inheritance** to share common configuration (base → child packs)
- **Multi-tenancy** with per-website scoping and localization
- **Deduplication** via slug/reference/email checks
- **Idempotency** - safe to run multiple times
- **Fallback behavior** - uses legacy yml_seeds if packs don't have data
- **External images** to avoid storage bloat (R2/Cloudflare)
- **Flexible options** for skipping sections and dry-run testing

Key files to know:
- `lib/pwb/seed_pack.rb` - Main orchestrator
- `lib/tasks/seed_packs.rake` - User interface
- `db/seeds/packs/*/pack.yml` - Pack configuration
- Property/content YAML files - Scenario-specific data
