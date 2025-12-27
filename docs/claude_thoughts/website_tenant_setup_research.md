# Website/Tenant Setup Flow Research

## Overview

PropertyWebBuilder is a multi-tenant Rails application where each "website" is a separate tenant (instance) serving different real estate agencies. The setup flow transforms a user signup into a fully provisioned, live website through a state machine-based provisioning process.

---

## 1. How @current_website Is Determined

### Primary Mechanisms (in order of priority)

#### In `Pwb::ApplicationController` (`app/controllers/pwb/application_controller.rb`):

1. **Subdomain-based routing** (preferred):
   ```ruby
   def current_website_from_subdomain
     subdomain = request.subdomain
     return nil if subdomain.blank?
     return nil if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
     Website.find_by_subdomain(subdomain)
   end
   ```
   - Reserved subdomains: `www`, `api`, `admin` (not used for tenant resolution)
   - Matches `tenant.propertywebbuilder.com` → finds `Website` with matching subdomain

2. **Fallback chain** in `current_agency_and_website`:
   ```ruby
   @current_website = current_website_from_subdomain || 
                      Pwb::Current.website || 
                      Website.first
   ```
   - Tries subdomain resolution first
   - Falls back to `Pwb::Current.website` (context variable)
   - Final fallback: **Website.first** (picks any existing website - problematic if multiple exist)

#### In `SubdomainTenant` concern (`app/controllers/concerns/subdomain_tenant.rb`):

Alternative multi-tenancy implementation with more robust host resolution:

1. **X-Website-Slug header** - for API/GraphQL requests
2. **Custom domain matching** - for tenant's own domains (www.myrealestate.com)
3. **Subdomain matching** - for platform domains (tenant.propertywebbuilder.com)
4. **Fallback to Website.first**

**Key Issue**: The fallback to `Website.first` is problematic in a true SaaS environment where:
- Multiple websites exist
- A new request without a proper host/subdomain shouldn't arbitrarily pick one

### ActsAsTenant Integration

```ruby
def current_agency_and_website
  # ... set @current_website ...
  ActsAsTenant.current_tenant = @current_website  # Scopes all tenant models
  Pwb::Current.website ||= @current_website       # Set context variable
end
```

- `ActsAsTenant` gem used for automatic query scoping
- Models including `ActsAsTenant` are automatically filtered by `website_id`

---

## 2. Existing Onboarding/Setup UI

### Site Admin Onboarding

**Controller**: `app/controllers/site_admin/onboarding_controller.rb`

**Purpose**: Guides newly provisioned users through post-signup setup steps

**5-Step Wizard Flow**:

1. **Welcome** (`welcome.html.erb`)
   - Introduction and expectations
   - Simple acknowledgment step

2. **Profile** (`profile.html.erb`)
   - Set agency/company name
   - Email and phone
   - Currency selection
   - Saves to `Pwb::Agency` record

3. **Property** (`property.html.erb`) - *Optional*
   - Add first property listing
   - Can be skipped
   - Saves to `Pwb::RealtyAsset`

4. **Theme** (`theme.html.erb`)
   - Select from available themes
   - Basic customization
   - Saves to `Website.theme_name`

5. **Complete** (`complete.html.erb`)
   - Summary with statistics
   - Marks `site_admin_onboarding_completed_at`
   - Shows property count, page count, selected theme

**Auto-Redirect Logic** (`app/controllers/concerns/site_admin_onboarding.rb`):
- Redirects new admin users to `/site_admin/onboarding` 
- Only shown to users whose website was provisioned < 30 days ago
- Only to users with `admin_for?(current_website)` role
- Until `site_admin_onboarding_completed_at` is set

**Views Location**: `/app/views/site_admin/onboarding/`

### Signup Flow (Public Signup Wizard)

**Controller**: `app/controllers/pwb/signup_controller.rb`

**4-Step Process**:

1. **Email Capture** - Email form, calls `ProvisioningService.start_signup`
2. **Site Configuration** - Subdomain & site type selection, calls `ProvisioningService.configure_site`
3. **Provisioning** - Progress indicator, calls `ProvisioningService.provision_website`
4. **Completion** - Success/next steps page

**Layout**: `layouts/pwb/signup.html.erb`

---

## 3. Seed Pack System

### Architecture

**Location**: `db/seeds/packs/`

**Available Packs** (at research time):
- `base` - Minimal configuration
- `netherlands_urban` - Netherlands-specific urban properties
- `spain_luxury` - Spain luxury real estate scenario

### Seed Pack Loading Mechanism

**Main Class**: `lib/pwb/seed_pack.rb`

**Key Methods**:

1. **Find and Load**:
   ```ruby
   pack = Pwb::SeedPack.find('base')
   pack.apply!(website: website, options: { verbose: true })
   ```

2. **Pack Structure**:
   ```
   packs/
   └── base/
       ├── pack.yml              # Configuration metadata
       ├── field_keys.yml        # Property field definitions
       ├── links.yml             # Navigation links
       ├── pages/                # Page definitions
       ├── page_parts/           # Page component definitions
       ├── properties/           # Sample property listings
       ├── content/              # Website content translations
       ├── images/               # Property images
       └── translations/         # I18n strings
   ```

3. **Application Order** (in `apply!`):
   - Apply parent pack first (if `inherits_from` set)
   - Seed website config (theme, locale, currency)
   - Seed agency (company info)
   - Seed field keys (property attributes)
   - Seed links (navigation)
   - Seed pages
   - Seed page parts (content components)
   - Seed properties
   - Seed content translations
   - Seed users
   - Seed translations
   - Refresh materialized view

### Integration with Provisioning

**In `ProvisioningService`** (`app/services/pwb/provisioning_service.rb`):

```ruby
def seed_pack_for_site_type(site_type)
  case site_type
  when 'residential' then 'base'
  when 'commercial' then 'base'
  when 'vacation_rental' then 'base'
  else 'base'
  end
end

def create_agency_for_website(website)
  # Try seed pack first
  if try_seed_pack_step(website, :agency)
    return
  end
  # Fallback to minimal agency creation
end
```

**Granular Seeding** (`SeedPack` public methods):
- `seed_agency!(website:)`
- `seed_links!(website:)`
- `seed_field_keys!(website:)`
- `seed_pages!(website:)`
- `seed_properties!(website:)`
- `seed_content!(website:)`

### Important Features

- **Dry Run Mode**: Preview changes without applying
- **Skip Options**: Can skip individual seeding steps
- **Inheritance**: Packs can inherit from parent packs
- **Validation**: Validates pack structure and required fields
- **Fallback**: If pack step fails, provides fallback logic
- **Locale Support**: Handles translations for multiple languages
- **Image Management**: External URLs (R2) or local file attachment

---

## 4. Missing Website Handling

### Current Behavior

**The Problem**: When no website matches the request, the application falls back to `Website.first`:

```ruby
@current_website = current_website_from_subdomain || 
                   Pwb::Current.website || 
                   Website.first
```

This means:
- **If no website exists**: Application crashes or exhibits undefined behavior
- **If multiple websites exist**: Arbitrary website picked (alphabetically first)
- **In development**: Usually only one website exists, masking the issue

### Locked State Mechanism

**State**: Websites in `locked_pending_email_verification` or `locked_pending_registration` states are "locked"

```ruby
def locked?
  locked_pending_email_verification? || locked_pending_registration?
end
```

**When websites are locked**:
1. After provisioning completes successfully
2. Email verification token generated
3. Owner must click email verification link
4. Then complete registration (Firebase account creation)

**Locked Page Handling** (in `current_agency_and_website`):
```ruby
def check_locked_website
  return unless @current_website&.locked?
  return unless request.path == '/' || request.path == root_path
  
  render 'pwb/locked/show', layout: 'pwb/locked'
end
```

- Only shows on landing page (/)
- Other pages still accessible if URL is known
- Displays `@locked_mode` and `@owner_email`

### Missing Website Scenarios Not Handled

1. **New deployment with no websites** - Would crash
2. **API call with unknown website** - Would return wrong website
3. **Custom domain request for non-existent domain** - Would pick Website.first
4. **Subdomain request for non-existent subdomain** - Would pick Website.first

---

## 5. Provisioning State Machine

**Module**: `app/models/concerns/pwb/website_provisionable.rb`

**States** (in order):
```
pending 
  ↓ (on: assign_owner, guard: has_owner?)
owner_assigned 
  ↓ (on: complete_agency, guard: has_agency?)
agency_created 
  ↓ (on: complete_links, guard: has_links?)
links_created 
  ↓ (on: complete_field_keys, guard: has_field_keys?)
field_keys_created 
  ↓ (on: seed_properties or skip_properties)
properties_seeded 
  ↓ (on: mark_ready, guard: provisioning_complete?)
ready 
  ↓ (on: enter_locked_state, guard: can_go_live?)
locked_pending_email_verification
  ↓ (on: verify_owner_email, guard: email_verification_valid?)
locked_pending_registration
  ↓ (on: complete_owner_registration)
live
```

**Failed State**: Any step can fail and transition to `:failed`

**Email Verification**:
- Token expires in 7 days (ENV: EMAIL_VERIFICATION_EXPIRY_DAYS)
- Must be verified before reaching `live` state
- Lock prevents website from being publicly visible until verified

---

## Recommendations for "Seed from Webpage" Functionality

### 1. Where to Add New Flow

**Two possible locations**:

#### Option A: New Admin Action (Recommended)
- **Path**: `/site_admin/seed_pack_selector`
- **Controller**: New `app/controllers/site_admin/seed_packs_controller.rb`
- **Purpose**: Allow existing websites to apply additional seed packs
- **Flow**: 
  - Browse available packs
  - Select pack to apply
  - Choose what to seed (skip options)
  - Confirm application

**Pros**:
- Reuses existing onboarding context
- Integrates with `SiteAdminController` (authenticated, website-scoped)
- Clear permissions model
- Can preview changes with dry-run

**Cons**:
- Limited to signed-in admin users

#### Option B: Post-Provisioning Onboarding Hook
- **Location**: Add new step to `OnboardingController`
- **Step 6**: "Import Sample Data"
- **Flow**: After completion wizard, offer to apply seed pack
- **Purpose**: Populate fresh website with realistic data

### 2. Critical Implementation Points

#### Handle Multiple Websites (Not Website.first)
- Validate website exists before seeding
- Return 404 or error if website missing
- Use explicit website scoping:
  ```ruby
  current_website.realty_assets.count  # Good
  Pwb::RealtyAsset.count              # Bad - crosses tenant boundaries
  ```

#### Use Existing SeedPack Infrastructure
- Leverage `Pwb::SeedPack.apply!(website:, options:)`
- Don't recreate seeding logic
- Respect skip options and dry-run mode

#### Consider Idempotency
- Current seed packs check `find_or_initialize_by` to avoid duplicates
- Seeding same pack twice should be safe
- May want to warn user if data already exists

#### Handle Locked Websites
- Decide: Can locked websites be seeded?
- Recommend yes - seeding doesn't require email verification
- Add guard if needed: `website.locked? && !can_seed_while_locked?`

#### Images and External URLs
- Check `Pwb::SeedImages.enabled?` for image strategy
- External URLs prefer R2 bucket over local attachment
- Handle missing images gracefully

### 3. User Interface Considerations

#### Discovery
- Add link in admin dashboard
- Add button in onboarding completion page
- Show in settings under "Manage Data"

#### Feedback
- Show pack name and what will be created
- Display preview of properties/pages/links count
- Progress indicator during seeding
- Success message with created counts

#### Safety
- Confirm before applying (especially for existing data)
- Show what will be created/overwritten
- Option to rollback (or warn that rollback not available)
- Dry-run preview first

### 4. Database Considerations

#### Materialized View Refresh
```ruby
Pwb::ListedProperty.refresh rescue nil  # Done at end of seeding
```

#### ActsAsTenant Scoping
- Ensure `website_id` is set before creating records
- Use `Pwb::Current.website = website` to set context
- Verify all created records are scoped to correct website

#### Data Isolation Testing
- Critical to test seeding doesn't leak across websites
- Use cross-tenant tests in spec suite

### 5. Available Seed Packs

Base functionality should work with:
- **base**: Minimal, universal setup
- **netherlands_urban**: Urban properties with Dutch defaults
- **spain_luxury**: Luxury market with Spanish defaults

Future: Create domain-specific packs (commercial, vacation_rental) matching site_type

---

## Key Files Reference

| Component | File |
|-----------|------|
| Seed Pack System | `lib/pwb/seed_pack.rb` |
| Provisioning Service | `app/services/pwb/provisioning_service.rb` |
| Website Model | `app/models/pwb/website.rb` |
| Provisioning State Machine | `app/models/concerns/pwb/website_provisionable.rb` |
| Onboarding Controller | `app/controllers/site_admin/onboarding_controller.rb` |
| Onboarding Views | `app/views/site_admin/onboarding/` |
| Signup Controller | `app/controllers/pwb/signup_controller.rb` |
| App Controller (Tenant Resolution) | `app/controllers/pwb/application_controller.rb` |
| Subdomain Tenant Concern | `app/controllers/concerns/subdomain_tenant.rb` |
| Onboarding Concern | `app/controllers/concerns/site_admin_onboarding.rb` |
| Seed Packs Directory | `db/seeds/packs/` |

---

## Conclusion

The PropertyWebBuilder multi-tenant setup is well-designed with:
- **Robust seeding system** via SeedPacks (reuse for new feature)
- **Granular provisioning** with state machine (14 states, clear guards)
- **Post-signup onboarding** for user configuration
- **Email verification** protecting live deployment

Main risks for new "seed from webpage" feature:
1. **Website.first fallback** - must handle missing websites
2. **Tenant isolation** - must scope all operations to correct website
3. **Locked state** - must decide if seeding allowed on locked websites
4. **Image handling** - must respect external URL vs local attachment strategy

Recommended: Create `/site_admin/seed_packs` endpoint that wraps existing `Pwb::SeedPack` infrastructure with UI for browsing and applying packs to existing websites.
