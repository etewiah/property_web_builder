# Authentication and Authorization System - Comprehensive Summary

**Last Updated**: December 7, 2025  
**Status**: Complete and verified against codebase  
**Compiled by**: Claude Code

---

## Executive Summary

PropertyWebBuilder uses a **dual authentication system** with Devise and Firebase, combined with **role-based multi-tenant access control**. This document provides a complete overview of:

1. **What's Implemented** - Working features
2. **What's Missing** - Authorization gaps
3. **Documentation Status** - What's documented where
4. **Test Coverage** - Existing tests
5. **Key Files** - Essential code locations

---

## 1. Authentication Implementation Status

### 1.1 What's Implemented ✓

The application has **two complete authentication systems**:

#### Firebase Authentication
- Location: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_auth_service.rb`
- **Method**: FirebaseUI widget → User login → ID token → Rails verification
- **Features**:
  - Email/password authentication
  - Google OAuth sign-in
  - JWT signature verification using `firebase_id_token` gem
  - Auto-creates users on first login
  - Creates membership with 'member' role
- **Configuration**: `config/initializers/firebase_id_token.rb`
- **Routes**:
  - GET `/firebase_login` - Login page
  - GET `/firebase_sign_up` - Sign-up page
  - GET `/firebase_forgot_password` - Password reset
  - POST `/api_public/v1/auth/firebase` - Token verification endpoint
- **Documentation**: `/Users/etewiah/dev/sites-older/property_web_builder/docs/FIREBASE_SETUP.md`

#### Devise Authentication
- Location: `app/models/pwb/user.rb`
- **Method**: Traditional Rails authentication with email/password
- **Modules Enabled**:
  - `:database_authenticatable` - Email/password login
  - `:registerable` - User registration
  - `:recoverable` - Password reset
  - `:rememberable` - Remember me cookie
  - `:trackable` - Sign-in tracking (IP, count, timestamps)
  - `:validatable` - Email/password validation
  - `:lockable` - Account lockout after failed attempts
  - `:timeoutable` - Session timeout (30 minutes)
  - `:omniauthable` - OAuth support (Facebook)

**Configuration**: `config/initializers/devise.rb`

**Key Settings**:
```
- Password cost: bcrypt with 11 stretches
- Session timeout: 30 minutes inactivity
- Account lockout: 5 failed attempts
- Unlock strategy: Email + auto-unlock after 1 hour
- Sign-out method: DELETE request
```

**Controllers**:
- `app/controllers/pwb/devise/sessions_controller.rb` - Login/logout
- `app/controllers/pwb/devise/passwords_controller.rb` - Password reset
- `app/controllers/pwb/devise/registrations_controller.rb` - Registration
- `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` - Facebook OAuth

#### OAuth Integration
- **Supported Providers**:
  - Facebook (via OmniAuth)
  - Google (via Firebase)
- **Model**: `app/models/pwb/authorization.rb`
- **Table**: `pwb_authorizations` (links OAuth providers to users)

### 1.2 Session Management ✓

- **Store**: Cookie-based sessions (`config/initializers/session_store.rb`)
- **Security**: HTTP-only cookies (secure by default)
- **Tenant Isolation**: Sessions NOT shared between subdomains
- **Helpers**: Devise provides `current_user`, `user_signed_in?`, `authenticate_user!`

### 1.3 Authentication Audit Logging ✓

**Model**: `app/models/pwb/auth_audit_log.rb`

**Events Logged**:
- login_success / login_failure
- logout
- oauth_success / oauth_failure
- password_reset_request / password_reset_success
- account_locked / account_unlocked
- session_timeout
- registration

**Captured Data**:
- User ID and email
- Event type and timestamp
- IP address and user agent
- Request path
- Failure reason (for failed attempts)
- OAuth provider
- Website/tenant context

**Access**: `/tenant_admin/auth_audit_logs` dashboard

---

## 2. Authorization Implementation Status

### 2.1 What's Implemented ✓

#### Role-Based Access (Multi-Tenancy)
- Location: `app/models/pwb/user_membership.rb`
- **Database Table**: `pwb_user_memberships`
- **Role Hierarchy**:
  1. **owner** - Full control (highest)
  2. **admin** - Admin access
  3. **member** - Regular member
  4. **viewer** - Read-only access (lowest)

**Key Features**:
- Each user has memberships to multiple websites
- Each membership has a specific role
- Memberships can be active/inactive
- Helper method: `user.admin_for?(website)`
- Role checking: `user.role_for(website)`

#### Site Admin Controller
- Location: `app/controllers/site_admin_controller.rb`
- **Scope**: Single website/tenant
- **Authentication**: ✓ Requires Devise login
- **Authorization**: ✓ Checks `user_is_admin_for_subdomain?`
- **Multi-tenancy**: ✓ Scoped via `acts_as_tenant`
- **Bypass**: Can skip auth with `BYPASS_ADMIN_AUTH=true` (dev/e2e only)
- **Helper Method**: `require_admin!` enforces admin check

#### Tenant Admin Controller
- Location: `app/controllers/tenant_admin_controller.rb`
- **Scope**: Cross-tenant (all websites)
- **Authentication**: ✓ Requires Devise login
- **Authorization**: ✓ Email-based whitelist via `TENANT_ADMIN_EMAILS` env var
- **Bypass**: Can skip auth with `BYPASS_ADMIN_AUTH=true` (dev/e2e only)
- **Helper Method**: `require_tenant_admin!` checks email whitelist

### 2.2 What's MISSING ✗

#### No Authorization Gem
- **Status**: Not using Pundit, CanCanCan, or similar
- **Impact**: Authorization must be checked manually in each controller
- **Gap**: No consistent authorization framework

#### No Granular Permissions
- **Status**: Only roles exist (owner/admin/member/viewer)
- **Missing**:
  - Permission matrix (e.g., "can_edit_properties", "can_manage_users")
  - Resource-level authorization (e.g., "can_edit_property_123")
  - Action-level permissions (create/read/update/delete)


---

## 3. Multi-Tenancy Implementation

### 3.1 Tenant Resolution ✓

**Location**: `app/controllers/concerns/subdomain_tenant.rb`

**Resolution Priority**:
1. `X-Website-Slug` header (API clients)
2. Request subdomain (e.g., `tenant1.app.com`)
3. Default to first website

**Reserved Subdomains**:
- www, api, admin, app, mail, ftp, smtp, pop, imap, ns1, ns2, localhost, staging, test, demo

**Implementation**: `Pwb::Current.website` - Thread-safe context for current tenant

### 3.2 User Access Scoping ✓

**User's accessible websites**: Via `user_memberships.active`

```ruby
user.accessible_websites      # All websites user is active member of
user.user_memberships         # All memberships (active + inactive)
user.admin_for?(website)      # Check if admin for specific website
user.role_for(website)        # Get user's role for website
user.can_access_website?(w)   # Check basic access
```

### 3.3 Model Scoping ✓

**Using `acts_as_tenant` gem**:
- `PwbTenant::` models are auto-scoped to `Pwb::Current.website`
- Example: `Pwb::PwbTenant::Property.all` only returns properties for current website
- Controllers must include `SubdomainTenant` concern to set current website

---

## 4. Documentation Status

### 4.1 Comprehensive Documentation ✓

Extensive documentation already exists in `/docs/claude_thoughts/`:

| Document | Path | Purpose |
|----------|------|---------|
| **README_AUTHENTICATION.md** | `docs/claude_thoughts/README_AUTHENTICATION.md` | Main index and quick navigation |
| **AUTHENTICATION_SYSTEM_ANALYSIS.md** | `docs/claude_thoughts/AUTHENTICATION_SYSTEM_ANALYSIS.md` | 200KB detailed technical analysis with code examples |
| **AUTH_QUICK_REFERENCE.md** | `docs/claude_thoughts/AUTH_QUICK_REFERENCE.md` | 20KB daily reference guide |
| **AUTH_ARCHITECTURE_DIAGRAMS.md** | `docs/claude_thoughts/AUTH_ARCHITECTURE_DIAGRAMS.md` | Visual flow diagrams |
| **AUTH_INVESTIGATION_SUMMARY.md** | `docs/claude_thoughts/AUTH_INVESTIGATION_SUMMARY.md` | Executive summary |
| **UNIFIED_AUTH_PLAN.md** | `docs/claude_thoughts/UNIFIED_AUTH_PLAN.md` | Future implementation roadmap |

### 4.2 Firebase Setup Guide ✓

**Location**: `/docs/FIREBASE_SETUP.md`
- Step-by-step Firebase project setup
- Environment variable configuration
- Creating test users
- Troubleshooting guide

### 4.3 Gaps in Documentation

- [ ] Authorization system gaps (what's missing)
- [ ] Implementation recommendations for Phase 2
- [ ] API authorization requirements (which endpoints need what roles)
- [ ] SPA-level authorization (admin vs site_admin vs tenant_admin)
- [ ] Testing authorization (how to test role enforcement)

---

## 5. Test Coverage Analysis

### 5.1 Authentication Tests ✓

**Firebase Auth Service**
- `/spec/services/pwb/firebase_auth_service_spec.rb` - 65+ lines
- Tests: User creation, email lookup, firebase_uid updates, invalid tokens
- Coverage: ✓ Good

**API Firebase Auth Endpoint**
- `/spec/requests/api_public/v1/auth_spec.rb` - 47 lines
- Tests: Valid token, invalid token, missing token scenarios
- Coverage: ✓ Good

**User Model**
- `/spec/models/pwb/user_spec.rb` - 77 lines
- Tests: OAuth authentication (Facebook), authorization creation
- Coverage: ✓ OAuth functional tests

**Auth Audit Log Model**
- `/spec/models/pwb/auth_audit_log_spec.rb` - 335 lines
- Tests: All event types, logging methods, query helpers, suspicious activity
- Coverage: ✓ Excellent (335 lines of tests)

### 5.2 Authorization Tests ✗

**What's Missing**:
- [ ] SiteAdminController authorization tests (require_admin! checks)
- [ ] TenantAdminController authorization tests (email whitelist checks)
- [ ] API endpoint authorization tests (user.admin_for? enforcement)
- [ ] Multi-tenant isolation tests (can users access other tenant's data?)
- [ ] Role hierarchy tests (ownership/management checks)
- [ ] UserMembership role tests

### 5.3 Test Summary

**Total Auth-Related Tests**: ~530 lines
- ✓ Authentication: ~400 lines (Firebase, Devise, OAuth, Audit)
- ✗ Authorization: ~0 lines (gap)
- ✓ Models: ~150 lines (User, UserMembership, AuthAuditLog)
- ✗ Controllers: ~0 lines (gap)

---

## 6. Key Files Reference

### Core Models

| File | Purpose |
|------|---------|
| `app/models/pwb/user.rb` | Main user model with Devise |
| `app/models/pwb/user_membership.rb` | User-to-website associations with roles |
| `app/models/pwb/authorization.rb` | OAuth provider links |
| `app/models/pwb/auth_audit_log.rb` | Authentication event logging |

### Services

| File | Purpose |
|------|---------|
| `app/services/pwb/firebase_auth_service.rb` | Firebase token verification |
| `app/services/pwb/user_membership_service.rb` | Membership management (grant, revoke, change role) |

### Controllers

| File | Purpose | Auth | Authz |
|------|---------|------|-------|
| `app/controllers/pwb/devise/sessions_controller.rb` | Login/logout | ✓ | ✗ |
| `app/controllers/pwb/devise/passwords_controller.rb` | Password reset | ✓ | ✗ |
| `app/controllers/pwb/devise/registrations_controller.rb` | Registration | ✓ | ✗ |
| `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` | OAuth | ✓ | ✗ |
| `app/controllers/site_admin_controller.rb` | Site admin base | ✓ | ✓ |
| `app/controllers/tenant_admin_controller.rb` | Tenant admin base | ✓ | ✓ |
| `app/controllers/pwb/firebase_login_controller.rb` | Firebase UI | ✗ | ✗ |
| `app/controllers/api_public/v1/auth_controller.rb` | Firebase API | ✗ | ~ |

### Concerns

| File | Purpose |
|------|---------|
| `app/controllers/concerns/subdomain_tenant.rb` | Multi-tenant context setting |
| `app/controllers/concerns/admin_auth_bypass.rb` | Dev/E2E bypass mechanism |

### Configuration

| File | Purpose |
|------|---------|
| `config/initializers/devise.rb` | Devise configuration |
| `config/initializers/firebase_id_token.rb` | Firebase JWT verification |
| `config/initializers/pwb_auth.rb` | Auth provider switching (Firebase vs Devise) |
| `config/initializers/auth_audit_hooks.rb` | Warden hooks for audit logging |
| `config/initializers/session_store.rb` | Session storage configuration |

### Migrations

| File | Purpose |
|------|---------|
| `db/migrate/*devise*.rb` | User table (email, password, etc.) |
| `db/migrate/*firebase*.rb` | Firebase UID column |
| `db/migrate/*user_membership*.rb` | UserMembership table |
| `db/migrate/*auth_audit*.rb` | AuthAuditLog table |
| `db/migrate/*authorization*.rb` | Authorization table (OAuth) |

---

## 7. Architecture Overview

### High-Level Flow

```
User Request
  ↓
SubdomainTenant Concern
  ├─ Resolve tenant from subdomain/header
  └─ Set Pwb::Current.website
  ↓
Authentication (Devise/Firebase)
  ├─ Check session cookie
  └─ Set current_user
  ↓
Authorization (Admin/Membership)
  ├─ Check if admin for website
  ├─ Check if owner/admin via membership
  └─ Allow/deny based on role
  ↓
Controller Action
  ↓
Audit Log (Warden hooks)
  └─ Log authentication events
```

### Database Relationships

```
User (pwb_users)
├── has_many :user_memberships
├── has_many :websites (through memberships)
├── has_many :authorizations (OAuth)
└── has_many :auth_audit_logs

UserMembership (pwb_user_memberships)
├── belongs_to :user
├── belongs_to :website
└── attributes: role, active

Website (pwb_websites)
├── has_many :user_memberships
└── has_many :users (through memberships)

Authorization (pwb_authorizations)
├── belongs_to :user
└── attributes: provider, uid

AuthAuditLog (pwb_auth_audit_logs)
├── belongs_to :user (optional)
├── belongs_to :website (optional)
└── attributes: event_type, email, ip_address, user_agent, metadata
```

---

## 8. Security Features

### Implemented ✓

1. **Session Timeout**: 30 minutes inactivity
2. **Account Lockout**: 5 failed attempts → 1 hour lockout
3. **Password Hashing**: bcrypt with 11 stretches
4. **CSRF Protection**: Automatic on all form submissions
5. **Multi-Tenancy Isolation**: Users scoped to websites via memberships
6. **Audit Logging**: All auth events logged with IP, user agent, timestamp
7. **Brute Force Detection**: Track failed attempts per email and IP
8. **OAuth Security**: JWT signature verification for Firebase tokens
9. **Secure Cookies**: HTTP-only, SameSite settings

### Environment-Based Bypass (Dev/E2E Only) ✓

```bash
BYPASS_ADMIN_AUTH=true      # Skip auth in /admin, /site_admin, /tenant_admin
BYPASS_API_AUTH=true        # Skip auth in /api endpoints
```

**Security**: Only works in development, e2e, test environments. Production immune.

---

## 9. Current Limitations & Gaps

### Authorization Gaps

1. **No Authorization Framework**
   - No Pundit, CanCanCan, or similar gem
   - Authorization checks scattered across controllers
   - Difficult to maintain and audit

2. **Inconsistent Authorization**
   - `/admin` (Vue SPA) - Authorization at API level only
   - `/site_admin` - Authorization in controller ✓
   - `/tenant_admin` - Authorization in controller ✓
   - No consistent pattern

3. **No Granular Permissions**
   - Only roles exist (owner/admin/member/viewer)
   - No permission matrix
   - No resource-level authorization

4. **Missing Tests**
   - No authorization controller tests
   - No multi-tenant isolation tests
   - No role enforcement tests

### API Authorization

- **Status**: Partially implemented
- **Gap**: Not all endpoints check `user.admin_for?(website)`
- **Need**: Audit all endpoints and add authorization checks

### Admin Flag Usage

- **Status**: Exists but not consistently used
- **Gap**: Unclear distinction between super-admin and website-admin
- **Need**: Define and enforce admin/super-admin roles

---

## 10. Recommended Next Steps

### Phase 1: Documentation (Current)
- ✓ Authentication system analyzed
- ✓ Authorization gaps identified
- ✓ Documentation created
- **Next**: Review with team, get feedback

### Phase 2: Authorization Implementation (Planned)
- [ ] Choose authorization gem (Pundit or CanCanCan)
- [ ] Define permission matrix
- [ ] Add authorization to all controllers
- [ ] Add authorization tests
- [ ] Audit API endpoints
- [ ] Document authorization patterns
- [ ] Implement resource-level authorization

### Phase 3: Security Hardening (Future)
- [ ] Remove bypass mechanisms from production
- [ ] Add rate limiting (Rack::Attack configured but may need tuning)
- [ ] Two-factor authentication (2FA)
- [ ] IP whitelisting for admin access
- [ ] Session encryption
- [ ] Regular security audits

---

## 11. Configuration Reference

### Environment Variables

```bash
# Firebase (Required for Firebase auth)
FIREBASE_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id

# Auth provider selection (default: firebase)
AUTH_PROVIDER=firebase  # or 'devise'

# Tenant admin authorization
TENANT_ADMIN_EMAILS=admin@example.com,super@example.com

# Development/E2E bypass (DON'T use in production!)
BYPASS_ADMIN_AUTH=true      # Skip auth in /admin, /site_admin, /tenant_admin
BYPASS_API_AUTH=true        # Skip auth in /api endpoints
```

### Devise Configuration

File: `config/initializers/devise.rb`

Key settings:
- `config.timeout_in = 30.minutes`
- `config.lock_strategy = :failed_attempts`
- `config.maximum_attempts = 5`
- `config.unlock_strategy = :both`
- `config.unlock_in = 1.hour`
- `config.stretches = 11`

### Rails Gems

```ruby
gem "devise", "~> 4.8"              # Authentication
gem "omniauth", "~> 2.1"            # OAuth framework
gem "omniauth-facebook"             # Facebook OAuth
gem "firebase"                      # Firebase client
gem "firebase_id_token", "~> 2.5"   # JWT verification
gem "acts_as_tenant"                # Multi-tenancy scoping
```

---

## 12. Testing Authentication

### Quick Tests (Console)

```ruby
# Test Devise auth
user = Pwb::User.find_by(email: 'user@example.com')
user.admin_for?(Pwb::Website.first)
user.accessible_websites

# Test Firebase service
token = "your_firebase_token"
service = Pwb::FirebaseAuthService.new(token)
result = service.call

# Test audit logs
Pwb::AuthAuditLog.recent.limit(10)
Pwb::AuthAuditLog.failures.last_hour
Pwb::AuthAuditLog.for_user(user).limit(5)
Pwb::AuthAuditLog.suspicious_ips(threshold: 10)
```

### Running Tests

```bash
# All auth tests
rspec spec/services/pwb/firebase_auth_service_spec.rb
rspec spec/models/pwb/auth_audit_log_spec.rb
rspec spec/models/pwb/user_spec.rb
rspec spec/models/pwb/user_membership_spec.rb
rspec spec/requests/api_public/v1/auth_spec.rb
rspec spec/helpers/auth_helper_spec.rb
rspec spec/lib/pwb/auth_config_spec.rb

# Full test suite
rspec
```

---

## 13. Getting Help

### Find Documentation For

| Topic | Document | Location |
|-------|----------|----------|
| Quick overview | AUTH_INVESTIGATION_SUMMARY.md | `docs/claude_thoughts/` |
| Technical details | AUTHENTICATION_SYSTEM_ANALYSIS.md | `docs/claude_thoughts/` |
| Daily reference | AUTH_QUICK_REFERENCE.md | `docs/claude_thoughts/` |
| Architecture | AUTH_ARCHITECTURE_DIAGRAMS.md | `docs/claude_thoughts/` |
| Firebase setup | FIREBASE_SETUP.md | `docs/` |
| Flow diagrams | README_AUTHENTICATION.md | `docs/claude_thoughts/` |

### Common Questions

- **How do users authenticate?** → FIREBASE_SETUP.md or AUTH_QUICK_REFERENCE.md
- **How does multi-tenancy work?** → AUTH_ARCHITECTURE_DIAGRAMS.md (Multi-Tenancy section)
- **How do I check admin status?** → AUTH_QUICK_REFERENCE.md (console commands)
- **What gets logged?** → AUTH_QUICK_REFERENCE.md (audit section)
- **Which endpoints are protected?** → AUTHENTICATION_SYSTEM_ANALYSIS.md (section 6)

---

## 14. Summary Table

| Feature | Status | Documentation | Tests | Notes |
|---------|--------|---|---|---|
| **Authentication** | ✓ Complete | ✓ Extensive | ✓ Good | Firebase + Devise |
| **Session Management** | ✓ Complete | ✓ Good | ~ Partial | Cookie-based, 30 min timeout |
| **Multi-Tenancy** | ✓ Complete | ✓ Good | ~ Partial | Subdomain-based |
| **User Memberships** | ✓ Complete | ✓ Good | ✓ Good | Roles: owner/admin/member/viewer |
| **Audit Logging** | ✓ Complete | ✓ Good | ✓ Excellent | All events logged |
| **Authorization** | ⚠ Partial | ✓ Good (gaps) | ✗ Missing | Only site_admin/tenant_admin |
| **API Authorization** | ⚠ Partial | ✓ Documented | ✗ Missing | Inconsistent enforcement |
| **Granular Permissions** | ✗ None | ⚠ Not documented | ✗ None | No permission matrix |
| **Authorization Gem** | ✗ None | ⚠ Not documented | ✗ None | Manual authorization |
| **Resource Authorization** | ✗ None | ⚠ Not documented | ✗ None | No per-resource checks |

---

## 15. Conclusion

PropertyWebBuilder has a **solid, well-documented authentication system** with:
- ✓ Multiple authentication methods (Firebase, Devise, OAuth)
- ✓ Comprehensive multi-tenancy support
- ✓ Audit logging for security monitoring
- ✓ Strong session and account security

However, **authorization is incomplete** with:
- ⚠ No authorization gem/framework
- ⚠ Inconsistent role enforcement
- ⚠ Missing granular permissions
- ⚠ Insufficient test coverage for authorization

**Recommended**: Implement Phase 2 authorization system using Pundit or CanCanCan to address current gaps and ensure consistent, maintainable authorization across the application.

---

## Document Information

- **Created**: December 7, 2025
- **Compiled By**: Claude Code (Anthropic)
- **Status**: Verified against codebase
- **Scope**: Complete authentication and authorization analysis
- **Next Review**: After Phase 2 authorization implementation
- **Related Docs**:
  - `docs/claude_thoughts/AUTHENTICATION_SYSTEM_ANALYSIS.md` (detailed analysis)
  - `docs/claude_thoughts/AUTH_QUICK_REFERENCE.md` (quick reference)
  - `docs/FIREBASE_SETUP.md` (Firebase configuration)
