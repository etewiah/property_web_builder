# PropertyWebBuilder Content Model Research

## Overview

PropertyWebBuilder is a multi-tenant real estate SaaS platform where each tenant gets a fully configured website. The system uses a sophisticated seed pack mechanism to provision websites with pre-configured content, properties, pages, and navigation.

## Content Model Structure

### Core Models

#### 1. **Pwb::Page** (`app/models/pwb/page.rb`)
- CMS pages for websites (home, about-us, contact-us, sell, etc.)
- Multi-locale support via Mobility gem (JSONB storage)
- Translatable fields: `raw_html`, `page_title`, `link_title`
- **Multi-tenancy**: Each page belongs to a `website` (website_id foreign key)
- Indexes: `slug` and `website_id` are unique together
- Related models:
  - `has_many :page_parts` - The template sections for the page
  - `has_many :page_contents` - Join models to contents
  - `has_many :contents` - The actual content blocks through join table
  - `has_many :links` - Navigation links associated with the page

#### 2. **Pwb::PagePart** (`app/models/pwb/page_part.rb`)
- Liquid template fragments that define the structure of page sections
- Can be theme-specific or use defaults
- Stored as text in database or loaded from filesystem
- Template resolution (priority): Database > Theme-specific file > Default file
- Multi-tenancy: `website_id` and unique index on `(page_part_key, page_slug, website_id)`
- Fields:
  - `page_part_key` - Identifier like `heroes/hero_centered`, `features/feature_grid_3col`
  - `page_slug` - Which page uses this part
  - `template` - Liquid template code
  - `block_contents` - JSON structure defining editable blocks within the template
  - `editor_setup` - Configuration for the editor UI
  - `is_rails_part` - Whether it's a custom Rails partial

#### 3. **Pwb::Content** (`app/models/pwb/content.rb`)
- Stores translatable content blocks (text, HTML, etc.)
- Multi-locale via Mobility: `raw_en`, `raw_nl`, `raw_es`, etc.
- Multi-tenancy: `website_id` foreign key, unique on `(website_id, key)`
- Fields:
  - `key` - Unique identifier for the content
  - `page_part_key` - Which page part this content belongs to
  - `raw` - HTML/text content (translatable via Mobility)
  - `input_type` - Type of input (html, text, etc.)
  - `status` - Publication status
  - `target_url` - Optional link URL
  - `tag` - Category tag for content

#### 4. **Pwb::PageContent** (`app/models/pwb/page_content.rb`)
- **Join model** connecting Pages and Content
- Allows same content block to appear on multiple pages
- Allows different sort orders and visibility per page
- Multi-tenancy: `website_id` foreign key
- Fields:
  - `visible_on_page` - Boolean to show/hide content
  - `sort_order` - Order within the page
  - `page_part_key` - References the page part
  - `label` - Optional label for this content instance
  - `is_rails_part` - Boolean for Rails partials

### Photo/Image Models

#### 5. **Pwb::ContentPhoto** (`app/models/pwb/content_photo.rb`)
- Images attached to Content blocks
- Uses Active Storage (`has_one_attached :image`)
- Multi-tenancy: `content_id` foreign key (via Content)
- Includes `ExternalImageSupport` mixin for external URL storage
- Fields:
  - `block_key` - Which block within content this image is for
  - `external_url` - URL for external images
  - `description` - Alt text
  - `folder` - Storage folder
  - `sort_order` - Order for multiple images
- Methods:
  - `optimized_image_url` - Returns CDN URL or external URL
  - `image_filename` - Extracts filename from URL or attribute

#### 6. **Pwb::WebsitePhoto** (`app/models/pwb/website_photo.rb`)
- Branding images for websites (logos, hero images, etc.)
- Uses Active Storage
- Multi-tenancy: `website_id` foreign key
- Fields:
  - `photo_key` - Identifier (e.g., 'logo', 'hero_background')
  - `external_url` - For external image mode
  - `description` - Purpose/alt text

## Multi-Tenancy Architecture

**Key Pattern**: Every content model includes `website_id` foreign key
- `Pwb::Website` is the tenant model
- Content is scoped to `website.id`
- Indexes ensure uniqueness per website (e.g., `(slug, website_id)` for pages)
- **Important**: Non-scoped models in `app/models/pwb/` are available for cross-tenant operations
- **Tenant-scoped models** exist in `PwbTenant::` namespace for web requests

## Data Association Example

```
Pwb::Website
  └─ has_many :pages
  └─ has_many :page_parts
  └─ has_many :contents
  └─ has_many :links

Pwb::Page (e.g., "home")
  ├─ has_many :page_parts (e.g., heroes/hero_centered)
  │  └─ has_many :content_blocks via block_contents JSON
  └─ has_many :page_contents (join table)
     └─ has_many :contents (actual content blocks)
        └─ has_many :content_photos

Pwb::Content (e.g., key: "hero_centered/title")
  ├─ raw_en: "Welcome to our site" (Mobility translatable)
  ├─ raw_nl: "Welkom op onze site"
  ├─ has_many :content_photos
  └─ has_many :page_contents (can be reused across pages)
```

## Seed Pack System

### Architecture

**Location**: `db/seeds/packs/*/`

Seed packs are pre-configured bundles containing:
1. `pack.yml` - Pack metadata and configuration
2. `content/` - Page content translations (YAML files)
3. `properties/` - Property listings (YAML files)
4. `page_parts/` - Custom page part templates (optional)
5. `field_keys.yml` - Property field definitions
6. `links.yml` - Navigation links
7. `images/` - Seed images

### Pack Configuration Structure

```yaml
name: netherlands_urban
display_name: "Dutch Urban Real Estate"
description: "..."
version: "1.0"
inherits_from: base  # Can inherit from parent pack

website:
  theme_name: bologna
  selected_palette: modern_slate
  default_client_locale: nl
  supported_locales: [nl, en]
  currency: EUR
  area_unit: sqmt
  search_config: {...}  # Custom search filters

agency:
  display_name: "Van der Berg Makelaars"
  email: "info@..."
  phone: "+31..."
  address:
    street_address: "..."
    city: Amsterdam
    region: Noord-Holland

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

### Content Files Format

**File**: `db/seeds/packs/netherlands_urban/content/home.yml`

```yaml
# Key is page_part_key like "heroes/hero_centered"
heroes/hero_centered:
  pretitle:
    nl: "Welkom bij Van der Berg Makelaars"
    en: "Welcome to Van der Berg Real Estate"
  title:
    nl: "Uw droomhuis in Nederland"
    en: "Your Dream Home in the Netherlands"
  cta_text:
    nl: "Bekijk woningen"
  cta_link: "/search/buy"
  background_image: "db/seeds/packs/netherlands_urban/images/hero_amsterdam_canal.jpg"
```

### Property Files Format

**File**: `db/seeds/packs/netherlands_urban/properties/grachtenpand_amsterdam.yml`

```yaml
reference: NL-GRA-001
prop_type: types.grachtenpand
prop_state: states.gerenoveerd
address: "Keizersgracht 324"
city: Amsterdam
bedrooms: 5
bathrooms: 3
constructed_area: 280
year_built: 1685

sale:
  highlighted: true
  price_cents: 249500000  # In cents
  title:
    nl: "Monumentaal grachtenpand aan de Keizersgracht"
    en: "Monumental Canal House on Keizersgracht"
  description:
    nl: "Prachtig gerestaureerd..."
    en: "Beautifully restored..."

features:
  - features.grachtzicht
  - amenities.cv_ketel
  - labels.centrum

image: amsterdam_canal_house.jpg
```

## Import/Export Functionality

### Existing Patterns

#### 1. **CSV Import/Export** (`app/models/pwb/content.rb`)
```ruby
# Export
Content.to_csv(export_column_names)
Content.to_csv_for_website(website, export_column_names)

# Import
Content.import(file)
```

#### 2. **Property Import Service** (`app/services/pwb/import_properties.rb`)
- `ImportProperties.new(csv_file).import_csv`
- Parses CSV and returns array of property hashes
- Has MLS TSV import support via ImportMapper

#### 3. **Property Export Service** (`app/services/pwb/property_export_service.rb`)
- Likely exports properties in various formats

#### 4. **Seed Pack System** (Main Pattern)
- Uses YAML files for structured data
- Inheritance model (packs can inherit from base)
- Comprehensive metadata in pack.yml
- All data is scoped to website via seed_pack.apply!(website: website)

### Seed Pack Seeding Methods

**Location**: `lib/pwb/seed_pack.rb`

Main entry point:
```ruby
pack = Pwb::SeedPack.find('netherlands_urban')
pack.apply!(website: website)
```

Granular seeding methods available:
- `seed_website!(website:)` - Configure theme, locale, currency
- `seed_agency!(website:)` - Create agency info
- `seed_field_keys!(website:)` - Property field definitions
- `seed_links!(website:)` - Navigation structure
- `seed_pages!(website:)` - CMS pages
- `seed_page_parts!(website:)` - Page templates
- `seed_properties!(website:)` - Listings
- `seed_content!(website:)` - Page content translations
- `seed_users!(website:)` - Team members

## Content Seeding Workflow

### Step 1: Page Setup
1. Create `Pwb::Page` with slug (e.g., 'home')
2. Assign `website_id`
3. Set translations: `page_title_en`, `page_title_nl`, etc.

### Step 2: Page Parts Setup
1. Create `Pwb::PagePart` entries for each section
2. Store Liquid template in `template` field
3. Store block structure in `block_contents` JSON
4. Link via `page_part_key` and `page_slug`

### Step 3: Content Creation
1. Create `Pwb::Content` blocks (key, page_part_key, raw_en, raw_nl, etc.)
2. Assign to website via `website_id`

### Step 4: Content Association
1. Create `Pwb::PageContent` join records
2. Associates `page_id` with `content_id`
3. Sets `visible_on_page` and `sort_order`

### Step 5: Images
1. Attach `ContentPhoto` to content
2. Upload via Active Storage or store external URL
3. Set `block_key` to link to specific blocks

## Rake Tasks for Content

**Location**: `lib/tasks/seed_packs.rake`

```bash
# List available packs
rails pwb:seed_packs:list

# Preview what a pack will create
rails pwb:seed_packs:preview[pack_name]

# Apply a pack to a website
rails pwb:seed_packs:apply[pack_name,website_id]

# Apply with options
rails pwb:seed_packs:apply_with_options[pack_name,'skip_properties,skip_users']

# Reset database and apply
rails pwb:seed_packs:reset_and_apply[pack_name]
```

## Key Implementation Details

### Translations/Localization
- Uses **Mobility gem** with JSONB backend
- Single JSONB column stores all locale translations
- Access via: `content.raw_en`, `content.raw_nl`, etc.
- Use `Mobility.with_locale(locale) { content.raw = '...' }`

### External Image Support
- Models include `ExternalImageSupport` mixin
- Can use either Active Storage attachments or external URLs
- `external_url` column for linking to CDN/external hosts
- `optimized_image_url` method returns CDN or external URL

### Template System
- **Liquid templates** for dynamic page parts
- Template sources (priority): DB > Theme file > Default file
- Block-based editing via `block_contents` JSON
- Editor UI configuration in `editor_setup`

### Asset Storage
- Active Storage with configurable backends
- Supports local, S3, R2, and custom backends
- CDN support via `CDN_IMAGES_URL` or `R2_PUBLIC_URL`

## Content Management Patterns

### Pattern 1: Global Content (website.contents)
- Stored in `Content` model
- Scoped by `website_id`
- Typically used for website-wide strings (contact info, footer, etc.)
- CSV export/import available

### Pattern 2: Page Content (PageContent join model)
- Associated via `PageContent` join table
- Allows reuse of content blocks across pages
- Per-page visibility and sort order control
- Includes page_part_key for structure

### Pattern 3: Page Templates (PagePart)
- Liquid-based templates
- Block-based content editing
- Theme override capability
- Store in DB or filesystem

## Dependencies and Integration

### Related Models
- `Pwb::Website` - Tenant container
- `Pwb::Link` - Navigation links
- `Pwb::FieldKey` - Property field definitions
- `Pwb::User` - Content editors
- `Pwb::Theme` - Theme configuration
- `Pwb::Media` / `Pwb::MediaFolder` - Asset management

### Storage Services
- Active Storage for image attachments
- Rails cache for template caching
- Database for translations (JSONB)

### Import Capabilities
- CSV files for content
- YAML files for seed packs
- Property imports from CSV/TSV
- MLS TSV import via ImportMapper

## Summary

PropertyWebBuilder's content system is:

1. **Multi-tenant**: Each website gets isolated content via `website_id`
2. **Highly translatable**: Mobility gem with JSONB enables 10+ language support
3. **Template-based**: Liquid templates with block editing
4. **Pack-based provisioning**: YAML-driven seed packs for quick setup
5. **Hierarchical**: Pages > PageParts > Content > Photos
6. **Flexible**: Supports both internal storage and external image URLs
7. **Themable**: Template resolution allows theme-specific overrides

The seed pack system is the primary import mechanism, allowing pre-configured website scenarios to be applied to new tenants with full content, properties, structure, and styling.
