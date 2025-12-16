# Code Locations - Website Seeding System

Quick reference for finding key code related to website seeding.

## Core Seeding System

### ProvisioningService (Main Orchestrator)
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/provisioning_service.rb`

| Method | Lines | Purpose |
|--------|-------|---------|
| `start_signup` | 21-82 | Create lead user + reserve subdomain |
| `configure_site` | 100-167 | Create website + owner + set seed pack |
| `provision_website` | 172-279 | **Main: Run all 7 provisioning steps** |
| `create_agency_for_website` | 321-336 | Create agency record (Step 1) |
| `create_links_for_website` | 339-362 | **Create navigation links (Step 2)** ← KEY |
| `create_field_keys_for_website` | 365-391 | Create property field keys (Step 3) |
| `create_pages_for_website` | 394-412 | Create pages + page parts (Step 4) |
| `seed_properties_for_website` | 415-431 | Seed sample properties (Step 5) |
| `try_seed_pack_step` | 435-470 | Attempt seed pack seeding with fallback |
| `send_verification_email` | 485-493 | Send email verification token |

**Key Lines**:
- Line 340: **EARLY RETURN CHECK** - `return if website.links.count >= 3` (Prevents re-seeding!)
- Line 346: Try seed pack for links
- Line 350-361: Fallback link creation

### SeedPack (Reusable Data Bundles)
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seed_pack.rb`

| Method | Lines | Purpose |
|--------|-------|---------|
| `initialize` | 39-44 | Load pack from directory |
| `apply!` | 59-94 | **Full apply: seed everything in order** |
| `seed_agency` | 260-290 | Seed agency data |
| `seed_links` | 344-362 | **Load and create navigation links** ← KEY |
| `seed_field_keys` | 292-342 | Load and create field keys |
| `seed_pages` | 364-383 | Load and create pages |
| `seed_page_parts` | 385-469 | Load and create page parts |
| `seed_content` | 499-521 | **Load and create content items** ← KEY |
| `seed_properties` | 482-497 | Load and create properties |
| `seed_users` | 523-562 | Create users and memberships |
| `seed_translations` | 564-591 | Seed translations |

**Key Details**:
- Line 350: Loads `links.yml` from pack directory
- Line 500: Looks for `content/` directory
- Line 506: Loads `.yml` files from content directory
- Entire `seed_content` is NOT called during provisioning!

### Website Model (State Machine)
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb`

| Feature | Lines | Purpose |
|---------|-------|---------|
| **AASM State Machine** | 61-192 | Define provisioning states and transitions |
| States definition | 62-74 | All 14 states (pending, owner_assigned, etc.) |
| Events definition | 76-192 | State transition events (assign_owner, etc.) |
| **Guard Methods** | 199-221 | Check prerequisites for transitions |
| `has_owner?` | 199-201 | Owner membership exists? |
| `has_agency?` | 204-206 | Agency record exists? |
| `has_links?` | 209-211 | At least 3 links exist? |
| `has_field_keys?` | 214-216 | At least 5 field keys exist? |
| `provisioning_complete?` | 219-221 | All requirements met? |
| **Status Methods** | 333-354 | Check provisioning status |
| `provisioning_checklist` | 333-342 | Return detailed status of all requirements |
| `provisioning_missing_items` | 345-354 | List what's missing for completion |
| `provisioning_status_message` | 303-320 | Human-readable status text |

**Key Lines**:
- Line 62-74: All 15 provisioning states
- Line 209-211: Guard that requires at least 3 links

---

## Navigation Links System

### Link Model
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/link.rb`

| Feature | Lines | Purpose |
|---------|-------|---------|
| Model definition | 1-53 | Complete Link model |
| `belongs_to :website` | 15 | Association to website (scoping) |
| `translates :link_title` | 18 | Mobility translations for display text |
| `enum :placement` | 22 | top_nav (0) or footer (1) |
| Scopes | 24-29 | Various ordering scopes |

**Key Attributes**:
- `slug` - Unique identifier (e.g., 'home')
- `link_title` - Display text (translatable)
- `placement` - enum: top_nav=0, footer=1
- `visible` - Boolean show/hide flag
- `page_slug` - Associated page
- `website_id` - Multi-tenancy scoping
- `sort_order` - Display order

### Base Seed Pack Links
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/base/links.yml`

**Contents** (11 links total):
```yaml
# Top Navigation (5)
- slug: home
- slug: buy
- slug: rent
- slug: about
- slug: contact

# Footer (6)
- slug: footer_home
- slug: footer_buy
- slug: footer_rent
- slug: footer_contact
- slug: privacy
- slug: terms
```

---

## Content System

### Content Model
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/content.rb`

| Feature | Lines | Purpose |
|---------|-------|---------|
| Model definition | 1-93 | Complete Content model |
| `belongs_to :website` | 17 | Association to website (scoping) |
| `translates :raw` | 24 | Mobility translations for content |

**Key Attributes**:
- `key` - Content identifier (e.g., 'logo', 'footer_text')
- `raw` - Content text (translatable via Mobility)
- `website_id` - Multi-tenancy scoping

### ContentsSeeder (Legacy)
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/contents_seeder.rb`

| Method | Lines | Purpose |
|--------|-------|---------|
| `seed_page_content_translations!` | 25-38 | Load content from global seed files |
| `seed_content_for_locale` | 52-75 | Process content for one language |

**Key Details**:
- Loads from: `db/yml_seeds/content_translations/{locale}.yml` (Global, not per-pack)
- NOT called during provisioning
- Legacy system for backwards compatibility

---

## Seed Packs

### Base Pack (Default)
**Directory**: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/base/`

| File | Purpose |
|------|---------|
| `pack.yml` | Pack metadata + website config |
| `links.yml` | 11 navigation items |
| `field_keys.yml` | 35+ property field keys |
| (no content/) | **NO CONTENT - must be added** |
| (no pages/) | No custom pages |
| (no properties/) | No sample properties |

### Spain Luxury Pack
**Directory**: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/spain_luxury/`

Inherits from base + adds:
- `content/` - Content for home, about-us, contact-us, sell
- `properties/` - 7 sample Spanish luxury properties
- Support for: en, es, de, fr

### Netherlands Urban Pack  
**Directory**: `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/netherlands_urban/`

Inherits from base + adds:
- `content/` - Content for pages
- Support for: en, nl, de

---

## Legacy Seeders (Fallbacks)

### PagesSeeder
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/pages_seeder.rb`

| Method | Lines | Purpose |
|--------|-------|---------|
| `seed_page_basics!` | 43-55 | Create 9 default pages (home, about, contact, etc.) |
| `seed_page_parts!` | 25-36 | Create page parts for pages |

**Key Details**:
- Used as fallback in `create_pages_for_website` when no seed pack pages
- Loads from: `db/yml_seeds/pages/*.yml`

### Seeder
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seeder.rb`

General-purpose legacy seeder, used for:
- Property seeding fallback
- Global database seeding

---

## Migrations (Multi-Tenancy)

### Add website_id to tables
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251121190959_add_website_id_to_tables.rb`

**Changes**:
- Adds `website_id` column to: pwb_contents, pwb_links, pwb_agencies
- Adds indexes for website_id

### Provisioning State Machine
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251209122349_add_provisioning_state_to_websites.rb`

**Changes**:
- Adds `provisioning_state` column with 15 possible states
- Adds provisioning tracking columns

---

## Tests

### Provisioning Service Tests
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/services/pwb/provisioning_seeding_spec.rb` (297 lines)

| Test Suite | Purpose |
|------------|---------|
| Full provisioning workflow | Test complete signup + provisioning |
| Individual provisioning steps | Test each step separately |
| SeedPack integration | Test seed pack loading |
| Progress reporting | Test progress callbacks |
| Error handling | Test error cases |
| Idempotency | Verify re-running doesn't duplicate |

### Website Model Tests
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/models/pwb/website_provisioning_spec.rb`

Tests for state machine and guard checks.

### SeedPack Tests
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/lib/pwb/seed_pack_spec.rb`

Tests for seed pack functionality.

---

## Database Schema

### Links Table
```
pwb_links:
  id (PK)
  slug (unique within website)
  link_title (translatable via Mobility)
  placement (enum: 0=top_nav, 1=footer, 2=social, 3=admin)
  page_slug (FK to pages.slug)
  link_url (for external links)
  visible (boolean)
  sort_order (for ordering)
  website_id (FK to websites, scoping)
  created_at, updated_at
```

### Contents Table
```
pwb_contents:
  id (PK)
  key (unique within website)
  raw (translatable via Mobility JSONB)
  website_id (FK to websites, scoping)
  created_at, updated_at
```

### Websites Table (Provisioning Fields)
```
pwb_websites:
  ...existing fields...
  provisioning_state (string)
  seed_pack_name (string)
  provisioning_started_at (timestamp)
  provisioning_completed_at (timestamp)
  provisioning_failed_at (timestamp)
  provisioning_error (text)
  email_verification_token (string)
  email_verification_token_expires_at (timestamp)
  email_verified_at (timestamp)
```

---

## How Navigation Links Are Created

### Complete Flow:

```
ProvisioningService.provision_website(website)
  ↓
[Step 2] create_links_for_website(website)
  ├─ Check: IF website.links.count >= 3 THEN return (line 340)
  │
  ├─ Try: try_seed_pack_step(website, :links)
  │  ├─ Load pack: Pwb::SeedPack.find('base')
  │  │
  │  ├─ Call: SeedPack.seed_links! (line 346)
  │  │  ├─ Load: db/seeds/packs/base/links.yml
  │  │  ├─ Parse YAML
  │  │  └─ For each link_data:
  │  │     └─ website.links.create!(link_data)
  │  │        └─ Creates 11 full-featured links
  │  │
  │  └─ Return: true (success)
  │
  └─ Fallback (if pack failed):
     └─ Create 4 basic links (minimal attributes)
```

---

## Summary by Topic

### "I want to find code that..."

**...creates navigation links**
- → `app/services/pwb/provisioning_service.rb` line 339-362
- → `lib/pwb/seed_pack.rb` line 344-362

**...defines the Link model**
- → `app/models/pwb/link.rb`

**...has the base navigation items**
- → `db/seeds/packs/base/links.yml`

**...creates content**
- → `lib/pwb/seed_pack.rb` line 499-521 (SeedPack)
- → `lib/pwb/contents_seeder.rb` (Legacy)

**...defines the provisioning state machine**
- → `app/models/pwb/website.rb` line 61-192 (AASM)
- → `app/models/pwb/website.rb` line 199-221 (Guards)

**...orchestrates provisioning**
- → `app/services/pwb/provisioning_service.rb` line 172-279

**...tests seeding**
- → `spec/services/pwb/provisioning_seeding_spec.rb`

**...defines Content model**
- → `app/models/pwb/content.rb`

