# Seed Data System Documentation

This directory contains comprehensive documentation about PropertyWebBuilder's seed data system. The system is designed for multi-tenant websites with pre-configured, scenario-based setup using "seed packs."

## Quick Start

### What is a Seed Pack?

A **Seed Pack** is a self-contained bundle of pre-configured data representing a real-world scenario. Each pack includes:

- Website configuration (theme, locales, currency)
- Agency details
- Property field keys (types, states, features)
- Sample properties with images
- Navigation links
- Page content in multiple languages
- Demo user accounts

**Example**: The `netherlands_urban` pack creates a fully functional Dutch real estate agency website with 8 sample properties in 15 seconds.

### Quick Commands

```bash
# List available packs
rails pwb:seed_packs:list

# Preview a pack (dry run)
rails pwb:seed_packs:preview[netherlands_urban]

# Apply to default website
rails pwb:seed_packs:apply[netherlands_urban]

# Apply to specific website
rails pwb:seed_packs:apply[netherlands_urban,5]

# Apply with selective options
rails pwb:seed_packs:apply_with_options[spain_luxury,'skip_properties']
```

### From Rails Console

```ruby
# Apply a pack
pack = Pwb::SeedPack.find('netherlands_urban')
pack.apply!(website: Pwb::Website.first)

# Preview
pack.preview

# Dry run
pack.apply!(
  website: Pwb::Website.first,
  options: { dry_run: true }
)
```

---

## Documentation Structure

### Core Documentation

1. **[SEED_SYSTEM_OVERVIEW.md](SEED_SYSTEM_OVERVIEW.md)** - Start here
   - Complete architecture overview
   - Directory structure and file formats
   - All configuration patterns
   - Seeding patterns and best practices
   - **Best for**: Understanding how the system works

2. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick lookup
   - Command reference
   - YAML format examples
   - Code snippets for common tasks
   - **Best for**: Looking up syntax and examples

3. **[RAKE_TASKS.md](RAKE_TASKS.md)** - Rake task reference
   - Complete documentation of each rake task
   - Usage examples for each task
   - Error handling and troubleshooting
   - Scripting examples
   - **Best for**: Working with rake tasks

### Supplementary Documentation

- **[SEEDING_COMPREHENSIVE_GUIDE.md](SEEDING_COMPREHENSIVE_GUIDE.md)** - In-depth guide (16 Dec)
- **[seed_packs_plan.md](seed_packs_plan.md)** - Architecture planning document
- **[external_seed_images.md](external_seed_images.md)** - Image management in R2/cloud storage
- **[seed_image_optimization.md](seed_image_optimization.md)** - Image optimization techniques
- **[RESPONSIVE_IMAGES.md](RESPONSIVE_IMAGES.md)** - Responsive image setup

---

## What's in the System

### Available Seed Packs

Three packs are currently available:

1. **base** - Foundation pack with field keys, navigation, and page structure
   - Inherited by all other packs
   - No sample properties (abstract)
   - Common field keys for all property types

2. **netherlands_urban** - Dutch real estate agency
   - Inherits from: base
   - Theme: bologna
   - Locales: nl, en
   - Properties: 8 Dutch properties (Amsterdam, Rotterdam, Utrecht, The Hague)
   - Users: admin + agent

3. **spain_luxury** - Spanish luxury real estate
   - Inherits from: base
   - Theme: brisbane
   - Locales: es, en, de
   - Properties: 7 luxury properties (Costa del Sol)
   - Users: admin + agent

### Directory Structure

```
db/seeds/
├── packs/                           # Seed packs
│   ├── base/                        # Inherited by all packs
│   │   ├── pack.yml                 # Configuration
│   │   ├── field_keys.yml           # Property types, states, features
│   │   └── links.yml                # Navigation links
│   ├── netherlands_urban/           # Dutch agency example
│   │   ├── pack.yml
│   │   ├── field_keys.yml
│   │   ├── properties/              # 8 properties
│   │   ├── content/                 # Page content
│   │   └── images/                  # Property images
│   └── spain_luxury/                # Spanish agency example
│       ├── pack.yml
│       ├── properties/              # 7 properties
│       ├── content/                 # Page content
│       └── images/                  # Property images
├── images/                          # Shared seed images
└── translations_*.rb                # Multi-language translations

lib/tasks/
├── seed_packs.rake                  # Primary rake tasks
├── pwb_update_seeds.rake            # Legacy seeding
├── pwb_seed_with_onboarding.rake    # Provisioning flow
└── seed_images.rake                 # Image management

lib/pwb/
├── seed_pack.rb                     # Main orchestrator (912 lines)
├── seeder.rb                        # Legacy seeder (586 lines)
├── seed_runner.rb                   # Interactive wrapper (549 lines)
├── pages_seeder.rb                  # Page seeding
├── contents_seeder.rb               # Content seeding
└── seed_images.rb                   # Image URL management
```

---

## Key Features

### 1. Modular Seed Packs

Each pack is independent and self-contained:
- Can be applied to any website
- Can inherit from parent packs
- Includes all data (config, properties, content, images)

### 2. Multi-Tenancy Support

Data is fully scoped to websites:
```ruby
website1.field_keys     # Isolated to website1
website2.field_keys     # Isolated to website2 (separate)

website1.properties     # Scoped by website_id
website2.properties     # Scoped by website_id
```

### 3. Multi-Language Translations

All content supports multiple languages:
```yaml
title:
  nl: "Dutch Title"
  en: "English Title"
  de: "German Title"
```

### 4. Idempotent Seeding

Safe to run multiple times:
- Deduplicates by reference, slug, email
- Won't create duplicates
- Can update existing records
- No data loss

### 5. Flexible Seeding Options

Apply selectively:
```bash
# Skip properties
rails pwb:seed_packs:apply_with_options[pack,'skip_properties']

# Skip multiple sections
rails pwb:seed_packs:apply_with_options[pack,'skip_users,skip_content']

# Dry run preview
pack.apply!(website: website, options: { dry_run: true })
```

### 6. External Image Storage

Reduces database bloat:
- Uses external URLs (R2/Cloudflare)
- Falls back to local files if configured
- Automatic URL construction based on pack structure

---

## Common Workflows

### Setup New Agency Website

```bash
# 1. List available packs
rails pwb:seed_packs:list

# 2. Preview the pack you want
rails pwb:seed_packs:preview[spain_luxury]

# 3. Apply to your website
rails pwb:seed_packs:apply[spain_luxury,5]
```

### Quick Development Setup

```bash
# Setup without sample properties (faster)
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_properties']
```

### Reset and Reseed

```bash
# Dangerous! Deletes all data and reseeds
rails pwb:seed_packs:reset_and_apply[netherlands_urban]
```

### Testing Setup

```ruby
website = Pwb::Website.create!(subdomain: 'test')
Pwb::SeedPack.find('base').apply!(
  website: website,
  options: {
    skip_properties: true,
    skip_users: true,
    verbose: false
  }
)
```

### Create Custom Pack

```bash
# 1. Create directory
mkdir db/seeds/packs/my_agency

# 2. Create pack.yml with configuration
# 3. Create properties/, content/, images/ subdirectories
# 4. Add YAML files for properties and content
# 5. Test it
rails pwb:seed_packs:preview[my_agency]
```

---

## Configuration Data Patterns

The system seeds different types of configuration:

| Data Type | File | Scope | Example |
|-----------|------|-------|---------|
| **Field Keys** | `field_keys.yml` | Per-Website | Property types (villa, apartment), states (excellent, needs_renovation) |
| **Links** | `links.yml` | Per-Website | Navigation menu (Home, Buy, Sell, Contact) |
| **Pages** | `pages/` | Per-Website | Page definitions (home, about, sell, contact) |
| **Page Parts** | From pack.yml or `page_parts/` | Per-Website | Page templates (heroes, features, testimonials) |
| **Properties** | `properties/*.yml` | Per-Website | Sample listings with details, pricing, images |
| **Users** | `pack.yml` | Platform-wide | Admin and agent accounts |
| **Content** | `content/*.yml` | Per-Website | Page content (titles, descriptions, CTA text) |
| **Images** | `images/` | Local cache or R2 | Property photos, background images |

---

## File Format Reference

### pack.yml - Pack Configuration

```yaml
name: pack_name
display_name: "Display Name"
version: "1.0"
inherits_from: base           # Parent pack

website:
  theme_name: theme_name
  selected_palette: palette_id
  default_client_locale: en
  supported_locales: [en, es]
  currency: EUR

agency:
  display_name: "Agency Name"
  email: "email@example.com"
  address:
    street_address: "Address"
    city: City
    country: Country

page_parts:
  home:
    - key: heroes/hero_centered
      order: 1

users:
  - email: admin@example.com
    role: admin
    password: password
```

### field_keys.yml - Configuration Metadata

```yaml
types:
  villa:
    en: Villa
    es: Villa

states:
  excellent:
    en: Excellent
    es: Excelente

features:
  pool:
    en: Swimming Pool
    es: Piscina
```

### Property YAML - Property Details

```yaml
reference: PROP-001
prop_type: types.villa
address: "123 Main St"
city: Madrid
bedrooms: 4
bathrooms: 3
constructed_area: 300
price_cents: 500000000    # €5,000,000

sale:
  title:
    en: "Luxury Villa"
    es: "Villa Lujosa"
  description:
    en: "Beautiful villa..."
    es: "Hermosa villa..."

features:
  - features.pool
  - amenities.heating

image: villa.jpg
```

### Content YAML - Page Content

```yaml
heroes/hero_centered:
  title:
    en: "Main Title"
    es: "Título Principal"
  subtitle:
    en: "Subtitle"
    es: "Subtítulo"
  cta_link: "/buy"

features/feature_grid_3col:
  feature_1_title:
    en: "Feature 1"
    es: "Característica 1"
```

---

## Architecture Layers

### Layer 1: Configuration Classes

- **Pwb::SeedPack** - Loads and applies packs
- **Pwb::Seeder** - Legacy seeder (backward compatible)
- **Pwb::SeedRunner** - Interactive wrapper with safety

### Layer 2: Rake Tasks

- **pwb:seed_packs:list** - List packs
- **pwb:seed_packs:preview** - Dry run
- **pwb:seed_packs:apply** - Apply pack
- **pwb:seed_packs:apply_with_options** - Apply with options
- **pwb:seed_packs:reset_and_apply** - Destructive reset

### Layer 3: Data Files

- YAML configuration (pack.yml, field_keys.yml, etc.)
- Property definitions (*.yml files)
- Content translations (*.yml files)
- Image assets (jpg, webp)

---

## Best Practices

1. **Always preview first**
   ```bash
   rails pwb:seed_packs:preview[pack_name]
   ```

2. **Use dry-run in development**
   ```ruby
   pack.apply!(website: website, options: { dry_run: true })
   ```

3. **Backup before reset**
   ```bash
   rails db:dump
   rails pwb:seed_packs:reset_and_apply[pack_name]
   ```

4. **Document custom packs**
   - Add README in pack directory
   - Document target market and use case
   - List sample properties included

5. **Test with console first**
   ```ruby
   pack = Pwb::SeedPack.find('custom_pack')
   pack.preview  # Inspect what will be seeded
   ```

6. **Use skip options for speed**
   ```bash
   rails pwb:seed_packs:apply_with_options[pack,'skip_properties,skip_translations']
   ```

---

## Troubleshooting

### Common Issues

**Pack not found**
```bash
rails pwb:seed_packs:list  # Verify pack exists
```

**Website not found**
```bash
rails dbconsole
SELECT id, subdomain FROM pwb_websites;  # Verify website ID
```

**Seed images unavailable (warning)**
```bash
# Set image URL environment variable
export SEED_IMAGES_BASE_URL=https://images.example.com
```

**Duplicate records created**
- Packs are idempotent - this shouldn't happen
- Check deduplication logic in seed_pack.rb
- Verify references/slugs are unique

**Data loss after reset**
- `reset_and_apply` is destructive and irreversible
- Always backup first
- Use `apply` for safer seeding

---

## Documentation Navigation

### For Different Use Cases

- **I want to setup a new website**: Start with [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **I want to understand the system**: Read [SEED_SYSTEM_OVERVIEW.md](SEED_SYSTEM_OVERVIEW.md)
- **I need rake task documentation**: See [RAKE_TASKS.md](RAKE_TASKS.md)
- **I want to create a custom pack**: Check examples in `db/seeds/packs/`
- **I need detailed architecture info**: See [SEEDING_COMPREHENSIVE_GUIDE.md](SEEDING_COMPREHENSIVE_GUIDE.md)

### For Different Roles

- **Developers**: [SEED_SYSTEM_OVERVIEW.md](SEED_SYSTEM_OVERVIEW.md) + [RAKE_TASKS.md](RAKE_TASKS.md)
- **DevOps/SREs**: [RAKE_TASKS.md](RAKE_TASKS.md) + scripting section
- **Product Managers**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for understanding capabilities
- **QA/Testers**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for test data setup

---

## Related Files in Codebase

- **Seed pack classes**: `lib/pwb/seed_pack.rb`, `lib/pwb/seed_runner.rb`
- **Rake tasks**: `lib/tasks/seed_packs.rake`, `lib/tasks/pwb_update_seeds.rake`
- **Database schema**: Check migrations for `pwb_field_keys`, `pwb_links`, `pwb_pages`, `pwb_page_parts`
- **Models**: `app/models/pwb/field_key.rb`, `app/models/pwb/realty_asset.rb`, etc.

---

## Version Information

- **Current System**: Seed Packs v1.0
- **Available Packs**: base, netherlands_urban, spain_luxury
- **Last Updated**: 2026-01-02
- **Documentation**: Comprehensive (3 core docs + 10+ supplementary)

---

## Quick Links

- [Seed System Architecture](SEED_SYSTEM_OVERVIEW.md)
- [Quick Reference Guide](QUICK_REFERENCE.md)
- [Rake Tasks Documentation](RAKE_TASKS.md)
- [Comprehensive Guide](SEEDING_COMPREHENSIVE_GUIDE.md)
- [Seed Packs Plan](seed_packs_plan.md)

---

**Questions?** Check the documentation files above or review the source code in `lib/pwb/seed_pack.rb`.
