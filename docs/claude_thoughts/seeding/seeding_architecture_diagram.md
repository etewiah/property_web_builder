# Website Seeding Architecture - Visual Guide

## High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                       USER SIGNUP WORKFLOW                          │
└─────────────────────────────────────────────────────────────────────┘

1. START SIGNUP
   ┌─────────────────────────────────────────┐
   │ ProvisioningService.start_signup(email) │
   └──────────────────┬──────────────────────┘
                      │
            ┌─────────▼──────────┐
            │ Create Lead User   │
            │ in 'lead' state    │
            └─────────┬──────────┘
                      │
            ┌─────────▼────────────────────┐
            │ Reserve Subdomain (10 min)   │
            │ from Subdomain Pool          │
            └─────────┬────────────────────┘
                      │
              ┌───────▼────────┐
              │ SUCCESS:       │
              │ - user         │
              │ - subdomain    │
              └────────────────┘

2. CONFIGURE SITE
   ┌──────────────────────────────────────────────────────┐
   │ ProvisioningService.configure_site(                 │
   │   user, subdomain_name, site_type)                   │
   └─────────────────────┬────────────────────────────────┘
                         │
          ┌──────────────▼──────────────┐
          │ Create Website Record       │
          │ - subdomain: 'mysite'       │
          │ - site_type: 'residential'  │
          │ - seed_pack_name: 'base'    │
          │ - state: 'pending'          │
          └──────────────┬───────────────┘
                         │
          ┌──────────────▼──────────────┐
          │ Create Owner Membership     │
          │ - user.role = 'owner'       │
          │ - user.active = true        │
          └──────────────┬───────────────┘
                         │
          ┌──────────────▼──────────────┐
          │ Transition to State:        │
          │ 'owner_assigned'            │
          │ (via AASM guard check)      │
          └──────────────┬───────────────┘
                         │
              ┌──────────▼─────────┐
              │ SUCCESS:           │
              │ - user             │
              │ - website          │
              │ - membership       │
              └────────────────────┘

3. PROVISION WEBSITE
   ┌────────────────────────────────────────┐
   │ ProvisioningService.provision_website  │
   │ (website, skip_properties: false)      │
   └─────────────┬──────────────────────────┘
                 │
        ┌────────▼──────────┐
        │ VERIFY STATE      │
        │ pending or        │
        │ owner_assigned    │
        └────────┬───────────┘
                 │
        ┌────────▼────────────────────────────┐
        │ STEP 1: CREATE AGENCY (30%)         │
        │ ├─ Try: SeedPack.seed_agency!       │
        │ │  └─ Looks for agency: config     │
        │ └─ Fallback: Create minimal agency │
        └────────┬───────────────────────────┘
                 │ [Guard: has_agency?]
        ┌────────▼────────────────────┐
        │ State: agency_created       │
        │ [15 → 30% complete]         │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────────────────────────────┐
        │ STEP 2: CREATE NAVIGATION LINKS (45%)           │
        │ ├─ Check early return:                          │
        │ │  └─ IF links.count >= 3: EXIT (PROBLEM!)     │
        │ ├─ Try: SeedPack.seed_links!                    │
        │ │  ├─ Load: db/seeds/packs/base/links.yml       │
        │ │  ├─ Parse YAML                                │
        │ │  └─ Create Link records:                       │
        │ │      ├─ slug: 'home', placement: 'top_nav'   │
        │ │      ├─ slug: 'buy', placement: 'top_nav'    │
        │ │      ├─ slug: 'about', placement: 'top_nav'  │
        │ │      ├─ slug: 'contact', placement: 'top_nav'│
        │ │      ├─ slug: 'footer_home', placement: 'footer' │
        │ │      ├─ slug: 'privacy', placement: 'footer' │
        │ │      └─ ... (6 more footer links)             │
        │ └─ Fallback (if pack not found):                │
        │    └─ Create 4 basic links (minimal):           │
        │        ├─ home → /                              │
        │        ├─ properties → /search                  │
        │        ├─ about → /about                        │
        │        └─ contact → /contact                    │
        │        (Missing: link_title, placement, page_slug) │
        └────────┬─────────────────────────────────────────┘
                 │ [Guard: has_links? (count >= 3)]
        ┌────────▼────────────────────┐
        │ State: links_created        │
        │ [30 → 45% complete]         │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────────────────────────────┐
        │ STEP 3: CREATE FIELD KEYS (50%)                 │
        │ ├─ Try: SeedPack.seed_field_keys!              │
        │ │  ├─ Load: db/seeds/packs/base/field_keys.yml │
        │ │  └─ Create 35+ FieldKey records:             │
        │ │      ├─ Types: villa, apt, house, ...        │
        │ │      ├─ States: excellent, good, ...         │
        │ │      ├─ Features: pool, garden, ...          │
        │ │      └─ Amenities: AC, heating, ...          │
        │ └─ Fallback:                                    │
        │    └─ Create 7 default field keys              │
        └────────┬─────────────────────────────────────────┘
                 │ [Guard: has_field_keys? (count >= 5)]
        ┌────────▼────────────────────┐
        │ State: field_keys_created   │
        │ [45 → 50% complete]         │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────────────────────────────┐
        │ STEP 4: CREATE PAGES & PAGE PARTS (65%)         │
        │ ├─ Try: SeedPack.seed_pages! + seed_page_parts!│
        │ │  └─ Look for pages/ directory in pack        │
        │ └─ Fallback: PagesSeeder                       │
        │    ├─ seed_page_basics! → 9 pages:            │
        │    │  ├─ home, sell, buy, rent, about         │
        │    │  ├─ contact, privacy_policy              │
        │    │  ├─ legal_notice                         │
        │    │  └─ (plus page_parts for each)           │
        │    └─ seed_page_parts! → Load from:            │
        │       └─ db/yml_seeds/page_parts/             │
        └────────┬─────────────────────────────────────────┘
                 │
        ┌────────▼────────────────────┐
        │ [65% complete]              │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────────────────────────────┐
        │ STEP 5: SEED PROPERTIES (80%, Optional)         │
        │ ├─ IF skip_properties: true                     │
        │ │  └─ State: skip_properties!                  │
        │ └─ ELSE:                                        │
        │    ├─ Try: SeedPack.seed_properties!           │
        │    │  └─ Load from properties/ directory       │
        │    └─ Fallback: Pwb::Seeder                    │
        │       └─ Load sample properties                │
        └────────┬─────────────────────────────────────────┘
                 │
        ┌────────▼────────────────────┐
        │ State: properties_seeded    │
        │ [65 → 80% complete]         │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────────────────────────────┐
        │ STEP 6: FINAL VERIFICATION (95%)                │
        │ ├─ Check: provisioning_complete?              │
        │ │  ├─ has_owner? ✓                            │
        │ │  ├─ has_agency? ✓                           │
        │ │  ├─ has_links? ✓                            │
        │ │  └─ has_field_keys? ✓                       │
        │ └─ If all checks pass:                         │
        │    └─ State: mark_ready!                       │
        └────────┬─────────────────────────────────────────┘
                 │
        ┌────────▼─────────────────────────────┐
        │ State: ready (90 → 95% complete)     │
        └────────┬──────────────────────────────┘
                 │
        ┌────────▼──────────────────────────────────────┐
        │ STEP 7: ENTER LOCKED STATE (95% complete)     │
        │ ├─ Check: can_go_live?                        │
        │ │  ├─ provisioning_complete? ✓                │
        │ │  └─ subdomain.present? ✓                    │
        │ ├─ State: enter_locked_state!                 │
        │ │  ├─ Generate email verification token       │
        │ │  └─ Send verification email to owner        │
        │ └─ State: locked_pending_email_verification   │
        └────────┬──────────────────────────────────────┘
                 │
              ┌──▼─────────────────────────────┐
              │ SUCCESS: Provisioning Complete │
              │ Website ready for user action  │
              └───────────────────────────────┘

4. USER VERIFIES EMAIL (N/A for seeding)
   └─ State: locked_pending_registration

5. USER CREATES FIREBASE ACCOUNT
   └─ State: live (Website public)
```

---

## Navigation Links Seeding - Detailed Flow

```
┌────────────────────────────────────────────────────────────┐
│ ProvisioningService.create_links_for_website(website)      │
└────────────────────┬─────────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │ Check Early Return:     │
         │ IF links.count >= 3     │ ◄─── POTENTIAL ISSUE
         │   RETURN (skip seeding) │     Can't reseed if
         └───────────┬────────────┘      fallback already ran
                     │
            ┌────────▼──────────────────────────────┐
            │ Try Seed Pack Path                    │
            │ try_seed_pack_step(website, :links)  │
            └────────┬───────────────────────────────┘
                     │
     ┌───────────────▼───────────────┐
     │ Find Pack: 'base' (or custom)  │
     └───────────────┬───────────────┘
                     │
     ┌───────────────▼──────────────────┐
     │ ERROR? (Pack not found)           │
     │ ├─ PackNotFoundError              │
     │ ├─ NoMethodError                  │
     │ └─ Other StandardError            │
     └───────────────┬──────────────────┘
                     │
    ┌────────────────▼─────────────────────────┐
    │ Seed Pack Found                           │
    │ execute: seed_pack.seed_links!            │
    │                                           │
    │ Inside SeedPack.seed_links (line 344):    │
    │ ├─ links_file = @path.join('links.yml')  │
    │ ├─ return unless links_file.exist?       │
    │ │  (EXIT if no links.yml found)          │
    │ ├─ links = YAML.safe_load(...)           │
    │ │  Loads file as array of hashes:        │
    │ │  [                                      │
    │ │    { slug: 'home',                     │
    │ │      link_title: 'Home',                │
    │ │      placement: 'top_nav',              │
    │ │      sort_order: 1,                     │
    │ │      visible: true,                     │
    │ │      page_slug: 'home' },               │
    │ │    { slug: 'buy', ... },                │
    │ │    ...                                  │
    │ │  ]                                      │
    │ ├─ For each link_data:                   │
    │ │  ├─ Check if exists:                   │
    │ │  │  website.links.find_by(slug: ...)   │
    │ │  └─ Create if not:                     │
    │ │     website.links.create!(link_data)   │
    │ │     └─ Includes website_id auto-scoped │
    │ └─ Return true (success)                 │
    │                                           │
    │ Creates these 9 links from base pack:     │
    │ ✓ home (top_nav, order 1)                 │
    │ ✓ buy (top_nav, order 2)                  │
    │ ✓ rent (top_nav, order 3)                 │
    │ ✓ about (top_nav, order 4)                │
    │ ✓ contact (top_nav, order 5)              │
    │ ✓ footer_home (footer, order 1)          │
    │ ✓ footer_buy (footer, order 2)           │
    │ ✓ footer_rent (footer, order 3)          │
    │ ✓ footer_contact (footer, order 4)       │
    │ ✓ privacy (footer, order 5)              │
    │ ✓ terms (footer, order 6)                │
    └────────────────┬─────────────────────────┘
                     │
           ┌─────────▼──────────┐
           │ SUCCESS: RETURN    │
           │ Links fully seeded │
           │ Provisioning done  │
           └────────────────────┘

             OR (if pack fails)

    ┌───────────────────────────────────────┐
    │ Fallback: Create Minimal Links        │
    │                                       │
    │ default_links = [                     │
    │   { slug: 'home',                    │
    │     link_url: '/',                   │
    │     visible: true },                 │
    │   { slug: 'properties',              │
    │     link_url: '/search',             │
    │     visible: true },                 │
    │   { slug: 'about',                   │
    │     link_url: '/about',              │
    │     visible: true },                 │
    │   { slug: 'contact',                 │
    │     link_url: '/contact',            │
    │     visible: true }                  │
    │ ]                                     │
    │                                       │
    │ For each link:                        │
    │   website.links.find_or_create_by!(   │
    │     slug: link_attrs[:slug])          │
    │   assign_attributes({                 │
    │     link_url: '/',                    │
    │     visible: true,                    │
    │     sort_order: index + 1             │
    │   })                                  │
    │                                       │
    │ Creates only 4 basic links:           │
    │ ⚠ home (minimal)                     │
    │ ⚠ properties (minimal)                │
    │ ⚠ about (minimal)                     │
    │ ⚠ contact (minimal)                   │
    │                                       │
    │ Missing attributes:                   │
    │ ✗ link_title → Will display blank     │
    │ ✗ placement → Defaults to top_nav (0) │
    │ ✗ page_slug → No page association    │
    │ ✗ Only 4/11 links vs base pack       │
    └──────────────┬──────────────┬─────────┘
                   │              │
         ┌─────────▼──┐  ┌────────▼───────┐
         │ PARTIAL    │  │ PROBLEM:       │
         │ Fallback   │  │ - Incomplete   │
         │ Used       │  │ - Can't reseed │
         │            │  │ - Missing data │
         └────────────┘  └────────────────┘
```

---

## Content Seeding - Where It Happens

```
┌──────────────────────────────────────────────────────────┐
│ NOTE: Content seeding is NOT called by ProvisioningService!
└──────────────────────────────────────────────────────────┘

To seed content, must call manually:

┌──────────────────────────────────────────────────────────┐
│ Method 1: Via SeedPack (Recommended)                      │
│                                                           │
│  pack = Pwb::SeedPack.find('base')                       │
│  pack.seed_content!(website: website)                    │
│                                                           │
│  Inside SeedPack.seed_content (line 499):                │
│  ├─ content_dir = @path.join('content')                  │
│  ├─ return unless content_dir.exist?                     │
│  │  (EXIT if no content/ found in pack)                  │
│  │                                                        │
│  │  Note: Base pack has NO content/ directory!           │
│  │  Spain Luxury has content/:                           │
│  │  ├─ home.yml                                          │
│  │  ├─ about-us.yml                                      │
│  │  ├─ contact-us.yml                                    │
│  │  └─ sell.yml                                          │
│  │                                                        │
│  ├─ Load each .yml file in content/:                     │
│  │  Example home.yml:                                    │
│  │  ───────────────────────────────────────────          │
│  │  hero_heading:                                         │
│  │    en: "Find Your Dream Property"                     │
│  │    es: "Encuentra Tu Casa Ideal"                      │
│  │  hero_subheading:                                     │
│  │    en: "Luxury Properties"                            │
│  │    es: "Propiedades de Lujo"                          │
│  │  ───────────────────────────────────────────          │
│  │                                                        │
│  ├─ For each key: translations pair:                     │
│  │  ├─ content = website.contents.find_or_initialize_by( │
│  │  │    key: key.to_s)                                  │
│  │  ├─ For each locale, value:                           │
│  │  │  content.raw_en = "Find Your Dream Property"       │
│  │  │  content.raw_es = "Encuentra Tu Casa Ideal"        │
│  │  └─ content.save!                                     │
│  │                                                        │
│  └─ Returns content count created                        │
│                                                           │
│  Result: Content records in pwb_contents table:          │
│  ├─ key: "hero_heading"                                  │
│  ├─ website_id: 123                                      │
│  ├─ translations_en: "Find Your Dream Property"          │
│  ├─ translations_es: "Encuentra Tu Casa Ideal"           │
│  └─ ... (more translations)                              │
│                                                           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Method 2: Via Legacy ContentsSeeder                       │
│                                                           │
│  Pwb::ContentsSeeder.seed_page_content_translations!(    │
│    website: website)                                      │
│                                                           │
│  Loads from: db/yml_seeds/content_translations/{locale}. │
│  yml (Global seeders, not per-pack)                      │
│                                                           │
│  Result: Content from global seed files                  │
│                                                           │
└──────────────────────────────────────────────────────────┘

IMPORTANT:
┌─────────────────────────────────────────────────┐
│ Base Pack (db/seeds/packs/base/) has NO content/│
│                                                  │
│ So during provisioning:                          │
│ ├─ Agency ✓ Created                             │
│ ├─ Links ✓ Created (9-11)                       │
│ ├─ Field Keys ✓ Created (35+)                   │
│ ├─ Pages ✓ Created (9)                          │
│ ├─ Properties ✓ Optional                        │
│ └─ Content ✗ NEVER CREATED                      │
│                                                  │
│ Result: Website has structure but no text!      │
└─────────────────────────────────────────────────┘
```

---

## Multi-Tenancy Scoping

```
┌────────────────────────────────────────────────────────────┐
│ How Multi-Tenancy Works During Seeding                     │
└────────────────────────────────────────────────────────────┘

When seeding, must always associate with website_id:

✓ CORRECT - Uses association to auto-scope:
  website.links.create!(link_data)
  └─ Automatically includes website_id

✓ CORRECT - Explicitly sets website_id:
  Pwb::Link.create!(link_data.merge(website_id: website.id))

✗ WRONG - No website scoping:
  Pwb::Link.create!(link_data)
  └─ Creates record in shared table (cross-tenant leak!)

During ProvisioningService (set scope once):
  def create_links_for_website(website)
    Pwb::Current.website = website  ← Set context
    
    # Now all operations scoped to this website
  end

During SeedPack (uses association):
  def seed_links
    links.each do |link_data|
      @website.links.create!(link_data)  ← Always scoped
    end
  end

Database Records Example:

TABLE: pwb_links
┌───────┬──────────┬─────────────┬──────────────────┐
│ id    │ slug     │ website_id  │ link_title       │
├───────┼──────────┼─────────────┼──────────────────┤
│ 1     │ home     │ 1           │ "Home"           │
│ 2     │ buy      │ 1           │ "Buy Properties" │
│ 3     │ home     │ 2           │ "Home"           │
│ 4     │ about    │ 2           │ "About Us"       │
└───────┴──────────┴─────────────┴──────────────────┘

Query correctly:
  Website 1:
    website_1.links
    └─ SELECT * FROM pwb_links WHERE website_id = 1
    └─ Returns: IDs 1, 2

  Website 2:
    website_2.links
    └─ SELECT * FROM pwb_links WHERE website_id = 2
    └─ Returns: IDs 3, 4
```

---

## State Machine Guards

```
┌────────────────────────────────────────────────────────────┐
│ AASM State Transitions with Guards                         │
└────────────────────────────────────────────────────────────┘

Each transition requires guard check:

pending ─[assign_owner, guard: has_owner?]─→ owner_assigned
  Guard checks: user_memberships.exists?(role: 'owner', active: true)

owner_assigned ─[complete_agency, guard: has_agency?]─→ agency_created
  Guard checks: agency.present?

agency_created ─[complete_links, guard: has_links?]─→ links_created
  Guard checks: links.count >= 3

links_created ─[complete_field_keys, guard: has_field_keys?]─→ field_keys_created
  Guard checks: field_keys.count >= 5

field_keys_created ─[seed_properties]─→ properties_seeded
  (No guard - properties optional)

properties_seeded ─[mark_ready, guard: provisioning_complete?]─→ ready
  Guard checks: has_owner? && has_agency? && has_links? && has_field_keys?

ready ─[enter_locked_state, guard: can_go_live?]─→ locked_pending_email_verification
  Guard checks: provisioning_complete? && subdomain.present?

locked_pending_email_verification ─[verify_owner_email]─→ locked_pending_registration
  Guard checks: email_verification_valid?

locked_pending_registration ─[complete_owner_registration]─→ live
  (No guard)

Any state can fail:
  * → [fail_provisioning] → failed

failed ─[retry_provisioning]─→ pending

Flow Guarantee:
  - Can only reach 'live' if all provisioning steps complete
  - Each step tracked in provisioning_state
  - Guards prevent invalid transitions
  - Fail state captures error for debugging
```

---

## Key Files Map

```
Website Seeding Architecture Files:

├─ app/services/pwb/
│  └─ provisioning_service.rb (525 lines)
│     ├─ start_signup (signup flow)
│     ├─ configure_site (create website)
│     ├─ provision_website (main orchestrator)
│     │  ├─ create_agency_for_website
│     │  ├─ create_links_for_website ← NAVIGATION HERE
│     │  ├─ create_field_keys_for_website
│     │  ├─ create_pages_for_website
│     │  ├─ seed_properties_for_website
│     │  └─ try_seed_pack_step ← Seed pack integration
│     └─ send_verification_email
│
├─ app/models/pwb/
│  ├─ website.rb (855 lines)
│  │  ├─ AASM state machine (states, events, guards)
│  │  ├─ has_owner? / has_agency? / has_links? / has_field_keys?
│  │  ├─ provisioning_complete? / provisioning_missing_items
│  │  └─ provisioning_checklist
│  ├─ link.rb (53 lines)
│  │  ├─ belongs_to :website
│  │  ├─ translates :link_title (Mobility)
│  │  └─ scopes: ordered_visible_top_nav, ordered_footer
│  └─ content.rb (93 lines)
│     ├─ belongs_to :website
│     ├─ translates :raw (Mobility)
│     └─ has_many :content_photos
│
├─ lib/pwb/
│  ├─ seed_pack.rb (790 lines)
│  │  ├─ find(name) - Load pack by name
│  │  ├─ apply!(website:, options:) - Full apply
│  │  ├─ seed_agency!
│  │  ├─ seed_links! ← NAVIGATION HERE
│  │  ├─ seed_field_keys!
│  │  ├─ seed_pages! / seed_page_parts!
│  │  ├─ seed_properties!
│  │  ├─ seed_content! ← CONTENT HERE
│  │  ├─ seed_users!
│  │  └─ seed_translations!
│  ├─ pages_seeder.rb (114 lines)
│  │  ├─ seed_page_basics!(website:) - 9 pages
│  │  └─ seed_page_parts!(website:) - Parts for pages
│  └─ contents_seeder.rb (98 lines)
│     └─ seed_page_content_translations!(website:)
│
├─ db/seeds/packs/
│  ├─ base/ ← Default pack for all site types
│  │  ├─ pack.yml (metadata)
│  │  ├─ links.yml (11 navigation items)
│  │  ├─ field_keys.yml (35+ property fields)
│  │  └─ (no content/, pages/, properties/)
│  ├─ spain_luxury/ (inherits from base)
│  │  └─ content/, properties/
│  └─ netherlands_urban/ (inherits from base)
│     └─ content/
│
├─ db/migrate/
│  ├─ 20170720183443_create_pwb_links.rb
│  ├─ 20251121190959_add_website_id_to_tables.rb ← Multi-tenancy
│  ├─ 20251209122349_add_provisioning_state_to_websites.rb ← AASM
│  └─ ... others
│
├─ db/yml_seeds/
│  ├─ pages/ (9 page definitions)
│  ├─ page_parts/ (page component definitions)
│  └─ content_translations/ (global content seed files)
│
└─ spec/
   ├─ services/pwb/
   │  └─ provisioning_seeding_spec.rb (297 lines)
   │     └─ Tests full workflow
   ├─ models/pwb/
   │  ├─ website_provisioning_spec.rb
   │  └─ website_spec.rb
   └─ lib/pwb/
      └─ seed_pack_spec.rb
```

---

## Debugging Workflow

```
Problem: Website created but no links visible

┌────────────────────────────────────────────────┐
│ 1. Check Provisioning State                    │
│   website.provisioning_state                   │
│   └─ Should be 'live' or 'ready' for complete │
│   └─ Check if stuck in 'links_created'?       │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 2. Check Links Exist                           │
│   website.links.count                          │
│   website.links.pluck(:slug, :placement)      │
│   └─ Should be >= 3                            │
│   └─ Check placement values (0=top_nav, 1=footer)
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 3. Check Link Attributes                       │
│   website.links.first                          │
│   ├─ slug? (should be set)                     │
│   ├─ link_title? (blank = problem!)            │
│   ├─ placement? (0 or 1)                       │
│   └─ page_slug? (associated page)              │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 4. Check Seed Pack                             │
│   website.seed_pack_name                       │
│   └─ Should be 'base' (or custom)              │
│   └─ Check if pack exists:                     │
│       Pwb::SeedPack.find('base')               │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 5. Check Pack Links                            │
│   pack = Pwb::SeedPack.find('base')            │
│   pack.preview                                 │
│   └─ Should show: properties: 0, links: 11    │
│   └─ Check if links.yml exists:                │
│       ls db/seeds/packs/base/links.yml         │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 6. Manually Reseed                             │
│   website.links.delete_all                     │
│   pack.seed_links!(website: website)           │
│   └─ Verify new links created with full data  │
└────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│ 7. Check Render Layer                          │
│   (Links may exist in DB but not display)      │
│   └─ Check placement enum values               │
│   └─ Check if CSS classes hide/show links      │
│   └─ Verify Mobility translations rendering    │
└────────────────────────────────────────────────┘
```

