# PropertyWebBuilder Onboarding & Seeding - Quick Reference

## At a Glance

### Two Onboarding Flows

**1. User Signup Onboarding** (User state)
- States: lead → registered → email_verified → onboarding → active
- Tracked in: `User.onboarding_state`, `User.onboarding_step`
- Completed when: `User.onboarding_completed_at` set
- Duration: Email verification + signup flow

**2. Site Admin Onboarding** (Setup wizard)
- 5 Steps: Welcome → Profile → Property → Theme → Complete
- Tracked in: `User.site_admin_onboarding_completed_at`
- Completed when: User finishes step 5
- Duration: Few minutes to set up site

### Website Provisioning States

```
pending → owner_assigned → agency_created → links_created → 
field_keys_created → properties_seeded → ready → 
locked_pending_email_verification → locked_pending_registration → live
```

Tracked in: `Website.provisioning_state`

---

## Seeding Systems

### SeedPack (Scenario-Based)
```ruby
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```
- Pre-configured bundles in `/db/seeds/packs/{name}/`
- Include: agency, field keys, properties, pages, users, translations
- Supports inheritance

### SeedRunner (File-Based)
```ruby
Pwb::SeedRunner.run(website: website, mode: :create_only)
```
- Loads from `/db/yml_seeds/`
- Modes: interactive, create_only, force_update, upsert
- Has dry-run support

### ProvisioningService (Workflow)
```ruby
service = Pwb::ProvisioningService.new
result = service.start_signup(email: "user@example.com")
result = service.configure_site(user: user, subdomain_name: "my-site", site_type: "residential")
result = service.provision_website(website: website)
```
- Orchestrates entire signup → live flow
- 3 main steps: signup, configure, provision

---

## Key Database Fields

### User Model
```
onboarding_state                    -- ENUM: lead, registered, email_verified, onboarding, active, churned
onboarding_step                     -- INT: current step (1-4)
onboarding_started_at               -- TIMESTAMP
onboarding_completed_at             -- TIMESTAMP
site_admin_onboarding_completed_at  -- TIMESTAMP (site setup wizard)
```

### Website Model
```
provisioning_state                  -- ENUM: pending, owner_assigned, ..., live
provisioning_started_at             -- TIMESTAMP
provisioning_completed_at           -- TIMESTAMP
provisioning_error                  -- TEXT
seed_pack_name                      -- VARCHAR: which pack used
site_type                           -- VARCHAR: residential|commercial|vacation_rental
owner_email                         -- VARCHAR
email_verification_token            -- VARCHAR
email_verified_at                   -- TIMESTAMP
```

---

## Important Methods

### User Model
```ruby
user.onboarding_state                     -- Current state
user.onboarding_step_title                -- Get display name
user.advance_onboarding_step!             -- Increment step
user.onboarding_progress_percentage       -- 0-100
user.needs_onboarding?                    -- Check if eligible
user.admin_for?(website)                  -- Check if owner/admin
user.can_access_website?(website)         -- Check membership

# State machine events:
user.register!                            -- lead → registered
user.verify_email!                        -- registered → email_verified  
user.start_onboarding!                    -- email_verified → onboarding
user.complete_onboarding!                 -- onboarding → active
user.activate!                            -- any → active (direct)
user.mark_churned!                        -- any → churned
user.reactivate!                          -- churned → lead
```

### Website Model
```ruby
website.provisioning_state                -- Current state
website.seed_pack_name                    -- Which pack used
website.provisioning_complete?            -- All required items present?
website.has_owner?                        -- Owner membership exists?
website.has_agency?                       -- Agency record exists?
website.has_links?                        -- >= 3 links exist?
website.has_field_keys?                   -- >= 5 field keys exist?
website.can_go_live?                      -- Ready for live state?

# State machine events:
website.assign_owner!                     -- pending → owner_assigned
website.complete_agency!                  -- owner_assigned → agency_created
website.complete_links!                   -- agency_created → links_created
website.complete_field_keys!              -- links_created → field_keys_created
website.seed_properties!                  -- field_keys_created → properties_seeded
website.skip_properties!                  -- field_keys_created → properties_seeded (no data)
website.mark_ready!                       -- properties_seeded → ready
website.enter_locked_state!               -- ready → locked_pending_email_verification
website.verify_owner_email!               -- locked_pending_email_verification → locked_pending_registration
website.go_live!                          -- locked_pending_registration → live
```

### SeedPack
```ruby
Pwb::SeedPack.available                   -- List all packs
Pwb::SeedPack.find('name')                -- Load specific pack
pack.apply!(website: w)                   -- Apply to website
pack.preview                              -- What would be created
pack.seed_agency!(website: w)             -- Individual step
pack.seed_properties!(website: w)         -- Individual step
```

### ProvisioningService
```ruby
service = Pwb::ProvisioningService.new
service.start_signup(email: "user@example.com")
service.verify_email(user: user, token: token)
service.configure_site(user: user, subdomain_name: "site", site_type: "residential")
service.provision_website(website: website)
service.errors                            -- Array of error messages
```

---

## Query Examples

### Find Users Needing Site Setup
```ruby
User.where(onboarding_state: 'active')
    .where(site_admin_onboarding_completed_at: nil)
    .where('created_at > ?', 7.days.ago)
```

### Find Failed Provisioning
```ruby
Website.where(provisioning_state: 'failed')
```

### Get Signup Funnel
```ruby
User.where(onboarding_state: 'lead').count           # Email captured
User.where(onboarding_state: 'registered').count     # Account created
User.where(onboarding_state: 'active').count         # Email verified
User.where(onboarding_state: 'active',
           site_admin_onboarding_completed_at: nil).count  # Pending site setup
```

### Get Provisioning Stats
```ruby
Website.where(provisioning_state: 'live').count      # Live
Website.where(provisioning_state: 'pending').count   # Not started
Website.where(provisioning_state: 'failed').count    # Failed
Website.where('provisioning_started_at IS NOT NULL').average(
  "EXTRACT(EPOCH FROM (provisioning_completed_at - provisioning_started_at))"
).to_i.minutes                                        # Avg provisioning time
```

---

## File Locations

```
lib/pwb/
  ├── seed_pack.rb                    # Seed pack system
  ├── seed_runner.rb                  # Enhanced seeding
  ├── seeder.rb                       # Legacy seeder
  ├── pages_seeder.rb                 # Page seeding
  └── contents_seeder.rb              # Content seeding

app/services/pwb/
  └── provisioning_service.rb         # Provisioning workflow

app/models/pwb/
  ├── user.rb                         # User with AASM
  └── website.rb                      # Website with provisioning

app/models/concerns/pwb/
  └── website_provisionable.rb        # Website state machine

app/controllers/site_admin/
  └── onboarding_controller.rb        # 5-step wizard

app/controllers/concerns/
  └── site_admin_onboarding.rb        # Auto-redirect concern

db/seeds/
  └── packs/                          # Seed pack definitions
     ├── base/                        # Base/default pack
     └── {custom_pack}/
        ├── pack.yml
        ├── agency.yml
        ├── field_keys.yml
        ├── pages/
        ├── properties/
        └── ...

db/yml_seeds/                         # Legacy seed files
  ├── agency.yml
  ├── field_keys.yml
  ├── users.yml
  ├── prop/
  └── ...

db/migrate/
  ├── 20251209122403_add_onboarding_state_to_users.rb
  ├── 20251216200000_add_site_admin_onboarding_to_users.rb
  └── 20251209122349_add_provisioning_state_to_websites.rb
```

---

## Common Workflows

### Onboard a User Completely
```ruby
# 1. User signs up
service = Pwb::ProvisioningService.new
result = service.start_signup(email: "owner@example.com")
user = result[:user]

# 2. Email verification (in real flow, user clicks link)
service.verify_email(user: user, token: token)

# 3. Configure site
result = service.configure_site(
  user: user,
  subdomain_name: "my-agency",
  site_type: "residential"
)
website = result[:website]

# 4. Provision website (background job)
service.provision_website(website: website)

# 5. User completes setup wizard (through browser)
# OnboardingController handles this automatically

# 6. Check status
user.reload
user.site_admin_onboarding_completed_at.present?  # => true
website.provisioning_state                        # => "live"
```

### Apply Seed Pack to New Website
```ruby
website = Pwb::Website.create!(subdomain: 'test', theme_name: 'bristol')
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)

# Or with options:
pack.apply!(
  website: website,
  options: {
    skip_properties: false,
    dry_run: false,
    verbose: true
  }
)
```

### Check Onboarding Progress
```ruby
user = Pwb::User.find(1)

# Signup flow progress
user.onboarding_state                       # "active"
user.onboarding_progress_percentage         # 100
user.onboarding_completed_at                # <timestamp>

# Site setup wizard progress
user.site_admin_onboarding_completed_at     # nil if not done, timestamp if done

# Website provisioning progress
website = user.website
website.provisioning_state                  # "live", "pending", etc.
website.provisioning_completed_at           # timestamp when done
```

---

## Troubleshooting

### User stuck in onboarding state
```ruby
user = Pwb::User.find(1)
user.onboarding_state  # => "onboarding"

# Manually activate if needed:
user.activate!
user.site_admin_onboarding_completed_at = Time.current
user.save!
```

### Website stuck in provisioning
```ruby
website = Pwb::Website.find(1)
website.provisioning_state  # => "pending"

# Check what's missing:
website.provisioning_complete?      # false
website.provisioning_missing_items  # array of missing items

# Reset and retry:
service = Pwb::ProvisioningService.new
service.provision_website(website: website)
```

### Reseed a website
```ruby
website = Pwb::Website.find(1)
pack = Pwb::SeedPack.find(website.seed_pack_name)

# Delete existing data (careful!)
website.agency.destroy if website.agency
website.field_keys.destroy_all
website.links.destroy_all

# Re-apply pack
pack.apply!(website: website)
```

---

## State Machine Diagrams

### User Onboarding States
```
                    ┌─────────────┐
                    │    lead     │  (initial)
                    └──────┬──────┘
                           │ register()
                           ▼
                    ┌─────────────┐
                    │ registered  │
                    └──────┬──────┘
                           │ verify_email()
                           ▼
                    ┌─────────────────┐
                    │ email_verified  │
                    └──────┬──────────┘
         ┌────────────────┤
         │                │ start_onboarding()
    activate()            ▼
         │          ┌──────────────┐
         │          │ onboarding   │
         │          └──────┬───────┘
         │                 │ complete_onboarding()
         └────────────────►├──────────────────┐
                           ▼                  ▼
                    ┌──────────────┐   ┌───────────┐
                    │    active    │   │  churned  │
                    └──────────────┘   └─────┬─────┘
                                             │ reactivate()
                                             ▼ (→lead)
```

### Website Provisioning States
```
    pending
      │ assign_owner() [has_owner?]
      ▼
  owner_assigned
      │ complete_agency() [has_agency?]
      ▼
  agency_created
      │ complete_links() [has_links? >= 3]
      ▼
  links_created
      │ complete_field_keys() [has_field_keys? >= 5]
      ▼
  field_keys_created
      │ seed_properties() OR skip_properties()
      ▼
  properties_seeded
      │ mark_ready() [provisioning_complete?]
      ▼
  ready
      │ enter_locked_state() [can_go_live?]
      ▼
  locked_pending_email_verification
      │ verify_owner_email()
      ▼
  locked_pending_registration
      │ go_live()
      ▼
  live
  
Failed state reachable from: any (fail_provisioning())
Suspended/Terminated: manual states
```

---

## Performance Considerations

- **Indexes:** Both state columns are indexed for fast queries
- **Seed Pack Inheritance:** Parent packs applied first, then child
- **Materialized View:** Properties materialized view refreshed after seeding
- **Background Jobs:** Provisioning should be async (respects `skip_properties` to reduce time)
- **State Transitions:** Guards prevent invalid transitions, logged for audit

---

## Testing

Key test files:
- `spec/models/pwb/user_onboarding_spec.rb`
- `spec/controllers/site_admin/onboarding_controller_spec.rb`
- `spec/services/pwb/provisioning_service_spec.rb`
- `spec/services/pwb/provisioning_seeding_spec.rb`
- `spec/lib/pwb/seed_pack_spec.rb`

Test with factories: `spec/factories/pwb_users.rb`
