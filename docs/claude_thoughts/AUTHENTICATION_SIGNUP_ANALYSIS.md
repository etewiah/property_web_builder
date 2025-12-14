# Authentication, Signup Flow, and Website Access Control Analysis

**Analysis Date**: December 14, 2025  
**Status**: Complete analysis of current implementation  
**Purpose**: Understanding signup flow, authentication mechanisms, and website access control for implementing magic links

---

## 1. SIGNUP FLOW OVERVIEW

### 1.1 Current Signup Process (4 Steps)

The application uses a **4-step signup wizard** with two implementations:

1. **API-driven approach** (recommended for decoupled UIs):
   - `Api::Signup::SignupsController` - RESTful API endpoints
   - Token-based state tracking (not session-based)

2. **UI-driven approach** (legacy):
   - `Pwb::SignupController` - Traditional form submissions
   - Session-based state tracking

### 1.2 Step-by-Step Flow

#### STEP 1: Email Capture
**File**: `app/controllers/api/signup/signups_controller.rb:32-54`  
**Endpoint**: `POST /api/signup/start`

```
User enters email
    ↓
SignupApiService.start_signup(email)
    ↓
Creates Pwb::User with state "lead"
Creates signup_token (24-hour expiry)
Reserves subdomain from pool
    ↓
Returns: { signup_token, subdomain }
```

**Database Impact**:
- Creates user record with minimal data (auto-confirms email)
- Generates temporary password
- Stores `signup_token` and `signup_token_expires_at` on user

**Key File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/signup_api_service.rb:20-66`

```ruby
def start_signup(email:)
  user = Pwb::User.new(
    email: email,
    password: SecureRandom.hex(16), # Temporary
    confirmed_at: Time.current # Auto-confirm
  )
  user.save(validate: false)
  
  token = SecureRandom.urlsafe_base64(32)
  user.update_columns(signup_token: token, signup_token_expires_at: 24.hours.from_now)
  
  subdomain = reserve_subdomain_for_user(email)
  { success: true, user: user, subdomain: subdomain, signup_token: token }
end
```

#### STEP 2: Site Configuration
**File**: `app/controllers/api/signup/signups_controller.rb:56-97`  
**Endpoint**: `POST /api/signup/configure`

```
User selects subdomain and site type
    ↓
SignupApiService.configure_site(user, subdomain, site_type)
    ↓
Validates subdomain
Creates Pwb::Website record with state "pending"
Creates UserMembership with role "owner"
Transitions website to "owner_assigned" state
    ↓
Returns: { website_id, subdomain, site_type }
```

**Key File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/signup_api_service.rb:84-139`

#### STEP 3: Website Provisioning
**File**: `app/controllers/api/signup/signups_controller.rb:99-143`  
**Endpoint**: `POST /api/signup/provision`

```
Triggers provisioning workflow
    ↓
ProvisioningService.provision_website()
    ↓
State machine transitions:
  pending → owner_assigned → agency_created → links_created 
  → field_keys_created → properties_seeded → ready → live
    ↓
Returns: { provisioning_status, progress, complete }
```

**AASM States** (Website): `app/models/pwb/website.rb:55-156`
- `pending` (0%)
- `owner_assigned` (15%) - Owner membership created
- `agency_created` (30%) - Agency record created
- `links_created` (45%) - Navigation links seeded
- `field_keys_created` (60%) - Property field keys created
- `properties_seeded` (80%) - Sample properties added
- `ready` (95%) - All setup complete
- `live` (100%) - Publicly accessible
- `failed` - Provisioning error
- `suspended`, `terminated` - Lifecycle states

**Guards/Validators** (checked before state transitions):
- `has_owner?` - Owner membership exists
- `has_agency?` - Agency record exists
- `has_links?` - At least 3 navigation links
- `has_field_keys?` - At least 5 field keys
- `provisioning_complete?` - All required steps done
- `can_go_live?` - Subdomain + all requirements met

#### STEP 4: Completion
**File**: `app/controllers/api/signup/signups_controller.rb:145-203`  
**Endpoint**: `GET /api/signup/status`

```
Poll for provisioning completion
    ↓
If website.live?:
  Returns website_url and admin_url
  Signup is complete
Else:
  Returns current progress and status message
```

---

## 2. AUTHENTICATION SYSTEM

### 2.1 Dual Authentication Architecture

The app supports **two independent authentication methods**:

#### A. Devise (Traditional)
**Location**: `app/models/pwb/user.rb:21-24`

**Enabled Modules**:
- `:database_authenticatable` - Email/password login
- `:registerable` - Registration support
- `:recoverable` - Password reset
- `:rememberable` - Remember me cookie
- `:trackable` - Login analytics (IP, count, timestamps)
- `:validatable` - Email/password validation
- `:lockable` - Account lockout (5 attempts)
- `:timeoutable` - Session timeout (30 minutes)
- `:omniauthable` - OAuth support
  - Facebook via OmniAuth
  - Google via Firebase (separate integration)

**Configuration**: `config/initializers/devise.rb`

**Controllers**:
- `app/controllers/pwb/devise/sessions_controller.rb` - Login/logout
- `app/controllers/pwb/devise/passwords_controller.rb` - Password reset
- `app/controllers/pwb/devise/registrations_controller.rb` - Registration
- `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` - Facebook OAuth

#### B. Firebase Authentication
**Location**: `app/services/pwb/firebase_auth_service.rb`

**Method**:
1. User logs in via FirebaseUI (email/password or Google)
2. Firebase returns JWT token
3. Client sends token to `POST /api_public/v1/auth/firebase`
4. Rails verifies JWT signature using `firebase_id_token` gem
5. Auto-creates user if first login
6. Creates membership with 'member' role

**Key File**: `app/controllers/api_public/v1/auth_controller.rb:6-53`

### 2.2 User Model & Onboarding States

**File**: `app/models/pwb/user.rb`

**AASM Onboarding State Machine**:
```ruby
aasm column: :onboarding_state do
  state :lead, initial: true              # Just provided email
  state :registered                       # Account created
  state :email_verified                   # Email verified
  state :onboarding                       # Going through wizard
  state :active                           # Fully onboarded
  state :churned                          # Abandoned signup
end
```

**Onboarding Step Tracking**:
```ruby
ONBOARDING_STEPS = {
  1 => 'Verify Email',
  2 => 'Choose Subdomain',
  3 => 'Select Site Type',
  4 => 'Setup Complete'
}
```

**Key User Attributes**:
- `signup_token` - For API-based signup tracking
- `signup_token_expires_at` - Token expiration (24 hours)
- `website_id` - Primary website (legacy, now has_many)
- `onboarding_state` - Current state in onboarding
- `onboarding_step` - Current step (1-4)
- `onboarding_started_at` - When onboarding began
- `onboarding_completed_at` - When onboarding finished
- `firebase_uid` - If authenticating via Firebase

**Multi-Website Support**:
```ruby
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships
```

---

## 3. WEBSITE ACCESS CONTROL

### 3.1 Access Control Model

**Base Implementation**: Role-based multi-tenant access via `Pwb::UserMembership`

**File**: `app/models/pwb/user_membership.rb`

**Available Roles**:
```ruby
ROLES = %w[owner admin member viewer].freeze
```

**Role Hierarchy**:
- `owner` - Full website control, can manage all users
- `admin` - Can edit content and manage some users
- `member` - Can edit content
- `viewer` - Read-only access

### 3.2 Access Control Flow

**1. User Registration/OAuth**: Creates membership with 'member' role
**2. First Owner**: Automatically assigned 'owner' role during signup
**3. Subsequent Users**: Can be invited/granted 'admin', 'member', or 'viewer' roles

**Grant/Revoke Access**:
```ruby
# File: app/services/pwb/user_membership_service.rb
UserMembershipService.grant_access(user: user, website: website, role: 'member')
UserMembershipService.revoke_access(user: user, website: website)
UserMembershipService.change_role(user: user, website: website, new_role: 'admin')
```

### 3.3 Website Access Verification

**Primary Method**: `Pwb::User.active_for_authentication?`

**File**: `app/models/pwb/user.rb:149-166`

```ruby
def active_for_authentication?
  return false unless super  # Devise's default checks
  
  return true if current_website.blank?  # No context = allow
  
  return true if website_id == current_website.id  # Primary website
  
  return true if user_memberships.active.exists?(website: current_website)  # Has membership
  
  return true if firebase_uid.present?  # Firebase users auto-allowed
  
  false  # No access
end
```

**Helper Method**: `User.can_access_website?(website)`
```ruby
def can_access_website?(website)
  return false unless website
  website_id == website.id || user_memberships.active.exists?(website: website)
end
```

### 3.4 Website State & Accessibility

**File**: `app/models/pwb/website.rb:230-238`

**Accessible States**:
```ruby
def accessible?
  live? || ready?  # Only live or ready websites visible
end

def provisioning?
  %w[pending owner_assigned agency_created links_created 
     field_keys_created properties_seeded].include?(provisioning_state)
end
```

**Current Website Context** (for tenant isolation):
```ruby
# File: app/models/pwb/current.rb
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end

# Usage in controllers/services:
Pwb::Current.website = website_from_subdomain_or_domain
```

---

## 4. TOKEN-BASED AUTHENTICATION (Magic Links)

### 4.1 Existing Token Patterns

#### A. Signup Token (Just Implemented!)
**Location**: `db/migrate/20251212175813_add_signup_token_to_users.rb`

**Fields**:
- `signup_token` (string, unique index)
- `signup_token_expires_at` (datetime)

**Usage**:
- Generated during signup
- 24-hour expiry
- Validates in `SignupApiService.find_user_by_token()`
- Passed in API requests to identify user across steps

**Example**:
```ruby
POST /api/signup/configure
{
  signup_token: "abc123xyz",
  subdomain: "my-site",
  site_type: "residential"
}
```

#### B. Devise Password Reset Token
**Built-in Devise feature** (`:recoverable` module)

**Auto-generated** by Devise when user requests password reset  
**Storage**: `reset_password_token` and `reset_password_sent_at` columns (auto-created)  
**Expiry**: 6 hours (configurable)  
**Usage**: User clicks link → reset password flow

#### C. Firebase JWT Tokens
**Method**: Firebase backend generates JWT  
**Verification**: Rails verifies using `firebase_id_token` gem  
**No DB storage**: Tokens verified cryptographically

### 4.2 Recommended Magic Link Pattern

Based on the existing signup token implementation, here's the recommended pattern:

**1. Create Migration**:
```ruby
add_column :pwb_users, :magic_link_token, :string
add_column :pwb_users, :magic_link_expires_at, :datetime
add_index :pwb_users, :magic_link_token, unique: true
```

**2. Generate Token** (similar to signup_token):
```ruby
token = SecureRandom.urlsafe_base64(32)
user.update_columns(
  magic_link_token: token,
  magic_link_expires_at: 24.hours.from_now
)
```

**3. Verify Token**:
```ruby
def self.find_by_magic_token(token)
  return nil if token.blank?
  user = find_by(magic_link_token: token)
  return nil unless user
  return nil if user.magic_link_expires_at && user.magic_link_expires_at < Time.current
  user
end
```

**4. Controller Action**:
```ruby
def magic_login
  token = params[:token]
  user = Pwb::User.find_by_magic_token(token)
  
  if user
    sign_in(user)  # Devise helper
    redirect_to authenticated_root_path
  else
    redirect_to login_path, alert: "Invalid or expired link"
  end
end
```

**5. Route**:
```ruby
get '/magic-login/:token', to: 'sessions#magic_login'
```

**6. Email Helper** (existing pattern - Devise uses ActionMailer):
```ruby
# config/initializers/devise.rb already configured for ActionMailer
# Just create app/mailers/pwb/user_mailer.rb with magic_link method
```

---

## 5. WEBSITE PROVISIONING & SEEDING

### 5.1 Provisioning Service

**File**: `app/services/pwb/provisioning_service.rb`

**Three Main Methods**:

1. `start_signup(email)` - Creates user, reserves subdomain
2. `configure_site(user, subdomain, site_type)` - Creates website, owner membership
3. `provision_website(website)` - Runs seeding, state transitions

### 5.2 Website State Machine & Guards

**File**: `app/models/pwb/website.rb:43-156`

**Provisioning Checklist**:
```ruby
def provisioning_checklist
  {
    owner: { complete: has_owner?, required: true },
    agency: { complete: has_agency?, required: true },
    links: { complete: has_links?, count: links.count, minimum: 3, required: true },
    field_keys: { complete: has_field_keys?, count: field_keys.count, minimum: 5, required: true },
    properties: { complete: realty_assets.any?, count: realty_assets.count, required: false },
    subdomain: { complete: subdomain.present?, value: subdomain, required: true }
  }
end
```

**Progress Calculation**:
```ruby
def provisioning_progress
  case provisioning_state
  when 'pending' then 0
  when 'owner_assigned' then 15
  when 'agency_created' then 30
  when 'links_created' then 45
  when 'field_keys_created' then 60
  when 'properties_seeded' then 80
  when 'ready' then 95
  when 'live' then 100
  else 0
  end
end
```

---

## 6. KEY FILES SUMMARY

### Authentication & Signup

| File | Purpose |
|------|---------|
| `app/models/pwb/user.rb` | User model with Devise + AASM states |
| `app/services/pwb/signup_api_service.rb` | API signup service (start, configure, provision) |
| `app/controllers/api/signup/signups_controller.rb` | Signup API endpoints |
| `app/controllers/pwb/signup_controller.rb` | Traditional signup UI |
| `app/services/pwb/provisioning_service.rb` | Website provisioning orchestration |
| `db/migrate/20251212175813_add_signup_token_to_users.rb` | Signup token columns |

### Access Control

| File | Purpose |
|------|---------|
| `app/models/pwb/user_membership.rb` | Role-based membership model |
| `app/services/pwb/user_membership_service.rb` | Grant/revoke access |
| `app/models/pwb/website.rb` | Website with provisioning states |
| `app/models/pwb/current.rb` | Tenant context (Current.website) |

### Devise/Authentication

| File | Purpose |
|------|---------|
| `config/initializers/devise.rb` | Devise configuration |
| `app/controllers/pwb/devise/sessions_controller.rb` | Login/logout |
| `app/controllers/pwb/devise/passwords_controller.rb` | Password reset |
| `app/controllers/pwb/devise/registrations_controller.rb` | Registration |
| `app/controllers/pwb/auth_controller.rb` | Unified auth (logout) |

### Firebase Authentication

| File | Purpose |
|------|---------|
| `app/services/pwb/firebase_auth_service.rb` | Firebase token verification |
| `app/controllers/api_public/v1/auth_controller.rb` | Firebase auth endpoint |
| `app/models/pwb/authorization.rb` | OAuth provider links |

### Audit Logging

| File | Purpose |
|------|---------|
| `app/models/pwb/auth_audit_log.rb` | Auth event logging |
| `config/initializers/auth_audit_hooks.rb` | Hooks to log events |

---

## 7. USER ONBOARDING FLOW

### Current Implementation

**State Transitions**:
```
lead (email captured)
  ↓
registered (account created via signup)
  ↓
email_verified (optional verification step)
  ↓
onboarding (multi-step wizard)
  ↓
active (fully onboarded)

Escape: churned → reactivate → lead
```

**Step Tracking** (1-4):
1. Verify Email
2. Choose Subdomain
3. Select Site Type
4. Setup Complete

**Helper Methods**:
```ruby
user.needs_onboarding?  # true if not :active
user.onboarding_progress_percentage  # 0-100
user.advance_onboarding_step!  # Move to next step
user.onboarding_step_title  # Get current step label
```

---

## 8. MULTI-WEBSITE SUPPORT

### Implementation

**User Model**:
```ruby
belongs_to :website, optional: true  # Legacy primary
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships
```

**Website Model**:
```ruby
has_many :user_memberships, dependent: :destroy
has_many :members, through: :user_memberships, source: :user
```

**UserMembership Model**:
```ruby
belongs_to :user
belongs_to :website
validates :role, inclusion: { in: ROLES }
scope :active, -> { where(active: true) }
scope :admins, -> { where(role: ['owner', 'admin']) }
```

### Access Patterns

```ruby
# User accessing their websites
current_user.accessible_websites  # All active memberships

# Admin checking user roles
user.admin_for?(website)
user.role_for(website)  # Returns 'owner', 'admin', 'member', 'viewer'

# Website checking permissions
website.admins  # All admin/owner members
website.members  # All members (through association)
```

---

## 9. RECOMMENDATIONS FOR MAGIC LINKS

### Implementation Strategy

1. **Add Token Fields** (Migration):
   ```ruby
   add_column :pwb_users, :magic_link_token, :string
   add_column :pwb_users, :magic_link_expires_at, :datetime
   add_index :pwb_users, :magic_link_token, unique: true
   ```

2. **Service Class** (Pattern from SignupApiService):
   ```ruby
   class MagicLinkService
     TOKEN_EXPIRY = 24.hours
     
     def generate_token(user)
       token = SecureRandom.urlsafe_base64(32)
       user.update_columns(
         magic_link_token: token,
         magic_link_expires_at: TOKEN_EXPIRY.from_now
       )
       token
     end
     
     def find_user_by_token(token)
       user = User.find_by(magic_link_token: token)
       return nil unless user
       return nil if user.magic_link_expires_at < Time.current
       user
     end
   end
   ```

3. **Controller Action** (Pattern from signup):
   ```ruby
   def magic_login
     token = params[:token]
     user = MagicLinkService.new.find_user_by_token(token)
     
     if user
       sign_in(user)
       user.update_columns(magic_link_token: nil)  # Clear token
       redirect_to authenticated_root_path
     else
       redirect_to login_path, alert: "Link expired"
     end
   end
   ```

4. **Email Delivery** (Use existing Devise mailer):
   ```ruby
   # app/mailers/pwb/user_mailer.rb
   def magic_link(user, token)
     @user = user
     @magic_link_url = magic_login_url(token: token, host: website_host)
     mail(to: user.email, subject: "Your login link")
   end
   ```

5. **Route**:
   ```ruby
   get '/magic-login/:token', to: 'sessions#magic_login'
   post '/request-magic-link', to: 'sessions#request_magic_link'
   ```

### Security Considerations

- Use `SecureRandom.urlsafe_base64(32)` (matches signup_token)
- Set 24-hour expiry (matches signup_token)
- Unique index prevents token reuse
- One-time use: clear token after login
- Clear expired tokens periodically (job)
- Rate limit magic link requests (optional)
- Log magic link events in AuthAuditLog

---

## 10. KEY INSIGHTS

### What's Working Well

1. **Signup Token System** - Already implements the exact pattern needed for magic links
2. **AASM State Machines** - Clean state management for both users and websites
3. **Multi-Website Architecture** - UserMembership properly isolates access
4. **Dual Authentication** - Devise + Firebase provide flexibility
5. **Audit Logging** - All auth events captured in AuthAuditLog
6. **Provisioning Guards** - AASM guards ensure data integrity during setup

### Potential Issues

1. **Signup Token Usage** - Currently used for multi-step API signup; magic links would use different token
2. **Session Management** - HTTP-only cookies but not domain-isolated (single subdomain per session)
3. **Password Reset vs Magic Link** - Devise's recoverable module covers password reset but not passwordless login
4. **Firebase Integration** - Separate from Devise; must ensure both auth paths create proper memberships

### Recommended Next Steps

1. Create `MagicLinkService` following `SignupApiService` pattern
2. Add `magic_link_token` and `magic_link_expires_at` columns
3. Implement `Sessions#request_magic_link` (POST) and `Sessions#magic_login` (GET)
4. Add magic link option to login page alongside email/password
5. Email template using existing `Pwb::UserMailer`
6. Log magic link events in `AuthAuditLog`
7. Add tests in `spec/requests/sessions_spec.rb` (pattern from `signups_spec.rb`)

---

## References

- **Signup API Tests**: `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/api/signup/signups_spec.rb`
- **Auth Documentation**: `/Users/etewiah/dev/sites-older/property_web_builder/docs/AUTHENTICATION_AND_AUTHORIZATION_SUMMARY.md`
- **Devise Config**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/devise.rb`
- **Architecture Docs**: `/Users/etewiah/dev/sites-older/property_web_builder/docs/claude_thoughts/`
