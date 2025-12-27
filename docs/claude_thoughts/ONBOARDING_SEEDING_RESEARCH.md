# PropertyWebBuilder Onboarding and Seeding Architecture Research

**Date:** December 27, 2025  
**Researched by:** Claude Code

## Executive Summary

PropertyWebBuilder has a well-architected onboarding and seeding system:

1. **Two-Layer Onboarding Model:**
   - **Signup Flow Onboarding** - State machine tracking user progression (lead → registered → email_verified → onboarding → active)
   - **Site Admin Onboarding** - 5-step wizard for new website owners to set up their site

2. **Seed System Architecture:**
   - **Seed Packs** - Pre-configured bundles of data for specific scenarios/site types
   - **SeedRunner** - Enhanced orchestrator with safety features (dry-run, interactive mode)
   - **ProvisioningService** - Manages complete tenant provisioning workflow from signup to live website

3. **Website Provisioning State Machine:**
   - 11-state AASM flow with granular guards ensuring each step completes before moving forward
   - Tracks progress from pending → owner_assigned → ... → live

---

## 1. Current Seeding Architecture

### 1.1 Seed Pack System (`lib/pwb/seed_pack.rb`)

**Purpose:** Pre-configured bundles representing real-world scenarios for tenant websites

**Key Features:**
- **Hierarchical:** Packs can inherit from parent packs (`inherits_from` field)
- **Location:** `/db/seeds/packs/{pack_name}/`
- **Configuration:** Each pack has a `pack.yml` with metadata and seeding directives

**Pack Structure:**
```
packs/
├── pack_name/
│   ├── pack.yml              # Pack configuration
│   ├── agency.yml            # Agency data
│   ├── field_keys.yml        # Property field keys/dropdowns
│   ├── links.yml             # Navigation links
│   ├── pages/                # Page definitions (YAML files)
│   ├── page_parts/           # Page component content
│   ├── properties/           # Sample properties (YAML)
│   ├── images/               # Property images
│   ├── content/              # Website content translations
│   ├── content_translations/ # Page part content translations
│   └── translations/         # i18n translations
```

**Pack Configuration Example:**
```yaml
display_name: "Spain Luxury"
description: "Luxury property sales in Spain"
version: "1.0"
inherits_from: "base"  # Optional parent pack

website:
  theme_name: "barcelona"
  default_client_locale: "es"
  currency: "EUR"
  area_unit: "sqm"
  supported_locales: ["es", "en", "fr"]

agency:
  display_name: "Luxury Estates Spain"
  email: "info@luxury-estates.es"
  phone: "+34 93 XXX XXXX"
  address:
    street_address: "Carrer de la Pau, 10"
    city: "Barcelona"
    region: "Catalonia"
    country: "ES"
    postal_code: "08002"

users:
  - email: "owner@luxury-estates.es"
    password: "temp123!"
    role: "owner"

page_parts:
  home:
    - key: "heroes/hero_image"
      order: 1
```

**Seeding Steps (in order):**
1. Apply parent pack first (if `inherits_from` specified)
2. `seed_website()` - Update theme, locale, currency
3. `seed_agency()` - Create agency + address
4. `seed_field_keys()` - Create property categories (types, states, features)
5. `seed_links()` - Create navigation structure
6. `seed_pages()` - Create page templates
7. `seed_page_parts()` - Add component content to pages
8. `seed_properties()` - Load sample properties
9. `seed_content()` - Populate page content translations
10. `seed_users()` - Create user accounts + memberships
11. `seed_translations()` - Load i18n translations

**Usage:**
```ruby
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)

# With options:
pack.apply!(website: website, options: {
  skip_properties: true,
  dry_run: true,
  verbose: true
})

# List available packs:
Pwb::SeedPack.available
```

### 1.2 SeedRunner (`lib/pwb/seed_runner.rb`)

**Purpose:** Enhanced seeding orchestrator with safety features

**Modes:**
- `:interactive` - Prompts user before updating existing data (default)
- `:create_only` - Only creates new records, skips existing
- `:force_update` - Updates without prompting
- `:upsert` - Creates or updates all records

**Features:**
- Validates seed files before processing
- Detects existing data and prompts for action
- Dry-run mode to preview changes
- Progress logging with visual indicators
- Statistics tracking (created, updated, skipped, errors)

**Seed Files Location:** `/db/yml_seeds/`
```
yml_seeds/
├── agency.yml              # Agency data
├── agency_address.yml      # Agency address
├── website.yml             # Website settings
├── field_keys.yml          # Property field keys
├── users.yml               # User accounts
├── contacts.yml            # Contact records
├── links.yml               # Navigation links
├── prop/                   # Sample properties
│   ├── villa_for_sale.yml
│   ├── villa_for_rent.yml
│   ├── flat_for_sale.yml
│   └── ...
└── translations_*.rb       # i18n translations
```

**Usage:**
```ruby
# Interactive mode (default)
Pwb::SeedRunner.run(website: website)

# Create-only mode
Pwb::SeedRunner.run(website: website, mode: :create_only)

# Force update
Pwb::SeedRunner.run(website: website, mode: :force_update)

# Dry-run
Pwb::SeedRunner.run(website: website, dry_run: true)

# Skip properties and translations
Pwb::SeedRunner.run(website: website, skip_properties: true, skip_translations: true)
```

### 1.3 ProvisioningService (`app/services/pwb/provisioning_service.rb`)

**Purpose:** Orchestrates complete tenant provisioning workflow

**Workflow Steps:**

1. **start_signup(email:)** - Create lead user and reserve subdomain
   - Creates user in `lead` state
   - Reserves subdomain for 10 minutes
   - Returns: `{ success: bool, user: User, subdomain: Subdomain }`

2. **verify_email(user:, token:)** - Mark email as verified
   - Transitions user from `registered` → `email_verified`
   - Returns: `{ success: bool, user: User }`

3. **configure_site(user:, subdomain_name:, site_type:)** - Set up website
   - Validates subdomain
   - Creates `Website` in `pending` state
   - Creates `UserMembership` with `owner` role
   - Allocates subdomain from pool
   - Returns: `{ success: bool, user: User, website: Website, membership: UserMembership }`

4. **provision_website(website:, skip_properties: false, &progress_block)** - Full provisioning
   - 11-step state machine ensuring each completes before next
   - Progress callback block: `{ state:, percentage:, message: }`
   - Returns: `{ success: bool, errors: [] }`

**Provisioning State Transitions:**
```
pending
  ↓ (has_owner? guard)
owner_assigned
  ↓ (has_agency? guard)
agency_created
  ↓ (has_links? guard >= 3)
links_created
  ↓ (has_field_keys? guard >= 5)
field_keys_created
  ↓
properties_seeded (or skip_properties)
  ↓ (provisioning_complete? guard)
ready
  ↓ (can_go_live? guard)
locked_pending_email_verification
  ↓ (email_verification_valid? guard)
locked_pending_registration
  ↓
live
```

**Guards/Validations:**
- Each transition requires guard checks (e.g., `has_owner?`, `has_agency?`)
- If guard fails, AASM::InvalidTransition exception raised
- Service catches and logs detailed error info

**Granular Provisioning Steps in Service:**
1. Create agency (or use seed pack)
2. Create navigation links (or use seed pack)
3. Create field keys (or use seed pack)
4. Create pages and page parts (or use seed pack)
5. Seed properties (optional, or use seed pack)
6. Final verification (all required items present)
7. Mark ready
8. Enter locked state
9. Send verification email

**Integration with Seed Packs:**
```ruby
try_seed_pack_step(website, :agency)    # Returns true if pack handled it
try_seed_pack_step(website, :properties) # Falls back to defaults if pack doesn't exist
```

**Error Handling:**
- Transaction-based with rollback support
- Detailed error messages with state tracking
- Can retry failed provisioning with `retry_provisioning(website:)`
- Logs all steps to Rails logger

---

## 2. Existing Onboarding Flags & Mechanisms

### 2.1 User Onboarding State Machine (`app/models/pwb/user.rb`)

**AASM State Machine (signup flow):**
```
lead (initial)
  ↓
registered
  ↓
email_verified
  ↓
onboarding
  ↓
active ← OR direct activation for admin users
↓ (from any except active)
churned (if abandoned)
```

**Events:**
- `register()` - lead → registered (sets `onboarding_started_at`)
- `verify_email()` - registered → email_verified
- `start_onboarding()` - lead/email_verified → onboarding (sets `onboarding_step: 1`)
- `complete_onboarding()` - onboarding → active (sets `onboarding_completed_at`)
- `activate()` - any → active (direct for admin users)
- `mark_churned()` - any → churned (if abandoned signup)
- `reactivate()` - churned → lead

**Database Columns (User model):**
```ruby
# == Schema Information
#
# Table name: pwb_users
#
#  onboarding_state              :string           default("active"), indexed
#  onboarding_step               :integer          default(0)
#  onboarding_started_at         :datetime
#  onboarding_completed_at       :datetime
#  site_admin_onboarding_completed_at :datetime    (indexed) 
```

**Helper Methods:**
- `onboarding_step_title()` - Get display name for current step
- `advance_onboarding_step!()` - Increment step and complete if at max
- `onboarding_progress_percentage()` - Returns 0-100 progress %
- `needs_onboarding?()` - Check if user in onboarding-eligible state
- `admin_for?(website)` - Check if owner/admin for website

### 2.2 Site Admin Onboarding Controller (`app/controllers/site_admin/onboarding_controller.rb`)

**Purpose:** 5-step guided setup wizard for new website owners

**Steps:**
1. **Welcome** - Introduction and expectations
2. **Profile** - Agency/company details (display_name, email, phone, company_name)
3. **Property** - Add first listing (optional, can skip)
4. **Theme** - Choose theme and basic customization
5. **Complete** - Summary and next steps

**Actions:**
- `show(step)` - Display current step
- `update(step)` - Save step data and advance
- `skip_step(step)` - Skip step 3 (properties only)
- `complete()` - Final screen after step 5
- `restart()` - Reset to step 1

**Step Data Models:**
- Step 2: `Pwb::Agency` with fields (display_name, email_primary, phone_number_primary, company_name)
- Step 3: `Pwb::RealtyAsset` + `Pwb::SaleListing` or `Pwb::RentalListing`
- Step 4: `Website.theme_name` update

**Key Implementation Details:**
- Skip `require_admin!` for onboarding pages (allow guests to progress)
- Calls `complete_onboarding!()` on step 5 which:
  - Sets `site_admin_onboarding_completed_at = Time.current`
  - Sets `onboarding_step = MAX_STEP` (5)
  - Calls `activate!()` if user state machine allows
- Redirect to dashboard if completed and no explicit step param

### 2.3 SiteAdminOnboarding Concern (`app/controllers/concerns/site_admin_onboarding.rb`)

**Purpose:** Automatic redirect to onboarding wizard for new website owners

**Before Action:** `redirect_to_onboarding_if_needed`

**Triggers onboarding redirect if:**
1. User is signed in
2. User is NOT currently on onboarding pages
3. Request is NOT JSON/API
4. User HASN'T completed `site_admin_onboarding_completed_at`
5. User needs onboarding (has owner/admin role and website < 30 days old)

**Helper Methods:**
- `onboarding_complete?()` - Check if `site_admin_onboarding_completed_at` present
- `onboarding_progress()` - Get 0-100 percentage

---

## 3. Database Fields for Onboarding State Tracking

### 3.1 User Model (`pwb_users` table)

**Signup Flow Tracking:**
```sql
onboarding_state              -- ENUM: lead, registered, email_verified, onboarding, active, churned
onboarding_step               -- INTEGER: current step (1-4)
onboarding_started_at         -- DATETIME: when user started signup
onboarding_completed_at       -- DATETIME: when user completed signup
site_admin_onboarding_completed_at -- DATETIME: when site setup wizard completed
```

**Indexes:**
- `index_pwb_users_on_onboarding_state`
- `index_pwb_users_on_site_admin_onboarding_completed_at`

### 3.2 Website Model (`pwb_websites` table)

**Provisioning State Tracking:**
```sql
provisioning_state                -- ENUM: pending, owner_assigned, agency_created, 
                                     links_created, field_keys_created, 
                                     properties_seeded, ready, 
                                     locked_pending_email_verification,
                                     locked_pending_registration, live, 
                                     failed, suspended, terminated
provisioning_started_at           -- DATETIME
provisioning_completed_at         -- DATETIME: when fully provisioned
provisioning_error                -- TEXT: error message if failed
provisioning_failed_at            -- DATETIME

seed_pack_name                    -- VARCHAR: which pack was used (e.g., 'base', 'spain_luxury')
site_type                         -- VARCHAR: 'residential', 'commercial', 'vacation_rental'
owner_email                       -- VARCHAR: owner's email for verification
email_verification_token          -- VARCHAR: unique token for email verification
email_verification_token_expires_at -- DATETIME
email_verified_at                 -- DATETIME: when owner verified email
```

**Indexes:**
- `index_pwb_websites_on_provisioning_state`
- `index_pwb_websites_on_site_type`
- `index_pwb_websites_on_email_verification_token`

### 3.3 User Membership Model (`pwb_user_memberships` table)

**Multi-website Support:**
```sql
user_id
website_id
role                       -- 'owner', 'admin', 'member', 'agent'
active                     -- BOOLEAN: whether membership is active
created_at
updated_at
```

---

## 4. Admin User Creation During Seeding

### 4.1 Seed Pack User Creation (`lib/pwb/seed_pack.rb` lines 591-630)

**From `seed_users()` method:**

```ruby
def seed_users
  users = users_config  # Get from pack.yml :users section
  
  users.each do |user_data|
    existing = Pwb::User.find_by(email: user_data[:email])
    
    user = existing || Pwb::User.new(
      email: user_data[:email],
      password: user_data[:password] || 'password123',
      password_confirmation: user_data[:password] || 'password123',
      website_id: @website.id,
      admin: user_data[:role] == 'admin'  # Set admin flag
    ).save!
    
    # Create membership with role
    role = user_data[:role] || 'member'
    membership_role = case role
                      when 'admin', 'owner' then role
                      when 'agent' then 'member'
                      else 'member'
                      end
    
    Pwb::UserMembership.find_or_create_by!(user: user, website: @website) do |m|
      m.role = membership_role
      m.active = true
    end
  end
end
```

**Pack.yml Configuration:**
```yaml
users:
  - email: "owner@mysite.com"
    password: "SecureTemp123!"
    role: "owner"
  - email: "admin@mysite.com"
    password: "SecureTemp123!"
    role: "admin"
  - email: "agent@mysite.com"
    password: "SecureTemp123!"
    role: "agent"
```

### 4.2 SeedRunner User Creation (`lib/pwb/seed_runner.rb` lines 333-370)

**From `seed_users()` method:**

```ruby
def seed_users
  users_yml = load_seed_yml("users.yml")
  
  users_yml.each do |user_data|
    email = user_data["email"]
    existing = Pwb::User.find_by(email: email)
    
    user = existing || Pwb::User.create!(
      user_data.merge(website_id: website.id)
    )
    
    # Create membership
    role = user_data["role"] || (user_data["admin"] ? "admin" : "member")
    membership_role = case role.to_s
                      when "admin", "owner" then role.to_s
                      when "agent" then "member"
                      else "member"
                      end
    
    Pwb::UserMembership.find_or_create_by!(user: user, website: website) do |m|
      m.role = membership_role
      m.active = true
    end
  end
end
```

**Yml File Structure (`db/yml_seeds/users.yml`):**
```yaml
- email: "owner@example.com"
  password_digest: "..."  # Optional
  role: "owner"
  admin: true
- email: "admin@example.com"
  password_digest: "..."
  role: "admin"
  admin: true
```

### 4.3 ProvisioningService Admin Creation

**During provisioning, NO users are created automatically.**

The service expects:
1. Owner user already exists (created in `start_signup()`)
2. Membership already exists (created in `configure_site()`)

Users from seed packs are only created during `seed_users()` step, which happens when called explicitly.

---

## 5. Pwb::ProvisioningService Details

### 5.1 Full Flow Breakdown

**Entry Point Chain:**
```
start_signup()           ← Email capture
    ↓
verify_email()           ← Email verification click
    ↓
configure_site()         ← Subdomain + site type selection
    ↓
provision_website()      ← Full provisioning with 11-step state machine
```

### 5.2 Granular Provisioning Implementation

Each provisioning step (in `provision_website()` method):

```ruby
# Step 1: Create agency
create_agency_for_website(website)
website.complete_agency!  # Guard: has_agency?

# Step 2: Create links
create_links_for_website(website)
website.complete_links!   # Guard: has_links? (>= 3)

# Step 3: Create field keys
create_field_keys_for_website(website)
website.complete_field_keys!  # Guard: has_field_keys? (>= 5)

# Step 4: Create pages
create_pages_for_website(website)

# Step 5: Seed properties (optional)
if skip_properties
  website.skip_properties!
else
  seed_properties_for_website(website)
  website.seed_properties!
end

# Step 6: Verify complete
website.mark_ready!       # Guard: provisioning_complete?

# Step 7: Enter locked state
website.enter_locked_state!  # Guard: can_go_live?

# Step 8: Send verification email
send_verification_email(website)
```

### 5.3 Seed Pack Integration Strategy

Service has `try_seed_pack_step(website, step)` method:

```ruby
def try_seed_pack_step(website, step)
  pack_name = website.seed_pack_name || 'base'
  
  begin
    seed_pack = Pwb::SeedPack.find(pack_name)
    
    case step
    when :agency
      seed_pack.seed_agency!(website: website)
      return website.agency.present?  # Verify
    when :links
      seed_pack.seed_links!(website: website)
      return website.links.count >= 3
    when :field_keys
      seed_pack.seed_field_keys!(website: website)
      return website.field_keys.count >= 5
    when :pages
      seed_pack.seed_pages!(website: website)
      seed_pack.seed_page_parts!(website: website)
      return website.pages.count >= 1
    when :properties
      seed_pack.seed_properties!(website: website)
      properties_dir = Rails.root.join('db', 'seeds', 'packs', pack_name, 'properties')
      return properties_dir.exist? && Dir.glob(properties_dir.join('*.yml')).any?
    end
  rescue Pwb::SeedPack::PackNotFoundError
    # Use fallback
  rescue StandardError => e
    Rails.logger.warn("[Provisioning] SeedPack step failed: #{e.message}")
  end
  
  false  # Fallback to default
end
```

**If seed pack returns true (handled it), provisioning uses that data.**  
**If returns false (pack missing or error), provisioning creates minimal defaults.**

---

## 6. Recommendations for Onboarding State Tracking

### 6.1 Website-Level Onboarding State

**Recommendation:** Add to `Website` model if not present

```ruby
# In migration:
add_column :pwb_websites, :onboarding_state, :string, 
  null: false, default: 'provisioning'  # provisioning, setup_wizard, live
add_column :pwb_websites, :onboarding_step, :integer, default: 0
add_column :pwb_websites, :onboarding_completed_at, :datetime
add_index :pwb_websites, :onboarding_state
```

**AASM State Machine:**
```ruby
aasm column: :onboarding_state do
  state :provisioning, initial: true  # While website is being provisioned
  state :setup_wizard                  # Awaiting owner to complete setup
  state :live                          # Fully onboarded
  
  event :complete_provisioning do
    transitions from: :provisioning, to: :setup_wizard
  end
  
  event :complete_onboarding do
    transitions from: :setup_wizard, to: :live
    after do
      update!(onboarding_completed_at: Time.current)
    end
  end
end
```

### 6.2 Separate Concerns

**User Onboarding** = Signup flow completion (email verification, password, account setup)  
**Site Admin Onboarding** = Website setup wizard (theme, agency, first property)  
**Website Provisioning** = System-level setup (seeding, configuration)

These should remain separate but coordinated:

```
User signup flow    → User.onboarding_state
Site setup wizard   → User.site_admin_onboarding_completed_at
Website provisioning→ Website.provisioning_state
```

### 6.3 Querying Onboarded vs Pending Users

```ruby
# Users who need site admin setup (completed signup but not site setup)
User.where(onboarding_state: 'active')
     .where(site_admin_onboarding_completed_at: nil)
     .where('created_at > ?', 7.days.ago)

# Websites ready for first login
Website.where(provisioning_state: 'live')
        .where(onboarding_state: 'setup_wizard')
        
# Fully onboarded sites
Website.where(onboarding_state: 'live')
```

### 6.4 Admin Dashboard Queries

```ruby
# Signup funnel
leads_count = User.where(onboarding_state: 'lead').count
registered_count = User.where(onboarding_state: 'registered').count
active_count = User.where(onboarding_state: 'active').count
site_setup_pending = User.where(onboarding_state: 'active',
                                site_admin_onboarding_completed_at: nil).count

# Provisioning pipeline
pending_websites = Website.pending.count
failed_websites = Website.failed.count
live_websites = Website.live.count

# Time to onboarding completion
avg_time_to_active = User.where('onboarding_completed_at IS NOT NULL')
  .average("EXTRACT(EPOCH FROM (onboarding_completed_at - onboarding_started_at))")
  .to_i.minutes

avg_time_to_site_setup = User.where('site_admin_onboarding_completed_at IS NOT NULL')
  .average("EXTRACT(EPOCH FROM (site_admin_onboarding_completed_at - created_at))")
  .to_i.minutes
```

---

## 7. Key Files Reference

| File | Purpose |
|------|---------|
| `lib/pwb/seed_pack.rb` | Core seed pack system - 850+ lines |
| `lib/pwb/seed_runner.rb` | Enhanced seeding orchestrator - 550+ lines |
| `app/services/pwb/provisioning_service.rb` | Provisioning workflow - 560+ lines |
| `app/models/pwb/user.rb` | User with AASM state machine - 320+ lines |
| `app/controllers/site_admin/onboarding_controller.rb` | 5-step wizard - 230+ lines |
| `app/controllers/concerns/site_admin_onboarding.rb` | Auto-redirect concern - 100 lines |
| `app/models/concerns/pwb/website_provisionable.rb` | Website state machine - 200+ lines |
| `db/migrate/20251209122403_add_onboarding_state_to_users.rb` | User onboarding columns |
| `db/migrate/20251216200000_add_site_admin_onboarding_to_users.rb` | Site admin tracking |
| `db/migrate/20251209122349_add_provisioning_state_to_websites.rb` | Website provisioning columns |

---

## 8. Testing Resources

**Test Files:**
- `spec/models/pwb/user_onboarding_spec.rb` - User state machine tests
- `spec/controllers/site_admin/onboarding_controller_spec.rb` - Wizard tests
- `spec/services/pwb/provisioning_service_spec.rb` - Provisioning tests
- `spec/services/pwb/provisioning_seeding_spec.rb` - Seeding integration tests
- `spec/lib/pwb/seed_pack_spec.rb` - Seed pack tests
- `spec/lib/pwb/seed_runner_spec.rb` - SeedRunner tests

**Factories:**
- `spec/factories/pwb_users.rb` - User factory with state options

---

## 9. Integration Points

### 9.1 How It All Works Together

```
1. User signs up (Devise)
   ↓
2. ProvisioningService.start_signup()
   Creates: User (state: lead)
   
3. User verifies email
   ↓
4. ProvisioningService.configure_site()
   Updates: User (state: email_verified → onboarding)
   Creates: Website (state: pending)
           UserMembership (role: owner)
   
5. ProvisioningService.provision_website()
   Updates: Website states (pending → ... → live)
   Seeds: Agency, field keys, pages, properties (via seed pack)
   
6. User visits admin dashboard
   SiteAdminOnboarding concern triggers
   Redirects to onboarding_controller
   
7. User completes 5-step wizard
   Updates: User (state: active, site_admin_onboarding_completed_at: now)
           Website (onboarding_state: live)
   
8. User sees fully provisioned website
```

### 9.2 Data Flow Diagram

```
User Signup Flow          Website Provisioning       Site Setup Wizard
─────────────────        ────────────────────       ──────────────────

Email provided
    ↓
start_signup()            Website created (pending)
User: lead                Subdomain reserved
    ↓
verify_email()
User: registered
    ↓
email verified link
    ↓
configure_site()          Website: pending → owner_assigned → ... → live
User: onboarding          
Membership: owner
    ↓
provision_website()       Seed pack applied
(background job)          Agency created
                         Links created
                         Field keys seeded
                         Pages created
                         Properties seeded
    ↓                     
Website live              User redirected to wizard
                         ↓
                         Step 1-5 completion
                         User: active
                         site_admin_onboarding_completed_at set
                         ↓
                         Dashboard access granted
```

---

## 10. Conclusion

PropertyWebBuilder has:

1. **Robust signup flow** with user state tracking (lead → active)
2. **Comprehensive provisioning** with granular state machine ensuring data integrity
3. **Flexible seeding** via packs that can be tailored per scenario
4. **5-step site setup wizard** for owner configuration post-provisioning
5. **Automatic onboarding redirect** that keeps new owners on the setup flow
6. **Well-indexed database** for efficient onboarding status queries

The system is production-ready and well-documented through code comments. Future enhancements could include:
- Website-level onboarding state machine (separate from provisioning)
- Onboarding analytics dashboard
- Progress persistence across sessions
- Email reminders for incomplete onboarding
- A/B testing of different onboarding flows
