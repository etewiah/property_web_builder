# 12. Authentication and Authorization

This document covers the authentication and authorization systems in PropertyWebBuilder.

## Overview

PropertyWebBuilder uses a **dual authentication system**:
1. **Firebase Authentication** - For the admin panel (FirebaseUI widget)
2. **Devise Authentication** - Traditional Rails email/password auth

Authorization is **role-based** with multi-tenant scoping via user memberships.

---

## Authentication Systems

### Firebase Authentication

Firebase provides the primary authentication for the admin panel.

**Key Files:**
- `app/services/pwb/firebase_auth_service.rb` - Token verification service
- `app/controllers/pwb/firebase_login_controller.rb` - Login views
- `app/controllers/api_public/v1/auth_controller.rb` - Token verification endpoint
- `config/initializers/firebase_id_token.rb` - Firebase configuration

**Routes:**
```
GET  /firebase_login           # Login page
GET  /firebase_sign_up         # Registration page
GET  /firebase_forgot_password # Password reset
POST /api_public/v1/auth/firebase  # Token verification API
```

**Authentication Flow:**
1. User visits `/firebase_login`
2. FirebaseUI widget handles authentication (email/password or Google OAuth)
3. Firebase returns an ID token to the browser
4. JavaScript POSTs token to `/api_public/v1/auth/firebase`
5. `FirebaseAuthService` verifies the JWT signature
6. User record is created/updated with `firebase_uid`
7. `UserMembership` is created (role: 'member') if needed
8. Devise session is established via `sign_in(user)`
9. User is redirected to `/admin`

**Configuration (Environment Variables):**
```bash
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
```

### Devise Authentication

Traditional Rails authentication with email/password.

**Key Files:**
- `app/models/pwb/user.rb` - User model with Devise modules
- `app/controllers/pwb/devise/sessions_controller.rb` - Login/logout
- `app/controllers/pwb/devise/passwords_controller.rb` - Password reset
- `app/controllers/pwb/devise/registrations_controller.rb` - Registration
- `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` - OAuth
- `config/initializers/devise.rb` - Devise configuration

**Devise Modules Enabled:**
- `database_authenticatable` - Email/password login
- `registerable` - User registration
- `recoverable` - Password reset
- `rememberable` - Remember me cookie
- `trackable` - Sign-in tracking
- `validatable` - Email/password validation
- `lockable` - Account lockout after failed attempts
- `timeoutable` - Session timeout
- `omniauthable` - OAuth support (Facebook)

**Security Settings:**
- Password cost: bcrypt with 11 stretches
- Session timeout: 30 minutes inactivity
- Account lockout: 5 failed attempts
- Unlock strategy: Email + auto-unlock after 1 hour

---

## Authorization System

### Role-Based Access Control

Authorization is managed through the `UserMembership` model which associates users with websites and roles.

**Key Files:**
- `app/models/pwb/user_membership.rb` - User-Website associations with roles
- `app/services/pwb/user_membership_service.rb` - Membership management service

**Role Hierarchy (highest to lowest):**
1. `owner` - Full control over the website
2. `admin` - Administrative access
3. `member` - Regular member access
4. `viewer` - Read-only access

**Key Methods:**
```ruby
# Check if user is admin for a website
user.admin_for?(website)  # true for owner or admin roles

# Get user's role for a website
user.role_for(website)  # 'owner', 'admin', 'member', 'viewer', or nil

# List all accessible websites
user.accessible_websites

# Membership role checks
membership.admin?   # true for owner or admin
membership.owner?   # true only for owner
membership.can_manage?(other_membership)  # role hierarchy check
```

### Controller Authorization

#### SiteAdminController

For single-website administration (subdomain-scoped).

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  before_action :require_admin!, unless: :bypass_admin_auth?

  def require_admin!
    unless current_user && user_is_admin_for_subdomain?
      render 'pwb/errors/admin_required', status: :forbidden
    end
  end

  def user_is_admin_for_subdomain?
    current_user&.admin_for?(current_website)
  end
end
```

#### TenantAdminController

For cross-tenant administration (not subdomain-scoped).

```ruby
class TenantAdminController < ActionController::Base
  before_action :authenticate_user!, unless: :bypass_admin_auth?
  before_action :require_tenant_admin!, unless: :bypass_admin_auth?

  def require_tenant_admin!
    unless tenant_admin_allowed?
      render 'pwb/errors/tenant_admin_required', status: :forbidden
    end
  end

  def tenant_admin_allowed?
    return false unless current_user
    allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip).map(&:downcase)
    allowed_emails.include?(current_user.email.downcase)
  end
end
```

**Configuration:**
```bash
TENANT_ADMIN_EMAILS=admin@example.com,super@example.com
```

### Development/E2E Bypass

For development and end-to-end testing, authentication can be bypassed:

```bash
BYPASS_ADMIN_AUTH=true  # Skip auth in /site_admin, /tenant_admin
BYPASS_API_AUTH=true    # Skip auth in API endpoints
```

**Important:** These only work in `development`, `e2e`, and `test` environments.

---

## Multi-Tenancy

### Tenant Resolution

Tenants are resolved via the `SubdomainTenant` concern:

1. `X-Website-Slug` header (for API clients)
2. Request subdomain (e.g., `tenant1.example.com`)
3. Default to first website

**Reserved Subdomains:**
```ruby
%w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo]
```

### Thread-Safe Context

The current tenant is stored in `Pwb::Current.website`:

```ruby
# Set tenant
Pwb::Current.website = website

# Access tenant
current_website = Pwb::Current.website

# Auto-scoping with acts_as_tenant
ActsAsTenant.current_tenant = current_website
```

### Session Isolation

Sessions are NOT shared between subdomains. Each subdomain has its own session cookie.

---

## Audit Logging

All authentication events are logged to `pwb_auth_audit_logs`.

**Key File:** `app/models/pwb/auth_audit_log.rb`

**Logged Events:**
- `login_success` / `login_failure`
- `logout`
- `oauth_success` / `oauth_failure`
- `password_reset_request` / `password_reset_success`
- `account_locked` / `account_unlocked`
- `session_timeout`
- `registration`

**Captured Data:**
- User ID and email
- Event type and timestamp
- IP address and user agent
- Request path
- Failure reason (for failed attempts)
- OAuth provider
- Website/tenant context

**Query Helpers:**
```ruby
Pwb::AuthAuditLog.for_user(user)
Pwb::AuthAuditLog.for_email(email)
Pwb::AuthAuditLog.for_ip(ip_address)
Pwb::AuthAuditLog.failures.last_hour
Pwb::AuthAuditLog.suspicious_ips(threshold: 10)
```

**Admin Access:** `/tenant_admin/auth_audit_logs`

---

## Database Schema

### pwb_users

Main user table with Devise fields:
- `email`, `encrypted_password`
- `firebase_uid` - For Firebase authentication
- `admin` - Super admin flag
- Devise tracking fields (sign_in_count, current_sign_in_at, etc.)
- Devise lockable fields (failed_attempts, locked_at, etc.)

### pwb_user_memberships

User-Website associations:
- `user_id`, `website_id`
- `role` - 'owner', 'admin', 'member', 'viewer'
- `active` - Boolean for active/inactive status

### pwb_authorizations

OAuth provider links:
- `user_id`
- `provider` - 'facebook', 'google', etc.
- `uid` - Provider's user ID

### pwb_auth_audit_logs

Authentication event history:
- `user_id`, `website_id` (optional)
- `event_type`, `email`
- `ip_address`, `user_agent`
- `metadata` - JSON for additional context

---

## Testing Authentication

### Running Auth Tests

```bash
# All auth-related tests
bundle exec rspec spec/services/pwb/firebase_auth_service_spec.rb
bundle exec rspec spec/models/pwb/auth_audit_log_spec.rb
bundle exec rspec spec/models/pwb/user_spec.rb
bundle exec rspec spec/models/pwb/user_membership_spec.rb
bundle exec rspec spec/requests/api_public/v1/auth_spec.rb
bundle exec rspec spec/controllers/site_admin/

# Full suite
bundle exec rspec
```

### Console Testing

```ruby
# Test user authentication
user = Pwb::User.find_by(email: 'test@example.com')
user.admin_for?(Pwb::Website.first)
user.accessible_websites

# Test membership service
Pwb::UserMembershipService.grant_access(
  user: user,
  website: Pwb::Website.first,
  role: 'admin'
)

# Test audit logs
Pwb::AuthAuditLog.recent.limit(10)
Pwb::AuthAuditLog.failures.last_hour
```

---

## Related Documentation

- `docs/FIREBASE_SETUP.md` - Firebase project configuration
- `docs/FIREBASE_TROUBLESHOOTING.md` - Common Firebase issues
- `docs/06_Multi_Tenancy.md` - Multi-tenancy architecture
- `docs/claude_thoughts/AUTH_QUICK_REFERENCE.md` - Quick reference guide
- `docs/claude_thoughts/AUTHENTICATION_SYSTEM_ANALYSIS.md` - Detailed technical analysis
