# Signup Component Extraction Guide

This guide provides detailed technical instructions for extracting the signup functionality into a standalone Rails engine or microservice.

---

## Component Overview

The signup system consists of 4 main layers:

```
┌──────────────────────────────────────┐
│   Web Layer (Views + JavaScript)     │  Thin, framework-agnostic
├──────────────────────────────────────┤
│   Controller Layer (SignupController)│  Rails-specific
├──────────────────────────────────────┤
│   Service Layer (ProvisioningService)│  Business logic, reusable
├──────────────────────────────────────┤
│   Model Layer (User, Website, etc.)  │  Database abstraction
└──────────────────────────────────────┘
```

---

## File Manifest

### Controllers (1 file)
```
app/controllers/pwb/signup_controller.rb (265 lines)
├─ 8 public actions
├─ 3 private helper methods
└─ Before/after hooks for session management
```

**Size:** ~10 KB  
**Lines:** 265  
**Dependencies:** Rails, AASM, SecureRandom

### Views (4 files + 1 layout)
```
app/views/pwb/signup/
├─ new.html.erb                    (Step 1: Email capture)
├─ configure.html.erb              (Step 2: Site config)
├─ provisioning.html.erb           (Step 3: Progress tracking)
└─ complete.html.erb               (Step 4: Success message)

app/views/layouts/pwb/signup.html.erb  (Shared layout)
```

**Total Size:** ~12 KB  
**Styling:** Tailwind CSS (already included in app)  
**JavaScript:** Inline in ERB templates (no external dependencies)

### Services (2 files)
```
app/services/pwb/provisioning_service.rb    (303 lines)
├─ 6 public methods
├─ 12 private methods
└─ Custom exceptions

app/services/pwb/subdomain_generator.rb     (167 lines)
├─ Name generation (Heroku-style)
├─ Validation logic
└─ Pool management
```

**Total Size:** ~17 KB  
**Dependencies:** AASM state machines, ActiveRecord

### Models (4 files)
```
app/models/pwb/
├─ website.rb                  (Uses existing model)
├─ user.rb                     (Uses existing model)
├─ subdomain.rb                (Uses existing model)
└─ user_membership.rb          (Uses existing model)
```

**Note:** These are NOT pure signup models - they're core domain models with signup-specific logic mixed in.

### Seeder (1 library)
```
lib/pwb/seeder.rb             (522 lines)
├─ Agency seeding
├─ Website defaults
├─ Property seeding
├─ Link seeding
└─ Photo handling
```

**Size:** ~20 KB  
**Dependencies:** YAML loading, ActiveStorage

### Routes (in config/routes.rb)
```ruby
# 8 signup-specific routes
get "/signup" => "signup#new"
post "/signup/start" => "signup#start"
get "/signup/configure" => "signup#configure"
post "/signup/configure" => "signup#save_configuration"
get "/signup/provisioning" => "signup#provisioning"
post "/signup/provision" => "signup#provision"
get "/signup/status" => "signup#status"
get "/signup/complete" => "signup#complete"
get "/signup/check_subdomain" => "signup#check_subdomain"
get "/signup/suggest_subdomain" => "signup#suggest_subdomain"
```

**Total Size:** 290 lines of code extracted

---

## Dependency Analysis

### Hard Dependencies (Required)

1. **Rails 7.0+**
   - ActionController::Base
   - ActiveRecord (models, transactions)
   - ActiveStorage (photo handling)
   - Rails.logger, SecureRandom

2. **AASM 5.0+**
   - State machines for Website and User
   - State machines for Subdomain

3. **ActiveRecord Models:**
   - Pwb::User (with onboarding state machine)
   - Pwb::Website (with provisioning state machine)
   - Pwb::Subdomain (with reservation state machine)
   - Pwb::UserMembership

4. **Database Tables:**
   ```sql
   pwb_users
   pwb_websites
   pwb_subdomains
   pwb_user_memberships
   pwb_agencies
   pwb_realty_assets
   pwb_sale_listings
   pwb_rental_listings
   pwb_links
   pwb_field_keys
   pwb_contacts
   ```

### Soft Dependencies (Optional Features)

1. **Devise** - For authentication (optional for extraction)
2. **I18n** - For translations in seeded content
3. **ActiveStorageDashboard** - For photo management (optional)
4. **Tailwind CSS** - For styling (can use alternate CSS)

### Environment Variables

```bash
# Required
PLATFORM_DOMAINS=propertywebbuilder.com,pwb.localhost

# Optional
TENANT_ADMIN_EMAILS=admin@example.com
R2_SEED_IMAGES_BUCKET=my-bucket
SEED_IMAGES_BASE_URL=https://cdn.example.com
RAILS_ENV=production|development|test
```

---

## Database Schema Requirements

### Critical Tables for Signup

#### pwb_users
```sql
CREATE TABLE pwb_users (
  id SERIAL PRIMARY KEY,
  email VARCHAR NOT NULL UNIQUE,
  password_digest VARCHAR,
  website_id INTEGER REFERENCES pwb_websites,
  onboarding_state VARCHAR (default 'lead'),
  onboarding_step INTEGER,
  onboarding_started_at TIMESTAMP,
  onboarding_completed_at TIMESTAMP,
  firebase_uid VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  -- Devise columns
  encrypted_password VARCHAR,
  sign_in_count INTEGER,
  failed_attempts INTEGER,
  locked_at TIMESTAMP,
  last_sign_in_at TIMESTAMP,
  last_sign_in_ip VARCHAR,
  current_sign_in_ip VARCHAR
);
```

#### pwb_websites
```sql
CREATE TABLE pwb_websites (
  id SERIAL PRIMARY KEY,
  subdomain VARCHAR UNIQUE,
  custom_domain VARCHAR UNIQUE,
  theme_name VARCHAR,
  site_type VARCHAR,
  company_display_name VARCHAR,
  provisioning_state VARCHAR (default 'pending'),
  provisioning_started_at TIMESTAMP,
  provisioning_completed_at TIMESTAMP,
  provisioning_error TEXT,
  seed_pack_name VARCHAR,
  default_client_locale VARCHAR,
  supported_locales TEXT[],
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### pwb_subdomains
```sql
CREATE TABLE pwb_subdomains (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL UNIQUE,
  website_id INTEGER REFERENCES pwb_websites,
  aasm_state VARCHAR (default 'available'),
  reserved_at TIMESTAMP,
  reserved_until TIMESTAMP,
  reserved_by_email VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### pwb_user_memberships
```sql
CREATE TABLE pwb_user_memberships (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES pwb_users,
  website_id INTEGER NOT NULL REFERENCES pwb_websites,
  role VARCHAR (enum: owner, admin, member, viewer),
  active BOOLEAN DEFAULT TRUE,
  UNIQUE(user_id, website_id),
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Supporting Tables (seeding)
```sql
pwb_agencies
pwb_realty_assets
pwb_sale_listings
pwb_rental_listings
pwb_links
pwb_field_keys
pwb_contacts
pwb_prop_photos
pwb_agency_photos
pwb_content_photos
pwb_translations (I18n)
```

---

## Extraction Strategies

### Strategy 1: Rails Engine (Recommended)

**Complexity:** Medium  
**Reusability:** High  
**Isolation:** Good  

```
lib/engines/pwb_signup/
├─ app/
│  ├─ controllers/pwb_signup/signup_controller.rb
│  ├─ views/pwb_signup/signup/
│  ├─ models/pwb_signup/ (minimal, extends host models)
│  └─ services/pwb_signup/
├─ lib/
│  ├─ pwb_signup.rb
│  └─ pwb_signup/version.rb
├─ config/
│  ├─ routes.rb
│  └─ initializers/
├─ Gemfile
├─ gemspec
└─ README.md
```

**Installation:**
```ruby
# In Gemfile
gem 'pwb_signup', path: 'lib/engines/pwb_signup'

# In routes.rb
mount PwbSignup::Engine => '/', as: 'pwb_signup'
```

### Strategy 2: Standalone Microservice

**Complexity:** High  
**Reusability:** Very High  
**Isolation:** Excellent  

```
propertywebbuilder-signup/
├─ app/
│  ├─ controllers/signup_controller.rb
│  ├─ views/signup/
│  ├─ models/
│  └─ services/
├─ config/
│  ├─ routes.rb
│  └─ database.yml
├─ Dockerfile
├─ docker-compose.yml
├─ Gemfile
├─ Procfile
└─ README.md
```

**API Contract:**
```
POST /api/v1/signup/start
{
  email: "user@example.com"
}
→ { user_id, subdomain, reserved_until }

POST /api/v1/signup/configure
{
  user_id, subdomain, site_type
}
→ { website_id, provisioning_state }

POST /api/v1/signup/provision
{
  website_id
}
→ { website_id, provisioning_state, progress }

GET /api/v1/signup/:website_id/status
→ { provisioning_state, progress, message, complete }
```

### Strategy 3: Modular Classes (Minimal)

**Complexity:** Low  
**Reusability:** Medium  
**Isolation:** Fair  

Simply move files to `app/signup/` and update require paths:

```
app/signup/
├─ controllers/signup_controller.rb
├─ views/
├─ services/
└─ generators/
```

---

## Refactoring for Extraction

### Issue 1: Tight Model Coupling

**Current:** State machines in User, Website, Subdomain models

**Solution:**
```ruby
# Extract into separate concern
module Pwb
  module Onboardable
    STATES = [:lead, :onboarding, :active].freeze
    # AASM configuration
  end
  
  module Provisionable
    STATES = [:pending, :configuring, :live].freeze
    # AASM configuration
  end
  
  class User < ApplicationRecord
    include Onboardable
  end
  
  class Website < ApplicationRecord
    include Provisionable
  end
end
```

### Issue 2: Service Dependencies on Pwb::Current

**Current:** ProvisioningService uses `Pwb::Current.website` for context

**Problem:** Tightly couples to global context  
**Solution:**
```ruby
# Refactor to dependency injection
class ProvisioningService
  def initialize(current_website: nil)
    @current_website = current_website
  end
  
  private
  
  def run_seed_pack
    Pwb::Seeder.seed!(website: @current_website)
  end
end

# Usage
service = ProvisioningService.new(current_website: website)
service.provision_website(website: website)
```

### Issue 3: Seeder Coupling to YAML Files

**Current:** Hardcoded file paths

**Solution:**
```ruby
# Make paths configurable
class Seeder
  def initialize(seed_path: Rails.root.join('db/yml_seeds'))
    @seed_path = seed_path
  end
  
  private
  
  def load_seed_yml(filename)
    YAML.load_file(@seed_path.join(filename))
  end
end
```

### Issue 4: View Template Tailwind CSS

**Current:** Views assume Tailwind is available

**Solution:** Abstract to CSS classes
```erb
<!-- Instead of inline Tailwind -->
<div class="<%= 'bg-white' if show_white %>">

<!-- Use CSS class hooks -->
<div class="signup-container">
  <div class="signup-form">
```

```css
/* Provide minimal CSS */
.signup-container { /* styles */ }
.signup-form { /* styles */ }
```

### Issue 5: Session-Based Flow

**Current:** Relies on Rails session for step tracking

**Problem:** Makes the flow stateful and server-dependent  
**Solution:**
```ruby
# Option A: Database-backed state
# Add signup_session table to track in-progress signups

# Option B: Encrypted URL parameters
# State passed via URL query params, validated with HMAC

# Option C: Keep session (simplest for engine approach)
# Document session dependency clearly
```

---

## Code Changes Required

### 1. Update Model Associations

```ruby
# Current
class User < ApplicationRecord
  belongs_to :website, optional: true
end

# For extraction, document clearly that website_id can be nil
# during signup, but must be set after Step 2
```

### 2. Extract Service Constants

```ruby
# Create signup configuration class
module Pwb::Signup
  class Config
    DEFAULT_THEME = 'bristol'
    DEFAULT_LOCALE = 'en'
    SUPPORTED_SITE_TYPES = %w[residential commercial vacation_rental]
    SUBDOMAIN_RESERVATION_DURATION = 10.minutes
    SUBDOMAIN_MIN_LENGTH = 3
    SUBDOMAIN_MAX_LENGTH = 40
  end
end
```

### 3. Add Feature Flags

```ruby
# Allow conditional seeding
module Pwb::Signup
  class Features
    def self.seed_sample_properties?
      ENV.fetch('SIGNUP_SEED_PROPERTIES', 'true') == 'true'
    end
    
    def self.require_email_verification?
      ENV.fetch('SIGNUP_REQUIRE_EMAIL_VERIFICATION', 'false') == 'true'
    end
    
    def self.use_seed_packs?
      ENV.fetch('SIGNUP_USE_SEED_PACKS', 'true') == 'true'
    end
  end
end
```

### 4. Create Error Classes

```ruby
module Pwb::Signup
  class SignupError < StandardError; end
  class InvalidEmailError < SignupError; end
  class SubdomainNotAvailableError < SignupError; end
  class ProvisioningError < SignupError; end
  class SeederError < SignupError; end
end
```

---

## Testing Strategy

### Unit Tests to Extract

```
spec/services/pwb/provisioning_service_spec.rb
spec/models/pwb/website_provisioning_spec.rb
spec/models/pwb/subdomain_spec.rb
spec/models/pwb/user_onboarding_spec.rb
```

### Tests to Refactor

```ruby
# Create isolated integration tests
describe "Signup Flow" do
  it "completes full signup process" do
    # Don't rely on database state from other tests
    # Seed subdomains in setup
    # Clean up after each test
  end
end
```

### Test Fixtures/Factories

```ruby
# Ensure factories are self-contained
FactoryBot.define do
  factory :pwb_website do
    subdomain { SecureRandom.hex(4) }
    site_type { 'residential' }
  end
  
  factory :pwb_subdomain do
    name { "#{SecureRandom.hex(4)}-test" }
    aasm_state { 'available' }
  end
end
```

---

## Integration Points

### 1. After Signup Completion

```ruby
# Host app should handle:
# - Email password reset link
# - Redirect to admin dashboard
# - Track signup metrics
# - Trigger welcome email

SignupMailer.send_welcome_email(user)
TenantSetupJob.perform_later(website_id)
```

### 2. Authentication

The signup system creates users but doesn't authenticate them. Host app must:

```ruby
# After Step 4 complete:
if user.active?
  sign_in user
end
```

### 3. Multi-Tenancy Context

Host app must ensure:

```ruby
# In request cycle
Pwb::Current.website = website_from_subdomain
```

### 4. Webhooks (for microservice)

```ruby
# Host app subscribes to:
# signup.started
# signup.completed
# signup.failed

SignupWebhook.on('signup.completed') do |event|
  user_id = event.data[:user_id]
  website_id = event.data[:website_id]
  
  # Trigger post-signup flows
end
```

---

## Configuration Example

```ruby
# config/initializers/pwb_signup.rb

Pwb::Signup.configure do |config|
  # Subdomain settings
  config.platform_domains = ENV['PLATFORM_DOMAINS'].split(',')
  config.subdomain_pool_minimum = 100
  config.subdomain_reservation_duration = 10.minutes
  
  # Provisioning settings
  config.default_theme = 'bristol'
  config.default_locale = 'en'
  config.seed_sample_properties = true
  config.seed_pack_path = Rails.root.join('db/seeds/packs')
  
  # Email settings
  config.send_welcome_email = true
  config.welcome_email_class = SignupMailer
  
  # Feature flags
  config.require_email_verification = false
  config.enable_custom_domain_during_signup = false
  config.enable_team_invitations = false
end
```

---

## Performance Checklist

- [ ] Subdomain pool pre-populated (1000+ entries)
- [ ] Theme list cached in memory
- [ ] Database indexes on frequently queried columns:
  - [ ] pwb_users(email)
  - [ ] pwb_websites(subdomain)
  - [ ] pwb_subdomains(name, aasm_state)
  - [ ] pwb_user_memberships(user_id, website_id)
- [ ] Seed data optimized:
  - [ ] Photo URLs use external CDN
  - [ ] Batch inserts for properties
  - [ ] Materialized view refresh optimized
- [ ] Provisioning moved to async job
- [ ] Logging structured, not chatty
- [ ] No N+1 queries in controller actions

---

## Security Checklist

- [ ] CSRF protection on all forms
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (use parameterized queries)
- [ ] Email validation before storing
- [ ] Session timeouts configured
- [ ] Rate limiting on signup endpoints
- [ ] Subdomain names validated against reserved words
- [ ] Temporary passwords never exposed
- [ ] Failed provisioning doesn't leak internal errors
- [ ] Audit logging for signup events
- [ ] No sensitive data in logs

---

## Deployment Considerations

### Database Migrations

```ruby
# Required migrations
rails g migration CreatePwbUsers
rails g migration CreatePwbWebsites
rails g migration CreatePwbSubdomains
rails g migration CreatePwbUserMemberships

# Optional but recommended
rails g migration AddIndexesToSignupTables
```

### Seeders

```bash
# Populate subdomain pool (required before signup works)
rails pwb:provisioning:populate_subdomains COUNT=1000

# Optional: load seed data
rails db:seed
```

### Environment Variables

```bash
# Production setup
export PLATFORM_DOMAINS="example.com,api.example.com"
export SIGNUP_SEED_PROPERTIES="true"
export SIGNUP_REQUIRE_EMAIL_VERIFICATION="false"
```

### Docker

```dockerfile
FROM ruby:3.2

WORKDIR /app

COPY Gemfile* ./
RUN bundle install

COPY . .

# Pre-compile assets
RUN rails assets:precompile

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
```

---

## Rollback Procedure

If signup encounters fatal errors:

```ruby
# Option 1: Delete signup session (user restarts)
session.delete(:signup_user_id)
session.delete(:signup_subdomain)
session.delete(:signup_website_id)

# Option 2: Soft delete created resources
website.destroy
subdomain.release! if subdomain.may_release?
user.mark_churned! if user.may_mark_churned?

# Option 3: Move website to failed state and allow retry
website.fail_provisioning!(error_message)
# User clicks "Retry" button
```

---

## Monitoring Queries

```sql
-- Active signups in progress
SELECT COUNT(*) FROM pwb_users WHERE onboarding_state = 'onboarding';

-- Pending websites
SELECT COUNT(*) FROM pwb_websites WHERE provisioning_state IN ('pending', 'configuring', 'seeding');

-- Subdomain pool health
SELECT aasm_state, COUNT(*) FROM pwb_subdomains GROUP BY aasm_state;

-- Signup conversion funnel
SELECT 
  onboarding_state,
  COUNT(*) as count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) as percentage
FROM pwb_users
GROUP BY onboarding_state
ORDER BY count DESC;

-- Failed provisioning
SELECT * FROM pwb_websites 
WHERE provisioning_state = 'failed' 
ORDER BY updated_at DESC;

-- Expired reservations (should be cleaned)
SELECT COUNT(*) FROM pwb_subdomains 
WHERE aasm_state = 'reserved' 
AND reserved_until < NOW();
```

---

## Final Considerations

1. **Backward Compatibility:** Ensure extracted component doesn't break existing host app
2. **Version Management:** Use semantic versioning
3. **Documentation:** Include API docs and architecture diagrams
4. **Examples:** Provide working example app
5. **Contributing:** Set up CI/CD for the component
6. **Support:** Document how to report issues
7. **Licensing:** Clarify license for extracted component

