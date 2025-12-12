# Signup Flow Documentation

## Overview

The PropertyWebBuilder signup flow is a 4-step wizard that guides new users from initial email capture to a fully provisioned website. The system is built with multi-tenancy in mind, creating isolated website instances for each user.

**Duration:** Approximately 2-3 minutes per signup  
**Key Components:** SignupController, ProvisioningService, Seeder, SubdomainGenerator, Website & User state machines  
**Session Management:** Uses Rails session to track progress across steps

---

## Architecture Diagram

```
┌─────────────────┐
│   User Email    │
└────────┬────────┘
         │
         v
┌──────────────────────────┐
│   Step 1: Email Capture  │  POST /signup/start
├──────────────────────────┤
│ - Validate email format  │
│ - Create lead User       │  User.onboarding_state = 'lead'
│ - Reserve subdomain      │  Subdomain.state = 'reserved'
│ - Store in session       │
└────────┬─────────────────┘
         │
         v
┌──────────────────────────────────┐
│ Step 2: Site Configuration       │  GET /signup/configure
├──────────────────────────────────┤
│ - Show subdomain suggestions     │  SubdomainGenerator
│ - Check subdomain availability   │
│ - Select site type               │
└────────┬───────────────────────┬─┘
         │                       │
         v (validation passes)   v (invalid)
    [Proceed]               [Retry/Suggest]
         │
         v
      POST /signup/configure (save_configuration)
├──────────────────────────────────┤
│ - Create Website                 │  Website.provisioning_state = 'subdomain_allocated'
│ - Allocate subdomain             │
│ - Create owner UserMembership    │
│ - Update User onboarding_step    │
└────────┬─────────────────────────┘
         │
         v
┌──────────────────────────────────┐
│  Step 3: Provisioning Progress   │  GET /signup/provisioning
├──────────────────────────────────┤
│ - Show status indicators         │  Shows real-time progress
│ - Poll provisioning status       │  Uses JavaScript polling
│ - JS triggers POST /signup/provision
└────────┬─────────────────────────┘
         │
         v
      POST /signup/provision (JSON API)
├──────────────────────────────────┤
│ 1. start_configuring             │  Update Website state machine
│ 2. configure_website_defaults    │  Set theme, locale
│ 3. start_seeding                 │
│ 4. run_seed_pack / Seeder        │  Load sample data
│ 5. mark_ready                    │
│ 6. go_live                       │  Website is LIVE
│ 7. activate User                 │  User becomes 'active'
└────────┬─────────────────────────┘
         │
         v
┌──────────────────────────────────┐
│  Step 4: Completion              │  GET /signup/complete
├──────────────────────────────────┤
│ - Show live website URL          │
│ - Provide next steps             │
│ - Clear signup session           │
│ - Offer links to:                │
│   - View public website          │
│   - Access admin dashboard       │
└──────────────────────────────────┘
```

---

## Step-by-Step Flow Details

### Step 1: Email Capture & Lead Creation

**Route:** `GET /signup` (show form) → `POST /signup/start` (submit)

**Controller:** `SignupController#new` / `SignupController#start`

**View:** `app/views/pwb/signup/new.html.erb`

**Process:**

1. User navigates to `/signup`
2. Form displays email input with brief description of features
3. User enters email and clicks "Get Started"
4. `SignupController#start` receives POST request:
   - Email is validated (format check using `URI::MailTo::EMAIL_REGEXP`)
   - Email is normalized: `downcase` and `strip`
   - `ProvisioningService.start_signup(email: email)` is called

**ProvisioningService#start_signup:**

```ruby
# Input: email (string)
# Output: { success: true/false, user: User, subdomain: Subdomain, errors: [String] }

1. Check if user already exists:
   - If active: return error "account already exists"
   - If churned: reactivate and continue
   - If doesn't exist: create new

2. Create lead User record:
   - email: normalized
   - password: random 16-byte hex (temporary, never used)
   - onboarding_state: 'lead'
   - marked as lead (no password verification required)

3. Reserve a subdomain:
   - Call Subdomain.reserve_for_email(email, duration: 10.minutes)
   - Randomly selects available subdomain from pool
   - Updates: aasm_state = 'reserved', reserved_by_email, reserved_until

4. Transaction rollback on any failure:
   - Pool empty error
   - Pool exhausted error
   - User creation failure

5. Return success result with user and reserved subdomain
```

**Session Storage:**
```ruby
session[:signup_user_id] = user.id
session[:signup_subdomain] = subdomain.name
```

**Next:** Redirect to `signup_configure_path`

**Error Handling:**
- Invalid email format → Flash error, re-render form
- Subdomain pool empty/exhausted → User-friendly message, contact support prompt
- Database errors → Rollback and return generic error

---

### Step 2: Site Configuration

**Route:** `GET /signup/configure` (show form) → `POST /signup/configure` (save_configuration)

**Controller:** `SignupController#configure` / `SignupController#save_configuration`

**View:** `app/views/pwb/signup/configure.html.erb`

**Before Action:** `load_current_signup` - Validates user exists in session

**Process:**

1. User loads configure page:
   - `@suggested_subdomain` = Either session subdomain or generated via `SubdomainGenerator.generate`
   - `@site_types` = `Website::SITE_TYPES` = `['residential', 'commercial', 'vacation_rental']`

2. Page displays:
   - Subdomain input field with live availability checking (JavaScript)
   - Site type radio buttons (residential, commercial, vacation_rental)

3. **Subdomain Availability Checking (JavaScript):**
   
   ```javascript
   // GET /signup/check_subdomain?name=VALUE (JSON endpoint)
   // Returns: { available: boolean, normalized: string, errors: [String] }
   
   // Debounced on input (300ms delay)
   // Shows green checkmark if available, red X if taken
   ```

   **SubdomainGenerator#validate_custom_name:**
   ```ruby
   # Validates:
   # 1. Format: lowercase alphanumeric + hyphens only
   # 2. Length: 3-40 characters
   # 3. Not in RESERVED_SUBDOMAINS list
   # 4. Not already allocated in Website table
   # 5. If in Subdomain pool: must be available or reserved by same email
   
   # Returns: { valid: boolean, errors: [String], normalized: string }
   ```

4. **Suggest Subdomain Button:**
   ```javascript
   GET /signup/suggest_subdomain (JSON endpoint)
   Returns: { subdomain: "adjective-noun-00" }
   ```

   **SubdomainGenerator#generate:**
   ```ruby
   # Generates Heroku-style names: "adjective-noun-##"
   # Examples: "sunny-meadow-42", "crystal-peak-17"
   # Uses pre-defined lists of adjectives and nouns
   # Checks uniqueness in both Subdomain and Website tables
   ```

5. User submits form:
   - Subdomain (custom string)
   - Site type (radio selection)
   - `POST /signup/configure` calls `save_configuration`

**ProvisioningService#configure_site:**

```ruby
# Input: user, subdomain_name, site_type
# Output: { success: true/false, website: Website, membership: UserMembership, errors: [String] }

1. Validate subdomain name:
   - Call SubdomainGenerator.validate_custom_name(subdomain, reserved_by_email: user.email)
   - Must be valid, normalized
   - User's email can use a reserved subdomain

2. Validate site type:
   - Must be in Website::SITE_TYPES

3. In transaction:
   a. Transition user to 'onboarding' state
   b. Create Website:
      - subdomain: normalized_name
      - site_type: selected_type
      - provisioning_state: 'pending'
      - seed_pack_name: determined by site_type ('base' for all types currently)
   
   c. Allocate subdomain from pool:
      - Find Subdomain record by name
      - Call subdomain.allocate!(website)
      - Updates: aasm_state = 'allocated', website_id
   
   d. Create owner UserMembership:
      - role: 'owner'
      - active: true
   
   e. Update user:
      - primary website: set to newly created website
      - onboarding_step: 3
   
   f. Transition website:
      - Call website.allocate_subdomain!
      - Updates: provisioning_state = 'subdomain_allocated'

4. Return website and membership
```

**Session Storage:**
```ruby
session[:signup_website_id] = website.id
```

**Next:** Redirect to `signup_provisioning_path`

**Error Handling:**
- Invalid subdomain (taken, format) → Flash error, re-render configure page
- Invalid site type → Flash error, re-render
- Database errors → Flash error, re-render

---

### Step 3: Website Provisioning

**Route:** `GET /signup/provisioning` (show progress) → `POST /signup/provision` (trigger provisioning)

**Controller:** `SignupController#provisioning` / `SignupController#provision`

**View:** `app/views/pwb/signup/provisioning.html.erb`

**Status Endpoint:** `GET /signup/status` (polling endpoint)

**Process:**

1. User loads provisioning page:
   - Fetches website from session: `Website.find_by(id: session[:signup_website_id])`
   - Displays progress UI with 5 step indicators:
     1. Subdomain allocated (20%)
     2. Configuring (40%)
     3. Adding sample properties (70%)
     4. Finalizing (95%)
     5. Going live (100%)

2. **JavaScript Initialization:**
   - Page checks website state on load
   - If `live?`: Redirects to `/signup/complete`
   - If provisioning state: Calls `startProvisioning()`

3. **Provisioning Trigger:**
   ```javascript
   POST /signup/provision (JSON)
   
   Returns: {
     success: true/false,
     status: 'subdomain_allocated|configuring|seeding|ready|live',
     progress: 0-100,
     message: 'User-friendly status message',
     error?: 'Error message if failed'
   }
   ```

**ProvisioningService#provision_website:**

```ruby
# Input: website
# Output: { success: true/false, website: Website, errors: [String] }
# Called synchronously (will be async in future)

1. Start configuring:
   a. Call website.start_configuring!
      - Updates: provisioning_state = 'configuring'
   b. Report progress: 40%

2. Configure website defaults:
   a. Select theme based on site_type:
      - All types → 'bristol' (default theme)
   b. Set defaults:
      - default_client_locale: 'en'
      - supported_locales: ['en']
      - theme_name: 'bristol'

3. Start seeding:
   a. Call website.start_seeding!
      - Updates: provisioning_state = 'seeding'
   b. Report progress: 70%

4. Run seed pack:
   a. Attempt to use Pwb::SeedPack infrastructure
   b. Fallback to Pwb::Seeder if pack not found
   c. Seed sample data:
      - Agency (with address)
      - Links (navigation, social media)
      - Sample properties (4 properties: 2 for sale, 2 for rent)
      - Field keys
      - Website content defaults
      - Contacts table

5. Mark ready:
   a. Call website.mark_ready!
      - Updates: provisioning_state = 'ready'
      - Sets: provisioning_completed_at = Time.current
   b. Report progress: 95%

6. Go live:
   a. Call website.go_live!
      - Updates: provisioning_state = 'live'
   b. Report progress: 100%

7. Activate user:
   a. Find owner user membership
   b. Call owner.activate! if may_activate?
      - Updates: onboarding_state = 'active'
      - Sets: onboarding_completed_at = Time.current
   c. Update: onboarding_step = 4

8. Return success
```

**Seeder Details:**

```ruby
Pwb::Seeder.new.seed_for_website(website)

Seeds:
1. Agency:
   - display_name
   - description
   - primary_address
   - contact info

2. Links:
   - Navigation links (top menu)
   - Footer links
   - Social media links (placeholders)

3. Sample Properties (via RealtyAsset + Listings):
   - Villa for Sale
   - Villa for Rent
   - Flat for Sale (2 variants)
   - Flat for Rent (2 variants)
   
   Each includes:
   - Address details
   - Bedrooms, bathrooms, garages
   - Square footage, plot area
   - Photos (external URLs, no local storage)
   - Translations (multiple languages)
   - Sale/rental pricing

4. Field Keys:
   - Property field configurations
   - Site-wide settings

5. Website defaults:
   - Style variables
   - Currency settings
   - Social media placeholders
```

**Polling During Provisioning:**

```javascript
// Client calls GET /signup/status every 1-2 seconds
// Endpoint returns current provisioning state
// UI updates progress bar and step indicators
// When complete (live? == true), redirects to complete page
```

**State Machine Transitions:**

```
Website states:
pending → subdomain_allocated → configuring → seeding → ready → live

User states (during provisioning):
lead → onboarding → active
```

**Error Handling:**
- Any failure during provisioning:
  - Call `website.fail_provisioning!(error_message)`
  - Updates: provisioning_state = 'failed', provisioning_error
  - Returns error to UI
  - User can retry

**Retry Logic:**
```ruby
ProvisioningService#retry_provisioning

- Only allowed for websites in 'failed' state
- Transitions website back to 'pending'
- Calls provision_website again
```

---

### Step 4: Completion

**Route:** `GET /signup/complete`

**Controller:** `SignupController#complete`

**View:** `app/views/pwb/signup/complete.html.erb`

**Process:**

1. Access check:
   - Verify website is `live?`
   - If not live, redirect back to provisioning page

2. Display completion page showing:
   - Success message
   - Website URL:
     ```
     Custom domain: https://custom.example.com (if verified)
     OR
     Subdomain: https://subdomain.propertywebbuilder.com
     ```
   
3. Provide action buttons:
   - "View Your Website" → Opens public site in new tab
   - "Go to Admin Dashboard" → Opens `/site_admin` in new tab

4. Display next steps checklist:
   1. Set password (email instructions)
   2. Add real properties (replace samples)
   3. Customize branding
   4. Connect custom domain (optional)

5. Clear signup session:
   ```ruby
   session.delete(:signup_user_id)
   session.delete(:signup_subdomain)
   session.delete(:signup_website_id)
   ```

6. User is now:
   - Authenticated (password set via email link)
   - Owner of website
   - Can access `/site_admin`
   - Ready to customize

---

## Database Models & State Machines

### User Model

**States (AASM):**
```
lead → registered → email_verified → onboarding → active
                                  ↓
                                churned
```

**Signup-relevant attributes:**
```ruby
class User < ApplicationRecord
  # Core
  email: string
  password_digest: string
  
  # Onboarding tracking
  onboarding_state: string (enum: AASM)
  onboarding_step: integer (1-4)
  onboarding_started_at: timestamp
  onboarding_completed_at: timestamp
  
  # Website association
  website_id: integer (foreign key, primary website)
  
  # Authentication
  failed_attempts: integer
  locked_at: timestamp
  last_sign_in_at: timestamp
  
  # Firebase (optional)
  firebase_uid: string
end
```

**Key Methods for Signup:**
- `start_onboarding!` - Transition from lead to onboarding
- `activate!` - Mark user as active (onboarded)
- `may_activate?` - Check if transition is allowed
- `needs_onboarding?` - True if not yet active

### Website Model

**States (AASM):**
```
pending → subdomain_allocated → configuring → seeding → ready → live
                                                             ↓
                                                          failed
```

**Signup-relevant attributes:**
```ruby
class Website < ApplicationRecord
  # Core
  subdomain: string (unique)
  custom_domain: string (optional)
  theme_name: string
  site_type: string (enum: residential|commercial|vacation_rental)
  
  # Provisioning tracking
  provisioning_state: string (enum: AASM)
  provisioning_started_at: timestamp
  provisioning_completed_at: timestamp
  provisioning_error: text (if failed)
  seed_pack_name: string
  
  # Configuration
  company_display_name: string
  default_client_locale: string
  supported_locales: string[] (array)
  
  # Associations
  has_many :user_memberships
  has_one :allocated_subdomain (Subdomain)
  has_one :agency
  has_many :realty_assets (properties)
end
```

**Key Methods:**
- `provisioning_state` - Current state machine state
- `provisioning_progress` - Returns 0-100 percentage
- `provisioning_status_message` - Human-readable message
- `provisioning?` - True if not yet live
- `live?` - True if provisioning complete
- `primary_url` - Returns the accessible URL
- State machine events:
  - `allocate_subdomain!`
  - `start_configuring!`
  - `start_seeding!`
  - `mark_ready!`
  - `go_live!`
  - `fail_provisioning!(error_message)`
  - `retry_provisioning!`

### Subdomain Model

**States (AASM):**
```
available → reserved → allocated
                    ↓
                 released → available
```

**Attributes:**
```ruby
class Subdomain < ApplicationRecord
  # Core
  name: string (unique, lowercase, 5-40 chars)
  aasm_state: string (enum: AASM)
  
  # Reservation (temporary hold)
  reserved_at: timestamp
  reserved_until: timestamp (5-10 minutes from reservation)
  reserved_by_email: string
  
  # Allocation (permanent)
  website_id: integer (foreign key)
  
  # Association
  belongs_to :website, optional: true
end
```

**Key Methods:**
- `self.reserve_for_email(email, duration: 5.minutes)` - Reserve random subdomain
- `self.reserve_specific(name, email, duration)` - Reserve specific name
- `self.name_available?(name)` - Check availability
- `self.release_expired!` - Cleanup expired reservations (scheduled job)
- State machine events:
  - `reserve!(email, duration)`
  - `allocate!(website)`
  - `release!`
  - `make_available!`

### UserMembership Model

**Attributes:**
```ruby
class UserMembership < ApplicationRecord
  # Core
  user_id: integer (foreign key)
  website_id: integer (foreign key)
  role: string (enum: owner|admin|member|viewer)
  active: boolean
  
  # Associations
  belongs_to :user
  belongs_to :website
end
```

**Signup Details:**
- Owner membership created during Step 2
- `role: 'owner'`
- `active: true`
- Allows user full website administration

---

## API Endpoints Summary

### Public Endpoints

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/signup` | GET | Email capture form | HTML view |
| `/signup/start` | POST | Create lead user, reserve subdomain | Redirect or form re-render |
| `/signup/configure` | GET | Site configuration form | HTML view |
| `/signup/configure` | POST | Save config, create website | Redirect or form re-render |
| `/signup/provisioning` | GET | Provisioning progress page | HTML view |
| `/signup/provision` | POST | Trigger provisioning | JSON `{success, status, progress, message}` |
| `/signup/status` | GET | Poll provisioning status | JSON `{success, status, progress, message, complete}` |
| `/signup/complete` | GET | Completion page | HTML view |
| `/signup/check_subdomain` | GET | Availability check | JSON `{available, normalized, errors}` |
| `/signup/suggest_subdomain` | GET | Get random suggestion | JSON `{subdomain}` |

### Session Data Passed Between Steps

```ruby
session[:signup_user_id]      # User ID (created in Step 1)
session[:signup_subdomain]    # Reserved subdomain name (Step 1)
session[:signup_website_id]   # Website ID (created in Step 2)
```

Cleared after Step 4 completion.

---

## Data Flow & Persistence

### Step 1 Database Operations

```sql
-- Insert into users table
INSERT INTO pwb_users (email, password_digest, onboarding_state, created_at)
VALUES ('user@example.com', 'hashed_random_password', 'lead', NOW())

-- Update subdomain in pool
UPDATE pwb_subdomains 
SET aasm_state = 'reserved', 
    reserved_by_email = 'user@example.com',
    reserved_at = NOW(),
    reserved_until = NOW() + 10 minutes
WHERE id = (SELECT id FROM pwb_subdomains WHERE aasm_state = 'available' 
            ORDER BY RANDOM() LIMIT 1)
```

### Step 2 Database Operations

```sql
-- Insert into websites table
INSERT INTO pwb_websites 
  (subdomain, site_type, provisioning_state, seed_pack_name, 
   theme_name, default_client_locale, created_at)
VALUES ('mysubdomain', 'residential', 'subdomain_allocated', 'base',
        'bristol', 'en', NOW())

-- Update subdomain allocation
UPDATE pwb_subdomains 
SET aasm_state = 'allocated', website_id = 123
WHERE name = 'mysubdomain'

-- Create owner membership
INSERT INTO pwb_user_memberships (user_id, website_id, role, active)
VALUES (456, 123, 'owner', true)

-- Update user
UPDATE pwb_users 
SET website_id = 123, onboarding_step = 3
WHERE id = 456
```

### Step 3 Database Operations

```sql
-- Update website provisioning states (transitional)
UPDATE pwb_websites SET provisioning_state = 'configuring' WHERE id = 123
UPDATE pwb_websites SET provisioning_state = 'seeding' WHERE id = 123
UPDATE pwb_websites SET provisioning_state = 'ready', 
                       provisioning_completed_at = NOW() WHERE id = 123
UPDATE pwb_websites SET provisioning_state = 'live' WHERE id = 123

-- Seed data operations
INSERT INTO pwb_agencies ...
INSERT INTO pwb_realty_assets ... (6 sample properties)
INSERT INTO pwb_sale_listings ...
INSERT INTO pwb_rental_listings ...
INSERT INTO pwb_links ...

-- Update user to active
UPDATE pwb_users SET onboarding_state = 'active', 
                     onboarding_completed_at = NOW()
WHERE id = 456
```

---

## Error Handling & Recovery

### Email Validation Errors (Step 1)

| Error | Cause | Recovery |
|-------|-------|----------|
| Invalid email format | Regex mismatch | User corrects email |
| Account already exists | Email in use, user active | Error message, suggest login |
| Subdomain pool empty | No available subdomains | Contact support, try later |
| Subdomain pool exhausted | All used | Contact support, try later |

### Configuration Errors (Step 2)

| Error | Cause | Recovery |
|-------|-------|----------|
| Subdomain taken | Name already allocated | Suggest new name or try another |
| Invalid subdomain format | Not matching pattern | User corrects format |
| Invalid site type | Not in allowed list | UI prevents invalid selection |

### Provisioning Errors (Step 3)

| Error | Cause | Recovery |
|-------|-------|----------|
| Seeding failure | Missing seed data | `fail_provisioning!`, show retry button |
| Theme not found | Theme name invalid | Use default theme fallback |
| Database constraint | Unique constraint violation | Log and retry |

**Retry Mechanism:**
```ruby
# User clicks "Retry" button on error
service.retry_provisioning(website: website)
# Transitions website from failed → pending
# Re-runs provision_website
```

---

## External Dependencies

### SubdomainGenerator
- **Purpose:** Generates and validates subdomain names
- **Heroku-style naming:** "adjective-noun-##" (e.g., "sunny-meadow-42")
- **Adjectives:** 50+ nature/weather words
- **Nouns:** 60+ geographic/natural features
- **Validation:** Format, length, reserved check, uniqueness check

### Seeder
- **Location:** `/lib/pwb/seeder.rb`
- **Seeds:** Agency, links, sample properties, field keys, translations
- **Multi-tenant:** Scoped to website via `Pwb::Current.website`
- **Sample Properties:** Uses YAML seed files with photo URLs
- **Materialized View:** Updates ListedProperty view after seeding

### SeedPack (Optional)
- **Purpose:** More advanced, site-type-specific seed bundles
- **Fallback:** Uses basic Seeder if pack not found
- **Future:** Will support residential, commercial, vacation_rental packs

### StructuredLogger
- **Purpose:** Structured logging for signup events
- **Events Logged:**
  - Email submission
  - Step 1 completion
  - Site configuration
  - Provisioning start/completion
  - Errors and retries

---

## Security Considerations

### CSRF Protection
- Forms use Rails CSRF tokens
- JSON endpoints require `X-CSRF-Token` header

### Session Management
- Uses Rails encrypted sessions
- Session data cleared after completion
- Session timeout via `timeoutable` Devise strategy

### Email Validation
- No email verification required during signup (async later)
- Email normalized (downcase, strip) before storage
- Temporary password created, never provided to user

### Subdomain Reservation
- 10-minute expiration prevents reservation hoarding
- Automatic cleanup via scheduled job
- Per-email reservation limit

### Multi-tenancy Isolation
- Each website is isolated via `Pwb::Current.website`
- UserMembership controls cross-website access
- Database queries scoped to website_id

---

## Performance Considerations

### Signup Duration
- Step 1: ~100ms (email validation, user creation, subdomain reserve)
- Step 2: ~200ms (validation, website creation, subdomain allocation)
- Step 3: ~30-60 seconds (seeding, sample data creation)
  - Currently synchronous (should be async in production)
  - Bottleneck: Property creation and photo processing

### Optimizations Implemented
1. **Batch Subdomain Generation:** Pre-populated pool avoids runtime generation
2. **Eager Loading:** Minimal N+1 queries in controller actions
3. **Caching:** Theme and site type lookups use constants
4. **External Photo URLs:** Sample properties use URLs, not local storage

### Future Optimizations
1. **Async Provisioning:** Move Step 3 to background job (Solid Queue)
2. **Seed Packing:** Pre-packaged seed data per site type
3. **Subdomain Pre-warming:** Generate pool during off-peak hours
4. **CDN Images:** External URLs reduce server load

---

## Testing

### Unit Tests
- `/spec/services/pwb/provisioning_service_spec.rb`
- `/spec/models/pwb/website_provisioning_spec.rb`
- `/spec/models/pwb/subdomain_spec.rb`
- `/spec/models/pwb/user_onboarding_spec.rb`

### Test Coverage
- Email validation
- Lead user creation
- Subdomain reservation
- Site configuration
- Website provisioning
- State machine transitions
- Error scenarios

### Running Tests
```bash
# All signup-related tests
bundle exec rspec spec/services/pwb/provisioning_service_spec.rb
bundle exec rspec spec/models/pwb/website_provisioning_spec.rb

# Controller tests
bundle exec rspec spec/controllers/pwb/signup_controller_spec.rb
```

---

## Extracting as a Standalone Component

To extract signup into a standalone Rails engine:

### Files to Extract
1. **Controller:** `app/controllers/pwb/signup_controller.rb`
2. **Views:** `app/views/pwb/signup/**`
3. **Service:** `app/services/pwb/provisioning_service.rb`
4. **Models:** `app/models/pwb/{website,user,subdomain,user_membership}.rb`
5. **Generators:** `app/services/pwb/subdomain_generator.rb`
6. **Seeder:** `lib/pwb/seeder.rb`
7. **Layouts:** `app/views/layouts/pwb/signup.html.erb`
8. **Routes:** Signup routes from `config/routes.rb`

### Dependencies to Include
- AASM gem (state machines)
- ActiveRecord (ORM)
- ActionView (templates)
- Devise (authentication, optional for extraction)
- SecureRandom (password generation)
- Pwb::Current (tenant context)

### Configuration Required
- Subdomain pool population
- Theme selection
- Seed pack selection
- SMTP for password reset emails
- ActiveStorage for photos (in seeding)

### Entry Points
```ruby
# Initialize signup for a new tenant
provisioning = Pwb::ProvisioningService.new
result = provisioning.start_signup(email: 'user@example.com')
result = provisioning.configure_site(user: user, subdomain: 'mysite', site_type: 'residential')
result = provisioning.provision_website(website: website)
```

---

## Monitoring & Debugging

### Key Log Messages
```
[Signup] Step 1: Email submission
[Signup] Step 1 completed
[Signup] Step 1 failed
[Signup] Step 2: Site configuration
[Signup] Step 2 completed
[Signup] Step 2 failed
[Signup] Step 3: Starting provisioning
[Signup] Step 3 completed: Website is live
[Signup] Step 3 failed: Provisioning error
[SubdomainPool] No available subdomains for reservation
```

### Monitoring Points
1. **Signup Funnel:**
   - Email captures (Step 1 starts)
   - Completions (website live)
   - Dropout rate by step
   - Average time per step

2. **Provisioning Duration:**
   - Subdomain allocation time
   - Seeding time
   - Total provisioning time

3. **Error Tracking:**
   - Pool exhaustion events
   - Failed provisioning count
   - Retry success rate

4. **Database Health:**
   - Subdomain pool size
   - Active reservations (should expire after 10 min)
   - Failed websites

### Debugging in Console
```ruby
# Find user and website
user = Pwb::User.find_by(email: 'test@example.com')
website = user.website

# Check states
user.onboarding_state           # lead, onboarding, active, etc.
website.provisioning_state      # subdomain_allocated, configuring, seeding, etc.

# Check subdomain
subdomain = website.allocated_subdomain
subdomain.aasm_state            # allocated
subdomain.reserved_until        # nil (already allocated)

# Retry failed provisioning
service = Pwb::ProvisioningService.new
service.retry_provisioning(website: website)

# Check provisioning progress
website.provisioning_progress   # 0-100
website.provisioning_status_message  # Human-readable
```

---

## Related Documentation

- [Multi-tenancy Architecture](./multi_tenancy.md)
- [Database Schema](./architecture/database.md)
- [Theme System](./architecture/themes.md)
- [Seed Packs](./seeding/seed_packs.md)
- [Authentication Flow](./authentication.md)

---

## Future Enhancements

1. **Async Provisioning:** Move to background jobs for better UX
2. **Email Verification:** Require email click before Step 2
3. **Email Templates:** Custom welcome emails with setup instructions
4. **Advanced Site Types:** Commercial and vacation_rental seed packs
5. **Domain Mapping:** Support custom domains during signup
6. **Payment Integration:** Freemium model with plan selection
7. **Team Invitations:** Add team members during/after signup
8. **Data Import:** Allow importing existing properties during setup
9. **Template Selection:** Choose from multiple design templates
10. **Analytics:** Track signup metrics per channel/campaign
