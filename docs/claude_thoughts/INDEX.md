# PropertyWebBuilder Onboarding & Seeding Research - Complete Index

This directory contains comprehensive research and documentation about PropertyWebBuilder's onboarding and seeding systems.

## Documents

### 1. ONBOARDING_SEEDING_RESEARCH.md (26 KB)
**Comprehensive technical deep dive** - Read this first for complete understanding

Contains:
- Executive summary
- Seeding architecture (SeedPack, SeedRunner, ProvisioningService)
- Existing onboarding flags and AASM state machines
- User and Website database fields/columns
- How admin users are created during seeding
- ProvisioningService detailed implementation
- Recommendations for onboarding state tracking
- Key file references
- Testing resources and integration points

**Best for:** Understanding the full system architecture, implementation details, and design decisions

### 2. QUICK_REFERENCE.md (14 KB)
**Practical quick lookup guide** - Reference this while coding

Contains:
- At-a-glance summaries of both onboarding flows
- Seed system comparisons
- Database field checklists
- Important method reference (User, Website, SeedPack, ProvisioningService)
- Common query examples
- File location map
- Common workflows (step-by-step)
- Troubleshooting guides
- State machine diagrams
- Performance considerations

**Best for:** Quick lookups, method signatures, example queries, troubleshooting

### 3. ARCHITECTURE_DIAGRAM.md (43 KB)
**Visual architecture representations** - Study these for understanding flow

Contains:
- High-level signup flow diagram
- Detailed provisioning workflow (11-step state machine)
- Seeding architecture breakdown (Pack, Runner, Service)
- User state machine visualization
- Website state machine visualization
- Complete data flow integration diagram
- OnboardingController 5-step wizard flow
- Summary of design principles

**Best for:** Understanding relationships between components, visualizing workflows, onboarding others

---

## Quick Navigation by Use Case

### I want to understand the complete system
1. Read: ONBOARDING_SEEDING_RESEARCH.md (Sections 1-5)
2. Study: ARCHITECTURE_DIAGRAM.md
3. Reference: QUICK_REFERENCE.md

### I need to implement a feature
1. Check: QUICK_REFERENCE.md for relevant methods
2. Read: ONBOARDING_SEEDING_RESEARCH.md (relevant section)
3. Look up: File locations in QUICK_REFERENCE.md
4. Code: Using the method signatures provided

### I need to debug an issue
1. Check: QUICK_REFERENCE.md troubleshooting section
2. Run: Query examples from QUICK_REFERENCE.md
3. Reference: ONBOARDING_SEEDING_RESEARCH.md (Section 8 - Key Files)
4. Trace: Using ARCHITECTURE_DIAGRAM.md flow diagrams

### I need to onboard someone new
1. Show: ARCHITECTURE_DIAGRAM.md (High-level overview)
2. Explain: ONBOARDING_SEEDING_RESEARCH.md (Section 1 - Executive Summary)
3. Drill down: QUICK_REFERENCE.md method reference
4. Deep dive: Individual file reading from ONBOARDING_SEEDING_RESEARCH.md (Section 8)

### I need to create a seed pack
1. Read: ONBOARDING_SEEDING_RESEARCH.md (Section 1.1 - Seed Pack System)
2. Reference: QUICK_REFERENCE.md (SeedPack section)
3. Check: File structure in QUICK_REFERENCE.md
4. See: Example pack.yml format in ONBOARDING_SEEDING_RESEARCH.md

---

## Key Concepts Summary

### Two-Layer Onboarding

**1. User Signup Flow** (Pwb::User state machine)
- Database field: `onboarding_state`
- States: lead → registered → email_verified → onboarding → active
- Used for: Tracking user account creation and email verification
- Duration: 5-15 minutes
- Completion flag: `onboarding_completed_at`

**2. Site Admin Onboarding** (OnboardingController 5-step wizard)
- Database field: `site_admin_onboarding_completed_at`
- Steps: Welcome → Profile → Property → Theme → Complete
- Used for: Guiding new website owners through setup
- Duration: 2-10 minutes
- Auto-triggered: By SiteAdminOnboarding concern before_action

### Three Seeding Systems

**1. SeedPack** (Scenario-based)
- Purpose: Pre-configured bundles for specific use cases
- Location: `/db/seeds/packs/{name}/`
- Features: Inheritance, hierarchical structure, comprehensive data
- Best for: New environments, specific scenarios

**2. SeedRunner** (File-based)
- Purpose: Enhanced seeding with safety features
- Location: `/db/yml_seeds/`
- Features: Dry-run, interactive mode, statistics
- Best for: Manual seeding, existing data updates

**3. ProvisioningService** (Workflow)
- Purpose: Orchestrates complete signup → live flow
- Method: `provision_website(website:)` with 11-state machine
- Features: Progress callbacks, granular guards, fallback defaults
- Best for: Automated provisioning during signup

### Website Provisioning States

11-state progression with guards ensuring each step completes:
```
pending → owner_assigned → agency_created → links_created → 
field_keys_created → properties_seeded → ready → 
locked_pending_email_verification → locked_pending_registration → live
```

Each transition requires a guard to verify data completeness.

---

## Database Schema Quick Reference

### User Model (pwb_users)
```
onboarding_state (STRING)                   -- ENUM: lead, registered, email_verified, onboarding, active, churned
onboarding_step (INTEGER)                   -- Current step (1-4)
onboarding_started_at (DATETIME)            -- When signup started
onboarding_completed_at (DATETIME)          -- When signup completed
site_admin_onboarding_completed_at (DATETIME)  -- When site setup wizard completed
```

**Indexes:** onboarding_state, site_admin_onboarding_completed_at

### Website Model (pwb_websites)
```
provisioning_state (STRING)                 -- ENUM: pending, owner_assigned, agency_created, ...
provisioning_started_at (DATETIME)          -- When provisioning started
provisioning_completed_at (DATETIME)        -- When provisioning finished
provisioning_error (TEXT)                   -- Error message if failed
seed_pack_name (VARCHAR)                    -- Which seed pack was used
site_type (VARCHAR)                         -- residential, commercial, vacation_rental
owner_email (VARCHAR)                       -- Owner's email for verification
email_verification_token (VARCHAR)          -- Token for email verification
email_verified_at (DATETIME)                -- When owner verified email
```

**Indexes:** provisioning_state, site_type, email_verification_token

---

## File Map

| Path | Purpose | Key Classes |
|------|---------|------------|
| `lib/pwb/seed_pack.rb` | Seed pack system (850+ lines) | `Pwb::SeedPack` |
| `lib/pwb/seed_runner.rb` | Enhanced seeding orchestrator (550+ lines) | `Pwb::SeedRunner` |
| `app/services/pwb/provisioning_service.rb` | Provisioning workflow (560+ lines) | `Pwb::ProvisioningService` |
| `app/models/pwb/user.rb` | User with AASM (320+ lines) | `Pwb::User` |
| `app/models/pwb/website.rb` | Website model | `Pwb::Website` |
| `app/models/concerns/pwb/website_provisionable.rb` | Website state machine (200+ lines) | `Pwb::WebsiteProvisionable` |
| `app/controllers/site_admin/onboarding_controller.rb` | 5-step wizard (230+ lines) | `SiteAdmin::OnboardingController` |
| `app/controllers/concerns/site_admin_onboarding.rb` | Auto-redirect concern (100 lines) | `SiteAdminOnboarding` |
| `db/seeds/packs/` | Seed pack definitions | YAML files |
| `db/yml_seeds/` | Legacy seed files | YAML files |

---

## Key Methods by Component

### Pwb::User (AASM Events)
- `register!()` - lead → registered
- `verify_email!()` - registered → email_verified
- `start_onboarding!()` - email_verified → onboarding
- `complete_onboarding!()` - onboarding → active
- `activate!()` - any → active (direct)
- `mark_churned!()` - any → churned
- `reactivate!()` - churned → lead

### Pwb::Website (AASM Events)
- `assign_owner!()` - pending → owner_assigned
- `complete_agency!()` - owner_assigned → agency_created
- `complete_links!()` - agency_created → links_created
- `complete_field_keys!()` - links_created → field_keys_created
- `seed_properties!()` - field_keys_created → properties_seeded
- `skip_properties!()` - field_keys_created → properties_seeded
- `mark_ready!()` - properties_seeded → ready
- `enter_locked_state!()` - ready → locked_pending_email_verification
- `verify_owner_email!()` - locked_pending_email_verification → locked_pending_registration
- `go_live!()` - locked_pending_registration → live

### Pwb::ProvisioningService (Main Methods)
- `start_signup(email:)` - Create user and reserve subdomain
- `verify_email(user:, token:)` - Mark email verified
- `configure_site(user:, subdomain_name:, site_type:)` - Create website and membership
- `provision_website(website:, skip_properties: false)` - Full 11-step provisioning

### Pwb::SeedPack (Main Methods)
- `find(name)` - Load a seed pack
- `available()` - List all available packs
- `apply!(website:, options:)` - Apply pack to website
- `preview()` - What would be created

### Pwb::SeedRunner (Main Method)
- `run(website:, mode:, ...)` - Run seeding

---

## Testing

Test files for this system:
- `spec/models/pwb/user_onboarding_spec.rb` - User state machine tests
- `spec/controllers/site_admin/onboarding_controller_spec.rb` - Wizard tests
- `spec/services/pwb/provisioning_service_spec.rb` - Service tests
- `spec/services/pwb/provisioning_seeding_spec.rb` - Seeding integration
- `spec/lib/pwb/seed_pack_spec.rb` - Seed pack tests
- `spec/lib/pwb/seed_runner_spec.rb` - SeedRunner tests

Factory: `spec/factories/pwb_users.rb`

---

## Related Documentation

Also see:
- `CLAUDE.md` - Project-wide Claude instructions
- `docs/architecture/` - Architecture decisions
- `docs/deployment/` - Deployment guides
- `docs/multi_tenancy/` - Multi-tenancy documentation

---

## Document Metadata

- **Research Date:** December 27, 2025
- **Version:** 1.0
- **Codebase Version:** Main development branch (develop)
- **System:** PropertyWebBuilder Rails 8.1 multi-tenant SaaS
- **Status:** Current and accurate as of Dec 27, 2025

---

## How to Use These Documents

1. **First time?** Start with ONBOARDING_SEEDING_RESEARCH.md Section 1 (Executive Summary)
2. **Implementing?** Use QUICK_REFERENCE.md method lookups + ONBOARDING_SEEDING_RESEARCH.md details
3. **Explaining to others?** Show ARCHITECTURE_DIAGRAM.md diagrams
4. **Deep debugging?** Cross-reference all three documents

Each document stands alone but complements the others for a complete picture of the system.

---

## Contributing

When updating this documentation:
1. Keep ONBOARDING_SEEDING_RESEARCH.md as the authoritative source
2. Update QUICK_REFERENCE.md for method signature changes
3. Update ARCHITECTURE_DIAGRAM.md for flow changes
4. Run tests to verify behavior matches documentation
5. Check both user state machine and website state machine consistency

---

## Questions?

Refer to:
- **"How do I..."** → QUICK_REFERENCE.md (workflows section)
- **"What does... do?"** → ONBOARDING_SEEDING_RESEARCH.md or method signature in QUICK_REFERENCE.md
- **"How do ... work together?"** → ARCHITECTURE_DIAGRAM.md data flow diagrams
- **"Where is... located?"** → QUICK_REFERENCE.md (file map)
