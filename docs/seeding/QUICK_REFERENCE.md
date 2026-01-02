# Seed System Quick Reference

## Rake Tasks

```bash
# List all packs
rails pwb:seed_packs:list

# Preview pack (dry run)
rails pwb:seed_packs:preview[pack_name]

# Apply to default website
rails pwb:seed_packs:apply[pack_name]

# Apply to specific website
rails pwb:seed_packs:apply[pack_name,website_id]

# Apply with options
rails pwb:seed_packs:apply_with_options[pack_name,'skip_users,skip_properties']

# Reset and apply (destructive!)
rails pwb:seed_packs:reset_and_apply[pack_name]
```

## Console Usage

```ruby
# Apply a pack
pack = Pwb::SeedPack.find('netherlands_urban')
pack.apply!(website: Pwb::Website.first)

# Dry run
pack.apply!(website: Pwb::Website.first, options: { dry_run: true })

# With options
pack.apply!(
  website: Pwb::Website.find(5),
  options: {
    skip_properties: true,
    skip_users: true,
    verbose: false
  }
)

# List available packs
Pwb::SeedPack.available.map(&:name)

# Preview pack
Pwb::SeedPack.find('spain_luxury').preview
```

## Pack Structure

```
db/seeds/packs/PACK_NAME/
├── pack.yml              # Configuration
├── field_keys.yml        # Property types, states, features
├── links.yml             # Navigation links
├── properties/           # Property YAML files
│   └── property1.yml
├── content/              # Page content translations
│   ├── home.yml
│   ├── about-us.yml
│   ├── sell.yml
│   └── contact-us.yml
└── images/               # Images
    ├── image1.jpg
    └── image1.webp
```

## Pack Configuration (pack.yml)

### Minimal Example
```yaml
name: my_pack
display_name: "My Pack"
description: "Description"
inherits_from: base

website:
  theme_name: default
  supported_locales: [en]
  currency: EUR
```

### Full Example
```yaml
name: netherlands_urban
display_name: "Dutch Urban Real Estate"
version: "1.0"
inherits_from: base

website:
  theme_name: bologna
  selected_palette: modern_slate
  default_client_locale: nl
  supported_locales: [nl, en]
  currency: EUR
  area_unit: sqmt

agency:
  display_name: "Agency Name"
  email: "info@example.nl"
  phone: "+31 20 123 4567"
  address:
    street_address: "Street 1"
    city: City
    region: Region
    country: Country
    postal_code: "12345"

page_parts:
  home:
    - key: heroes/hero_centered
      order: 1
    - key: features/feature_grid_3col
      order: 2

users:
  - email: admin@example.nl
    role: admin
    password: demo123
```

## Property YAML Format

```yaml
reference: NL-001          # Unique ID
prop_type: types.villa     # Links to field key
prop_state: states.excellent

# Location
address: "Street 1"
city: Amsterdam
region: Noord-Holland
country: Netherlands
postal_code: "1012"
latitude: 52.37
longitude: 4.89

# Details
bedrooms: 4
bathrooms: 2
garages: 1
constructed_area: 250
plot_area: 400
year_built: 2000

# Sale Listing
sale:
  highlighted: true
  price_cents: 50000000  # €500,000
  title:
    nl: "Title in Dutch"
    en: "Title in English"
  description:
    nl: "Description in Dutch"
    en: "Description in English"

# OR Rental Listing
rental:
  highlighted: false
  monthly_price_cents: 200000  # €2,000/month
  long_term: true
  short_term: false
  furnished: true

# Features
features:
  - features.garden
  - amenities.heating
  - labels.new

# Image
image: property.jpg
```

## Field Keys YAML Format

```yaml
# Hierarchical format (translated)

types:
  villa:
    en: Villa
    nl: Villa
  apartment:
    en: Apartment
    nl: Appartement

states:
  excellent:
    en: Excellent
    nl: Uitstekend
  needs_renovation:
    en: Needs Renovation
    nl: Renovatiebehoefte

features:
  private_pool:
    en: Private Pool
    nl: Privé zwembad
  garden:
    en: Garden
    nl: Tuin

amenities:
  heating:
    en: Heating
    nl: Verwarming

labels:
  new:
    en: New
    nl: Nieuw
```

## Links YAML Format

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
```

## Page Content YAML Format

```yaml
# For home.yml, about-us.yml, etc.

heroes/hero_centered:
  pretitle:
    nl: "Subtitle"
    en: "Subtitle"
  title:
    nl: "Main Title"
    en: "Main Title"
  subtitle:
    nl: "Description"
    en: "Description"
  cta_text:
    nl: "Button Text"
    en: "Button Text"
  cta_link: "/path"
  background_image: "db/seeds/packs/pack_name/images/image.jpg"

features/feature_grid_3col:
  section_title:
    nl: "Title"
    en: "Title"
  feature_1_title:
    nl: "Feature"
    en: "Feature"
  feature_1_description:
    nl: "Description"
    en: "Description"
```

## Core Classes

| Class | Purpose | Location |
|-------|---------|----------|
| `Pwb::SeedPack` | Load and apply packs | `lib/pwb/seed_pack.rb` |
| `Pwb::Seeder` | Legacy individual seeding | `lib/pwb/seeder.rb` |
| `Pwb::SeedRunner` | Interactive wrapper | `lib/pwb/seed_runner.rb` |
| `Pwb::PagesSeeder` | Page and page_part seeding | `lib/pwb/pages_seeder.rb` |
| `Pwb::ContentsSeeder` | Page content seeding | `lib/pwb/contents_seeder.rb` |

## Skip Options

```ruby
pack.apply!(
  website: website,
  options: {
    skip_website: true,        # Don't update theme/locales
    skip_agency: true,         # Don't create agency
    skip_field_keys: true,     # Don't create field keys
    skip_links: true,          # Don't create navigation links
    skip_pages: true,          # Don't create pages
    skip_page_parts: true,     # Don't create page templates
    skip_properties: true,     # Don't create sample properties
    skip_content: true,        # Don't seed page content
    skip_users: true,          # Don't create demo accounts
    skip_translations: true,   # Don't seed i18n translations
    dry_run: true,             # Preview without changes
    verbose: false             # Suppress logging
  }
)
```

## Multi-Tenancy Scoping

```ruby
# Each website gets isolated data
website1 = Pwb::Website.find(1)
website2 = Pwb::Website.find(2)

# Apply to website1 only
Pwb::SeedPack.find('netherlands_urban').apply!(website: website1)

# Data is scoped
website1.field_keys.count          # >= 0
website2.field_keys.count          # >= 0 (separate)

website1.properties.count          # >= 0
website2.properties.count          # >= 0 (separate)
```

## Available Packs

```
base                - Foundation pack with field keys and navigation
netherlands_urban   - Dutch agency with Amsterdam, Rotterdam, Utrecht properties
spain_luxury        - Spanish luxury agency with Costa del Sol properties
```

## Common Workflows

### Setup New Website from Pack
```bash
# List options
rails pwb:seed_packs:list

# Preview
rails pwb:seed_packs:preview[spain_luxury]

# Apply to new website
rails pwb:seed_packs:apply[spain_luxury,5]
```

### Reset and Reseed
```bash
# Destructive reset
rails pwb:seed_packs:reset_and_apply[netherlands_urban]
```

### Development/Testing
```ruby
# Fast setup without properties
Pwb::SeedPack.find('base').apply!(
  website: website,
  options: { skip_properties: true }
)
```

### Custom Pack Development
```bash
# 1. Create directory
mkdir db/seeds/packs/my_pack

# 2. Create pack.yml with inherits_from: base
# 3. Add properties/content/field_keys as needed
# 4. Test it
rails pwb:seed_packs:preview[my_pack]
rails pwb:seed_packs:apply[my_pack,1]
```

## Deduplication Rules

| Data Type | Dedup By | Location |
|-----------|----------|----------|
| Links | `slug` | `db/seeds/packs/PACK/links.yml` |
| Pages | `slug` | `db/seeds/packs/PACK/pages/` |
| Properties | `reference` | `db/seeds/packs/PACK/properties/` |
| Users | `email` | `pack.yml` → `users` |
| Field Keys | `global_key + website_id` | `db/seeds/packs/PACK/field_keys.yml` |

## Environment Variables

```bash
# Use external seed images (R2/Cloudflare)
R2_SEED_IMAGES_BUCKET=bucket-name
SEED_IMAGES_BASE_URL=https://images.example.com

# Skip properties in default seed
SKIP_PROPERTIES=true
```

## Troubleshooting

```bash
# Clear and reseed everything
rails db:reset
rails pwb:seed_packs:apply[netherlands_urban]

# Dry run to see what would happen
rails pwb:seed_packs:preview[spain_luxury]

# Check available packs
rails pwb:seed_packs:list

# Debug console
rails console
Pwb::SeedPack.available.map { |p| [p.name, p.display_name] }
```
