# Authentication System Analysis Report - PropertyWebBuilder

**Date**: December 7, 2025  
**Project**: PropertyWebBuilder (PWB)  
**Framework**: Rails 8.0  
**Analysis Scope**: Complete authentication architecture review

---

## Executive Summary

PropertyWebBuilder implements a multi-faceted authentication and authorization system supporting both traditional email/password login and OAuth (Facebook) social authentication. The system is designed around a multi-tenant architecture where each website is a tenant with role-based user management through memberships. This report provides a detailed analysis of the authentication architecture, identifying current implementation details, security considerations, and potential improvement areas.

---

## 1. Authentication Gems and Configuration

### 1.1 Key Authentication Gems

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/Gemfile`

#### Installed Gems:
- **devise (~> 4.8)**: Primary authentication framework for user sessions and password management
- **omniauth (~> 2.1)**: OAuth framework for social login integration
- **omniauth-facebook**: Facebook OAuth provider
- **firebase_id_token (~> 2.5)**: Firebase ID token verification for alternative authentication flow
- **firebase**: Firebase client for real-time features
- **acts_as_tenant (~> 1.0)**: Multi-tenancy with automatic model scoping

### 1.2 Devise Configuration

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/devise.rb`

#### Key Settings:
```ruby
# Authentication strategy
devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable,
  :validatable, :omniauthable, omniauth_providers: [:facebook]

# Password configuration
config.stretches = Rails.env.test? ? 1 : 11  # bcrypt cost factor
config.password_length = 6..128

# Email configuration
config.case_insensitive_keys = [:email]      # Case-insensitive email lookup
config.strip_whitespace_keys = [:email]      # Whitespace trimming
config.email_regexp = /\A[^@\s]+@[^@\s]+\z/  # Email validation

# Password reset
config.reset_password_within = 6.hours

# Remember me token expiration
config.expire_all_remember_me_on_sign_out = true

# OmniAuth
config.omniauth_path_prefix = '/users/auth'

# Confirmation
config.reconfirmable = true  # Email reconfirmation required for changes

# Session security
config.skip_session_storage = [:http_auth]

# Sign out HTTP method
config.sign_out_via = :delete

# Parent controller for custom hooks
config.parent_controller = "Pwb::DeviseController"
```

### 1.3 Firebase Configuration

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/firebase_id_token.rb`

```ruby
FirebaseIdToken.configure do |config|
  config.project_ids = [ENV['FIREBASE_PROJECT_ID']]
  # Optional Redis caching for certificate performance
  config.redis = redis if available
end
```

### 1.4 Session Storage

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/session_store.rb`

```ruby
# Development/Test: Cache store
# Production: Cookie store (secure by default)
Rails.application.config.session_store :cookie_store, key: '_pwb_session'
```

---

## 2. User Models and Related Models

### 2.1 Primary User Model

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`

#### Key Characteristics:
- **NOT tenant-scoped** (by design for flexibility)
- Designed for console work and cross-tenant operations
- Inherits all Devise modules

#### Database Columns:
```ruby
# Authentication
email                    # NOT NULL, UNIQUE
encrypted_password       # Bcrypt hashed
authentication_token     # Legacy token field

# Password Recovery
reset_password_token     # UNIQUE
reset_password_sent_at

# Session Tracking
remember_created_at
sign_in_count (default: 0)
current_sign_in_at
last_sign_in_at
current_sign_in_ip
last_sign_in_ip

# Email Confirmation
confirmation_token       # UNIQUE
confirmed_at
confirmation_sent_at
unconfirmed_email        # For reconfirmation

# Account Lockout
failed_attempts (default: 0)
unlock_token
locked_at

# Authorization
admin (default: false)   # Global admin flag
website_id (NULLABLE)    # Legacy single-website support

# User Profile
first_names
last_names
skype
phone_number_primary
default_client_locale
default_admin_locale
default_currency

# Timestamps
created_at, updated_at
```

#### Key Associations:
```ruby
belongs_to :website, optional: true
has_many :authorizations                # OAuth providers
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships
```

#### Authentication Methods:
```ruby
def admin_for?(website)
  # Check if user has owner or admin role for website
  user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
end

def role_for(website)
  # Get user's role for specific website
  user_memberships.active.find_by(website: website)&.role
end

def accessible_websites
  # Get all websites user is member of
  websites.where(pwb_user_memberships: { active: true })
end

def active_for_authentication?
  # Validate user can authenticate on their assigned website/subdomain
  super && website.present? && (current_website.blank? || website_id == current_website&.id)
end
```

#### OAuth Integration:
```ruby
def self.find_for_oauth(auth, website: nil)
  # Find or create user from OAuth provider
  authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s).first
  return authorization.user if authorization

  # Create new user if doesn't exist
  email = auth.info[:email]
  unless email.present?
    email = "#{SecureRandom.urlsafe_base64}@example.com"
  end
  
  user = User.where(email: email).first
  if user
    user.create_authorization(auth)
  else
    password = ::Devise.friendly_token[0, 20]
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      website: website || Pwb::Current.website || Pwb::Website.first
    )
    user.create_authorization(auth)
  end
  user
end

def create_authorization(auth)
  authorizations.create(provider: auth.provider, uid: auth.uid)
end
```

### 2.2 Tenant-Scoped User Model

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/user.rb`

```ruby
class PwbTenant::User < Pwb::User
  include RequiresTenant
  acts_as_tenant :website, class_name: 'Pwb::Website'
end
```

**Purpose**: Automatically scopes all queries to the current tenant (website)
**Use in**: Web requests where tenant isolation is required

### 2.3 Authorization Model (OAuth)

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/authorization.rb`

```ruby
class Authorization < ApplicationRecord
  belongs_to :user
  
  # Stores OAuth provider information
  # provider: 'facebook', 'google', etc.
  # uid: unique identifier from provider
end
```

### 2.4 User Membership Model (Role-Based Access)

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user_membership.rb`

#### Role Hierarchy:
```ruby
ROLES = %w[owner admin member viewer].freeze
```

#### Key Features:
```ruby
# Associations
belongs_to :user, class_name: 'Pwb::User'
belongs_to :website, class_name: 'Pwb::Website'

# Validations
validates :role, inclusion: { in: ROLES }
validates :user_id, uniqueness: { scope: :website_id }
validates :active, inclusion: { in: [true, false] }

# Scopes
scope :active, -> { where(active: true) }
scope :admins, -> { where(role: ['owner', 'admin']) }
scope :owners, -> { where(role: 'owner') }

# Helper Methods
def admin?
  role.in?(['owner', 'admin'])
end

def owner?
  role == 'owner'
end

def can_manage?(other_membership)
  return false unless active?
  role_level > other_membership.role_level
end
```

#### Database Schema:
```ruby
create_table :pwb_user_memberships do |t|
  t.references :user, null: false, foreign_key: { to_table: :pwb_users }
  t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
  t.string :role, null: false, default: 'member'
  t.boolean :active, default: true, null: false
  t.timestamps
  
  t.index [:user_id, :website_id], unique: true
end
```

---

## 3. Authentication Controllers

### 3.1 Devise Base Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise_controller.rb`

```ruby
class DeviseController < ApplicationController
  layout "pwb/devise"

  def after_sign_out_path_for(_resource_or_scope)
    home_path
  end

  def after_sign_in_path_for(_resource_or_scope)
    admin_path  # TODO: check for admin v standard users
  end
end
```

### 3.2 Sessions Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/sessions_controller.rb`

#### Key Features:
- Subdomain tenant detection via `SubdomainTenant` concern
- Website validation on sign-in
- Prevents cross-subdomain authentication

```ruby
class SessionsController < ::Devise::SessionsController
  include SubdomainTenant
  before_action :validate_user_website, only: [:create]

  protected

  def validate_user_website
    # Ensure user belongs to current website/subdomain
    email = sign_in_params[:email]
    user = Pwb::User.find_by(email: email)
    current_site = current_website_from_subdomain
    
    if user.website_id != current_site&.id
      flash[:alert] = "You don't have access to this subdomain..."
      redirect_to new_user_session_path
    end
  end

  def sign_in_params
    params.fetch(:user, {}).permit(:email, :password, :remember_me)
  end
end
```

### 3.3 Registrations Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/registrations_controller.rb`

```ruby
class RegistrationsController < Devise::RegistrationsController
  def after_update_path_for(_resource)
    pwb.user_edit_success_path
  end
end
```

### 3.4 OmniAuth Callbacks

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/omniauth_callbacks_controller.rb`

```ruby
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    I18n.locale = session[:omniauth_login_locale] || I18n.default_locale
    
    @user = Pwb::User.find_for_oauth(request.env['omniauth.auth'])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Facebook')
    end
  end
end
```

### 3.5 Localized OmniAuth Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/omniauth_controller.rb`

```ruby
class OmniauthController < ApplicationController
  def localized
    # Save locale in session before redirecting to provider
    session[:omniauth_login_locale] = I18n.locale
    redirect_to omniauth_authorize_path("user", params[:provider])
  end
end
```

### 3.6 Firebase Login Views Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/firebase_login_controller.rb`

```ruby
class FirebaseLoginController < ApplicationController
  layout 'pwb/devise'

  def index
    # Firebase login page
  end

  def sign_up
    # Firebase signup page
  end

  def forgot_password
    # Password recovery via Firebase
  end

  def change_password
    # Requires authenticated user
  end
end
```

---

## 4. Authentication Flows

### 4.1 Email/Password Registration Flow

**Route**: `POST /users` (Devise registrations)

```
1. User visits signup page
2. Submits email, password, password_confirmation
3. Devise validates credentials
4. User created with encrypted_password via bcrypt
5. Email confirmation token generated (if enabled)
6. Confirmation email sent
7. User must click confirmation link
8. User account activated
9. User redirected to admin path after confirmation
```

#### Security Features:
- Bcrypt password hashing (cost factor: 11 in production, 1 in test)
- Email confirmation required
- Password validation: 6-128 characters
- Case-insensitive email lookup
- Whitespace trimming on email

### 4.2 Email/Password Login Flow

**Route**: `POST /users/sign_in` (Devise sessions)

```
1. User visits login page
2. Submits email and password
3. Sessions controller validates_user_website
   - Ensures user's website_id matches current subdomain
   - Prevents cross-subdomain authentication
4. Devise authenticates credentials against encrypted_password
5. Sign in count incremented
6. Current/last sign-in IP and timestamp recorded
7. Session created
8. User redirected to admin_path
```

#### Session Management:
- Session stored in secure cookie (`_pwb_session`)
- Remember-me token available (expires on sign-out)
- Tracked sign-in: count, timestamp, IP address
- CSRF protection enabled

### 4.3 Facebook OAuth Flow

**Route**: `GET /omniauth/:provider` (localized)

```
1. User clicks "Login with Facebook"
2. OmniauthController#localized saves locale in session
3. Redirects to Facebook OAuth authorize endpoint
4. User authenticates with Facebook
5. Facebook redirects to callback with auth code
6. OmniauthCallbacks#facebook handles response
7. User.find_for_oauth processes auth data:
   a. Checks if Authorization exists (linked account)
      - If exists, returns associated user
   b. If not, checks if user with email exists
      - If exists, creates Authorization
   c. If not, creates new user with random password
8. User signed in automatically
9. Redirected to admin_path
```

#### Key Implementation Details:
- Email fallback: `"#{SecureRandom.urlsafe_base64}@example.com"` if not provided
- Random password generated: 20-character Devise friendly token
- Authorization model links provider + uid to user
- Locale preserved through session

### 4.4 Firebase Authentication Flow

**Alternative flow for client-side Firebase authentication**

```
1. Client-side Firebase SDK handles login
2. User receives Firebase ID token
3. Token sent to server (implementation TBD)
4. FirebaseIdToken.verify validates token
5. User looked up or created based on Firebase UID
6. User signed in to Rails session
```

**Note**: This flow appears partially implemented with gem installed but not fully integrated.

### 4.5 Password Reset Flow

**Route**: `GET/POST /users/password` (Devise recoverable)

```
1. User visits password reset page
2. Enters email address
3. Devise generates reset_password_token
4. Token set in DB with reset_password_sent_at timestamp
5. Email with reset link sent
6. User clicks link with token
7. User enters new password
8. Token validated and password updated
9. User can sign in with new password
10. Expires after 6 hours
```

#### Configuration:
```ruby
config.reset_password_within = 6.hours
config.sign_in_after_reset_password = false  # User must sign in
```

### 4.6 Email Confirmation/Reconfirmation Flow

**Route**: `GET /users/confirmation` (Devise confirmable)

```
1. User registration generates confirmation_token
2. Confirmation email sent to unconfirmed_email
3. Token stored with confirmation_sent_at timestamp
4. User clicks confirmation link
5. Token validated
6. Email moved to confirmed_at, confirmed_at timestamp set
7. User can now sign in
8. If email changed, reconfirmation required (config.reconfirmable = true)
```

---

## 5. Authorization and Access Control

### 5.1 Role-Based Access Control (RBAC)

**Role Hierarchy** (from most to least privileged):
```ruby
ROLES = %w[owner admin member viewer].freeze

owner   # Full control, can manage other admins
admin   # Can manage most resources
member  # Can access assigned resources
viewer  # Read-only access
```

### 5.2 Admin Access Control

#### Admin Panel Gating

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/admin_panel_controller.rb`

```ruby
def show
  unless bypass_admin_auth? || (current_user && user_is_admin_for_subdomain?)
    render 'pwb/errors/admin_required'
  end
end

private

def user_is_admin_for_subdomain?
  return false unless current_user
  return false unless request.subdomain.present?
  
  website = Pwb::Website.find_by_subdomain(request.subdomain)
  return false unless website
  
  # Check if user has admin/owner role for this specific website
  current_user.admin_for?(website)
end
```

#### Site-Specific Admin Controller

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin_controller.rb`

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  include AdminAuthBypass
  
  before_action :set_tenant_from_subdomain
  before_action :authenticate_user!, unless: :bypass_admin_auth?

  # All PwbTenant:: models auto-scoped to current_website via acts_as_tenant
end
```

#### Tenant Admin Controller (Cross-Tenant)

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin_controller.rb`

```ruby
class TenantAdminController < ActionController::Base
  include AdminAuthBypass
  
  # CRITICAL: Does NOT include SubdomainTenant concern
  # Operates across ALL tenants without automatic scoping
  
  before_action :authenticate_user!, unless: :bypass_admin_auth?
  
  # Uses Devise authentication only (Phase 1)
  # Authorization will be added in Phase 2 with super_admin flag
end
```

### 5.3 Multi-Tenancy with User Memberships

**Tenant Isolation Pattern**:

```ruby
# Website-scoped user query
user.accessible_websites  # Returns websites user is member of

# Check admin access
user.admin_for?(website)  # Returns boolean

# Get user role for website
user.role_for(website)    # Returns 'owner', 'admin', 'member', 'viewer'

# Membership validation
membership = user_memberships.active.find_by(website: website)
membership.can_manage?(other_membership)  # Hierarchical role check
```

### 5.4 API Authentication

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/application_api_controller.rb`

```ruby
class ApplicationApiController < ActionController::Base
  before_action :authenticate_user!, :current_agency, :check_user, 
                unless: :bypass_authentication?

  private

  ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

  def bypass_authentication?
    return false unless ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env)
    ENV['BYPASS_API_AUTH'] == 'true' || ENV['BYPASS_ADMIN_AUTH'] == 'true'
  end

  def check_user
    # Allow if user is admin for current website
    unless current_user && current_user.admin_for?(current_website)
      render_json_error "unauthorised_user", status: 422
    end
  end
end
```

#### Environment Variables for Development:
```bash
BYPASS_API_AUTH=true      # Skip authentication for API
BYPASS_ADMIN_AUTH=true    # Skip authentication for admin panels
```

### 5.5 GraphQL Authentication

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/graphql_controller.rb`

```ruby
class GraphqlController < Pwb::ApplicationController
  protect_from_forgery with: :null_session
  
  def execute
    context = {
      session: session,
      current_user: current_user,  # Can be nil for public queries
      request_url: request.referer,
      request_host: request.host,
      request_ip: request.ip,
      request_user_agent: request.user_agent,
    }
    # GraphQL resolvers check context[:current_user]
  end

  private

  def current_user
    return nil  # TODO: Implement token-based auth
  end
end
```

**Note**: GraphQL authentication is not fully implemented yet.

---

## 6. Multi-Tenancy Architecture

### 6.1 Subdomain-Based Tenant Resolution

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/concerns/subdomain_tenant.rb`

```ruby
module SubdomainTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_website_from_subdomain
  end

  private

  def set_current_website_from_subdomain
    # Priority 1: X-Website-Slug header (API/GraphQL)
    slug = request.headers["X-Website-Slug"]
    Pwb::Current.website = Pwb::Website.find_by(slug: slug) if slug.present?

    # Priority 2: Request subdomain
    if Pwb::Current.website.blank? && request_subdomain.present?
      Pwb::Current.website = Pwb::Website.find_by(subdomain: request_subdomain)
    end

    # Priority 3: Fallback to first website
    Pwb::Current.website ||= Pwb::Website.first
  end

  RESERVED_SUBDOMAINS = %w[www api admin].freeze

  def request_subdomain
    subdomain = request.subdomain
    return nil if subdomain.blank?
    return nil if RESERVED_SUBDOMAINS.include?(subdomain)
    subdomain.split(".").first  # Handle multi-level subdomains
  end
end
```

### 6.2 Automatic Model Scoping with acts_as_tenant

**Usage Pattern**:

```ruby
# Unscoped model - cross-tenant queries
Pwb::User.all  # All users across all websites

# Tenant-scoped model - auto-scoped to ActsAsTenant.current_tenant
PwbTenant::User.all  # Only users for current website

# Manual scoping
ActsAsTenant.with_tenant(website) do
  PwbTenant::User.all  # Users for specified website
end
```

### 6.3 Tenant Enforcement

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/concerns/pwb_tenant/requires_tenant.rb`

```ruby
module RequiresTenant
  extend ActiveSupport::Concern

  included do
    default_scope do
      if ActsAsTenant.current_tenant.nil? && !ActsAsTenant.unscoped?
        raise ActsAsTenant::Errors::NoTenantSet,
              "#{name} requires a tenant to be set..."
      end
      all
    end
  end
end
```

---

## 7. Security Concerns and Issues

### 7.1 Password Security

**Status**: Well-implemented

- **Hashing**: Bcrypt with configurable cost factor
  - Production: 11 stretches (standard)
  - Test: 1 stretch (performance)
- **Minimum Length**: 6 characters (configurable 6-128)
- **Validation**: Email regex validation + format checks
- **Storage**: Never stored in plaintext

**Recommendation**: Consider increasing minimum password length to 8-12 characters.

### 7.2 Session Security

**Status**: Good, some areas need attention

**Strengths**:
- Secure cookie-based sessions
- CSRF protection enabled via `protect_from_forgery`
- `config.sign_out_via = :delete` (prevents CSRF via GET)
- Remember-me tokens expire on sign-out
- Session tracking (sign-in count, IP, timestamp)

**Concerns**:
- GraphQL uses `null_session` for CSRF (necessary for API but requires care)
- Some API endpoints skip CSRF verification for file uploads
- No explicit rate limiting on authentication endpoints visible

**Recommendations**:
1. Add rate limiting to login, password reset, and signup endpoints
2. Implement IP whitelisting for admin accounts
3. Add two-factor authentication (2FA) support
4. Monitor failed login attempts and implement account lockout

### 7.3 OAuth Security

**Status**: Implemented but with considerations

**Current Flow**:
- Uses standard OmniAuth flow
- Facebook provider configured
- Token exchange handled by OmniAuth library

**Concerns**:
- Email generation fallback: `"#{SecureRandom.urlsafe_base64}@example.com"`
  - Creates invalid email addresses
  - User experience issue
- No state parameter validation visible in code (should be handled by OmniAuth library)
- Redirect URLs not explicitly validated

**Recommendations**:
1. Request email from user if provider doesn't provide it
2. Add provider-specific configuration validation
3. Implement email verification before account activation
4. Log all OAuth authentication events

### 7.4 Cross-Tenant Isolation

**Status**: Good architecture, implementation complete

**Positive**:
- `TenantAdminController` explicitly does NOT inherit `SubdomainTenant`
- `SiteAdminController` properly scopes to current subdomain
- Database-level unique constraint: `[user_id, website_id]` on memberships
- `PwbTenant::User` enforces tenant requirement
- Acts_as_tenant automatically filters queries

**Verification Needed**:
- Ensure all tenant-scoped models inherit from `PwbTenant::*` versions in web controllers
- Verify no raw SQL queries bypass tenant scoping

### 7.5 API Authentication

**Status**: Basic, needs improvement

**Current State**:
- Uses Devise session authentication (inherited from browser session)
- API key authentication: Not implemented
- JWT tokens: Not implemented
- GraphQL: No authentication (returns nil for current_user)

**Concerns**:
```ruby
# ApplicationApiController
def bypass_authentication?
  return false unless ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env)
  ENV['BYPASS_API_AUTH'] == 'true'  # Can disable auth entirely!
end
```

**Recommendations**:
1. Implement token-based authentication (JWT or API keys)
2. Remove bypass authentication for production
3. Implement rate limiting per token/user
4. Add token expiration and refresh logic
5. Complete GraphQL authentication implementation

### 7.6 Admin Auth Bypass

**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/concerns/admin_auth_bypass.rb`

**Status**: Development-only, properly guarded

```ruby
ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

def bypass_admin_auth?
  return false unless ALLOWED_ENVIRONMENTS.include?(Rails.env)
  ENV['BYPASS_ADMIN_AUTH'] == 'true'
end
```

**Good Security Practices**:
- Only enabled in non-production environments
- Explicitly checks environment whitelist
- Creates temporary test users with `bypass-admin@{subdomain}.test` email

**Potential Issues**:
- If somehow enabled in production, creates security hole
- Test users might not be cleaned up if bypass is disabled

**Recommendation**: Add assertions that bypass is never loaded in production.

### 7.7 Account Lockout

**Status**: Configured but not enabled

```ruby
# In devise initializer (commented out)
# config.lock_strategy = :failed_attempts
# config.maximum_attempts = 20
# config.unlock_strategy = :both
# config.unlock_in = 1.hour
```

**Column exists**: `failed_attempts`, `unlock_token`, `locked_at`

**Recommendation**: Enable account lockout to prevent brute force attacks.

### 7.8 CSRF Protection

**Status**: Partially implemented

**Strength**:
- `protect_from_forgery with: :exception` in main controllers
- Devise automatically handles token validation
- DELETE method for sign-out prevents CSRF

**Concerns**:
- GraphQL uses `null_session` (intentional but risky)
- Some API endpoints skip CSRF:
  ```ruby
  skip_before_action :verify_authenticity_token, only: [:update]
  ```
- Set-CSRF-Token headers in responses need client handling

**Recommendations**:
1. Use `:reset_session` instead of `:null_session` if possible
2. Implement SameSite cookie attribute (Rails 6.1+)
3. Add explicit CSRF token validation for JSON APIs
4. Document which endpoints skip CSRF and why

### 7.9 Email Security

**Status**: Configured, some concerns

**Current**:
- Email confirmation required
- Reconfirmation required for email changes
- Confirmation token: UNIQUE, 32+ character token

**Concerns**:
- Confirmation tokens visible in URLs (HTTPS required)
- 6-hour reset password window might be too long
- No explicit email encryption in transit (relies on HTTPS)

**Recommendations**:
1. Ensure all auth URLs are HTTPS-only
2. Consider shorter reset password windows (2-4 hours)
3. Implement email verification step for OAuth accounts
4. Add email change notification to old email address

### 7.10 Logging and Monitoring

**Status**: Basic logging, missing monitoring

**Tracked**:
- Sign-in count per user
- Current/last sign-in IP
- Current/last sign-in timestamp

**Not Tracked**:
- Failed login attempts (except in lockout)
- OAuth authentication events
- Authorization failures
- Admin actions

**Recommendations**:
1. Implement audit logging for all authentication events
2. Monitor failed login attempts
3. Alert on unusual access patterns
4. Log all authorization failures
5. Use log aggregation service (Logster is already mounted!)

---

## 8. Identified Issues and Vulnerabilities

### High Priority

1. **API Authentication Bypass**
   - Issue: `BYPASS_API_AUTH=true` completely disables authentication
   - Impact: If set in production, all API access is public
   - Fix: Remove bypass for production, use environment-specific credentials

2. **GraphQL No Authentication**
   - Issue: `current_user` always returns nil in GraphQL context
   - Impact: No user context available for authorization
   - Fix: Implement token-based authentication for GraphQL

3. **Account Lockout Disabled**
   - Issue: No protection against brute force attacks
   - Impact: Passwords can be brute-forced
   - Fix: Enable `lock_strategy = :failed_attempts`

4. **No Rate Limiting**
   - Issue: Login, password reset, signup endpoints not rate-limited
   - Impact: Brute force and abuse attacks possible
   - Fix: Implement rate limiting (rack-attack gem)

### Medium Priority

5. **OAuth Email Fallback**
   - Issue: Creates invalid emails if provider doesn't supply
   - Impact: User can't login later with real email
   - Fix: Request email from user before creating account

6. **Session Timeout Not Configured**
   - Issue: Sessions don't expire after inactivity
   - Impact: Stolen session tokens never expire
   - Fix: Add `config.timeout_in = 30.minutes`

7. **No Two-Factor Authentication**
   - Issue: Passwords are only factor
   - Impact: Account compromise from single stolen credential
   - Fix: Implement TOTP (Time-based One-Time Password) with 2FA gem

8. **API Tokens Not Implemented**
   - Issue: API clients must use session authentication
   - Impact: No way to grant limited-scope API access
   - Fix: Implement JWT or API key tokens

### Low Priority

9. **Weak Password Length Default**
   - Issue: Minimum 6 characters is short
   - Impact: Passwords more vulnerable to brute force
   - Fix: Increase minimum to 10-12 characters

10. **Remember-Me Never Configured**
    - Issue: Config present but remember_created_at never used
    - Impact: Lost functionality
    - Fix: Enable and configure properly

---

## 9. Authentication Routes and Endpoints

### Devise Routes (Auto-generated)

```ruby
POST   /users/sign_in          # Login form submission
GET    /users/sign_out         # Logout (DELETE via form)
POST   /users/sign_up          # Registration form submission
GET    /users/sign_up          # Registration form page
GET    /users/password/new     # Password reset request page
POST   /users/password         # Password reset email send
GET    /users/password/edit    # Password reset form page
PUT    /users/password         # Password update
GET    /users/cancel           # Account deletion page
DELETE /users                  # Account deletion
GET    /users/edit             # User profile edit page
PUT    /users                  # User profile update
GET    /users/confirmation/new # Email confirmation page
GET    /users/confirmation     # Email confirmation link
POST   /users/confirmation     # Resend confirmation
GET    /users/unlock/new       # Account unlock request page
POST   /users/unlock           # Account unlock email send
GET    /users/unlock           # Account unlock link

# OmniAuth
GET    /users/auth/facebook    # Redirect to Facebook
GET    /users/auth/facebook/callback  # Facebook callback
```

### Custom Routes

```ruby
GET    /en/omniauth/facebook   # Localized OAuth redirect (saves locale in session)
GET    /users/edit_success     # Success page after profile update

# Firebase
GET    /firebase_login         # Firebase login page
GET    /firebase_sign_up       # Firebase signup page
GET    /firebase_forgot_password # Password reset page
GET    /firebase_change_password # Change password page

# Admin Panels
GET    /admin                  # Angular admin panel
GET    /admin/*path            # Angular admin routes
GET    /v-admin/*path          # Vue admin panel routes

# Site Admin
GET    /site_admin             # Tenant-scoped admin dashboard
GET    /site_admin/*path       # Site admin nested routes

# Tenant Admin (Cross-tenant)
GET    /tenant_admin           # System-wide admin dashboard
GET    /tenant_admin/*path     # Tenant admin nested routes
```

---

## 10. Database Schema for Authentication

### pwb_users Table

```sql
Column Name              | Type         | Notes
------------------------|--------------|----------------------------------------
id                       | SERIAL       | Primary key
email                    | VARCHAR      | NOT NULL, UNIQUE - login identifier
encrypted_password       | VARCHAR      | NOT NULL - bcrypt hash
reset_password_token     | VARCHAR      | UNIQUE - for password recovery
reset_password_sent_at   | TIMESTAMP    | When reset was initiated
remember_created_at      | TIMESTAMP    | When "Remember me" was created
sign_in_count            | INTEGER      | Default: 0
current_sign_in_at       | TIMESTAMP    | Last login
last_sign_in_at          | TIMESTAMP    | Previous login
current_sign_in_ip       | VARCHAR      | IP from last login
last_sign_in_ip          | VARCHAR      | IP from previous login
confirmation_token       | VARCHAR      | UNIQUE - email confirmation
confirmed_at             | TIMESTAMP    | When email confirmed
confirmation_sent_at     | TIMESTAMP    | When confirmation email sent
unconfirmed_email        | VARCHAR      | New email pending confirmation
failed_attempts          | INTEGER      | Default: 0 - for lockout
unlock_token             | VARCHAR      | For account unlock
locked_at                | TIMESTAMP    | Account locked at
authentication_token     | VARCHAR      | Legacy API token
admin                    | BOOLEAN      | Default: false - global admin flag
firebase_uid             | VARCHAR      | UNIQUE - Firebase identifier
website_id               | INTEGER      | FK to pwb_websites - legacy single-site
first_names              | VARCHAR      | User profile
last_names               | VARCHAR      | User profile
skype                    | VARCHAR      | User profile
phone_number_primary     | VARCHAR      | User profile
default_client_locale    | VARCHAR      | Locale preference
default_admin_locale     | VARCHAR      | Admin locale preference
default_currency         | VARCHAR      | Currency preference
created_at               | TIMESTAMP    | Account creation
updated_at               | TIMESTAMP    | Last update
```

### pwb_authorizations Table

```sql
Column Name   | Type    | Notes
--------------|---------|------------------------------------
id            | SERIAL  | Primary key
user_id       | BIGINT  | FK to pwb_users
provider      | VARCHAR | e.g., 'facebook', 'google'
uid           | VARCHAR | Provider's unique user identifier
created_at    | TIMESTAMP | When linked
updated_at    | TIMESTAMP | Last update

Indexes:
- user_id
```

### pwb_user_memberships Table

```sql
Column Name   | Type         | Notes
--------------|--------------|------------------------------------------
id            | BIGINT       | Primary key
user_id       | BIGINT       | FK to pwb_users (NOT NULL)
website_id    | BIGINT       | FK to pwb_websites (NOT NULL)
role          | VARCHAR      | Default: 'member'
               |              | Values: owner, admin, member, viewer
active        | BOOLEAN      | Default: true
created_at    | TIMESTAMP    | Membership created
updated_at    | TIMESTAMP    | Last update

Indexes:
- user_id
- website_id
- [user_id, website_id] UNIQUE - prevents duplicate memberships
```

---

## 11. Security Best Practices Checklist

### Implemented
- [x] Bcrypt password hashing
- [x] Email confirmation required
- [x] Password reset functionality
- [x] CSRF protection in forms
- [x] Role-based access control
- [x] Multi-tenancy with isolation
- [x] Session tracking (IP, timestamp)
- [x] Admin access control
- [x] OAuth integration
- [x] Secure cookie session storage

### Not Implemented
- [ ] Rate limiting on auth endpoints
- [ ] Two-factor authentication (2FA)
- [ ] Account lockout after failed attempts
- [ ] Session timeout after inactivity
- [ ] API token authentication
- [ ] JWT token implementation
- [ ] GraphQL authentication
- [ ] Audit logging
- [ ] IP whitelisting for admin
- [ ] Email notification on login from new IP
- [ ] HTTPS enforcement
- [ ] SameSite cookie attributes

---

## 12. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Client / Browser                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                    HTTP/HTTPS Request
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼───┐          ┌───▼───┐         ┌───▼────┐
    │Devise │          │Session│         │ CSRF   │
    │Authn  │          │Cookie │         │ Token  │
    └───┬───┘          └───┬───┘         └───┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
        ┌──────────────────▼──────────────────┐
        │    Rails Application Controller      │
        ├──────────────────────────────────────┤
        │ - SubdomainTenant (resolve website)  │
        │ - authenticate_user! (Devise)        │
        │ - AdminAuthBypass (dev bypass)       │
        └──────────────────┬──────────────────┘
                           │
        ┌──────────────────▼──────────────────┐
        │    Authorization Layer               │
        ├──────────────────────────────────────┤
        │ - admin_for?(website)                │
        │ - role_for(website)                  │
        │ - user_memberships check             │
        └──────────────────┬──────────────────┘
                           │
        ┌──────────────────▼──────────────────┐
        │    Model Layer (Multi-tenant)        │
        ├──────────────────────────────────────┤
        │ - PwbTenant::User                    │
        │ - ActsAsTenant automatic scoping     │
        │ - Pwb::User (unscoped, cross-tenant) │
        └──────────────────┬──────────────────┘
                           │
        ┌──────────────────▼──────────────────┐
        │    Database                          │
        ├──────────────────────────────────────┤
        │ - pwb_users (auth credentials)       │
        │ - pwb_authorizations (OAuth links)   │
        │ - pwb_user_memberships (RBAC)        │
        │ - pwb_websites (tenants)             │
        └──────────────────────────────────────┘
```

---

## 13. Recommendations and Next Steps

### Critical (Immediate)
1. Enable account lockout after 5-10 failed attempts
2. Implement rate limiting on auth endpoints (Rack::Attack gem)
3. Complete GraphQL authentication implementation
4. Remove `BYPASS_API_AUTH` from production builds

### High Priority (Next Sprint)
1. Implement two-factor authentication (2FA)
2. Add audit logging for auth events
3. Implement API token authentication (JWT)
4. Add session timeout after 30 minutes of inactivity

### Medium Priority (Next Quarter)
1. IP whitelisting for admin accounts
2. Email notification on login from new IP
3. Implement HTTPS enforcement
4. Add SameSite cookie attributes
5. Increase minimum password length to 10 characters

### Low Priority (Future)
1. Support additional OAuth providers (Google, GitHub, Apple)
2. Implement passwordless authentication (magic links)
3. Add biometric authentication support
4. Implement single sign-on (SSO)

---

## 14. Conclusion

PropertyWebBuilder implements a solid authentication foundation with Devise, OmniAuth, and a well-designed multi-tenant architecture using `acts_as_tenant`. The role-based access control through UserMemberships provides flexibility for managing user permissions across multiple websites.

However, several security features are missing or not fully implemented:
- No rate limiting or brute-force protection
- GraphQL authentication incomplete
- API token authentication missing
- Account lockout disabled
- No two-factor authentication

The codebase is well-organized with clear separation between tenant-scoped (PwbTenant::) and cross-tenant (Pwb::) models, making the multi-tenancy architecture clean and maintainable.

**Overall Security Assessment**: 7/10
- Good foundation and design patterns
- Missing critical security controls (rate limiting, 2FA, lockout)
- Requires implementation of modern API authentication
- Audit logging needed

The recommendations in Section 13 should be prioritized to bring the authentication system to production-grade security standards.

---

## Appendix: File Locations Reference

| Component | File Path |
|-----------|-----------|
| User Model | `/app/models/pwb/user.rb` |
| Tenant User | `/app/models/pwb_tenant/user.rb` |
| Memberships | `/app/models/pwb/user_membership.rb` |
| Authorization OAuth | `/app/models/pwb/authorization.rb` |
| Sessions Controller | `/app/controllers/pwb/devise/sessions_controller.rb` |
| Registrations Controller | `/app/controllers/pwb/devise/registrations_controller.rb` |
| OmniAuth Callbacks | `/app/controllers/pwb/devise/omniauth_callbacks_controller.rb` |
| Admin Panel | `/app/controllers/pwb/admin_panel_controller.rb` |
| Site Admin | `/app/controllers/site_admin_controller.rb` |
| Tenant Admin | `/app/controllers/tenant_admin_controller.rb` |
| Devise Config | `/config/initializers/devise.rb` |
| Firebase Config | `/config/initializers/firebase_id_token.rb` |
| Tenant Concern | `/app/controllers/concerns/subdomain_tenant.rb` |
| Admin Bypass | `/app/controllers/concerns/admin_auth_bypass.rb` |
| Routes | `/config/routes.rb` |
| Schema | `/db/schema.rb` |
| User Migration | `/db/migrate/20161205223003_devise_create_pwb_users.rb` |
| Authorization Migration | `/db/migrate/20180111045213_create_authorizations.rb` |
| Membership Migration | `/db/migrate/20251201140925_create_pwb_user_memberships.rb` |

---

**Report Generated**: December 7, 2025
**Analysis Depth**: Comprehensive
**Status**: Complete
