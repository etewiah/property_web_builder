# Authentication System Documentation Index

Welcome! This folder contains comprehensive documentation of PropertyWebBuilder's authentication system.

## Quick Navigation

### I want a quick overview
Start with: **`AUTH_INVESTIGATION_SUMMARY.md`** (5 min read)
- Summary of findings
- What works, what doesn't
- Recommendations
- Links to other docs

### I need to understand the code
Start with: **`AUTHENTICATION_SYSTEM_ANALYSIS.md`** (30-60 min read)
- Complete technical analysis
- Code examples and file paths
- All configuration details
- Database schema
- Testing instructions

### I need a cheat sheet for daily work
Start with: **`AUTH_QUICK_REFERENCE.md`** (5 min lookup)
- Quick facts about each system
- Key files and locations
- Authentication checks
- Console commands
- Routes summary

### I need to understand the architecture
Start with: **`AUTH_ARCHITECTURE_DIAGRAMS.md`** (15 min read)
- System architecture diagram
- Firebase authentication flow (step-by-step)
- Devise authentication flow (step-by-step)
- Multi-tenancy flow
- Session lifecycle
- Database relationships

---

## Document Overview

| Document | Length | Best For | Reading Time |
|----------|--------|----------|--------------|
| `AUTH_INVESTIGATION_SUMMARY.md` | 3KB | Getting oriented, next steps | 5 min |
| `AUTH_QUICK_REFERENCE.md` | 20KB | Daily reference, quick lookups | 5 min |
| `AUTHENTICATION_SYSTEM_ANALYSIS.md` | 200KB | Complete understanding, implementation | 60 min |
| `AUTH_ARCHITECTURE_DIAGRAMS.md` | 50KB | Understanding flows, architecture | 15 min |

---

## Key Questions Answered

### How does Firebase authentication work?

**File**: `AUTH_ARCHITECTURE_DIAGRAMS.md` (Firebase section)

**Quick answer**: FirebaseUI widget → User login → Firebase returns ID token → POST token to Rails → verify JWT signature → create/update user → sign in with Devise

**Details**: See `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 1

### What about Devise/traditional Rails authentication?

**File**: `AUTH_QUICK_REFERENCE.md` or `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 2

**Quick answer**: Email/password form → Warden authenticates → check password → create session cookie → available

**Key features**: 30 min timeout, 5 attempts → 1 hour lockout, bcrypt password hashing

### How does multi-tenancy work?

**File**: `AUTH_ARCHITECTURE_DIAGRAMS.md` (Multi-Tenancy section)

**Quick answer**: Subdomain resolution → look up website record → set `Pwb::Current.website` → auto-scope all queries to that website

**User access**: Via `user_memberships` with roles (owner, admin, member, viewer)

### Which admin panels require authentication?

**File**: `AUTH_QUICK_REFERENCE.md` (Admin Panels table)

| Panel | Auth Required | Scope |
|-------|---------------|-------|
| `/admin` | No (API enforces) | Public SPA |
| `/v-admin` | No (API enforces) | Public SPA |
| `/site_admin` | Yes | Single website |
| `/tenant_admin` | Yes | All websites |

### How do I check if a user is authenticated in a controller?

**File**: `AUTH_QUICK_REFERENCE.md` or `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 4

**Quick answer**: Use Devise helpers:
```ruby
current_user           # Get logged-in user
user_signed_in?       # Check if authenticated
authenticate_user!    # Require authentication
```

### How is authorization different from authentication?

**File**: `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 14

**Quick answer**: 
- **Authentication** = Who are you? (login/session)
- **Authorization** = What can you do? (permissions/roles)

Currently implemented: Authentication ✓, Authorization (Phase 2)

### Can I bypass authentication in development?

**File**: `AUTH_QUICK_REFERENCE.md` or `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 9

**Quick answer**: Yes! Set environment variables:
```bash
BYPASS_ADMIN_AUTH=true    # Skip auth in admin panels
BYPASS_API_AUTH=true      # Skip auth in API
```

**WARNING**: Only works in `development`, `e2e`, `test` environments. Production is immune.

### What gets logged in the audit trail?

**File**: `AUTH_QUICK_REFERENCE.md` or `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 7

**Logged events**:
- login_success / login_failure
- logout
- oauth_success / oauth_failure
- password_reset_request / password_reset_success
- account_locked / account_unlocked
- session_timeout
- registration

**Access**: `/tenant_admin/auth_audit_logs` dashboard

---

## Common Tasks

### Task: Add a new user to a website

```ruby
# In Rails console
user = Pwb::User.create!(
  email: "user@example.com",
  password: "secure_password_123",
  password_confirmation: "secure_password_123"
)

website = Pwb::Website.first

Pwb::UserMembershipService.grant_access(
  user: user,
  website: website,
  role: 'member'  # or 'admin', 'owner', 'viewer'
)
```

### Task: Check if user is admin for a website

```ruby
user = Pwb::User.find_by(email: 'user@example.com')
website = Pwb::Website.first

if user.admin_for?(website)
  puts "User is admin"
else
  puts "User is not admin"
end
```

### Task: View recent authentication events

```ruby
# Last 10 auth events globally
Pwb::AuthAuditLog.recent.limit(10)

# Failed logins in last hour
Pwb::AuthAuditLog.failures.last_hour

# All events for a specific user
Pwb::AuthAuditLog.for_user(user).limit(20)

# Suspicious IPs (10+ failures in 1 hour)
Pwb::AuthAuditLog.suspicious_ips(threshold: 10, since: 1.hour.ago)
```

### Task: Test Firebase authentication

See `AUTHENTICATION_SYSTEM_ANALYSIS.md` section 15 for detailed testing instructions.

### Task: Understand a controller's authentication

Look at the controller and find:
1. Does it `include SubdomainTenant`? (multi-tenant scoping)
2. Does it have `before_action :authenticate_user!`? (requires login)
3. Does it call `check_user`? (requires admin role)

Example:
```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant  # ← Scoped to one website
  before_action :authenticate_user!  # ← Requires login
  before_action :authorize_admin!  # ← (If Phase 2 implemented)
end
```

---

## Configuration Reference

### Environment Variables

```bash
# Firebase (Required for Firebase login)
FIREBASE_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id

# Development/E2E Bypass (DON'T use in production!)
BYPASS_ADMIN_AUTH=true      # Skip auth in /admin, /site_admin, /tenant_admin
BYPASS_API_AUTH=true        # Skip auth in /api endpoints
```

### Devise Configuration

**File**: `config/initializers/devise.rb`

Key settings:
- Session timeout: `config.timeout_in = 30.minutes`
- Failed attempts before lockout: `config.maximum_attempts = 5`
- Lockout duration: `config.unlock_in = 1.hour`
- Password cost: `config.stretches = 11`

---

## Important Files Map

### Core Authentication
- `app/models/pwb/user.rb` - User model with Devise
- `app/models/pwb/user_membership.rb` - User-website associations
- `app/services/pwb/firebase_auth_service.rb` - Firebase token verification
- `app/models/pwb/auth_audit_log.rb` - Auth event logging

### Controllers
- `app/controllers/pwb/devise/sessions_controller.rb` - Login
- `app/controllers/pwb/devise/passwords_controller.rb` - Password reset
- `app/controllers/pwb/devise/registrations_controller.rb` - Registration
- `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` - OAuth
- `app/controllers/api_public/v1/auth_controller.rb` - Firebase API
- `app/controllers/site_admin_controller.rb` - Single-website admin
- `app/controllers/tenant_admin_controller.rb` - Cross-tenant admin

### Views
- `app/views/pwb/firebase_login/` - Firebase login pages
- `app/views/devise/` - Devise templates

### Configuration
- `config/initializers/devise.rb` - Devise setup
- `config/initializers/firebase_id_token.rb` - Firebase setup
- `config/initializers/auth_audit_hooks.rb` - Audit logging hooks
- `config/initializers/session_store.rb` - Session configuration

### Concerns
- `app/controllers/concerns/subdomain_tenant.rb` - Multi-tenancy
- `app/controllers/concerns/admin_auth_bypass.rb` - Dev/E2E bypass

### Database
- `db/migrate/*devise*.rb` - User table
- `db/migrate/*firebase*.rb` - Firebase UID column
- `db/migrate/*user_membership*.rb` - Membership table
- `db/migrate/*auth_audit*.rb` - Audit log table

---

## Glossary

| Term | Definition | Example |
|------|-----------|---------|
| **Authentication** | Verifying who you are | Login/session |
| **Authorization** | Verifying what you can do | Roles/permissions (Phase 2) |
| **Tenant** | Isolated instance/website | Website by subdomain |
| **Subdomain** | Tenant identifier in URL | `tenant1.app.com` |
| **Devise** | Rails auth framework | Email/password login |
| **Firebase** | Google's auth service | FirebaseUI login |
| **OmniAuth** | OAuth framework | Facebook login |
| **JWT** | JSON Web Token | Firebase ID token |
| **Session** | User's active login period | Stored in secure cookie |
| **Membership** | User's access to website | With role (admin, member, etc.) |
| **Role** | User's permission level | owner > admin > member > viewer |
| **Audit Log** | Record of auth events | login_success, logout, etc. |

---

## Known Issues & Limitations

### Current Limitations
- [ ] Authorization checks not enforced in admin panels (Phase 2)
- [ ] Admin flag exists but not consistently used
- [ ] Some pages accessible to any authenticated user
- [ ] No granular permission system
- [ ] Bypass mechanisms must be removed for production

### What's Working
- [x] Firebase authentication (email + Google)
- [x] Devise authentication (email + password)
- [x] Facebook OAuth
- [x] Multi-tenancy via subdomains
- [x] User memberships with roles
- [x] Session management
- [x] Account lockout
- [x] Audit logging

---

## Getting Help

### I need to understand [specific topic]

1. Check "Common Tasks" section above
2. Search the comprehensive analysis: `AUTHENTICATION_SYSTEM_ANALYSIS.md`
3. Look at code examples in quick reference: `AUTH_QUICK_REFERENCE.md`
4. View flow diagrams: `AUTH_ARCHITECTURE_DIAGRAMS.md`

### I found a bug in authentication

1. Check `AUTH_QUICK_REFERENCE.md` for common issues
2. See `AUTH_INVESTIGATION_SUMMARY.md` limitations section
3. Review audit logs: `/tenant_admin/auth_audit_logs`

### I'm implementing [feature]

1. Read `AUTH_INVESTIGATION_SUMMARY.md` Phase 2 recommendations
2. Find relevant code in `AUTHENTICATION_SYSTEM_ANALYSIS.md`
3. Reference flows in `AUTH_ARCHITECTURE_DIAGRAMS.md`
4. Use console commands from `AUTH_QUICK_REFERENCE.md`

---

## Version Information

- **Rails**: 8.0+
- **Devise**: ~4.8
- **OmniAuth**: ~2.1
- **Firebase**: Latest
- **firebase_id_token**: ~2.5
- **acts_as_tenant**: (for multi-tenancy scoping)

---

## Last Updated

These documents were created as part of a comprehensive authentication system analysis on **2025-12-07**.

**Created by**: Claude (Anthropic)
**Status**: Complete and verified against codebase
**Next Review**: Recommend review after Phase 2 authorization implementation

---

## Document Links

- **Summary**: `AUTH_INVESTIGATION_SUMMARY.md`
- **Analysis**: `AUTHENTICATION_SYSTEM_ANALYSIS.md`
- **Quick Ref**: `AUTH_QUICK_REFERENCE.md`
- **Diagrams**: `AUTH_ARCHITECTURE_DIAGRAMS.md`
- **Index**: `README_AUTHENTICATION.md` (you are here)
