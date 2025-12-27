# PropertyWebBuilder Authentication System Analysis

## Overview

PropertyWebBuilder has a **dual authentication system** combining:
1. **Firebase Authentication** - For admin panel login (email/password + Google OAuth)
2. **Devise Authentication** - Traditional Rails authentication with email/password and Facebook OAuth

Both systems integrate with **multi-tenancy** based on subdomains, where each website/tenant has its own set of users with role-based access control via `UserMembership`.

---

## 1. Firebase Authentication

### 1.1 Current Implementation

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/firebase_login_controller.rb`

```ruby
module Pwb
  class FirebaseLoginController < ApplicationController
    layout 'pwb/devise'

    def index
      render "pwb/firebase_login/index"
    end

    def forgot_password
      render "pwb/firebase_login/forgot_password"
    end

    def sign_up
      render "pwb/firebase_login/sign_up"
    end

    def change_password
      unless current_user
        redirect_to "/firebase_login" and return
      end
      render "pwb/firebase_login/change_password"
    end
  end
end
```

### 1.2 Firebase UI Integration

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/firebase_login/index.html.erb`

The login page uses **FirebaseUI** (Google's official Firebase authentication UI library):

```html
<!-- CDN includes for Firebase SDK and FirebaseUI -->
<script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/ui/6.0.1/firebase-ui-auth.js"></script>
```

**Configuration passed via environment variables:**
- `FIREBASE_API_KEY` - The web API key for client-side Firebase
- `FIREBASE_PROJECT_ID` - The Firebase project ID

**Supported Authentication Methods:**
- Email/Password (with account creation enabled)
- Google Sign-In

**Post-Login Flow:**
1. User enters credentials in FirebaseUI widget
2. FirebaseUI authenticates with Firebase backend
3. On success, the app calls `getIdToken()` to get a Firebase ID token
4. Token is sent to Rails backend via POST `/api_public/v1/auth/firebase`
5. Backend verifies token and signs user in

```javascript
// Example from view
authResult.user.getIdToken().then(function(accessToken) {
  fetch('/api_public/v1/auth/firebase', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: accessToken })
  })
  .then(response => {
    if (response.ok) {
      window.location.assign('/admin');
    } else {
      alert('Login failed on server side.');
    }
  });
});
```

### 1.3 Firebase Token Verification

**Service**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_auth_service.rb`

```ruby
module Pwb
  class FirebaseAuthService
    def initialize(token, website: nil)
      @token = token
      @website = website
    end

    def call
      # Step 1: Verify the JWT token signature using Firebase public keys
      begin
        payload = FirebaseIdToken::Signature.verify(@token)
      rescue StandardError => e
        Rails.logger.error "FirebaseAuthService: Verification failed - #{e.class}: #{e.message}"
        return nil
      end

      # Step 2: Extract user info from token payload
      uid = payload['user_id']
      email = payload['email']

      # Step 3: Find or create user in Rails database
      user = User.find_by(firebase_uid: uid) || User.find_by(email: email)

      if user
        # Update firebase_uid if found by email
        user.update(firebase_uid: uid) if user.firebase_uid.blank?
      else
        # Create new user if not found
        website = @website || Pwb::Current.website || Website.first
        
        user = User.new(
          email: email,
          firebase_uid: uid,
          password: ::Devise.friendly_token[0, 20],
          website: website
        )
        user.save!

        # Grant access to the website
        UserMembershipService.grant_access(
          user: user,
          website: website,
          role: 'member'
        )
      end

      user
    end
  end
end
```

**Key Points:**
- Uses `firebase_id_token` gem to verify JWT signatures
- Extracts `user_id` and `email` from token payload
- Creates `UserMembership` on first login (grants 'member' role)
- Admin status must be set manually

### 1.4 Firebase Configuration

**Initializer**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/firebase_id_token.rb`

```ruby
FirebaseIdToken.configure do |config|
  config.project_ids = [ENV['FIREBASE_PROJECT_ID']]
  
  # Use Redis for certificate caching if available
  if defined?(Redis)
    begin
      redis = Redis.new
      redis.ping
      config.redis = redis
    rescue => e
      Rails.logger.warn "Redis not available for Firebase certificate caching"
    end
  end
end

# Fetch certificates on initialization
if ENV['FIREBASE_PROJECT_ID'].present?
  begin
    Rails.logger.info "Fetching Firebase certificates..."
    FirebaseIdToken::Certificates.request
  rescue => e
    Rails.logger.warn "Could not fetch Firebase certificates on initialization"
  end
end
```

**Environment Variables Required:**
```bash
FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
FIREBASE_PROJECT_ID=your-project-id
```

### 1.5 Routes for Firebase Auth

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/routes.rb`

```ruby
get "/firebase_login" => "firebase_login#index"
get "/firebase_sign_up" => "firebase_login#sign_up"
get "/firebase_forgot_password" => "firebase_login#forgot_password"
get "/firebase_change_password" => "firebase_login#change_password"

# API endpoint for token verification
post "/api_public/v1/auth/firebase" => "api_public/v1/auth#firebase"
```

### 1.6 API Controller

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/api_public/v1/auth_controller.rb`

```ruby
module ApiPublic
  module V1
    class AuthController < BaseController
      def firebase
        token = params[:token]
        unless token
          return render json: { error: "Token is missing" }, status: :bad_request
        end

        begin
          user = Pwb::FirebaseAuthService.new(token, website: current_website).call
          
          if user
            sign_in(user)  # Sign in with Devise/Warden
            render json: { 
              user: {
                id: user.id,
                email: user.email,
                firebase_uid: user.firebase_uid
              },
              message: "Logged in successfully" 
            }
          else
            render json: { error: "Invalid token" }, status: :unauthorized
          end
        rescue StandardError => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end
```

---

## 2. Devise Authentication

### 2.1 Devise Configuration

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/devise.rb`

**Devise Modules Enabled:**

```ruby
devise :database_authenticatable,  # Email/password login
        :registerable,              # User registration
        :recoverable,               # Password reset
        :rememberable,              # Remember me cookie
        :trackable,                 # Sign-in tracking
        :validatable,               # Email/password validation
        :lockable,                  # Account lockout
        :timeoutable,               # Session timeout
        :omniauthable,              # OAuth support
        omniauth_providers: [:facebook]
```

**Key Settings:**
```ruby
config.timeout_in = 30.minutes                    # Session timeout
config.lock_strategy = :failed_attempts          # Lock after failed attempts
config.maximum_attempts = 5                       # Max login attempts
config.unlock_strategy = :both                    # Unlock by email or time
config.unlock_in = 1.hour                         # Unlock wait time
config.stretches = 11                             # bcrypt cost factor
config.sign_out_via = :delete                     # Sign out via DELETE request
config.expire_all_remember_me_on_sign_out = true # Clear remember me on logout
```

### 2.2 User Model

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`

```ruby
class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable,
    :validatable, :lockable, :timeoutable,
    :omniauthable, omniauth_providers: [:facebook]

  # Associations
  belongs_to :website, optional: true
  has_many :authorizations
  has_many :auth_audit_logs
  has_many :user_memberships, dependent: :destroy
  has_many :websites, through: :user_memberships

  # Multi-tenancy validation
  validates :website, presence: true, if: -> { user_memberships.none? }

  # Active for authentication only on correct subdomain
  def active_for_authentication?
    super && website.present? && 
    (current_website.blank? || website_id == current_website&.id)
  end

  # OAuth integration
  def self.find_for_oauth(auth, website: nil)
    authorization = Authorization.where(provider: auth.provider, 
                                       uid: auth.uid.to_s).first
    return authorization.user if authorization

    email = auth.info[:email] || "#{SecureRandom.urlsafe_base64}@example.com"
    user = User.where(email: email).first

    if user
      user.create_authorization(auth)
    else
      password = ::Devise.friendly_token[0, 20]
      current_website = website || Pwb::Current.website || Website.first
      user = User.create!(
        email: email, 
        password: password, 
        password_confirmation: password,
        website: current_website
      )
      user.create_authorization(auth)
    end

    user
  end
end
```

**User Model Attributes:**

| Column | Type | Purpose |
|--------|------|---------|
| email | string | Email address (unique) |
| encrypted_password | string | bcrypt hashed password |
| firebase_uid | string | Firebase UID (if using Firebase) |
| website_id | integer | Primary website (legacy) |
| admin | boolean | Admin flag |
| reset_password_token | string | Password reset token |
| confirmation_token | string | Email confirmation token |
| unlock_token | string | Account unlock token |
| locked_at | datetime | When account was locked |
| failed_attempts | integer | Failed login count |
| sign_in_count | integer | Total logins |
| current_sign_in_at | datetime | Last login time |
| last_sign_in_ip | string | Last login IP |

### 2.3 Devise Controllers

#### Sessions Controller
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/sessions_controller.rb`

```ruby
class SessionsController < ::Devise::SessionsController
  include SubdomainTenant
  before_action :validate_user_website, only: [:create]

  protected

  def validate_user_website
    email = sign_in_params[:email]
    return unless email.present?

    user = Pwb::User.find_by(email: email)
    return unless user.present?

    current_site = current_website_from_subdomain
    
    # Validate user belongs to current subdomain
    if user.website_id != current_site&.id
      flash[:alert] = "You don't have access to this subdomain."
      redirect_to new_user_session_path and return
    end
  end

  def sign_in_params
    params.fetch(:user, ActionController::Parameters.new)
          .permit(:email, :password, :remember_me)
  end
end
```

**Key Points:**
- Validates user belongs to current website/subdomain
- Prevents credential stuffing across subdomains

#### Registrations Controller
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/registrations_controller.rb`

```ruby
class RegistrationsController < Devise::RegistrationsController
  def edit_success
    render "/devise/registrations/edit_success"
  end

  def after_update_path_for(_resource)
    pwb.user_edit_success_path
  end
end
```

#### Password Reset Controller
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/passwords_controller.rb`

```ruby
class PasswordsController < Devise::PasswordsController
  def create
    # Log password reset request
    Pwb::AuthAuditLog.log_password_reset_request(
      email: resource_params[:email],
      request: request
    )
    super
  end

  def update
    super do |resource|
      if resource.errors.empty?
        Pwb::AuthAuditLog.log_password_reset_success(
          user: resource,
          request: request
        )
      else
        Pwb::AuthAuditLog.log_login_failure(
          email: resource.email,
          reason: 'password_reset_failed',
          request: request
        )
      end
    end
  end
end
```

#### OmniAuth Callbacks Controller
**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/omniauth_callbacks_controller.rb`

```ruby
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    I18n.locale = session[:omniauth_login_locale] || I18n.default_locale

    @user = Pwb::User.find_for_oauth(request.env['omniauth.auth'])
    if @user.persisted?
      Pwb::AuthAuditLog.log_oauth_success(
        user: @user,
        provider: 'facebook',
        request: request
      )
      sign_in_and_redirect @user, event: :authentication
    else
      Pwb::AuthAuditLog.log_oauth_failure(
        email: request.env.dig('omniauth.auth', 'info', 'email'),
        provider: 'facebook',
        reason: 'user_not_persisted',
        request: request
      )
    end
  end
end
```

### 2.4 Devise Routes

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/routes.rb`

```ruby
scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
  devise_for :users, 
    skip: :omniauth_callbacks, 
    class_name: "Pwb::User", 
    module: :devise,
    controllers: {
      registrations: "pwb/devise/registrations",
      omniauth_callbacks: "pwb/devise/omniauth_callbacks",
      sessions: "pwb/devise/sessions",
      passwords: "pwb/devise/passwords"
    }
end
```

---

## 3. Multi-Tenancy & User Roles

### 3.1 User Memberships

**Model**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user_membership.rb`

```ruby
class UserMembership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze

  belongs_to :user, class_name: 'Pwb::User'
  belongs_to :website, class_name: 'Pwb::Website'

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :website_id }
  validates :active, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: ['owner', 'admin']) }

  def admin?
    role.in?(['owner', 'admin'])
  end

  def can_manage?(other_membership)
    return false unless active?
    role_level > other_membership.role_level
  end
end
```

**Role Hierarchy:**
1. **owner** - Full control (highest)
2. **admin** - Admin access
3. **member** - Regular member
4. **viewer** - Read-only access (lowest)

### 3.2 UserMembership Service

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/user_membership_service.rb`

```ruby
class UserMembershipService
  class << self
    def grant_access(user:, website:, role: 'member')
      membership = UserMembership.find_or_initialize_by(user: user, website: website)
      membership.role = role
      membership.active = true
      membership.save!
      membership
    end

    def revoke_access(user:, website:)
      membership = UserMembership.find_by(user: user, website: website)
      return false unless membership
      membership.update!(active: false)
    end

    def change_role(user:, website:, new_role:)
      raise ArgumentError, "Invalid role" unless UserMembership::ROLES.include?(new_role)
      membership = UserMembership.find_by!(user: user, website: website)
      membership.update!(role: new_role)
    end

    def list_user_websites(user:, role: nil)
      scope = user.user_memberships.active.includes(:website)
      scope = scope.where(role: role) if role
      scope.map(&:website)
    end
  end
end
```

### 3.3 User Model Role Helpers

```ruby
# In Pwb::User
def admin_for?(website)
  user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
end

def role_for(website)
  user_memberships.active.find_by(website: website)&.role
end

def accessible_websites
  websites.where(pwb_user_memberships: { active: true })
end
```

---

## 4. Authentication Checks & Session Management

### 4.1 Devise Controller Helpers

**Parent Controller**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise_controller.rb`

```ruby
class DeviseController < ApplicationController
  layout "pwb/devise"

  # Sign-in redirect
  def after_sign_in_path_for(_resource_or_scope)
    admin_path
  end

  # Sign-out redirect
  def after_sign_out_path_for(_resource_or_scope)
    home_path
  end
end
```

**Default Devise methods available to all controllers:**
- `current_user` - Gets the currently logged-in user
- `user_signed_in?` - Checks if user is logged in
- `authenticate_user!` - Redirects to login if not authenticated
- `sign_in(user)` - Signs in a user
- `sign_out` - Signs out the current user

### 4.2 Session Store Configuration

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/session_store.rb`

```ruby
if Rails.env.test?
  Rails.application.config.session_store :cache_store
else
  Rails.application.config.session_store :cookie_store, key: '_pwb_session'
end
```

**Notes:**
- Uses secure cookies (HTTP only)
- Sessions are NOT shared between subdomains
- Each subdomain gets its own session cookie

### 4.3 Warden/Devise Integration Hooks

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/auth_audit_hooks.rb`

Logs all authentication events via Warden hooks:

```ruby
# Log successful authentication
Warden::Manager.after_authentication do |user, auth, opts|
  next unless auth.winning_strategy
  
  if auth.winning_strategy.is_a?(Devise::Strategies::OmniauthCallbacks)
    provider = request.env.dig('omniauth.auth', 'provider') || 'oauth'
    Pwb::AuthAuditLog.log_oauth_success(
      user: user,
      provider: provider,
      request: request
    )
  else
    Pwb::AuthAuditLog.log_login_success(
      user: user,
      request: request
    )
  end
end

# Log logout
Warden::Manager.before_logout do |user, auth, opts|
  request = auth.request
  Pwb::AuthAuditLog.log_logout(
    user: user,
    request: request
  )
end
```

---

## 5. Admin Panels & Authentication Requirements

### 5.1 /admin (Vue Admin Panel)

**Route**: `GET /admin` and `GET /admin/*path`

**Controller**: `Pwb::AdminPanelVueController` (via catch-all route)

**Authentication**: None currently (renders Vue app for client-side routing)

**Access Control**: Typically enforced at the API level in controllers

### 5.2 /site_admin (Single Website Admin)

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin_controller.rb`

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  include AdminAuthBypass

  before_action :set_tenant_from_subdomain
  before_action :authenticate_user!, unless: :bypass_admin_auth?

  layout 'site_admin'

  def current_website
    Pwb::Current.website
  end
end
```

**Key Features:**
- Scoped to single website via `SubdomainTenant` concern
- Automatically sets `Pwb::Current.website` from subdomain
- Requires Devise authentication (`authenticate_user!`)
- Can be bypassed with `BYPASS_ADMIN_AUTH=true` in dev/e2e
- All `PwbTenant::` models auto-scoped to current website

### 5.3 /tenant_admin (Cross-Tenant Admin)

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/tenant_admin_controller.rb`

```ruby
class TenantAdminController < ActionController::Base
  include AdminAuthBypass
  include Pagy::Backend

  protect_from_forgery with: :exception
  before_action :authenticate_user!, unless: :bypass_admin_auth?

  layout 'tenant_admin'

  def unscoped_model(model_class)
    model_class.unscoped
  end
end
```

**Key Features:**
- Does NOT include `SubdomainTenant` concern
- Operates across all websites/tenants
- Access to all data via `unscoped_model` helper
- Requires Devise authentication
- Currently uses only authentication, authorization in Phase 2

### 5.4 /v-admin (Vue Admin)

**Route**: `GET /v-admin` and `GET /v-admin/*path`

**Controller**: `Pwb::AdminPanelVueController`

**Authentication**: Typically handled at API endpoint level

---

## 6. API Authentication

### 6.1 Authenticated API Routes

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/config/routes.rb`

```ruby
authenticate :user do
  namespace :import do
    get "/mls" => "mls#retrieve"
    post "/properties/retrieve_from_mls" => "properties#retrieve_from_mls"
    # ... other import routes
  end

  namespace :export do
    get "/translations/all" => "translations#all"
    # ... other export routes
  end
end
```

**Authentication Check**: Uses Devise's `authenticate :user` block

### 6.2 API Controller Base

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/application_api_controller.rb`

```ruby
class ApplicationApiController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true
  
  before_action :authenticate_user!, :current_agency, :check_user, unless: :bypass_authentication?

  ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

  private

  def bypass_authentication?
    return false unless ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env)
    ENV['BYPASS_API_AUTH'] == 'true' || ENV['BYPASS_ADMIN_AUTH'] == 'true'
  end

  def check_user
    unless current_user && current_user.admin_for?(current_website)
      render_json_error "unauthorised_user"
    end
  end

  def current_website
    @current_website ||= current_website_from_subdomain || 
                         Pwb::Current.website || 
                         Website.first
  end
end
```

**Key Features:**
- Requires user authentication via `authenticate_user!`
- Checks user is admin for current website
- Can bypass via `BYPASS_API_AUTH=true` in dev/e2e
- Gets current website from subdomain

### 6.3 Firebase API Endpoint

**Route**: `POST /api_public/v1/auth/firebase`

**No Authentication Required** (public endpoint)

**Endpoint Implementation**:
```ruby
module ApiPublic
  module V1
    class AuthController < BaseController
      def firebase
        token = params[:token]
        unless token
          return render json: { error: "Token is missing" }, status: :bad_request
        end

        begin
          user = Pwb::FirebaseAuthService.new(token, website: current_website).call
          
          if user
            sign_in(user)
            render json: { 
              user: {
                id: user.id,
                email: user.email,
                firebase_uid: user.firebase_uid
              },
              message: "Logged in successfully" 
            }
          else
            render json: { error: "Invalid token" }, status: :unauthorized
          end
        rescue StandardError => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end
```

---

## 7. Authentication Audit Logging

### 7.1 AuthAuditLog Model

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/auth_audit_log.rb`

```ruby
class AuthAuditLog < ApplicationRecord
  EVENT_TYPES = %w[
    login_success
    login_failure
    logout
    oauth_success
    oauth_failure
    password_reset_request
    password_reset_success
    account_locked
    account_unlocked
    session_timeout
    registration
  ].freeze

  belongs_to :user, optional: true
  belongs_to :website, optional: true

  # Log all events with context
  def self.log_login_success(user:, request:, website: nil)
    create_log(
      event_type: 'login_success',
      user: user,
      email: user.email,
      website: website || Pwb::Current.website,
      request: request
    )
  end

  def self.log_login_failure(email:, request:, reason: nil, website: nil)
    # Similar logging...
  end

  def self.log_oauth_success(user:, provider:, request:, website: nil)
    # Similar logging...
  end

  # Useful scopes and queries
  scope :recent, -> { order(created_at: :desc) }
  scope :failures, -> { where(event_type: %w[login_failure oauth_failure]) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_ip, ->(ip) { where(ip_address: ip) }

  def self.failed_attempts_for_email(email, since: 1.hour.ago)
    for_email(email).failures.where('created_at >= ?', since).count
  end

  def self.suspicious_ips(threshold: 10, since: 1.hour.ago)
    where('created_at >= ?', since)
      .failures
      .group(:ip_address)
      .having('count(*) >= ?', threshold)
      .count
  end
end
```

**Logged Information:**
- User ID and email
- Event type (login, logout, oauth, etc.)
- Website/tenant context
- IP address and user agent
- Request path
- Failure reasons (invalid password, locked, etc.)
- Provider (for OAuth events)

### 7.2 Tenant Admin Dashboard

**Route**: `GET /tenant_admin/auth_audit_logs`

**Features:**
- View all authentication events across tenants
- Filter by user, IP, date range
- Monitor suspicious activity
- Detect brute force attacks

---

## 8. Subdomain-Based Multi-Tenancy

### 8.1 SubdomainTenant Concern

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/concerns/subdomain_tenant.rb`

```ruby
module SubdomainTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_website_from_subdomain
  end

  private

  def set_current_website_from_subdomain
    # Priority 1: X-Website-Slug header (for API)
    slug = request.headers["X-Website-Slug"]
    if slug.present?
      Pwb::Current.website = Pwb::Website.find_by(slug: slug)
    end

    # Priority 2: Request subdomain
    if Pwb::Current.website.blank? && request_subdomain.present?
      Pwb::Current.website = Pwb::Website.find_by(subdomain: request_subdomain)
    end

    # Fallback to default
    Pwb::Current.website ||= Pwb::Website.first
  end

  def request_subdomain
    subdomain = request.subdomain
    return nil if subdomain.blank?
    return nil if subdomain == "www"
    return nil if subdomain == "api"
    return nil if subdomain == "admin"

    # For multi-level: "site1.staging" -> "site1"
    subdomain.split(".").first
  end

  def current_website
    Pwb::Current.website
  end
end
```

**Tenant Resolution Priority:**
1. `X-Website-Slug` header (useful for API clients)
2. Request subdomain (e.g., `tenant1.app.com`)
3. Default to first website

**Reserved Subdomains** (cannot be used as tenant IDs):
- `www` - Ignored in tenant resolution
- `api` - API subdomain
- `admin` - Admin subdomain
- `app`, `mail`, `ftp`, `smtp`, etc. (in Website model)

### 8.2 Subdomain Validation in Website Model

```ruby
class Website < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[
    www api admin app mail ftp smtp pop imap 
    ns1 ns2 localhost staging test demo
  ].freeze

  validates :subdomain,
    uniqueness: { case_sensitive: false, allow_blank: true },
    format: {
      with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/i,
      message: "can only contain alphanumeric characters and hyphens"
    },
    length: { minimum: 2, maximum: 63 }

  validate :subdomain_not_reserved

  def self.find_by_subdomain(subdomain)
    return nil if subdomain.blank?
    where("LOWER(subdomain) = ?", subdomain.downcase).first
  end

  private

  def subdomain_not_reserved
    return if subdomain.blank?
    if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
      errors.add(:subdomain, "is reserved")
    end
  end
end
```

---

## 9. Admin Auth Bypass (Development/E2E)

### 9.1 AdminAuthBypass Concern

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/concerns/admin_auth_bypass.rb`

```ruby
module AdminAuthBypass
  extend ActiveSupport::Concern

  ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

  included do
    prepend_before_action :check_admin_auth_bypass
  end

  private

  def bypass_admin_auth?
    return false unless ALLOWED_ENVIRONMENTS.include?(Rails.env)
    ENV['BYPASS_ADMIN_AUTH'] == 'true'
  end

  def check_admin_auth_bypass
    if bypass_admin_auth?
      sign_in_bypass_user if current_user.nil?
    end
  end

  def find_or_create_bypass_user
    website = respond_to?(:current_website) ? current_website : Pwb::Current.website
    return nil unless website

    # Try to find existing admin
    admin = Pwb::User.find_by(website_id: website.id, admin: true)
    return admin if admin

    # Create bypass admin
    Pwb::User.find_or_create_by!(email: "bypass-admin@#{website.subdomain || 'default'}.test") do |user|
      user.password = 'bypass_password_123'
      user.password_confirmation = 'bypass_password_123'
      user.website_id = website.id
      user.admin = true
    end
  end
end
```

**Usage:**
```bash
# Enable bypass in development
export BYPASS_ADMIN_AUTH=true
export BYPASS_API_AUTH=true

# Disable with 'false'
export BYPASS_ADMIN_AUTH=false
```

**SECURITY WARNING**: Only works in `development`, `e2e`, and `test` environments. Production is immune to this bypass.

---

## 10. Configuration Files

### 10.1 Gems Used

**Location**: Gemfile

```ruby
gem "devise", "~> 4.8"              # Rails authentication
gem "omniauth", "~> 2.1"            # OAuth support
gem "omniauth-facebook"             # Facebook OAuth
gem "firebase"                      # Firebase client library
gem "firebase_id_token", "~> 2.5"   # Firebase JWT verification
```

### 10.2 Environment Variables

**Required for Firebase:**
```bash
FIREBASE_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id
```

**Optional for Development:**
```bash
BYPASS_ADMIN_AUTH=true              # Skip auth in dev/e2e
BYPASS_API_AUTH=true                # Skip API auth in dev/e2e
```

---

## 11. Database Schema

### 11.1 pwb_users Table

```sql
CREATE TABLE pwb_users (
  id INTEGER PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  encrypted_password VARCHAR NOT NULL,
  firebase_uid VARCHAR UNIQUE,                 -- Firebase UID
  website_id INTEGER,                          -- Primary website (legacy)
  admin BOOLEAN DEFAULT false,
  
  -- Password recovery
  reset_password_token VARCHAR UNIQUE,
  reset_password_sent_at TIMESTAMP,
  
  -- Email confirmation
  confirmation_token VARCHAR UNIQUE,
  confirmed_at TIMESTAMP,
  confirmation_sent_at TIMESTAMP,
  unconfirmed_email VARCHAR,
  
  -- Account lockout
  locked_at TIMESTAMP,
  unlock_token VARCHAR UNIQUE,
  failed_attempts INTEGER DEFAULT 0,
  
  -- Sign-in tracking
  sign_in_count INTEGER DEFAULT 0,
  current_sign_in_at TIMESTAMP,
  last_sign_in_at TIMESTAMP,
  current_sign_in_ip VARCHAR,
  last_sign_in_ip VARCHAR,
  
  -- Remember me
  remember_created_at TIMESTAMP,
  
  -- Profile info
  first_names VARCHAR,
  last_names VARCHAR,
  skype VARCHAR,
  phone_number_primary VARCHAR,
  default_client_locale VARCHAR,
  default_admin_locale VARCHAR,
  default_currency VARCHAR,
  
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE UNIQUE INDEX index_pwb_users_on_email ON pwb_users(email);
CREATE UNIQUE INDEX index_pwb_users_on_firebase_uid ON pwb_users(firebase_uid);
CREATE UNIQUE INDEX index_pwb_users_on_reset_password_token ON pwb_users(reset_password_token);
```

### 11.2 pwb_user_memberships Table

```sql
CREATE TABLE pwb_user_memberships (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES pwb_users(id),
  website_id INTEGER NOT NULL REFERENCES pwb_websites(id),
  role VARCHAR NOT NULL DEFAULT 'member',       -- owner, admin, member, viewer
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE UNIQUE INDEX index_user_memberships_on_user_and_website 
  ON pwb_user_memberships(user_id, website_id);
```

### 11.3 pwb_authorizations Table (OAuth)

```sql
CREATE TABLE pwb_authorizations (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES pwb_users(id),
  provider VARCHAR NOT NULL,                    -- 'facebook', 'google', etc.
  uid VARCHAR NOT NULL,                         -- OAuth provider's user ID
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### 11.4 pwb_auth_audit_logs Table

```sql
CREATE TABLE pwb_auth_audit_logs (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES pwb_users(id),
  website_id INTEGER REFERENCES pwb_websites(id),
  event_type VARCHAR NOT NULL,                  -- login_success, failure, etc.
  email VARCHAR,                                -- For failed login attempts
  provider VARCHAR,                             -- OAuth provider
  ip_address VARCHAR,
  user_agent VARCHAR,
  request_path VARCHAR,
  failure_reason VARCHAR,                       -- Why auth failed
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX index_pwb_auth_audit_logs_on_event_type ON pwb_auth_audit_logs(event_type);
CREATE INDEX index_pwb_auth_audit_logs_on_email ON pwb_auth_audit_logs(email);
CREATE INDEX index_pwb_auth_audit_logs_on_ip_address ON pwb_auth_audit_logs(ip_address);
CREATE INDEX index_pwb_auth_audit_logs_on_created_at ON pwb_auth_audit_logs(created_at);
CREATE INDEX index_pwb_auth_audit_logs_on_user_and_event ON pwb_auth_audit_logs(user_id, event_type);
CREATE INDEX index_pwb_auth_audit_logs_on_website_and_event ON pwb_auth_audit_logs(website_id, event_type);
```

---

## 12. Authentication Flow Diagrams

### 12.1 Firebase Login Flow

```
User visits /firebase_login
    ↓
FirebaseUI widget loads
    ↓
User enters email/password or clicks "Sign in with Google"
    ↓
Firebase backend validates credentials
    ↓
FirebaseUI receives ID token
    ↓
JavaScript: authResult.user.getIdToken() → token
    ↓
POST /api_public/v1/auth/firebase with token
    ↓
FirebaseAuthService.new(token).call
    ├─ Verify JWT signature via firebase_id_token gem
    ├─ Extract user_id and email from payload
    ├─ Find or create Pwb::User
    ├─ Create UserMembership (role: 'member')
    └─ Return user object
    ↓
sign_in(user) via Devise
    ↓
Response: { user: {...}, message: "Logged in" }
    ↓
Redirect to /admin
    ↓
User authenticated in Rails session
```

### 12.2 Devise Login Flow

```
User visits /users/sign_in
    ↓
POST /users/sign_in with email/password
    ↓
SessionsController#create
    ├─ validate_user_website: Check user belongs to subdomain
    └─ sign_in_params: Extract email/password
    ↓
Devise authenticates credentials
    ├─ Find user by email
    ├─ Check encrypted password
    ├─ Verify account not locked
    └─ Verify account not timed out
    ↓
Warden hooks trigger:
    ├─ after_authentication: Log success
    └─ Update sign_in tracking (count, IP, timestamp)
    ↓
Session created (cookie-based)
    ↓
Redirect to after_sign_in_path_for
    ↓
User authenticated in Rails session
```

### 12.3 API Authentication Flow

```
GET /api/v1/protected_endpoint
    ↓
ApplicationApiController#authenticate_user!
    ├─ Check BYPASS_API_AUTH env var (dev/e2e only)
    ├─ Check Rails session for Devise user
    └─ If no user: Redirect to login
    ↓
ApplicationApiController#check_user
    ├─ Get current_website from subdomain
    └─ Verify user.admin_for?(current_website)
    ↓
If authorized: Continue to action
If unauthorized: render_json_error "unauthorised_user"
```

---

## 13. Key Security Features

1. **Session Timeout**: 30 minutes of inactivity
2. **Account Lockout**: 5 failed attempts → 1 hour lockout
3. **Password Hashing**: bcrypt with cost factor 11
4. **CSRF Protection**: Token validation on all state-changing requests
5. **Multi-Tenancy Isolation**: 
   - Subdomain-based tenant resolution
   - Users scoped to websites via memberships
   - SessionsController validates user belongs to subdomain
6. **OAuth Integration**:
   - Facebook OAuth via OmniAuth
   - Firebase OAuth (via FirebaseUI)
7. **Audit Logging**: All auth events logged to database
8. **Security Monitoring**:
   - Detect brute force attempts by IP
   - Track failed login attempts per email
   - Monitor suspicious activity patterns

---

## 14. Current Limitations & Future Improvements

### Phase 1 (Current):
- Authentication only (users can log in)
- No authorization checks in site_admin/tenant_admin
- Admin flag used but not enforced everywhere

### Phase 2 (Planned):
- Authorization system based on user roles/memberships
- Permission checking in all admin controllers
- Super admin flag for tenant admin
- Granular permissions per resource

### Known Issues:
1. Some admin pages accessible to any logged-in user
2. No per-resource authorization checks
3. Bypass mechanisms need to be removed before production
4. Documentation needs updating

---

## 15. Testing Authentication

### Test Firebase Auth Endpoint

```bash
# 1. Get a Firebase ID token from browser DevTools
# (Network tab when logging in to /firebase_login)

# 2. Test the endpoint
curl -X POST http://localhost:3000/api_public/v1/auth/firebase \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_FIREBASE_TOKEN_HERE"}'

# Expected response:
# {"user":{"id":123,"email":"user@example.com","firebase_uid":"abc..."},"message":"Logged in successfully"}
```

### Console Tests

```ruby
# Test Devise authentication
rails c

# Find a user
user = Pwb::User.first

# Check memberships
user.user_memberships
user.accessible_websites

# Check admin status
user.admin_for?(Pwb::Website.first)
user.role_for(Pwb::Website.first)

# Test Firebase service
token = "your_firebase_token"
service = Pwb::FirebaseAuthService.new(token)
result = service.call

# Check audit logs
Pwb::AuthAuditLog.recent.limit(10)
Pwb::AuthAuditLog.for_user(user).limit(5)
Pwb::AuthAuditLog.failures.last_hour
```

---

## 16. References & Documentation

### Setup & Configuration
- `/Users/etewiah/dev/sites-older/property_web_builder/docs/FIREBASE_SETUP.md`
- `/Users/etewiah/dev/sites-older/property_web_builder/docs/FIREBASE_TROUBLESHOOTING.md`

### Key Files
- Controllers: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/devise/`
- Models: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`
- Services: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/`
- Views: `/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/firebase_login/`
- Initializers: `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/`

### External Resources
- [Devise Documentation](https://github.com/heartcombo/devise)
- [OmniAuth Documentation](https://github.com/omniauth/omniauth)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [FirebaseUI Web](https://firebase.google.com/docs/auth/web/firebaseui)
