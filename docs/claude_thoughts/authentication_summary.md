# Authentication System - Quick Reference Summary

## Current Authentication Stack

**Primary Framework**: Devise 4.8  
**OAuth Support**: OmniAuth 2.1 (Facebook)  
**Multi-Tenancy**: acts_as_tenant 1.0  
**Alternative Auth**: Firebase (partially implemented)

## Key Models

```
Pwb::User (NOT tenant-scoped)
  ├── has_many :authorizations (OAuth links)
  ├── has_many :user_memberships
  └── has_many :websites (through memberships)

PwbTenant::User (tenant-scoped via acts_as_tenant)
  └── Auto-scoped to current website

Pwb::UserMembership (Role-based access)
  ├── belongs_to :user
  ├── belongs_to :website
  └── Roles: owner, admin, member, viewer

Pwb::Authorization (OAuth)
  └── Links user to OAuth provider (provider, uid)
```

## Authentication Flows

| Flow | Route | Status |
|------|-------|--------|
| Email/Password | POST /users/sign_in | Implemented |
| Registration | POST /users/sign_up | Implemented |
| Password Reset | POST /users/password | Implemented |
| Email Confirmation | GET /users/confirmation | Implemented |
| Facebook OAuth | GET /users/auth/facebook | Implemented |
| Firebase Auth | /firebase_login | Partial |
| GraphQL Auth | POST /graphql | NOT implemented |
| API Tokens | N/A | NOT implemented |

## Security Features

### Implemented
- Bcrypt password hashing (cost: 11 in production)
- Email confirmation required
- Password reset (6-hour window)
- CSRF protection
- Session tracking (IP, count, timestamp)
- Multi-tenancy isolation via acts_as_tenant
- Role-based access control

### Missing
- Rate limiting on auth endpoints
- Account lockout (configured but disabled)
- Two-factor authentication
- Session timeout
- API token authentication (JWT/keys)
- Audit logging

## Critical Security Issues

### HIGH
1. **API Auth Bypass**: `BYPASS_API_AUTH=true` disables all authentication
2. **GraphQL No Auth**: `current_user` always returns nil
3. **No Rate Limiting**: Login/signup/password reset unprotected
4. **Account Lockout Disabled**: Brute force attacks possible

### MEDIUM
5. **No Session Timeout**: Stolen sessions never expire
6. **No 2FA**: Only password as factor
7. **OAuth Email Issue**: Invalid fallback email created
8. **No API Tokens**: All API clients must use session auth

## Multi-Tenancy Architecture

```
Request → Subdomain Resolution → Set Pwb::Current.website
                ↓
         SiteAdminController (scoped)
                ↓
         ActsAsTenant auto-scopes PwbTenant:: models
```

**Key Classes**:
- `SubdomainTenant` concern: Resolves website from subdomain
- `RequiresTenant` concern: Enforces tenant on PwbTenant:: models
- `SiteAdminController`: Single-website scoped admin
- `TenantAdminController`: Cross-tenant (NO scoping)

## Devise Configuration Highlights

```ruby
# Authentication strategies
devise :database_authenticatable, :registerable, :recoverable,
       :rememberable, :trackable, :validatable, :omniauthable

# Password hashing
config.stretches = Rails.env.test? ? 1 : 11

# Password requirements
config.password_length = 6..128  # Can increase to 10-12

# Email confirmation
config.reconfirmable = true  # Require confirmation for email changes

# Account lockout (DISABLED)
# config.lock_strategy = :failed_attempts
# config.maximum_attempts = 20
# config.unlock_strategy = :both
# config.unlock_in = 1.hour

# Session management
config.expire_all_remember_me_on_sign_out = true
config.sign_out_via = :delete  # Prevents CSRF via GET

# Password reset window
config.reset_password_within = 6.hours
```

## Admin Access Control

**Three-tiered approach**:

1. **Admin Panel** (`/admin`)
   - Requires: `user.admin_for?(website)`
   - Can bypass: `BYPASS_ADMIN_AUTH=true` (dev/e2e only)

2. **Site Admin** (`/site_admin`)
   - Requires: Devise authentication
   - Scoped to: Current subdomain/website
   - Can bypass: `BYPASS_ADMIN_AUTH=true`

3. **Tenant Admin** (`/tenant_admin`)
   - Requires: Devise authentication
   - Scope: Cross-tenant (no automatic scoping)
   - Can bypass: `BYPASS_ADMIN_AUTH=true`
   - Note: Authorization layer missing (Phase 2)

## Role Hierarchy

```
owner   ← Full control, manages admins
  ↓
admin   ← Can manage most resources
  ↓
member  ← Can access assigned resources
  ↓
viewer  ← Read-only access
```

Methods:
- `user.admin_for?(website)`: Check owner/admin status
- `user.role_for(website)`: Get user's role
- `membership.can_manage?(other)`: Hierarchical comparison

## API Authentication

### Current State
- **Session-based**: Uses Devise session cookie
- **Bypass**: `ENV['BYPASS_API_AUTH']='true'` disables auth entirely
- **Rate Limiting**: None
- **API Tokens**: Not implemented
- **GraphQL**: No authentication

### Controller Pattern
```ruby
class ApplicationApiController < ActionController::Base
  before_action :authenticate_user!, unless: :bypass_authentication?
  before_action :check_user
  
  # Requires user to be admin for current website
end
```

## Database Schema (Auth Tables)

### pwb_users
- Email (unique, case-insensitive)
- encrypted_password (bcrypt)
- reset_password_token
- confirmation_token
- failed_attempts, unlock_token
- admin (boolean)
- website_id (legacy, optional)
- firebase_uid (optional)

### pwb_authorizations
- user_id (FK)
- provider (e.g., 'facebook')
- uid (provider's user ID)

### pwb_user_memberships
- user_id (FK)
- website_id (FK)
- role (owner/admin/member/viewer)
- active (boolean)
- Unique constraint: [user_id, website_id]

## Key Files

```
Authentication Core:
  /app/models/pwb/user.rb
  /app/models/pwb/user_membership.rb
  /app/models/pwb/authorization.rb

Tenant Scoping:
  /app/models/pwb_tenant/user.rb
  /app/controllers/concerns/subdomain_tenant.rb
  /app/models/concerns/pwb_tenant/requires_tenant.rb

Controllers:
  /app/controllers/pwb/devise/sessions_controller.rb
  /app/controllers/pwb/devise/registrations_controller.rb
  /app/controllers/pwb/devise/omniauth_callbacks_controller.rb
  /app/controllers/pwb/admin_panel_controller.rb
  /app/controllers/site_admin_controller.rb
  /app/controllers/tenant_admin_controller.rb

Configuration:
  /config/initializers/devise.rb
  /config/initializers/firebase_id_token.rb
  /config/initializers/session_store.rb
  /config/routes.rb
```

## Environment Variables for Authentication

```bash
# Firebase
FIREBASE_PROJECT_ID=your-project-id

# Development/Testing Bypasses (NON-PRODUCTION ONLY)
BYPASS_API_AUTH=true        # Skip API authentication
BYPASS_ADMIN_AUTH=true      # Skip admin authentication
```

## Quick Fixes to Implement

### Priority 1: Security Controls
```ruby
# Enable account lockout in devise.rb
config.lock_strategy = :failed_attempts
config.maximum_attempts = 5
config.unlock_strategy = :time
config.unlock_in = 30.minutes

# Add to routes
gem 'rack-attack'  # Rate limiting
gem 'devise-two-factor'  # 2FA support
gem 'devise-security'  # Additional security
```

### Priority 2: API Authentication
```ruby
# Generate JWT tokens
def create_token(user)
  payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
  JWT.encode(payload, Rails.application.credentials.jwt_secret)
end
```

### Priority 3: Audit Logging
```ruby
# Track authentication events
Auditor.log_auth(:login, user, current_website)
Auditor.log_auth(:password_reset, user, current_website)
Auditor.log_auth(:oauth_signup, user, provider)
```

## Common Pitfalls

1. **Don't use `Pwb::User` in web controllers**
   - Use `PwbTenant::User` for automatic tenant scoping
   - Or manually scope: `ActsAsTenant.with_tenant(website) { ... }`

2. **Don't skip tenant checks**
   - `TenantAdminController` explicitly bypasses scoping
   - Make sure authorization layer is added

3. **Don't rely on `admin` column for RBAC**
   - Use `user_memberships` and role hierarchy
   - `admin` is legacy, mostly unused

4. **Don't enable BYPASS_* in production**
   - These should only be in development/test
   - Add assertion: `assert_not_enabled_in_production`

5. **Don't forget CSRF in API endpoints**
   - Use `null_session` carefully
   - Document why CSRF is skipped

## Testing Authentication

```ruby
# Sign in for tests
sign_in user

# Sign in as admin for website
user.user_memberships.create(website: website, role: 'admin', active: true)
sign_in user

# Check authorization
expect(user.admin_for?(website)).to be true
expect(user.role_for(website)).to eq 'admin'

# Test tenant scoping
ActsAsTenant.with_tenant(website) do
  expect(PwbTenant::User.all).to include(user)
end
```

## Resources

- Devise Wiki: https://github.com/heartcombo/devise/wiki
- OmniAuth: https://github.com/omniauth/omniauth
- acts_as_tenant: https://github.com/ErwinM/acts-as-tenant
- OWASP Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html

---

**Last Updated**: December 7, 2025
**Created by**: Authentication Analysis Report
