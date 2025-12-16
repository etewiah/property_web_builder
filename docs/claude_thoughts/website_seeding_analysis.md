# Website Seeding Flow Analysis - PropertyWebBuilder

## Overview

PropertyWebBuilder has a sophisticated multi-step provisioning and seeding system for new websites. This document explains how websites are created, provisioned, and why navigation items and contents might be missing in certain scenarios.

## Architecture Summary

The seeding flow is orchestrated through **three main components**:

1. **ProvisioningService** (`app/services/pwb/provisioning_service.rb`) - Orchestrates the workflow
2. **SeedPack System** (`lib/pwb/seed_pack.rb`) - Reusable data bundles
3. **Legacy Seeders** (`lib/pwb/pages_seeder.rb`, `lib/pwb/contents_seeder.rb`) - Fallback seeders

---

## 1. Website Provisioning State Machine

The `Pwb::Website` model (lines 61-192) implements an AASM state machine with granular provisioning states:

### Provisioning State Flow:

```
pending 
  → owner_assigned      (Step 1: Owner user created)
  → agency_created      (Step 2: Agency information saved)
  → links_created       (Step 3: Navigation links seeded)
  → field_keys_created  (Step 4: Property field keys seeded)
  → properties_seeded   (Step 5: Sample properties added)
  → ready               (Step 6: All provisioning complete)
  → locked_pending_email_verification  (Step 7: Awaiting email verification)
  → locked_pending_registration         (Step 8: Email verified, awaiting Firebase)
  → live                (Step 9: Website publicly accessible)
```

### Guard Checks:

Before transitioning states, the system verifies prerequisites:

```ruby
has_owner?       # At least one owner membership exists
has_agency?      # Agency record exists
has_links?       # At least 3 links created
has_field_keys?  # At least 5 field keys created
```

**Location**: `Pwb::Website` lines 199-221

---

## 2. ProvisioningService Workflow

The `ProvisioningService` orchestrates the complete provisioning in `provision_website` method (lines 172-279).

### Step-by-Step Process:

#### **Step 1: Agency Creation** (lines 321-336)
```ruby
def create_agency_for_website(website)
  return if website.agency.present?
  
  # Try seed pack first
  if try_seed_pack_step(website, :agency)
    return
  end
  
  # Fallback: create minimal agency
  website.create_agency!(display_name: website.subdomain.titleize, ...)
end
```

#### **Step 2: Navigation Links Creation** (lines 339-362)
```ruby
def create_links_for_website(website)
  return if website.links.count >= 3  # Early return if already seeded
  
  # Try seed pack first
  if try_seed_pack_step(website, :links)
    return
  end
  
  # Fallback: create 4 default links
  default_links = [
    { slug: 'home', link_url: '/', visible: true },
    { slug: 'properties', link_url: '/search', visible: true },
    { slug: 'about', link_url: '/about', visible: true },
    { slug: 'contact', link_url: '/contact', visible: true }
  ]
  
  website.links.find_or_create_by!(slug: link_attrs[:slug])
end
```

#### **Step 3: Field Keys Creation** (lines 365-391)
Creates property types, states, and features (minimum 5 required).

#### **Step 4: Pages & Page Parts Creation** (lines 394-412)
- Tries to use seed pack pages
- Fallback: `PagesSeeder.seed_page_basics!` and `seed_page_parts!`

#### **Step 5: Properties Seeding** (lines 415-431)
Optional step. Can be skipped with `skip_properties: true`.

---

## 3. Seed Pack System

The `Pwb::SeedPack` class (`lib/pwb/seed_pack.rb`) provides reusable, scenario-based seed data.

### Pack Directory Structure:

```
db/seeds/packs/
├── base/
│   ├── pack.yml           # Pack metadata
│   ├── links.yml          # Navigation items
│   ├── field_keys.yml     # Property fields
│   ├── pages/             # Page definitions
│   ├── page_parts/        # Page part definitions
│   ├── content/           # Translatable content
│   └── properties/        # Sample properties
├── spain_luxury/
│   └── (inherits from base)
└── netherlands_urban/
    └── (inherits from base)
```

### Base Pack Contents:

**File**: `db/seeds/packs/base/pack.yml`

```yaml
name: base
display_name: "Base Pack"
website:
  theme_name: bristol
  supported_locales: [en]
  currency: EUR
```

**File**: `db/seeds/packs/base/links.yml` (9 links total)

The base pack defines:
- **Top Navigation** (5 links):
  - home → home page
  - buy → buy page
  - rent → rent page
  - about → about page
  - contact → contact page

- **Footer** (6 links):
  - footer_home, footer_buy, footer_rent, footer_contact
  - privacy, terms

**File**: `db/seeds/packs/base/field_keys.yml` (35+ field keys)

Organized by category:
- **Types**: villa, apartment, penthouse, townhouse, house, studio, duplex, bungalow, land, commercial
- **States**: new_build, excellent, good, needs_renovation, under_construction
- **Features**: pool variants, views, garden, terrace, jacuzzi, sauna
- **Amenities**: HVAC, security, automation, elevator, storage

### SeedPack Application Method:

```ruby
def apply!(website:, options: {})
  # Apply parent pack if configured
  apply_parent_pack! if config[:inherits_from]
  
  # Seed in order
  seed_website
  seed_agency
  seed_field_keys
  seed_links          # <-- Where navigation items come from
  seed_pages
  seed_page_parts
  seed_properties
  seed_content        # <-- Where contents come from
  seed_users
  seed_translations
end
```

**Location**: `lib/pwb/seed_pack.rb` lines 59-94

---

## 4. How Navigation Links Are Created

### Path A: Via SeedPack (lines 344-362)

When a website is provisioned with a seed pack:

1. `try_seed_pack_step(website, :links)` is called
2. Looks for `links.yml` in the pack directory
3. Parses YAML and creates `Pwb::Link` records with:
   - `slug`: Unique identifier (e.g., 'home', 'about')
   - `link_title`: Display text (translatable via Mobility)
   - `placement`: 'top_nav' or 'footer'
   - `sort_order`: Display order
   - `visible`: Boolean flag
   - `page_slug`: Reference to associated page (optional)
   - `website_id`: Multi-tenancy scoping

**SeedPack code** (`lib/pwb/seed_pack.rb` lines 344-362):
```ruby
def seed_links
  links_file = @path.join('links.yml')
  return unless links_file.exist?
  
  links = YAML.safe_load(File.read(links_file), symbolize_names: true) || []
  count = 0
  
  links.each do |link_data|
    existing = @website.links.find_by(slug: link_data[:slug])
    unless existing
      @website.links.create!(link_data)
      count += 1
    end
  end
end
```

### Path B: Fallback Links (lines 350-361)

If seed pack is unavailable or has no `links.yml`:

```ruby
# Fallback: create minimal links
default_links = [
  { slug: 'home', link_url: '/', visible: true },
  { slug: 'properties', link_url: '/search', visible: true },
  { slug: 'about', link_url: '/about', visible: true },
  { slug: 'contact', link_url: '/contact', visible: true }
]

default_links.each_with_index do |link_attrs, index|
  website.links.find_or_create_by!(slug: link_attrs[:slug]) do |link|
    link.assign_attributes(link_attrs.merge(sort_order: index + 1))
  end
end
```

**Important**: The fallback links only set:
- `slug`
- `link_url`
- `visible`
- `sort_order`

They **do NOT set**:
- `link_title` (translatable field)
- `placement` (top_nav vs footer)
- `page_slug` (association to pages)

---

## 5. How Contents Are Seeded

### Path A: Via SeedPack (lines 499-521)

SeedPack looks for a `content/` directory with YAML files:

```ruby
def seed_content
  content_dir = @path.join('content')
  return unless content_dir.exist?
  
  count = 0
  Dir.glob(content_dir.join('*.yml')).each do |content_file|
    content_data = YAML.safe_load(File.read(content_file), symbolize_names: true)
    
    content_data.each do |key, translations|
      content = @website.contents.find_or_initialize_by(key: key.to_s)
      translations.each do |locale, value|
        content.send("raw_#{locale}=", value) if content.respond_to?("raw_#{locale}=")
      end
      content.save!
    end
  end
end
```

**Content Model** (`app/models/pwb/content.rb`):
- Uses Mobility for multi-language support
- Translates `:raw` field
- Has `website_id` for multi-tenancy
- Example: `Content.find_by(key: 'logo', website_id: website.id)`

### Path B: Legacy Seeding (via PagesSeeder/ContentsSeeder)

If no seed pack content:
- Uses `Pwb::ContentsSeeder.seed_page_content_translations!(website: website)`
- Looks in `db/yml_seeds/content_translations/{locale}.yml`
- Creates content entries from page_part definitions

---

## 6. Why Navigation Items and Contents Might Be Missing

### Common Scenarios:

#### **Scenario 1: Seed Pack Not Found**

**Symptom**: No links created; only fallback 4 basic links appear

**Root Cause**:
- Website created with `seed_pack_name: 'nonexistent'`
- `Pwb::SeedPack.find(name)` raises `PackNotFoundError`
- Service catches error and uses hardcoded fallback links

**Where this happens**:
```ruby
def try_seed_pack_step(website, step)
  pack_name = website.seed_pack_name || 'base'
  
  begin
    seed_pack = Pwb::SeedPack.find(pack_name)
    # ... use seed pack ...
  rescue Pwb::SeedPack::PackNotFoundError
    # Pack doesn't exist, use fallback
  rescue StandardError => e
    Rails.logger.warn("[Provisioning] SeedPack step '#{step}' failed: #{e.message}")
  end
  
  false  # <-- Returns false, triggering fallback
end
```

**Location**: `app/services/pwb/provisioning_service.rb` lines 435-470

#### **Scenario 2: No links.yml in Pack**

**Symptom**: Fallback links used even though pack exists

**Root Cause**:
```ruby
def seed_links
  links_file = @path.join('links.yml')
  return unless links_file.exist?  # <-- Returns early if file doesn't exist
  # ...
end
```

**Location**: `lib/pwb/seed_pack.rb` lines 344-347

#### **Scenario 3: Fallback Links Incomplete**

**Symptom**: Links appear but without titles, placement, or proper page association

**Root Cause**: The fallback code only sets minimal attributes:
```ruby
{ slug: 'home', link_url: '/', visible: true }
```

Missing:
- `link_title` → Links will display as blank or slug name
- `placement` → Defaults to `top_nav: 0`, won't appear in footer
- `page_slug` → Not associated with pages

#### **Scenario 4: Early Return on Multiple Calls**

**Symptom**: Provisioning service called twice; second time nothing happens

**Root Cause**:
```ruby
def create_links_for_website(website)
  return if website.links.count >= 3  # <-- Early return!
  
  # Seeding code never runs if 3+ links exist
end
```

**Location**: `app/services/pwb/provisioning_service.rb` line 340

This is intentional for idempotency but prevents re-seeding if links are incomplete.

#### **Scenario 5: No Content Seeding in Provisioning**

**Symptom**: Websites have pages and links but no content text

**Root Cause**:
- The provisioning service does NOT call content seeding
- Content seeding requires calling separate steps or using seed pack manually
- Default seed pack (base) has NO `content/` directory

**Missing workflow**:
```ruby
# NOT called during provision_website
Pwb::SeedPack.find('base').seed_content  # This would need to be called

# NOT called during provisioning
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

---

## 7. Multi-Tenancy Impact on Seeding

### Key Scoping:

The seeding system properly scopes resources:

1. **Links**: `website.links.create!(link_data)` ✅
   - Foreign key: `website_id` added in migration 20251121190959

2. **Contents**: `@website.contents.find_or_initialize_by(key: key.to_s)` ✅
   - Foreign key: `website_id`

3. **Field Keys**: `Pwb::FieldKey.create!(fk.merge(pwb_website_id: @website.id))` ✅
   - Foreign key: `pwb_website_id`

4. **Pages**: `@website.pages.create!(page_data)` ✅
   - Foreign key: `website_id`

### Potential Issue:

Old code might not include `website_id` when creating records:

```ruby
# ❌ BAD - Creates link not scoped to website
Pwb::Link.create!(slug: 'home')

# ✅ GOOD - Scoped to website
website.links.create!(slug: 'home')
```

---

## 8. Available Seed Packs

Currently configured (3 packs):

1. **base** (`db/seeds/packs/base/`)
   - 11 navigation links (5 top nav + 6 footer)
   - 35+ field keys
   - No pages directory
   - No content directory
   - No properties directory

2. **spain_luxury** (`db/seeds/packs/spain_luxury/`)
   - Inherits from base
   - 7 sample properties
   - Content files for home, about-us, contact-us, sell

3. **netherlands_urban** (`db/seeds/packs/netherlands_urban/`)
   - Inherits from base
   - Content files for pages
   - Various property examples

---

## 9. Default Seed Pack Selection

**File**: `app/services/pwb/provisioning_service.rb` lines 307-314

```ruby
def seed_pack_for_site_type(site_type)
  case site_type
  when 'residential' then 'base'
  when 'commercial' then 'base'
  when 'vacation_rental' then 'base'
  else 'base'
  end
end
```

All site types currently use the 'base' pack.

---

## 10. Debugging Seeding Issues

### Check what's being seeded:

```ruby
# Console commands
website = Pwb::Website.find_by(subdomain: 'mysite')

# Verify seed pack
pack = Pwb::SeedPack.find('base')
pack.preview  # => Lists what pack would create

# Check what's missing
website.provisioning_missing_items
# => ["links (have 4, need 3)", "field_keys (have 0, need 5)", ...]

# Check state
website.provisioning_state   # => 'links_created'
website.provisioning_checklist
# => {:owner=>{:complete=>true, ...}, :links=>{:complete=>true, :count=>9, ...}}
```

### Manually seed missing resources:

```ruby
# Reseed links
pack = Pwb::SeedPack.find('base')
pack.seed_links!(website: website)

# Reseed content
pack.seed_content!(website: website)

# Reseed page parts with content
Pwb::PagesSeeder.seed_page_parts!(website: website)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

---

## 11. Flow Diagram

```
User Signs Up
    ↓
[ProvisioningService.start_signup]
    ├─ Create user (lead state)
    └─ Reserve subdomain (10 min TTL)

User Configures Site
    ↓
[ProvisioningService.configure_site]
    ├─ Create website (pending state)
    ├─ Set subdomain, site_type
    ├─ Select seed_pack_name ('base')
    ├─ Allocate subdomain
    └─ Create owner membership → website: owner_assigned

User Provisions Website
    ↓
[ProvisioningService.provision_website]
    ├─ [1] Create Agency
    │   ├─ Try SeedPack.seed_agency!
    │   └─ Fallback: Create minimal agency → website: agency_created
    ├─ [2] Create Links
    │   ├─ Try SeedPack.seed_links!
    │   │   └─ Load links.yml → Create Link records with website_id
    │   └─ Fallback: 4 basic links → website: links_created
    ├─ [3] Create Field Keys
    │   ├─ Try SeedPack.seed_field_keys!
    │   └─ Fallback: 7 default field keys → website: field_keys_created
    ├─ [4] Create Pages & Page Parts
    │   ├─ Try SeedPack.seed_pages! & seed_page_parts!
    │   └─ Fallback: PagesSeeder → website: pages_created
    ├─ [5] Seed Properties (optional)
    │   ├─ Try SeedPack.seed_properties!
    │   └─ Fallback: Basic seeder → website: properties_seeded
    ├─ [6] Final Checks
    │   └─ Verify all requirements met → website: ready
    ├─ [7] Enter Locked State
    │   ├─ Generate email verification token
    │   └─ Send verification email → website: locked_pending_email_verification
    └─ SUCCESS

User Verifies Email
    ↓
website: locked_pending_registration

User Creates Firebase Account
    ↓
website: live
```

---

## 12. Summary: Why Content/Navigation Might Be Missing

| Issue | Cause | Fix |
|-------|-------|-----|
| **No navigation links** | Seed pack not found | Use 'base' pack or create custom pack |
| **Links without titles** | Fallback links used instead of pack | Add `link_title` to fallback or use pack |
| **Links not in footer** | `placement` field not set | Explicitly set `placement: 'footer'` in seed pack |
| **No content/text** | Content seeding not called during provisioning | Call `SeedPack.seed_content!` or `ContentsSeeder` manually |
| **Incomplete pages** | No page parts created | Call `PagesSeeder.seed_page_parts!` |
| **Pages without content** | Content translations not seeded | Call `ContentsSeeder.seed_page_content_translations!` |

---

## References

- **Website Model**: `/app/models/pwb/website.rb` (855 lines, AASM state machine)
- **ProvisioningService**: `/app/services/pwb/provisioning_service.rb` (525 lines)
- **SeedPack**: `/lib/pwb/seed_pack.rb` (790 lines)
- **PagesSeeder**: `/lib/pwb/pages_seeder.rb` (114 lines)
- **ContentsSeeder**: `/lib/pwb/contents_seeder.rb` (98 lines)
- **Migrations**: 
  - `20251121190959_add_website_id_to_tables.rb` (multi-tenancy)
  - `20251209122349_add_provisioning_state_to_websites.rb` (state machine)
- **Tests**: `/spec/services/pwb/provisioning_seeding_spec.rb` (297 lines)

