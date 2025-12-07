---
name: seed-packs
description: Create and manage seed packs for PropertyWebBuilder. Use when creating new scenario-based seed data bundles, adding properties to packs, or setting up new tenant websites with pre-configured content.
---

# Seed Packs for PropertyWebBuilder

## What Are Seed Packs?

Seed packs are pre-configured bundles of seed data representing real-world property management scenarios. They provide a way to quickly spin up fully functional tenant websites with realistic data for testing, demonstrations, or initial setup.

## Directory Structure

```
db/seeds/packs/
├── base/                     # Root pack (inherited by all others)
│   ├── pack.yml              # Pack metadata (REQUIRED)
│   ├── field_keys.yml        # Property types, states, features
│   └── links.yml             # Navigation structure
│
└── [pack_name]/              # Scenario pack (e.g., spain_luxury)
    ├── pack.yml              # Pack config (REQUIRED)
    ├── properties/           # Property YAML files
    │   └── *.yml             # One file per property
    ├── content/              # Page content by page slug
    │   ├── home.yml
    │   ├── about-us.yml
    │   └── contact-us.yml
    ├── translations/         # Custom i18n translations
    │   ├── en.yml
    │   └── es.yml
    └── images/               # Property photos (optional)
```

## Core Files

### 1. pack.yml (REQUIRED)

The main configuration file for the pack:

```yaml
name: pack_name                          # Unique identifier (matches folder name)
display_name: "Human Readable Name"      # Display name
description: "Description of the pack"   # Brief description
version: "1.0"                           # Version number

# Optional - inherit from another pack
inherits_from: base

# Website Configuration
website:
  theme_name: bristol                    # Theme to use
  default_client_locale: en              # Default locale
  supported_locales:                     # Supported languages
    - en
    - es
    - de
  currency: EUR                          # Default currency
  area_unit: sqm                         # sqm or sqft

# Agency Configuration
agency:
  display_name: "Agency Name"
  email: "info@example.com"
  phone: "+1 234 567 890"
  address:
    street_address: "123 Main Street"
    city: London
    region: Greater London
    country: UK
    postal_code: "SW1A 1AA"

# Page Parts - specify which templates to use per page
page_parts:
  home:
    - key: heroes/hero_centered
      order: 1
    - key: features/feature_grid_3col
      order: 2
  about-us:
    - key: content_html
      order: 1

# Users to create
users:
  - email: admin@example.com
    role: admin
    password: demo123
  - email: agent@example.com
    role: agent
    password: demo123
```

### 2. properties/*.yml

One YAML file per property:

```yaml
# Property identifier
reference: UK-VILLA-001

# Property classification (uses field_keys)
prop_type: types.villa
prop_state: states.excellent

# Location
address: "123 Park Lane"
city: London
region: Greater London
country: UK
postal_code: "W1K 7AA"
latitude: 51.5074
longitude: -0.1278

# Property Details
bedrooms: 5
bathrooms: 4
garages: 2
constructed_area: 450      # In configured area_unit
plot_area: 800
year_built: 2020

# Sale Listing (optional - omit if not for sale)
sale:
  highlighted: true
  price_cents: 500000000   # Price in cents (e.g., 5000000.00 GBP)
  title:
    en: "Luxury Villa in Mayfair"
    es: "Villa de lujo en Mayfair"
  description:
    en: "Stunning 5-bedroom villa with private garden..."
    es: "Impresionante villa de 5 dormitorios..."

# Rental Listing (optional - omit if not for rent)
rental:
  highlighted: false
  long_term: true
  short_term: false
  furnished: true
  monthly_price_cents: 1500000  # Monthly price in cents
  title:
    en: "Modern Apartment for Rent"
  description:
    en: "Beautiful modern apartment..."

# Features (reference field_keys)
features:
  - features.private_pool
  - features.private_garden
  - features.terrace
  - amenities.air_conditioning
  - amenities.alarm_system

# Image filename (from pack's images/ dir or db/seeds/images/)
image: villa_luxury.jpg
```

### 3. content/*.yml

Page content organized by page slug:

```yaml
# Content keys match page part templates
heroes/hero_centered:
  pretitle:
    en: "Welcome"
    es: "Bienvenido"
  title:
    en: "Find Your Dream Home"
    es: "Encuentra tu hogar soñado"
  subtitle:
    en: "Luxury properties in prime locations"
    es: "Propiedades de lujo en ubicaciones privilegiadas"
  cta_text:
    en: "View Properties"
    es: "Ver propiedades"
  cta_link: "/search/buy"
  background_image: "db/example_images/hero_background.jpg"

features/feature_grid_3col:
  section_title:
    en: "Our Services"
    es: "Nuestros servicios"
  feature_1_icon: "fa-home"
  feature_1_title:
    en: "Buying"
    es: "Compra"
  feature_1_description:
    en: "We guide you through the buying process"
    es: "Te guiamos en el proceso de compra"
```

### 4. field_keys.yml

Property taxonomy (types, states, features, amenities):

```yaml
# Property Types
types:
  villa:
    en: Villa
    es: Villa
  apartment:
    en: Apartment
    es: Apartamento
  penthouse:
    en: Penthouse
    es: Ático

# Property States
states:
  new_build:
    en: New Build
    es: Obra nueva
  excellent:
    en: Excellent
    es: Excelente
  good:
    en: Good
    es: Bueno

# Features
features:
  private_pool:
    en: Private Pool
    es: Piscina privada
  sea_views:
    en: Sea Views
    es: Vistas al mar

# Amenities
amenities:
  air_conditioning:
    en: Air Conditioning
    es: Aire acondicionado
  elevator:
    en: Elevator
    es: Ascensor
```

### 5. links.yml

Navigation structure:

```yaml
# Top Navigation
- slug: home
  page_slug: home
  link_title: Home
  placement: top_nav
  sort_order: 1
  visible: true

- slug: buy
  page_slug: buy
  link_title: Buy
  placement: top_nav
  sort_order: 2
  visible: true

# Footer Navigation
- slug: footer_privacy
  page_slug: privacy
  link_title: Privacy Policy
  placement: footer
  sort_order: 1
  visible: true
```

## Implementation

### Core Class: Pwb::SeedPack

Located at `lib/pwb/seed_pack.rb`:

```ruby
# Find and apply a pack
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)

# Preview what will be created (dry run)
pack.preview

# Apply with options
pack.apply!(
  website: website,
  options: {
    skip_properties: false,
    skip_users: true,
    skip_content: false,
    dry_run: false,
    verbose: true
  }
)

# List all available packs
Pwb::SeedPack.available
```

### Rake Tasks

```bash
# List available packs
rails pwb:seed_packs:list

# Preview what a pack would create
rails pwb:seed_packs:preview[pack_name]

# Apply pack to default website
rails pwb:seed_packs:apply[pack_name]

# Apply pack to specific website
rails pwb:seed_packs:apply[pack_name,website_id]

# Apply with skip options
rails pwb:seed_packs:apply_with_options[pack_name,'skip_users,skip_properties']

# Reset and apply (WARNING: destroys existing data)
rails pwb:seed_packs:reset_and_apply[pack_name]
```

## Creating a New Seed Pack

### Step 1: Create Directory Structure

```bash
mkdir -p db/seeds/packs/my_new_pack/{properties,content,translations,images}
```

### Step 2: Create pack.yml

Start with the minimum required configuration:

```yaml
name: my_new_pack
display_name: "My New Pack"
description: "Description of what this pack represents"
version: "1.0"
inherits_from: base

website:
  theme_name: bristol
  default_client_locale: en
  supported_locales: [en]
  currency: GBP
  area_unit: sqft

agency:
  display_name: "My Agency Name"
  email: "info@myagency.com"
```

### Step 3: Add Properties

Create property files in `properties/` directory:

```yaml
# properties/property_001.yml
reference: MY-001
prop_type: types.house
prop_state: states.good
city: London
bedrooms: 3
bathrooms: 2
constructed_area: 1500

sale:
  price_cents: 45000000
  title:
    en: "Charming Family Home"
  description:
    en: "Beautiful 3-bedroom house..."

features:
  - features.private_garden
  - amenities.central_heating
```

### Step 4: Add Content (Optional)

Create content files for each page:

```yaml
# content/home.yml
heroes/hero_centered:
  title:
    en: "Welcome to My Agency"
  cta_text:
    en: "Browse Properties"
```

### Step 5: Test the Pack

```bash
# Preview first
rails pwb:seed_packs:preview[my_new_pack]

# Apply to test website
rails pwb:seed_packs:apply[my_new_pack]
```

## Inheritance

Packs can inherit from parent packs:

```yaml
# Child pack inherits field_keys, links from base
inherits_from: base
```

When applied:
1. Parent pack is applied first (with skip_website and skip_agency)
2. Child pack is applied, overriding parent where specified

## Key Patterns

### Multi-Language Content

Always provide translations for supported locales:

```yaml
title:
  en: "English Title"
  es: "Título en Español"
  de: "Deutscher Titel"
```

### Price Format

Prices are always in cents to avoid floating-point issues:

```yaml
sale:
  price_cents: 395000000  # = 3,950,000.00
rental:
  monthly_price_cents: 150000  # = 1,500.00/month
```

### Feature References

Features reference field_keys using dot notation:

```yaml
features:
  - features.private_pool      # from field_keys.yml features section
  - amenities.air_conditioning # from field_keys.yml amenities section
  - types.villa                # from field_keys.yml types section
```

### Image Handling

Images are looked up in order:
1. Pack's `images/` directory
2. Shared `db/seeds/images/` directory

```yaml
image: villa_ocean.jpg  # Filename only, no path
```

## Existing Packs Reference

### base
- Foundation pack inherited by all others
- Contains common field_keys and navigation links
- No properties or users

### spain_luxury
- Spanish Costa del Sol luxury real estate scenario
- 7 properties (villas, apartments, penthouses)
- 3 languages (es, en, de)
- Complete home page content

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| SeedPack class | `lib/pwb/seed_pack.rb` | Main implementation |
| Rake tasks | `lib/tasks/seed_packs.rake` | CLI interface |
| Base pack | `db/seeds/packs/base/` | Foundation pack |
| Spain luxury | `db/seeds/packs/spain_luxury/` | Example pack |
| Documentation | `docs/seeding/seed_packs_plan.md` | Detailed docs |
