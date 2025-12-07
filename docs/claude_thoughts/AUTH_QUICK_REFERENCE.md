# PropertyWebBuilder Authentication - Quick Reference

## Two Auth Systems

### 1. Firebase (For Admin Panel)
- **Endpoint**: `/firebase_login`
- **Tech**: FirebaseUI + firebase_id_token gem
- **Methods**: Email/Password, Google OAuth
- **Flow**: Browser → Firebase → ID Token → POST `/api_public/v1/auth/firebase` → Devise sign_in
- **Config**: `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`
- **Token Validation**: `FirebaseAuthService` + JWT signature verification
- **Auto-creates**: User + UserMembership (role: 'member')

### 2. Devise (Traditional Rails Auth)
- **Type**: Email/password + Facebook OAuth
- **Modules**: database_authenticatable, registerable, recoverable, lockable, timeoutable, omniauthable
- **Config**: `config/initializers/devise.rb`
- **Controllers**: `app/controllers/pwb/devise/`
- **Session**: Secure HTTP-only cookies, NOT shared between subdomains

---

## Key Files

| File | Purpose |
|------|---------|
| `app/models/pwb/user.rb` | User model with Devise |
| `app/models/pwb/user_membership.rb` | User-Website association with roles |
| `app/services/pwb/firebase_auth_service.rb` | Firebase token verification |
| `app/controllers/pwb/firebase_login_controller.rb` | Firebase login views |
| `app/controllers/pwb/devise/sessions_controller.rb` | Login controller (validates subdomain) |
| `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` | OAuth callback |
| `app/controllers/api_public/v1/auth_controller.rb` | Firebase API endpoint |
| `app/models/pwb/auth_audit_log.rb` | Auth event logging |
| `config/initializers/devise.rb` | Devise configuration |
| `config/initializers/firebase_id_token.rb` | Firebase token verification setup |
| `app/controllers/concerns/subdomain_tenant.rb` | Multi-tenant subdomain resolution |
| `app/controllers/concerns/admin_auth_bypass.rb` | Dev/E2E auth bypass |

---

## Authentication Checks in Controllers

```ruby
# Site Admin (single website)
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  before_action :authenticate_user!, unless: :bypass_admin_auth?
end

# Tenant Admin (cross-tenant)
class TenantAdminController < ActionController::Base
  before_action :authenticate_user!, unless: :bypass_admin_auth?
end

# API Controllers
class ApplicationApiController < ActionController::Base
  before_action :authenticate_user!, :check_user, unless: :bypass_authentication?
end
```

---

## User Model - Key Methods

```ruby
# Check if user is admin for a website
user.admin_for?(website)

# Get role for a website
user.role_for(website)

# List accessible websites
user.accessible_websites

# Role helpers (via UserMembership)
membership.admin?           # owner or admin?
membership.owner?           # owner role?
membership.can_manage?(other)  # can manage other user?
```

---

## User Roles (Hierarchy)

```
owner (highest)
  ↓
admin
  ↓
member
  ↓
viewer (lowest)
```

---

## Admin Panels

| Panel | Route | Scope | Auth | Authorization |
|-------|-------|-------|------|---------------|
| /admin | Vue SPA | Public | None (client-side) | API endpoints enforce |
| /site_admin | Single website | Subdomain-scoped | Devise | TODO (Phase 2) |
| /tenant_admin | All websites | Cross-tenant | Devise | TODO (Phase 2) |
| /v-admin | Vue SPA | Public | None (client-side) | API endpoints enforce |

---

## Multi-Tenancy via Subdomains

```ruby
# Tenant resolution order:
# 1. X-Website-Slug header
# 2. Request subdomain
# 3. Default website (first)

# Reserved subdomains (cannot be tenant IDs):
%w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo]

# Access current website
Pwb::Current.website
current_website

# Session NOT shared between subdomains
# Each subdomain = separate session cookie
```

---

## Session & Authentication

```ruby
# Devise helpers (in all controllers)
current_user              # Logged-in user
user_signed_in?          # Check if authenticated
authenticate_user!       # Redirect to login if not auth
sign_in(user)           # Sign in a user
sign_out                 # Sign out

# Session config
Timeout: 30 minutes
Lockout: 5 failed attempts → 1 hour
Password cost: bcrypt with 11 stretches
```

---

## Firebase Authentication Flow

```
1. User visits /firebase_login
2. FirebaseUI widget shows email/password or "Sign in with Google"
3. User authenticates with Firebase (browser)
4. Firebase returns ID token
5. JavaScript: fetch('/api_public/v1/auth/firebase', {token: token})
6. Backend: FirebaseAuthService verifies JWT signature
7. Backend: Create/update User and UserMembership
8. Backend: sign_in(user) via Devise
9. User now has Devise session cookie
10. Redirect to /admin
```

---

## Devise Authentication Flow

```
1. User visits /users/sign_in
2. POST /users/sign_in with email/password
3. SessionsController validates user belongs to subdomain
4. Devise authenticates (check password, locked, timeout)
5. Warden hooks log the authentication event
6. Session cookie created
7. Redirect to /admin
```

---

## API Authentication

```ruby
# Requires Devise session (from login)
before_action :authenticate_user!

# Check user is admin for current website
before_action :check_user

# Can bypass in dev/e2e:
ENV['BYPASS_API_AUTH'] = 'true'
ENV['BYPASS_ADMIN_AUTH'] = 'true'
```

---

## Audit Logging

All auth events logged to `pwb_auth_audit_logs`:
- login_success / login_failure
- logout
- oauth_success / oauth_failure
- password_reset_request / password_reset_success
- account_locked / account_unlocked
- session_timeout
- registration

**Access via**:
- `Pwb::AuthAuditLog.for_user(user)`
- `Pwb::AuthAuditLog.for_email(email)`
- `Pwb::AuthAuditLog.for_ip(ip_address)`
- `Pwb::AuthAuditLog.failures.last_hour`
- `/tenant_admin/auth_audit_logs`

---

## Database Tables

| Table | Purpose |
|-------|---------|
| pwb_users | User accounts (email, password hash, firebase_uid) |
| pwb_user_memberships | User-Website associations (role: owner/admin/member/viewer) |
| pwb_authorizations | OAuth provider links (facebook, google, etc.) |
| pwb_auth_audit_logs | Authentication event history |

---

## Environment Variables

```bash
# Firebase (Required)
FIREBASE_API_KEY=your_key
FIREBASE_PROJECT_ID=your_project

# Dev/E2E Bypass (DON'T use in production)
BYPASS_ADMIN_AUTH=true    # Skip auth in admin panels
BYPASS_API_AUTH=true      # Skip auth in API
```

---

## Current Status

### What Works
- Devise email/password authentication
- Firebase authentication via FirebaseUI
- Facebook OAuth
- Multi-tenancy via subdomains
- Session management
- Account lockout and timeout
- Audit logging
- User memberships with roles

### What's Planned (Phase 2)
- Authorization checks (using roles/permissions)
- Super admin flag
- Granular permission system
- Resource-level access control

---

## Security Features

- Sessions: Secure HTTP-only cookies
- Passwords: bcrypt hashing with cost 11
- Account Lockout: 5 attempts → 1 hour lockout
- Session Timeout: 30 minutes inactivity
- Audit Logs: All auth events tracked
- CSRF Protection: Token validation
- Multi-Tenancy: Data isolation by subdomain
- Subdomain Validation: User scoped to website

---

## Useful Console Commands

```ruby
rails c

# Find user
user = Pwb::User.find_by(email: 'user@example.com')

# Check memberships
user.user_memberships
user.accessible_websites

# Create/update membership
Pwb::UserMembershipService.grant_access(
  user: user,
  website: Pwb::Website.first,
  role: 'admin'
)

# Check audit logs
Pwb::AuthAuditLog.recent.limit(10)
Pwb::AuthAuditLog.failures.last_hour
Pwb::AuthAuditLog.for_user(user)

# Mark as admin (Firebase only - manual step)
user.update(admin: true)
```

---

## Routes Summary

```ruby
# Firebase auth
GET  /firebase_login
GET  /firebase_sign_up
GET  /firebase_forgot_password
GET  /firebase_change_password
POST /api_public/v1/auth/firebase

# Devise auth (localized)
GET  /users/sign_in
POST /users
GET  /users/password/new
POST /users/password
PATCH /users/password
GET  /users/edit
PATCH /users

# OAuth
GET  /omniauth/:provider
GET  /users/auth/:provider/callback

# Admin panels
GET /admin (Vue SPA)
GET /v-admin (Vue SPA)
GET /site_admin (Subdomain-scoped)
GET /tenant_admin (Cross-tenant)
```

---

For detailed information, see: `/Users/etewiah/dev/sites-older/property_web_builder/docs/claude_thoughts/AUTHENTICATION_SYSTEM_ANALYSIS.md`
