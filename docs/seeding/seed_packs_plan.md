# Seed Packs Implementation Plan

This document outlines the plan for implementing "Seed Packs" - a scenario-based approach to organizing and applying seed data in PropertyWebBuilder.

## Overview

Seed Packs are pre-configured bundles of seed data representing real-world scenarios. Each pack contains all the data needed to create a fully functional tenant website for a specific use case.

## Goals

1. **Scenario-Based Seeding**: Group seed data by realistic business scenarios
2. **Easy Tenant Setup**: Quickly spin up demo/test tenants with realistic data
3. **Composable**: Packs can inherit from or extend other packs
4. **Maintainable**: Clear separation between scenarios, easy to update
5. **Locale-Aware**: Support multiple languages per scenario

## Example Scenarios

| Pack Name | Description | Locales | Property Types |
|-----------|-------------|---------|----------------|
| `spain_luxury` | Spanish estate agent with luxury villas | es, en, de | Villas, Penthouses |
| `uk_residential` | UK residential agency | en | Houses, Flats |
| `france_vacation` | French vacation rentals | fr, en, de | Vacation homes |
| `usa_commercial` | US commercial real estate | en | Offices, Retail |
| `germany_mixed` | German mixed-use agency | de, en | Mixed residential/commercial |

## Proposed Directory Structure

```
db/
├── seeds/
│   ├── packs/                          # Seed pack definitions
│   │   ├── base/                       # Base pack (inherited by all)
│   │   │   ├── pack.yml                # Pack metadata and config
│   │   │   ├── field_keys.yml          # Core field keys
│   │   │   ├── pages.yml               # Standard page structure
│   │   │   └── links.yml               # Navigation links
│   │   │
│   │   ├── spain_luxury/               # Spain luxury scenario
│   │   │   ├── pack.yml                # Pack config (inherits: base)
│   │   │   ├── website.yml             # Website settings
│   │   │   ├── agency.yml              # Agency info
│   │   │   ├── properties/             # Property definitions
│   │   │   │   ├── villa_marbella.yml
│   │   │   │   ├── penthouse_barcelona.yml
│   │   │   │   └── ...
│   │   │   ├── translations/           # Pack-specific translations
│   │   │   │   ├── es.yml
│   │   │   │   ├── en.yml
│   │   │   │   └── de.yml
│   │   │   ├── content/                # Page content
│   │   │   │   └── home.yml
│   │   │   └── images/                 # Property images
│   │   │       ├── villa_marbella_1.jpg
│   │   │       └── ...
│   │   │
│   │   ├── uk_residential/             # UK residential scenario
│   │   │   ├── pack.yml
│   │   │   └── ...
│   │   │
│   │   └── usa_commercial/             # USA commercial scenario
│   │       ├── pack.yml
│   │       └── ...
│   │
│   ├── e2e_seeds.rb                    # E2E test seeds (uses packs)
│   └── translations_*.rb               # Global translations
│
└── yml_seeds/                          # Legacy location (backwards compat)
```

## Pack Configuration (pack.yml)

```yaml
# db/seeds/packs/spain_luxury/pack.yml
name: spain_luxury
display_name: "Spanish Luxury Real Estate"
description: "Estate agent specializing in luxury properties on the Costa del Sol"
version: "1.0"

# Inheritance
inherits_from: base

# Website Configuration
website:
  theme_name: bristol
  default_client_locale: es
  supported_locales:
    - es
    - en
    - de
  country: Spain
  currency: EUR
  area_unit: sqm

# Agency Configuration
agency:
  display_name: "Costa Luxury Properties"
  email: "info@costaluxury.es"
  phone: "+34 952 123 456"
  address:
    city: Marbella
    region: Málaga
    country: Spain
    postal_code: "29600"

# Property Configuration
properties:
  count: 8                    # Number of properties to generate
  types:                      # Property type distribution
    - type: villa
      percentage: 50
      price_range: [800000, 5000000]
    - type: penthouse
      percentage: 30
      price_range: [400000, 2000000]
    - type: apartment
      percentage: 20
      price_range: [200000, 800000]

  listing_types:
    - for_sale: 70%
    - for_rent: 20%
    - both: 10%

  features:
    common:
      - features.private_pool
      - features.sea_views
      - amenities.air_conditioning
    luxury:
      - features.heated_pool
      - features.wine_cellar
      - features.home_automation

# Content Configuration
content:
  home:
    tagline:
      es: "Propiedades de lujo en la Costa del Sol"
      en: "Luxury properties on the Costa del Sol"
      de: "Luxusimmobilien an der Costa del Sol"

# Users
users:
  - email: admin@costaluxury.es
    role: admin
    password: demo123
```

## Implementation Components

### 1. SeedPack Class

```ruby
# lib/pwb/seed_pack.rb
module Pwb
  class SeedPack
    attr_reader :name, :config, :path

    def initialize(name)
      @name = name
      @path = Rails.root.join('db', 'seeds', 'packs', name)
      @config = load_config
    end

    def apply!(website:, options: {})
      validate!

      # Apply inherited pack first
      if config[:inherits_from]
        parent = SeedPack.new(config[:inherits_from])
        parent.apply!(website: website, options: options.merge(skip_website: true))
      end

      # Apply this pack's data
      seed_website(website) unless options[:skip_website]
      seed_agency(website)
      seed_properties(website)
      seed_content(website)
      seed_users(website)
      seed_translations

      # Refresh materialized view
      Pwb::ListedProperty.refresh
    end

    def preview
      # Returns summary of what would be created
    end

    def self.available
      # Lists all available packs
    end

    def self.find(name)
      new(name)
    end
  end
end
```

### 2. SeedPackRunner (Rake Tasks)

```ruby
# lib/tasks/seed_packs.rake
namespace :pwb do
  namespace :seed_packs do
    desc "List all available seed packs"
    task list: :environment do
      Pwb::SeedPack.available.each do |pack|
        puts "#{pack.name}: #{pack.config[:display_name]}"
      end
    end

    desc "Preview a seed pack"
    task :preview, [:pack_name] => :environment do |t, args|
      pack = Pwb::SeedPack.find(args[:pack_name])
      puts pack.preview
    end

    desc "Apply a seed pack to create a new tenant"
    task :apply, [:pack_name, :subdomain] => :environment do |t, args|
      pack = Pwb::SeedPack.find(args[:pack_name])

      website = Pwb::Website.find_or_create_by!(subdomain: args[:subdomain]) do |w|
        w.slug = args[:subdomain]
        w.theme_name = pack.config.dig(:website, :theme_name)
      end

      pack.apply!(website: website)
    end
  end
end
```

### 3. Property Generator

```ruby
# lib/pwb/seed_pack/property_generator.rb
module Pwb
  class SeedPack
    class PropertyGenerator
      def initialize(pack_config, website)
        @config = pack_config[:properties]
        @website = website
        @locale = pack_config.dig(:website, :default_client_locale)
      end

      def generate!
        properties = []

        @config[:types].each do |type_config|
          count = (@config[:count] * type_config[:percentage] / 100.0).ceil
          count.times do |i|
            properties << create_property(type_config, i)
          end
        end

        properties
      end

      private

      def create_property(type_config, index)
        # Uses property YAML files if available
        # Falls back to generating realistic data
      end
    end
  end
end
```

## Usage Examples

### Command Line

```bash
# List available packs
rails pwb:seed_packs:list

# Preview what a pack would create
rails pwb:seed_packs:preview[spain_luxury]

# Create a new tenant with a pack
rails pwb:seed_packs:apply[spain_luxury,costa-luxury]

# Create with custom subdomain
SUBDOMAIN=my-agency rails pwb:seed_packs:apply[spain_luxury]
```

### Programmatic

```ruby
# In Rails console or scripts
pack = Pwb::SeedPack.find('spain_luxury')

# Create new website with pack
website = Pwb::Website.create!(subdomain: 'costa-demo', theme_name: 'bristol')
pack.apply!(website: website)

# Apply pack with options
pack.apply!(
  website: website,
  options: {
    skip_properties: false,
    skip_users: true,
    dry_run: false
  }
)
```

### E2E Testing

```ruby
# db/seeds/e2e_seeds.rb
# Create test tenants using packs

tenant_spain = Pwb::Website.find_or_create_by!(subdomain: 'spain-test') do |w|
  w.theme_name = 'bristol'
end
Pwb::SeedPack.find('spain_luxury').apply!(website: tenant_spain)

tenant_uk = Pwb::Website.find_or_create_by!(subdomain: 'uk-test') do |w|
  w.theme_name = 'bristol'
end
Pwb::SeedPack.find('uk_residential').apply!(website: tenant_uk)
```

## Implementation Status

### Phase 1: Core Infrastructure - COMPLETED
- [x] Create `Pwb::SeedPack` class with basic loading (`lib/pwb/seed_pack.rb`)
- [x] Create pack.yml schema and validation
- [x] Implement pack inheritance mechanism
- [x] Create base pack with shared data (`db/seeds/packs/base/`)
- [x] Add rake tasks for listing and previewing (`lib/tasks/seed_packs.rake`)

### Phase 2: First Pack (spain_luxury) - COMPLETED
- [x] Create spain_luxury pack structure
- [x] Add Spanish property data (7 properties: villas, penthouses, apartments, townhouse)
- [x] Add multi-language titles/descriptions (es, en, de)
- [x] Add agency and website configuration
- [x] Create field_keys.yml with property types, states, and features
- [x] Create home page content

### Phase 3: Property Generator - DEFERRED
- [ ] Implement PropertyGenerator for dynamic creation
- [ ] Add realistic data generation (addresses, prices)
- [ ] Support for property type distribution
- [ ] Feature/amenity assignment

### Phase 4: Additional Packs - FUTURE
- [ ] Create uk_residential pack
- [ ] Create usa_commercial pack
- [ ] Create france_vacation pack

### Phase 5: Integration - FUTURE
- [ ] Update e2e_seeds.rb to use packs
- [ ] Add pack selection to admin UI (optional)
- [ ] Migration guide for existing seeds

## Backwards Compatibility

The existing seeding system (`Pwb::Seeder`, `Pwb::SeedRunner`) will remain functional:

1. Existing `db/yml_seeds/` directory preserved
2. All existing rake tasks continue to work
3. Seed packs are an additional, optional feature
4. E2E seeds can gradually migrate to use packs

## Benefits

1. **Faster Demo Setup**: Spin up realistic tenants in seconds
2. **Consistent Test Data**: E2E tests use well-defined scenarios
3. **Easy Customization**: Fork a pack and modify for specific needs
4. **Locale Coverage**: Each pack includes all needed translations
5. **Visual Consistency**: Packs include matching images
6. **Documentation**: Pack configs serve as documentation

## Open Questions

1. Should packs be gems that can be shared across PWB installations?
2. How to handle pack versioning and updates?
3. Should there be a pack generator CLI?
4. Integration with theme selection?
