# Website Seeding Issues - Quick Reference

## Problem Summary

When new websites are provisioned in PropertyWebBuilder, navigation items and content may be incomplete or missing. This document provides quick answers to common questions.

---

## Q1: Where are navigation links created?

### Answer:
Navigation links are created in **`ProvisioningService.create_links_for_website`** (lines 339-362)

**Two paths**:

#### Path A: Via Seed Pack (Preferred)
```ruby
# Tries to load links.yml from the seed pack
if try_seed_pack_step(website, :links)
  return  # Done - uses pack links
end
```

**Seed pack location**: `db/seeds/packs/base/links.yml`

**What gets created** (11 links):
- **Top Navigation**: home, buy, rent, about, contact (5)
- **Footer**: footer_home, footer_buy, footer_rent, footer_contact, privacy, terms (6)

#### Path B: Fallback (Used if pack fails)
```ruby
# Only creates 4 basic links if seed pack unavailable
default_links = [
  { slug: 'home', link_url: '/', visible: true },
  { slug: 'properties', link_url: '/search', visible: true },
  { slug: 'about', link_url: '/about', visible: true },
  { slug: 'contact', link_url: '/contact', visible: true }
]
```

**Problem with fallback**:
- No `link_title` (appears blank)
- No `placement` field (won't appear in footer)
- No `page_slug` association
- Only 4 links instead of 11

---

## Q2: Why would navigation links be missing after provisioning?

### Possible Causes:

#### 1. **Seed Pack Not Found**
- **Symptom**: Only 4 fallback links appear
- **Root cause**: `website.seed_pack_name` is 'nonexistent' or blank
- **Fix**: Set `seed_pack_name: 'base'` in `configure_site` step
- **Code location**: `ProvisioningService.seed_pack_for_site_type` (line 307)

#### 2. **Early Return Check**
- **Symptom**: Provisioning called twice, second time no links added
- **Root cause**: 
  ```ruby
  def create_links_for_website(website)
    return if website.links.count >= 3  # Line 340 - early exit!
  end
  ```
- **Problem**: If only 4 fallback links exist (count >= 3), seeding never runs
- **Impact**: Once fallback links created, can never reseed from pack

#### 3. **Missing links.yml in Pack**
- **Symptom**: Pack directory exists but no links created
- **Root cause**: Pack doesn't have `links.yml` file
- **Fix**: Add `db/seeds/packs/{pack_name}/links.yml`

#### 4. **No Website Scoping**
- **Symptom**: Links created but for wrong website
- **Root cause**: Old code uses `Pwb::Link.create!` instead of `website.links.create!`
- **Fix**: Always scope to website: `website.links.create!(link_data)`

---

## Q3: Where are "contents" seeded?

### Answer:
Contents (translatable text blocks) are created by **`SeedPack.seed_content`** (lines 499-521)

**Location**: `lib/pwb/seed_pack.rb`

**How it works**:
```ruby
def seed_content
  content_dir = @path.join('content')  # Looks for db/seeds/packs/{pack}/content/
  return unless content_dir.exist?     # Returns if no content directory
  
  # Loads each .yml file from content/ directory
  Dir.glob(content_dir.join('*.yml')).each do |content_file|
    content_data = YAML.safe_load(File.read(content_file), symbolize_names: true)
    
    # For each key: value pair, creates Content record
    content_data.each do |key, translations|
      content = @website.contents.find_or_initialize_by(key: key.to_s)
      translations.each do |locale, value|
        content.send("raw_#{locale}=", value)
      end
      content.save!
    end
  end
end
```

**Data structure example** (from `db/seeds/packs/spain_luxury/content/home.yml`):
```yaml
hero_heading:
  en: "Find Your Dream Property in Spain"
  es: "Encuentra tu Casa Ideal en España"
hero_subheading:
  en: "Luxury Properties in Costa del Sol"
  es: "Propiedades de Lujo en Costa del Sol"
```

---

## Q4: Why would content be missing after provisioning?

### Primary Cause:

**ProvisioningService does NOT call content seeding!**

Looking at `provision_website` (lines 172-279):
- ✅ Seeds agency
- ✅ Seeds links
- ✅ Seeds field keys
- ✅ Seeds pages/page_parts
- ✅ Seeds properties
- ❌ **Does NOT seed content**

**Why**: Content is optional and requires pages to already exist. It's meant to be seeded separately or via seed pack's full apply.

### Workaround:

To seed content after provisioning:
```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')
pack = Pwb::SeedPack.find('base')

# If pack has content/
pack.seed_content!(website: website)

# Or use legacy seeder (loads from db/yml_seeds/)
Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
```

### Note:
- **Base pack** (`db/seeds/packs/base/`) has NO `content/` directory
- **Spain Luxury pack** has content files
- **Netherlands Urban pack** has content files

---

## Q5: What's the correct complete provisioning flow?

### Step-by-Step:

1. **User Signs Up**
   ```ruby
   service.start_signup(email: "user@example.com")
   # Creates user (lead state) + reserves subdomain
   ```

2. **User Configures Site**
   ```ruby
   service.configure_site(
     user: user,
     subdomain_name: 'mysite',
     site_type: 'residential'  # Sets seed_pack_name: 'base'
   )
   # Website created in 'pending' state → 'owner_assigned'
   ```

3. **System Provisions Website**
   ```ruby
   service.provision_website(website: website)
   # Runs all 5 provisioning steps:
   # 1. Create agency
   # 2. Create links (from seed pack)
   # 3. Create field keys
   # 4. Create pages/page parts
   # 5. Seed properties (optional)
   # Result: website.provisioning_state == 'locked_pending_email_verification'
   ```

4. **Optionally Seed Content** (NOT done automatically)
   ```ruby
   pack = Pwb::SeedPack.find(website.seed_pack_name)
   pack.seed_content!(website: website)
   ```

5. **User Verifies Email**
   ```ruby
   website.verify_owner_email!
   # website.provisioning_state == 'locked_pending_registration'
   ```

6. **User Creates Account**
   ```ruby
   website.complete_owner_registration!
   # website.provisioning_state == 'live'
   ```

---

## Q6: How can I reseed navigation links?

### Option 1: Use Seed Pack (Recommended)
```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')
pack = Pwb::SeedPack.find('base')

# Clear old links (optional)
website.links.delete_all

# Reseed from pack
pack.seed_links!(website: website)
```

**Problem**: This won't work if `website.links.count >= 3` check is in place.

### Option 2: Manual Reseed
```ruby
# Remove early-return check in provisioning_service.rb
# Or delete existing links first:
website.links.delete_all

# Then run provisioning again:
service = Pwb::ProvisioningService.new
service.send(:create_links_for_website, website)
```

### Option 3: Update the Provisioning Service
The ideal fix would remove the early-return check:
```ruby
# Current (problematic):
def create_links_for_website(website)
  return if website.links.count >= 3  # ← Problem!
  # ...
end

# Better:
def create_links_for_website(website)
  # Don't early-return - allow re-seeding
  # Or check if properly seeded from pack
  # ...
end
```

---

## Q7: What data is scoped per website?

### ✅ Properly Scoped (Multi-Tenant Safe):
- **Links**: `website_id` foreign key (migration 20251121190959)
- **Contents**: `website_id` foreign key
- **Field Keys**: `pwb_website_id` foreign key
- **Pages**: `website_id` foreign key
- **Page Parts**: `website_id` foreign key

### ⚠️ Potentially Not Scoped:
- **Themes**: Shared via ActiveHash (global)
- **Translations**: Global I18n table (no website_id)

### Query Correctly:
```ruby
# ✅ CORRECT - scoped to website
website.links
website.contents
website.field_keys
website.pages

# ❌ INCORRECT - returns all records
Pwb::Link.all
Pwb::Content.all
```

---

## Q8: How do I verify everything was seeded correctly?

### Check Provisioning Status:
```ruby
website = Pwb::Website.find_by(subdomain: 'mysite')

# Get detailed checklist
website.provisioning_checklist
# => {
#   :owner=> { :complete=>true, :required=>true },
#   :agency=> { :complete=>true, :required=>true },
#   :links=> { :complete=>true, :count=>9, :minimum=>3, :required=>true },
#   :field_keys=> { :complete=>true, :count=>35, :minimum=>5, :required=>true },
#   :properties=> { :complete=>false, :count=>0, :required=>false },
#   :subdomain=> { :complete=>true, :value=>'mysite', :required=>true }
# }

# Get missing items
website.provisioning_missing_items
# => [] if complete, or ["links (have 4, need 3)", ...] if incomplete

# Check state
website.provisioning_state
# => 'live' if ready for users
```

### Check Individual Resources:
```ruby
# Links
website.links.count  # Should be >= 3
website.links.pluck(:slug, :placement)
# => [['home', 0], ['buy', 0], ['about', 0], ...]

# Field Keys
website.field_keys.count  # Should be >= 5
website.field_keys.group_by(&:tag)
# => {'property-types' => [...], 'property-states' => [...], ...}

# Content
website.contents.pluck(:key)
# => ['logo', 'footer_text', ...] or empty if not seeded

# Pages
website.pages.pluck(:slug)
# => ['home', 'about', 'contact', ...] or empty if not seeded
```

---

## Q9: What's in the base seed pack vs other packs?

### Base Pack (`db/seeds/packs/base/`)
- **Links**: 11 (5 top nav + 6 footer)
- **Field Keys**: 35+ (types, states, features, amenities)
- **Pages**: None
- **Content**: None
- **Properties**: None
- **Inheritance**: Root pack (no parent)

### Spain Luxury Pack (`db/seeds/packs/spain_luxury/`)
- **Inherits**: Everything from base
- **Adds**:
  - 7 sample properties (villas, apartments, penthouses in Marbella area)
  - Content for: home, about-us, contact-us, sell
  - Multilocal support (en, es, de, fr)

### Netherlands Urban Pack (`db/seeds/packs/netherlands_urban/`)
- **Inherits**: Everything from base
- **Adds**:
  - Content for multiple pages
  - Multilocal support (en, nl, de)
  - Tailored for urban properties

---

## Q10: How do I create a custom seed pack?

### Directory Structure:
```
db/seeds/packs/my_custom_pack/
├── pack.yml                    # Required: pack metadata
├── links.yml                   # Optional: navigation items
├── field_keys.yml              # Optional: property fields
├── pages/                       # Optional: page definitions
│   ├── home.yml
│   ├── about.yml
│   └── contact.yml
├── page_parts/                 # Optional: page components
│   ├── home__hero.yml
│   └── home__featured.yml
├── content/                    # Optional: translatable content
│   ├── home.yml
│   ├── about.yml
│   └── contact-us.yml
├── properties/                 # Optional: sample properties
│   ├── property1.yml
│   └── property2.yml
├── images/                     # Optional: property images
│   ├── property1.jpg
│   └── property2.jpg
└── translations/               # Optional: I18n translations
    ├── es.yml
    ├── de.yml
    └── fr.yml
```

### Minimal pack.yml:
```yaml
name: my_custom_pack
display_name: "My Custom Pack"
description: "Custom setup for specific use case"
version: "1.0"

# Inherit from base for default links, field keys, etc.
inherits_from: base

website:
  theme_name: bristol
  default_client_locale: en
  supported_locales: [en, es]
  currency: EUR
  area_unit: sqmt
```

### Use the pack:
```ruby
# When provisioning
service.configure_site(
  user: user,
  subdomain_name: 'mysite',
  site_type: 'residential'
)

website = result[:website]
website.update!(seed_pack_name: 'my_custom_pack')

# Then provision
service.provision_website(website: website)
```

---

## Key Code Locations

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| **Provisioning** | `app/services/pwb/provisioning_service.rb` | 172-279 | Orchestrates complete workflow |
| **Link Seeding** | `app/services/pwb/provisioning_service.rb` | 339-362 | Creates navigation links |
| **Seed Pack** | `lib/pwb/seed_pack.rb` | Full | Reusable data bundles |
| **Seed Pack Links** | `lib/pwb/seed_pack.rb` | 344-362 | Loads links.yml |
| **Seed Pack Content** | `lib/pwb/seed_pack.rb` | 499-521 | Loads content.yml |
| **State Machine** | `app/models/pwb/website.rb` | 61-192 | Provisioning states |
| **Guards** | `app/models/pwb/website.rb` | 199-221 | State transition requirements |
| **Base Pack Links** | `db/seeds/packs/base/links.yml` | N/A | 11 navigation items |
| **Base Pack Fields** | `db/seeds/packs/base/field_keys.yml` | N/A | 35+ property fields |

---

## Common Fixes

### Fix 1: Make Seed Pack the Default
**Problem**: Website created without seed_pack_name
**File**: `app/services/pwb/provisioning_service.rb` line 127
```ruby
website = Website.new(
  subdomain: validation[:normalized],
  site_type: site_type,
  provisioning_state: 'pending',
  seed_pack_name: seed_pack_for_site_type(site_type)  # ← Always set this
)
```

### Fix 2: Remove Early-Return Check
**Problem**: Can't reseed if links already exist
**File**: `app/services/pwb/provisioning_service.rb` line 340
```ruby
# BEFORE:
def create_links_for_website(website)
  return if website.links.count >= 3  # ← Problem!

# AFTER:
def create_links_for_website(website)
  # No early return - allow idempotent reseeding
```

### Fix 3: Add Content Seeding to Provisioning
**Problem**: Content never seeded by default
**File**: `app/services/pwb/provisioning_service.rb` (add after line 231)
```ruby
# Step 5.5: Seed content
if try_seed_pack_step(website, :content)
  report_progress(progress_block, website, 'content_seeded', 72)
end
```

### Fix 4: Seed Content from Pack apply!
**Current**: SeedPack.apply! doesn't get called during provisioning
**Solution**: Use seed pack's full apply method instead of individual steps:
```ruby
pack = Pwb::SeedPack.find(website.seed_pack_name)
pack.apply!(website: website, options: { skip_website: true })
```

---

## Testing Seeding

### Unit Test:
```ruby
describe "Website Seeding" do
  let(:website) { create(:pwb_website, seed_pack_name: 'base') }
  
  it "creates navigation links from seed pack" do
    service = Pwb::ProvisioningService.new
    service.send(:create_links_for_website, website)
    
    expect(website.links.count).to be >= 3
    expect(website.links.pluck(:slug)).to include('home')
  end
  
  it "creates content from seed pack" do
    pack = Pwb::SeedPack.find('base')
    pack.seed_content!(website: website)
    
    expect(website.contents.count).to be > 0
  end
end
```

---

