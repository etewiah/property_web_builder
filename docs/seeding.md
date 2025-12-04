# Database Seeding Guide

This guide provides comprehensive information about PropertyWebBuilder's database seeding system, including the enhanced seeding features, multi-tenancy support, and safety mechanisms.

## Overview

PropertyWebBuilder uses a sophisticated seeding system designed for multi-tenant environments. The system provides both basic seeding for development and enhanced seeding with safety features for production environments.

## Architecture

### Core Components

- **`Pwb::Seeder`** - Original seeding logic for basic data
- **`Pwb::SeedRunner`** - Enhanced seeding orchestrator with safety features
- **`Pwb::PagesSeeder`** - Handles page and page part seeding
- **`Pwb::ContentsSeeder`** - Handles content translation seeding

### Seed Data Structure

Seed files are stored in YAML format under `db/yml_seeds/`:

```
db/yml_seeds/
├── agency.yml           # Agency information
├── agency_address.yml   # Agency address
├── contacts.yml         # Sample contacts
├── field_keys.yml       # Property field definitions
├── links.yml            # Navigation links
├── users.yml            # Sample users
├── website.yml          # Website settings
└── prop/                # Sample properties
    ├── villa_for_sale.yml
    ├── villa_for_rent.yml
    └── ...
```

## Basic Seeding

### Standard Rake Tasks

```bash
# Seed the default website
rake pwb:db:seed

# Seed a specific tenant
rake pwb:db:seed_tenant[my-subdomain]

# Seed all tenants
rake pwb:db:seed_all_tenants

# Seed only pages and content
rake pwb:db:seed_pages
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SKIP_PROPERTIES` | Skip seeding sample properties | `false` |

## Enhanced Seeding (SeedRunner)

The `Pwb::SeedRunner` provides advanced seeding capabilities with safety features.

### Basic Usage

```bash
# Enhanced seeding with interactive mode
rake pwb:db:seed_enhanced

# Enhanced seeding for specific tenant
rake pwb:db:seed_tenant_enhanced[my-subdomain]

# Dry-run (preview changes)
rake pwb:db:seed_dry_run

# Validate seed files
rake pwb:db:validate_seeds
```

### Seed Modes

Control how existing records are handled:

| Mode | Description | Use Case |
|------|-------------|----------|
| `interactive` | Prompts before updating existing records | Development, safe updates |
| `create_only` | Only creates new records, skips existing | Production, safe seeding |
| `force_update` | Updates existing records without prompting | Development, data refresh |
| `upsert` | Creates or updates all records | Development, full refresh |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SEED_MODE` | How to handle existing records | `interactive` |
| `DRY_RUN` | Preview changes without applying | `false` |
| `SKIP_PROPERTIES` | Skip sample properties | `false` |
| `VERBOSE` | Show detailed output | `true` |

### Examples

```bash
# Production-safe seeding (create-only, no properties)
SEED_MODE=create_only SKIP_PROPERTIES=true rake pwb:db:seed_enhanced

# Preview what would change for a tenant
DRY_RUN=true rake pwb:db:seed_tenant_enhanced[my-tenant]

# Force update all data (development)
SEED_MODE=force_update rake pwb:db:seed_enhanced

# Minimal output
VERBOSE=false rake pwb:db:seed_enhanced
```

### Interactive Mode

When using `interactive` mode with existing data, you'll see:

```
⚠️  WARNING: EXISTING DATA DETECTED

The following existing data was found for this website:
   • Contacts: 5
   • Field Keys: 71
   • Links: 28
   • Properties: 6

What would you like to do?

   [C] Create only - Skip existing records, only create new ones
   [U] Update all  - Update existing records with seed data
   [Q] Quit        - Cancel seeding and exit

Your choice [C/U/Q]:
```

## Multi-Tenancy Support

### Website Scoping

All seeded data is properly scoped to websites:

- **Contacts** - Associated via `website_id`
- **Links** - Associated via `website_id`
- **Properties** - Associated via `website_id`
- **Field Keys** - Associated via `pwb_website_id`
- **Users** - Associated via `website_id`

### Global vs. Website-Specific Data

- **Global Data**: Translations, users (with website association)
- **Website Data**: Properties, links, contacts, field keys

### Tenant-Specific Seeding

```ruby
# Seed a specific website
website = Pwb::Website.find_by(subdomain: 'my-tenant')
Pwb::SeedRunner.run(website: website, mode: :create_only)

# Seed all websites
Pwb::Website.all.each do |website|
  Pwb::SeedRunner.run(website: website, mode: :create_only)
end
```

## Programmatic Usage

### Using SeedRunner Directly

```ruby
require 'pwb/seed_runner'

# Basic usage
Pwb::SeedRunner.run(
  website: Pwb::Website.first,
  mode: :create_only,
  dry_run: false,
  skip_properties: true,
  verbose: true
)

# Advanced configuration
Pwb::SeedRunner.run(
  website: website,
  mode: :upsert,
  dry_run: true,
  skip_properties: false,
  skip_translations: false,
  verbose: false
)
```

### Using Individual Seeders

```ruby
# Seed only pages for a website
Pwb::PagesSeeder.seed_page_basics!(website: website)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)

# Seed only properties
Pwb::Seeder.seed!(website: website, skip_properties: false)
```

## E2E Testing Seeding

For end-to-end testing, use the specialized E2E seeder:

```ruby
# In db/seeds/e2e_seeds.rb
seed_for_website(tenant_a)
seed_for_website(tenant_b)
```

This creates test tenants with full data sets for Playwright tests.

## Seed File Format

### YAML Structure

All seed files use YAML format with consistent structure:

```yaml
# Single record
field_name: value
another_field: value

# Multiple records (for properties)
- field_name: value1
  another_field: value1
- field_name: value2
  another_field: value2
```

### Required Fields

Each model has specific required fields. For example:

```yaml
# agency.yml
display_name: "My Real Estate Agency"
email_primary: "info@agency.com"

# links.yml
slug: "home"
page_slug: "home"
link_title: "Home"
```

## Troubleshooting

### Common Issues

#### "website_id column does not exist"

**Problem**: Some migrations may not be run, causing missing columns.

**Solution**: Run pending migrations:
```bash
rails db:migrate
```

#### "Unique constraint violation"

**Problem**: Field keys have global uniqueness constraints.

**Solution**: Use `create_only` mode to skip existing records:
```bash
SEED_MODE=create_only rake pwb:db:seed_enhanced
```

#### "Seed file not found"

**Problem**: Missing or renamed seed files.

**Solution**: Check file exists in `db/yml_seeds/`:
```bash
rake pwb:db:validate_seeds
```

### Validation

Validate seed files before running:

```bash
rake pwb:db:validate_seeds
```

This checks:
- All required files exist
- YAML syntax is valid
- Basic structure validation

### Dry-Run Mode

Always test changes with dry-run first:

```bash
DRY_RUN=true rake pwb:db:seed_enhanced
```

This shows exactly what would be created, updated, or skipped.

## Performance Considerations

### Large Datasets

For large seed datasets:

1. Use `create_only` mode to avoid expensive updates
2. Skip properties in production: `SKIP_PROPERTIES=true`
3. Use minimal verbosity: `VERBOSE=false`
4. Consider batch processing for very large datasets

### Memory Usage

The seeder loads all YAML files into memory. For very large seed files:

1. Split large files into smaller chunks
2. Use streaming for extremely large datasets
3. Monitor memory usage in production environments

## Best Practices

### Development

- Use `interactive` mode for safety
- Regularly run `dry_run` to preview changes
- Keep seed data minimal and focused

### Production

- Always use `create_only` mode
- Set `SKIP_PROPERTIES=true`
- Validate seed files before deployment
- Use dry-run in staging environments

### Multi-Tenant Deployments

- Seed each tenant independently
- Use website-specific data validation
- Monitor for cross-tenant data leakage
- Test seeding in staging with production-like data

## Extending the Seeder

### Adding New Seed Data

1. Create YAML file in `db/yml_seeds/`
2. Add seeding logic to `Pwb::SeedRunner`
3. Update validation in `validate_seed_files`
4. Add specs for new functionality

### Custom Seed Logic

```ruby
class Pwb::SeedRunner
  def seed_custom_data
    log "🌟 Seeding custom data...", :info
    
    custom_yml = load_seed_yml("custom.yml")
    custom_yml.each do |data|
      # Custom seeding logic
      website.custom_records.create!(data)
    end
  end
end
```

## API Reference

### Pwb::SeedRunner.run

```ruby
Pwb::SeedRunner.run(
  website: Pwb::Website,           # Target website (optional)
  mode: Symbol,                    # :interactive, :create_only, :force_update, :upsert
  dry_run: Boolean,                # Preview mode
  skip_properties: Boolean,        # Skip sample properties
  skip_translations: Boolean,      # Skip translation seeding
  verbose: Boolean                 # Detailed output
) -> Boolean                       # Success status
```

### Pwb::Seeder.seed!

```ruby
Pwb::Seeder.seed!(
  website: Pwb::Website,           # Target website (optional)
  skip_properties: Boolean         # Skip sample properties
)
```

## Migration Notes

### From Basic to Enhanced Seeding

When upgrading from basic seeding:

1. Test enhanced seeding in development first
2. Use `dry_run` mode to preview changes
3. Gradually adopt enhanced features
4. Update deployment scripts to use new rake tasks

### Backwards Compatibility

The original `Pwb::Seeder` remains available for backwards compatibility. All existing rake tasks continue to work unchanged.