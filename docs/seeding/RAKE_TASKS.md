# Seed Rake Tasks Reference

## Overview

The seed system provides rake tasks for managing and applying seed packs. All seed pack tasks are under the `pwb:seed_packs` namespace.

Location: `lib/tasks/seed_packs.rake`

---

## Task: pwb:seed_packs:list

**Purpose**: List all available seed packs with metadata.

**Usage**:
```bash
rails pwb:seed_packs:list
```

**Output Example**:
```
Available Seed Packs:
==================================================

Base Pack (base)
  Foundation pack with common field keys, pages, and navigation structure
  Version: 1.0
  Inherits from: none
  Theme: default

Dutch Urban Real Estate (netherlands_urban)
  Popular estate agent specializing in city apartments and houses across the Netherlands
  Version: 1.0
  Inherits from: base
  Theme: bologna
  Locales: nl, en
  Currency: EUR

Spanish Luxury Real Estate (spain_luxury)
  Estate agent specializing in luxury properties on the Costa del Sol
  Version: 1.0
  Inherits from: base
  Theme: brisbane
  Locales: es, en, de
  Currency: EUR

==================================================
Use 'rails pwb:seed_packs:apply[pack_name]' to apply a pack
Use 'rails pwb:seed_packs:preview[pack_name]' to preview a pack
```

**Notes**:
- Shows all packs found in `db/seeds/packs/*/pack.yml`
- Lists pack metadata: name, display_name, description, version
- Shows inheritance chain
- Shows theme and supported locales
- Scans at runtime (no static list)

---

## Task: pwb:seed_packs:preview

**Purpose**: Preview what a seed pack will create WITHOUT making any changes (dry-run mode).

**Usage**:
```bash
rails pwb:seed_packs:preview[pack_name]
```

**Examples**:
```bash
rails pwb:seed_packs:preview[netherlands_urban]
rails pwb:seed_packs:preview[spain_luxury]
rails pwb:seed_packs:preview[base]
```

**Output Example**:
```
Previewing Seed Pack: Dutch Urban Real Estate
==================================================

Pack Name:
  netherlands_urban

Display Name:
  Dutch Urban Real Estate

Inherits From:
  base

Website:
  theme_name: bologna
  selected_palette: modern_slate
  default_client_locale: nl

Properties:
  8

Locales:
  nl
  en

Users:
  2

==================================================
This is a preview. Use 'rails pwb:seed_packs:apply[netherlands_urban]' to apply.
```

**What It Shows**:
- Pack name and metadata
- Inheritance chain
- Website configuration (theme, palette, locales)
- Number of properties
- Number of users
- Other configuration details

**Notes**:
- Non-destructive operation
- Useful for verifying pack contents before applying
- Shows preview of what would be created
- Helps prevent applying wrong pack to wrong website

**Error Handling**:
```bash
# If pack not found:
rails pwb:seed_packs:preview[nonexistent]
# Output: Error: Pack 'nonexistent' not found
# Run 'rails pwb:seed_packs:list' to see available packs
```

---

## Task: pwb:seed_packs:apply

**Purpose**: Apply a seed pack to a website, creating all configured data.

**Usage**:
```bash
# Apply to default (first) website
rails pwb:seed_packs:apply[pack_name]

# Apply to specific website by ID
rails pwb:seed_packs:apply[pack_name,website_id]
```

**Examples**:
```bash
# Apply netherlands_urban to default website
rails pwb:seed_packs:apply[netherlands_urban]

# Apply spain_luxury to website with ID 5
rails pwb:seed_packs:apply[spain_luxury,5]

# Apply base pack to website 3
rails pwb:seed_packs:apply[base,3]
```

**Output Example**:
```
Applying Seed Pack: Dutch Urban Real Estate
To Website: 1
==================================================
  Configuring website...
    Website configured: theme=bologna, palette=modern_slate, locale=nl
  Seeding agency...
    Agency: Van der Berg Makelaars
  Seeding field keys...
    Created 45 field keys
  Seeding navigation links...
    Created 8 links (0 skipped)
  Seeding pages...
    Created 8 pages (0 skipped)
  Seeding custom page parts from pack...
    Created 16 page parts
  Seeding properties...
    Created 8 properties
  Seeding content from pack...
    Created/updated 28 content items
  Seeding default page content translations...
    Default page content translations seeded
  Seeding users...
    Created 2 users
  Refreshing properties materialized view...
✅ Seed pack 'netherlands_urban' applied successfully!
```

**What It Does** (in order):
1. Validates pack exists
2. Checks seed image availability (if configured)
3. Applies parent pack first (if inherits_from specified)
4. Seeds website configuration (theme, locales, currency)
5. Seeds agency details
6. Seeds field keys (property types, states, features)
7. Seeds navigation links
8. Seeds pages
9. Seeds page parts (templates)
10. Seeds sample properties
11. Seeds page content
12. Seeds user accounts
13. Refreshes materialized views

**Error Handling**:
```bash
# Pack not found
rails pwb:seed_packs:apply[invalid_pack]
# Output: Error: Pack 'invalid_pack' not found

# Website not found
rails pwb:seed_packs:apply[netherlands_urban,999]
# Output: Error: Website not found

# Seed images unavailable (warning, continues)
# Output: ⚠️  Seed images not configured - properties will have no images
```

**Idempotency**:
- Safe to run multiple times
- Won't duplicate existing data (deduplicates by reference, slug, email)
- Updates existing records if they match uniqueness constraints

---

## Task: pwb:seed_packs:apply_with_options

**Purpose**: Apply a seed pack with fine-grained control over what gets seeded.

**Usage**:
```bash
rails pwb:seed_packs:apply_with_options[pack_name,'option1,option2']
```

**Available Options**:
- `skip_website` - Don't update website configuration
- `skip_agency` - Don't create/update agency
- `skip_field_keys` - Don't seed property field keys
- `skip_links` - Don't create navigation links
- `skip_pages` - Don't create pages
- `skip_page_parts` - Don't create page templates
- `skip_properties` - Don't seed sample properties
- `skip_content` - Don't seed page content
- `skip_users` - Don't create demo user accounts
- `skip_translations` - Don't seed i18n translations

**Examples**:
```bash
# Skip properties (useful for quick setup without sample data)
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_properties']

# Skip multiple options
rails pwb:seed_packs:apply_with_options[spain_luxury,'skip_properties,skip_users']

# Skip almost everything (just get configuration)
rails pwb:seed_packs:apply_with_options[base,'skip_properties,skip_content,skip_users']

# Skip website settings (keep existing theme/locales)
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_website']
```

**Output Example**:
```
Applying Seed Pack: Dutch Urban Real Estate
Options: skip_properties, skip_users
==================================================
  Configuring website...
    Website configured: theme=bologna, palette=modern_slate, locale=nl
  Seeding agency...
    Agency: Van der Berg Makelaars
  [... field keys, links, pages, page_parts ...]
  Seeding properties...
    No properties found
  Seeding content from pack...
    Created/updated 28 content items
  Seeding users...
    No users configured
✅ Seed pack 'netherlands_urban' applied successfully!
```

**Common Patterns**:

1. **Quick Setup** - Just configuration without data:
```bash
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_properties']
```

2. **Update Content Only**:
```bash
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_properties,skip_users,skip_field_keys']
```

3. **Testing** - Fast, minimal footprint:
```bash
rails pwb:seed_packs:apply_with_options[base,'skip_properties,skip_translations']
```

---

## Task: pwb:seed_packs:reset_and_apply

**Purpose**: Completely reset website data and apply a fresh seed pack (DESTRUCTIVE).

**Usage**:
```bash
rails pwb:seed_packs:reset_and_apply[pack_name]
```

**Examples**:
```bash
rails pwb:seed_packs:reset_and_apply[netherlands_urban]
rails pwb:seed_packs:reset_and_apply[spain_luxury]
```

**Warning**:
```
*** WARNING ***
This will delete all existing properties, users, and content!
Press Ctrl+C to cancel, or wait 5 seconds to continue...
```

**What It Does**:
1. Shows warning message
2. Waits 5 seconds (allows Ctrl+C cancellation)
3. Destroys all properties
4. Destroys all users (except admin@example.com)
5. Destroys all content
6. Destroys all links
7. Applies the seed pack fresh

**Output Example**:
```
*** WARNING ***
This will delete all existing properties, users, and content!
Press Ctrl+C to cancel, or wait 5 seconds to continue...

Resetting database...
Applying seed pack: Dutch Urban Real Estate
  Configuring website...
    Website configured: theme=bologna, palette=modern_slate, locale=nl
  [... seeding continues ...]
✅ Reset and apply completed successfully!
```

**DANGER WARNINGS**:
- Irreversible without backups
- Deletes user accounts (except admin@example.com)
- Deletes all sample data
- Deletes custom content
- Only use on development environments
- Test with preview or apply_with_options first

---

## Rake Task: pwb_update_seeds

**Purpose**: Legacy seeding with the old Seeder class.

**Location**: `lib/tasks/pwb_update_seeds.rake`

**Usage**:
```bash
rails pwb:seed
```

**Notes**:
- Uses legacy `Pwb::Seeder` class
- Mainly for backward compatibility
- Prefer seed_packs for new workflows
- Loads legacy YAML from `db/yml_seeds/`

---

## Environment-Based Seeding

### Development Environment

```bash
# Full setup with sample properties
rails pwb:seed_packs:apply[netherlands_urban]

# Quick setup without properties
rails pwb:seed_packs:apply_with_options[netherlands_urban,'skip_properties']
```

### Test Environment

```ruby
# In test setup
before(:all) do
  website = Pwb::Website.create!(subdomain: 'test')
  Pwb::SeedPack.find('base').apply!(
    website: website,
    options: { skip_properties: true, verbose: false }
  )
end
```

### Production Environment

```bash
# Dry run first
rails pwb:seed_packs:preview[spain_luxury]

# Apply carefully
rails pwb:seed_packs:apply[spain_luxury,production_website_id]
```

---

## Integration with Onboarding

The `pwb_seed_with_onboarding.rake` task integrates seeding with the website provisioning flow:

```bash
rails pwb:provision[pack_name,website_id]
```

This:
1. Creates website from pack configuration
2. Applies full seed pack
3. Sets up team members
4. Configures agency details

---

## Scripting with Rake

### Bash Script Example

```bash
#!/bin/bash
# setup_new_agency.sh

PACK_NAME=$1
WEBSITE_ID=$2

if [ -z "$PACK_NAME" ] || [ -z "$WEBSITE_ID" ]; then
  echo "Usage: $0 pack_name website_id"
  exit 1
fi

echo "Setting up $PACK_NAME for website $WEBSITE_ID..."
rails pwb:seed_packs:preview[$PACK_NAME]

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rails pwb:seed_packs:apply[$PACK_NAME,$WEBSITE_ID]
  echo "Done!"
else
  echo "Cancelled."
fi
```

### Ruby Script Example

```ruby
# scripts/setup_agency.rb
pack_name = ARGV[0]
website_id = ARGV[1]

raise "Usage: rails runner scripts/setup_agency.rb pack_name website_id" unless pack_name && website_id

pack = Pwb::SeedPack.find(pack_name)
website = Pwb::Website.find(website_id)

puts "Applying #{pack.display_name} to website #{website.subdomain}..."
pack.apply!(website: website)
puts "Done!"
```

Usage:
```bash
rails runner scripts/setup_agency.rb netherlands_urban 5
```

---

## Monitoring Seed Progress

### With Verbose Output
```bash
# Default is verbose
rails pwb:seed_packs:apply[netherlands_urban]
```

### Silent Mode (from console)
```ruby
Pwb::SeedPack.find('netherlands_urban').apply!(
  website: website,
  options: { verbose: false }
)
```

### Logging
Seeding output is logged to:
- Console (real-time)
- Rails log files (if running via rake)

Check logs:
```bash
tail -f log/development.log | grep -i seed
```

---

## Troubleshooting Rake Tasks

### Task Not Found
```bash
# Error: Don't know how to build task 'pwb:seed_packs:apply'
# Solution: Check task name, use rake -T to list
rake -T | grep seed
```

### Pack Not Found
```bash
rails pwb:seed_packs:apply[typo_pack_name]
# Error: Pack 'typo_pack_name' not found. Available packs: base, netherlands_urban, spain_luxury
# Solution: Check pack directory exists and has pack.yml
```

### Website Not Found
```bash
rails pwb:seed_packs:apply[netherlands_urban,999]
# Error: Website not found
# Solution: Verify website ID exists
rails dbconsole
# SELECT id, subdomain FROM pwb_websites;
```

### Seed Images Not Available
```bash
# Warning: Seed images not configured
# Solution: Set R2_SEED_IMAGES_BUCKET or SEED_IMAGES_BASE_URL
export SEED_IMAGES_BASE_URL=https://images.example.com
rails pwb:seed_packs:apply[netherlands_urban]
```

### Database Connection Error
```bash
# Could not find a valid db/config.yml file
# Solution: Ensure database is configured and migrations run
rails db:create
rails db:migrate
rails pwb:seed_packs:apply[netherlands_urban]
```

---

## Best Practices

1. **Always preview first**:
   ```bash
   rails pwb:seed_packs:preview[pack_name]
   ```

2. **Use dry-run in console**:
   ```ruby
   pack.apply!(website: website, options: { dry_run: true })
   ```

3. **Backup before reset**:
   ```bash
   rails db:dump
   rails pwb:seed_packs:reset_and_apply[pack_name]
   ```

4. **List available packs regularly**:
   ```bash
   rails pwb:seed_packs:list
   ```

5. **Use skip options for speed**:
   ```bash
   rails pwb:seed_packs:apply_with_options[pack,'skip_properties,skip_translations']
   ```

6. **Document custom packs**:
   Add README in pack directory explaining purpose and use case

7. **Test with console first**:
   ```ruby
   pack = Pwb::SeedPack.find('custom_pack')
   pack.preview
   ```

---

## Related Tasks

- `rails db:seed` - Load seeds.rb (doesn't use seed packs)
- `rails db:reset` - Drop, create, migrate, seed database
- `rails db:fixtures:load` - Load test fixtures
- `rails pwb:seed` - Legacy seeder (old Seeder class)
