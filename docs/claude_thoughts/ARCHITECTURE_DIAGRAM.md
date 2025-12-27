# PropertyWebBuilder Onboarding & Seeding Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SIGNUP FLOW                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. User signs up                                                    │
│     ↓                                                                │
│  2. ProvisioningService.start_signup()                              │
│     Creates: User (state: lead)                                     │
│     Reserves: Subdomain (10 min)                                    │
│     ↓                                                                │
│  3. Email verification link sent                                    │
│     User clicks link                                                │
│     ↓                                                                │
│  4. ProvisioningService.verify_email()                              │
│     User state: registered → email_verified                         │
│     ↓                                                                │
│  5. User selects subdomain + site type                              │
│     ↓                                                                │
│  6. ProvisioningService.configure_site()                            │
│     Creates: Website (state: pending)                               │
│     Creates: UserMembership (role: owner)                           │
│     Updates: User state → onboarding                                │
│     ↓                                                                │
│  7. ProvisioningService.provision_website() [ASYNC]                │
│     (See detailed diagram below)                                    │
│     ↓                                                                │
│  8. Website live, user redirected to admin dashboard                │
│     ↓                                                                │
│  9. SiteAdminOnboarding concern triggers (before_action)            │
│     Checks: User not completed site_admin_onboarding                │
│     Checks: Website provisioning_state == 'live'                    │
│     Redirects: to site_admin_onboarding_path                        │
│     ↓                                                                │
│ 10. OnboardingController (5-step wizard)                            │
│     Step 1: Welcome                                                 │
│     Step 2: Agency/Profile (Pwb::Agency)                           │
│     Step 3: First Property (optional)                               │
│     Step 4: Theme selection                                         │
│     Step 5: Complete                                                │
│     ↓                                                                │
│ 11. User.site_admin_onboarding_completed_at = now                  │
│     User state: active (via activate!)                              │
│     ↓                                                                │
│ 12. User has full access, wizard disappears                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Detailed Provisioning Workflow

```
┌──────────────────────────────────────────────────────────────────────┐
│                  PROVISION_WEBSITE WORKFLOW                           │
│              (Called by ProvisioningService.provision_website)        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Website state: pending (or owner_assigned)                          │
│  User: onboarding (with owner membership)                            │
│  ↓                                                                    │
│  ┌─ STEP 1: Create Agency ─────────────────────────┐                │
│  │  try_seed_pack_step(website, :agency)           │                │
│  │    ↓                                             │                │
│  │    IF seed pack returns true                    │                │
│  │      → Use pack's agency data                   │                │
│  │    ELSE                                         │                │
│  │      → Create minimal agency with subdomain.title │              │
│  │    ↓                                             │                │
│  │  website.complete_agency!                       │                │
│  │  Guard: has_agency? ✓                           │                │
│  │  State: pending → owner_assigned → agency_created │              │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 2: Create Navigation Links ──────────────┐                │
│  │  try_seed_pack_step(website, :links)            │                │
│  │    ↓                                             │                │
│  │    IF seed pack returns true (>= 3 links)      │                │
│  │      → Use pack's links                         │                │
│  │    ELSE                                         │                │
│  │      → Create 4 default links:                  │                │
│  │        - home, buy, rent, contact               │                │
│  │    ↓                                             │                │
│  │  website.complete_links!                        │                │
│  │  Guard: has_links? (>= 3) ✓                     │                │
│  │  State: agency_created → links_created          │                │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 3: Create Field Keys ────────────────────┐                │
│  │  try_seed_pack_step(website, :field_keys)       │                │
│  │    ↓                                             │                │
│  │    IF seed pack returns true (>= 5 keys)       │                │
│  │      → Use pack's field keys                    │                │
│  │    ELSE                                         │                │
│  │      → Create minimal field keys:               │                │
│  │        - types: house, apartment, villa         │                │
│  │        - states: good, new                      │                │
│  │        - features: pool, garage                 │                │
│  │    ↓                                             │                │
│  │  website.complete_field_keys!                   │                │
│  │  Guard: has_field_keys? (>= 5) ✓                │                │
│  │  State: links_created → field_keys_created      │                │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 4: Create Pages & Page Parts ────────────┐                │
│  │  try_seed_pack_step(website, :pages)            │                │
│  │    ↓                                             │                │
│  │    IF seed pack has pages/page_parts            │                │
│  │      → Create from pack                         │                │
│  │    ELSE                                         │                │
│  │      → Use PagesSeeder.seed_page_basics!        │                │
│  │      → PagesSeeder.seed_page_parts!             │                │
│  │    ↓                                             │                │
│  │  Seed content translations                      │                │
│  │  (Page part content like hero text)             │                │
│  │                                                 │                │
│  │  State: field_keys_created → (stays)            │                │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 5: Seed Properties (Optional) ───────────┐                │
│  │  IF skip_properties == true                     │                │
│  │    → website.skip_properties!                   │                │
│  │  ELSE                                           │                │
│  │    → try_seed_pack_step(website, :properties)   │                │
│  │    ↓                                             │                │
│  │    IF seed pack has properties                  │                │
│  │      → Load from properties/ YAML files         │                │
│  │    ELSE                                         │                │
│  │      → Use Pwb::Seeder.seed_properties_only!    │                │
│  │    ↓                                             │                │
│  │    website.seed_properties!                     │                │
│  │    State: field_keys_created → properties_seeded │              │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 6: Verify Provisioning Complete ────────┐                │
│  │  Check: provisioning_complete? guard            │                │
│  │  Required:                                      │                │
│  │    ✓ Agency exists                              │                │
│  │    ✓ >= 3 Links exist                           │                │
│  │    ✓ >= 5 Field keys exist                      │                │
│  │    ✓ >= 1 Page exists                           │                │
│  │    ✓ Owner has membership                       │                │
│  │    ↓                                             │                │
│  │  website.mark_ready!                            │                │
│  │  State: properties_seeded → ready               │                │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 7: Enter Locked State ──────────────────┐                │
│  │  Generate email verification token              │                │
│  │  Token expires in: 7 days (configurable)        │                │
│  │  ↓                                              │                │
│  │  website.enter_locked_state!                    │                │
│  │  State: ready → locked_pending_email_verification │              │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  ┌─ STEP 8: Send Verification Email ─────────────┐                │
│  │  EmailVerificationMailer.verification_email()   │                │
│  │  Send to: website.owner_email                   │                │
│  │  Contains: email verification link              │                │
│  │  Non-blocking if email fails                    │                │
│  └─────────────────────────────────────────────────┘                │
│         ↓                                                             │
│  Return: { success: true, website: website }                        │
│  Logging: All steps logged to Rails.logger                          │
│  Error Handling: Detailed AASM::InvalidTransition messages          │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## Seeding Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                       SEEDING SYSTEMS                                 │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    SEED PACK (lib/pwb/seed_pack.rb)         │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │                                                              │    │
│  │  apply!(website:, options:)                                 │    │
│  │    ↓                                                         │    │
│  │  Location: /db/seeds/packs/{pack_name}/                     │    │
│  │  Config: pack.yml (metadata + structure)                    │    │
│  │    ↓                                                         │    │
│  │  Hierarchy: Supports pack.inherits_from                     │    │
│  │  If parent specified, apply parent first                    │    │
│  │    ↓                                                         │    │
│  │  Seeding Order:                                             │    │
│  │    1. seed_website()         [theme, locale, currency]      │    │
│  │    2. seed_agency()          [agency + address]             │    │
│  │    3. seed_field_keys()      [property categories]          │    │
│  │    4. seed_links()           [navigation]                   │    │
│  │    5. seed_pages()           [page definitions]             │    │
│  │    6. seed_page_parts()      [component content]            │    │
│  │    7. seed_properties()      [sample listings]              │    │
│  │    8. seed_content()         [translations]                 │    │
│  │    9. seed_users()           [admin accounts]               │    │
│  │   10. seed_translations()    [i18n strings]                 │    │
│  │    ↓                                                         │    │
│  │  Features:                                                  │    │
│  │    • Preview before apply (dry_run: true)                   │    │
│  │    • Verbose logging                                        │    │
│  │    • Idempotent (won't duplicate if run twice)              │    │
│  │    • Fallbacks to defaults if data missing                  │    │
│  │    ↓                                                         │    │
│  │  Usage:                                                     │    │
│  │    pack = Pwb::SeedPack.find('spain_luxury')                │    │
│  │    pack.apply!(website: website)                            │    │
│  │                                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                  SEED RUNNER (lib/pwb/seed_runner.rb)       │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │                                                              │    │
│  │  run(website:, mode:, dry_run:, ...)                        │    │
│  │    ↓                                                         │    │
│  │  Location: /db/yml_seeds/                                   │    │
│  │  Files: agency.yml, users.yml, contacts.yml, etc.           │    │
│  │    ↓                                                         │    │
│  │  Modes:                                                     │    │
│  │    • :interactive  - Prompt if data exists                  │    │
│  │    • :create_only  - Skip existing records                  │    │
│  │    • :force_update - Update existing without prompt         │    │
│  │    • :upsert       - Create or update all                   │    │
│  │    ↓                                                         │    │
│  │  Seeding Steps:                                             │    │
│  │    1. Validate seed files exist                             │    │
│  │    2. If existing data, prompt user for action              │    │
│  │    3. Load and seed: agency, website, field_keys            │    │
│  │    4. Load and seed: users, contacts, links                 │    │
│  │    5. Load and seed: properties, pages                      │    │
│  │    6. Report statistics                                     │    │
│  │    ↓                                                         │    │
│  │  Features:                                                  │    │
│  │    • Dry-run support                                        │    │
│  │    • Interactive mode with prompts                          │    │
│  │    • Statistics tracking (created/updated/skipped)          │    │
│  │    • Error handling & validation                            │    │
│  │    ↓                                                         │    │
│  │  Usage:                                                     │    │
│  │    Pwb::SeedRunner.run(website: website)                    │    │
│  │    Pwb::SeedRunner.run(website: w, mode: :create_only)      │    │
│  │                                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              PROVISIONING SERVICE (seeding)                 │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │                                                              │    │
│  │  provision_website(website:) integrates seeding:            │    │
│  │    ↓                                                         │    │
│  │  Seed Pack First Strategy:                                  │    │
│  │    For each seeding step (agency, links, field_keys, etc.): │    │
│  │      1. try_seed_pack_step(website, :step_name)             │    │
│  │      2. IF pack found && step returns data → USE IT         │    │
│  │      3. ELSE → Use fallback defaults                        │    │
│  │    ↓                                                         │    │
│  │  Example Fallback Defaults:                                 │    │
│  │    • Agency: { display_name: subdomain.titleize, ... }      │    │
│  │    • Links: home, buy, rent, contact                        │    │
│  │    • Field keys: types (house, apt, villa), features, etc.  │    │
│  │    • Pages: Uses Pwb::PagesSeeder                           │    │
│  │    • Properties: Uses Pwb::Seeder                           │    │
│  │    ↓                                                         │    │
│  │  This ensures: Seeding never fails (always have fallbacks)  │    │
│  │                                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## User State Machine

```
                       ┌──────────────────┐
                       │      lead        │ (initial)
                       │   (email only)   │
                       └────────┬─────────┘
                                │
                       register()│ (ProvisioningService)
                                │
                       ┌────────▼─────────┐
                       │   registered     │
                       │ (account created)│
                       └────────┬─────────┘
                                │
                    verify_email()│ (email verified)
                                │
                       ┌────────▼────────────┐
                       │  email_verified    │
                       │ (awaiting onboarding)
                       └────────┬────────────┘
                    ┌──────────┴─────────────┐
              start_│                        │activate!
             onboard│                        │(direct, no flow)
            ing()   │                        │
                    │                        │
                    ▼                        ▼
              ┌──────────────┐        ┌──────────────┐
              │ onboarding   │        │    active    │◄──── Web request
              │(in setup flow)       │(fully ready) │     completes wizard
              └────────┬─────┘        └──────────────┘
                       │
       complete_onboarding()
                       │
                       ▼
              ┌──────────────┐
              │    active    │
              │(fully ready) │
              └──────────────┘
                       ▲
                       │ reactivate()
                       │ (from churned)
              ┌──────────────┐
              │   churned    │
              │ (abandoned)  │
              └──────────────┘
```

## Website State Machine (Provisioning)

```
                       pending
                         │
              assign_owner() [has_owner? guard]
                         │
                   owner_assigned
                         │
          complete_agency() [has_agency? guard]
                         │
                   agency_created
                         │
         complete_links() [has_links? >= 3 guard]
                         │
                   links_created
                         │
    complete_field_keys() [has_field_keys? >= 5 guard]
                         │
                   field_keys_created
                         │
        ┌────────────────┴────────────────┐
        │                                 │
  seed_properties()                skip_properties()
        │                                 │
        └────────────────┬────────────────┘
                         │
                   properties_seeded
                         │
             mark_ready() [provisioning_complete? guard]
                         │
                       ready
                         │
        enter_locked_state() [can_go_live? guard]
                         │
        locked_pending_email_verification
                         │
          verify_owner_email() [email_verification_valid? guard]
                         │
        locked_pending_registration
                         │
                    go_live()
                         │
                       live


Alternative paths:
  any_state ──fail_provisioning()──► failed ──retry_provisioning()──► pending
  any_state ──suspend()──────────────► suspended
  any_state ──terminate()─────────────► terminated
```

## Data Flow Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     COMPLETE DATA FLOW                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─ User Model ─────────────────────────────────────────────────────┐   │
│  │  Columns:                                                         │   │
│  │    • onboarding_state     (lead → registered → ... → active)    │   │
│  │    • onboarding_step      (current step in signup)              │   │
│  │    • onboarding_started_at                                       │   │
│  │    • onboarding_completed_at                                     │   │
│  │    • site_admin_onboarding_completed_at (wizard completion)     │   │
│  │    • website_id            (primary website)                    │   │
│  │    • user_memberships     (has_many)                            │   │
│  │  AASM State Machine:                                             │   │
│  │    Events: register, verify_email, start_onboarding,            │   │
│  │             complete_onboarding, activate, mark_churned,        │   │
│  │             reactivate                                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         ↑                                                                │
│         │                                                                │
│  ┌──────┴─ ProvisioningService (app/services) ──────────────┐          │
│  │                                                           │          │
│  │  start_signup(email)        → User (lead)               │          │
│  │  verify_email(user, token)  → User (email_verified)     │          │
│  │  configure_site(...)        → Website (pending)         │          │
│  │                             → UserMembership (owner)    │          │
│  │  provision_website(website) → 11-step provisioning      │          │
│  │                                                           │          │
│  └───────────────────────────────────────────┬──────────────┘          │
│                                              │                         │
│                                              ▼                         │
│  ┌─ Website Model ────────────────────────────────────────────────┐   │
│  │  Columns:                                                       │   │
│  │    • provisioning_state  (pending → ... → live)               │   │
│  │    • provisioning_started_at                                   │   │
│  │    • provisioning_completed_at                                 │   │
│  │    • seed_pack_name      (which pack was used)                │   │
│  │    • site_type           (residential|commercial|vacation)    │   │
│  │    • owner_email                                              │   │
│  │    • email_verification_token                                 │   │
│  │    • email_verified_at                                        │   │
│  │  AASM State Machine:                                           │   │
│  │    Events: assign_owner, complete_agency, complete_links,     │   │
│  │             complete_field_keys, seed_properties,             │   │
│  │             skip_properties, mark_ready, enter_locked_state,  │   │
│  │             verify_owner_email, go_live, fail_provisioning    │   │
│  └────────────────────────────┬──────────────────────────────────┘   │
│                               │                                       │
│              Seeding Stack Decides What Gets Created:                │
│                               │                                       │
│         ┌─────────────────────┴─────────────────────┐               │
│         │                                           │               │
│         ▼                                           ▼               │
│  ┌──────────────────┐                       ┌──────────────────┐   │
│  │  Seed Pack       │                       │  SeedRunner      │   │
│  │  (scenario-based)│                       │  (file-based)    │   │
│  │                  │                       │                  │   │
│  │ /db/seeds/packs/ │                       │ /db/yml_seeds/   │   │
│  │  {pack_name}/    │                       │                  │   │
│  │                  │                       │                  │   │
│  │ • pack.yml       │                       │ • agency.yml     │   │
│  │ • agency.yml     │                       │ • users.yml      │   │
│  │ • field_keys.yml │                       │ • field_keys.yml │   │
│  │ • properties/    │                       │ • prop/          │   │
│  │ • pages/         │                       │                  │   │
│  │ • users/         │                       │ Run modes:       │   │
│  │ • images/        │                       │ • interactive    │   │
│  │ • translations/  │                       │ • create_only    │   │
│  │                  │                       │ • force_update   │   │
│  │ apply!()         │                       │ • upsert         │   │
│  └──────────────────┘                       └──────────────────┘   │
│         │                                           │               │
│         └──────────────────┬──────────────────────┘               │
│                            │                                       │
│         Creates in Database:                                      │
│         ─────────────────────                                    │
│            • Pwb::Agency                                         │
│            • Pwb::FieldKey                                       │
│            • Pwb::Link                                           │
│            • Pwb::Page                                           │
│            • Pwb::PagePart                                       │
│            • Pwb::RealtyAsset + listings                         │
│            • Pwb::User + UserMembership                          │
│            • I18n translations                                   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## OnboardingController (5-Step Wizard)

```
                      User Dashboard
                            │
                   Redirect if not onboarded
                            │
              SiteAdminOnboarding concern
              (before_action check)
                            │
      ┌─────────────────────┴──────────────────────┐
      │                                            │
      NO (already onboarded)                    YES (redirect)
      │                                            │
      ▼                                            ▼
   Continue                            OnboardingController
   (normal flow)                                  │
                           ┌──────────────┬───────┼───────┬─────────────┐
                           │              │               │             │
                        GET /onboarding                    │             │
                           │              │               │             │
                           ▼              │               │             │
                       show(step: 1)      │               │             │
                           │              │               │             │
        ┌──────────────────┬──────────────┘               │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Step 1: Welcome                      │             │
        │            ├─ Display intro                     │             │
        │            └─ POST → advance_step!              │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Step 2: Profile                      │             │
        │            ├─ Form for Agency                   │             │
        │            │   (display_name, email, phone)     │             │
        │            ├─ POST → save_profile               │             │
        │            └─ update(Pwb::Agency)               │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Step 3: Property [OPTIONAL]          │             │
        │            ├─ Form for RealtyAsset              │             │
        │            ├─ Can skip                          │             │
        │            ├─ POST → save_property              │             │
        │            └─ create(Pwb::RealtyAsset)          │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Step 4: Theme                        │             │
        │            ├─ Theme selector                    │             │
        │            ├─ POST → save_theme                 │             │
        │            └─ update(Website.theme_name)        │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Step 5: Complete                     │             │
        │            ├─ Summary stats                     │             │
        │            │   - Property count                 │             │
        │            │   - Page count                     │             │
        │            │   - Theme chosen                   │             │
        │            └─ GET complete()                    │             │
        │                  │                              │             │
        │                  ├─ complete_onboarding!        │             │
        │                  │   └─ User.site_admin_        │             │
        │                  │      onboarding_completed_at │             │
        │                  │   └─ User.activate! (if      │             │
        │                  │      state allows)           │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Wizard Complete                      │             │
        │            └─ Redirect to dashboard             │             │
        │                  │                              │             │
        │                  ▼                              │             │
        │            Access Granted ✓                     │             │
        │            (site_admin_onboarding_               │             │
        │             completed_at != nil)               │             │
        └──────────────────────────────────────────────────┘             │
                                                                         │
                         (if already onboarded)                          │
                         (before_action skips redirect)                  │
                                                                         │
                         → Normal admin access                           │
                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Summary

This architecture ensures:

1. **Clear separation** between signup flow, website provisioning, and site setup
2. **Multiple entry points** for seeding (SeedPack, SeedRunner, ProvisioningService)
3. **State machines** track progress at both user and website level
4. **Fallback defaults** ensure provisioning never fails due to missing seed data
5. **Flexible seeding** via packs that can be tailored per scenario
6. **Automatic onboarding redirect** keeps new users on track
7. **Database indexing** on state columns for efficient querying
8. **Comprehensive logging** for debugging and auditing
