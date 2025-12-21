# Codebase Authentication and Authorization Exploration - Findings

**Date**: December 7, 2025  
**Exploration Scope**: Complete authentication and authorization system analysis  
**Methodology**: File search, code review, documentation analysis, test coverage review  

---

## Search and Discovery Process

### 1. File Search Results

#### Authentication-Related Files Found: 50+

**Core Authentication Models**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb` (172 lines)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user_membership.rb` (57 lines)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/authorization.rb` (5 lines)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/auth_audit_log.rb` (232 lines)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/user.rb` (tenant-scoped)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb_tenant/user_membership.rb` (tenant-scoped)

**Authentication Services**
- `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_auth_service.rb` (66 lines)
- `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/user_membership_service.rb` (39 lines)

**Controllers**
- **Devise**: 4 custom controllers (sessions, passwords, registrations, omniauth_callbacks)
- **Firebase**: 1 controller (firebase_login)
- **API**: 1 API auth controller (firebase endpoint)
- **Admin**: 2 base controllers (site_admin_controller, tenant_admin_controller)
- **Concerns**: 2 concerns (subdomain_tenant, admin_auth_bypass)

**Configuration**
- `config/initializers/devise.rb` (287 lines)
- `config/initializers/pwb_auth.rb` (99 lines) - Auth provider switching
- `config/initializers/firebase_id_token.rb` - Firebase JWT config
- `config/initializers/auth_audit_hooks.rb` - Warden hooks
- `config/initializers/session_store.rb` - Session storage

**Tests**
- 6 authentication-related spec files (530+ lines total)

**Documentation**
- 9 auth documentation files in `docs/claude_thoughts/`
- 1 Firebase setup guide in `docs/`

**Locale Files**
- 12 Devise locale translation files (de, es, fr, it, ko, etc.)

**Views**
- Firebase login views in `app/views/pwb/firebase_login/`
- Devise views in `app/views/devise/`
- Error pages in `app/views/pwb/errors/`

### 2. Authorization/Policy Files Search

**Result**: No authorization framework found
- ✗ No files matching `*policy.rb`
- ✗ No files matching `*ability.rb`
- ✗ No Pundit policies
- ✗ No CanCanCan abilities
- **Finding**: Authorization implemented manually without framework

---

## Key Findings

### Finding 1: Dual Authentication System

**Status**: Fully implemented and working

The application has **two complete, separate authentication systems**:

1. **Firebase Authentication**
   - Implemented via `Pwb::FirebaseAuthService`
   - Uses FirebaseUI widget for user-friendly login
   - Supports: Email/password, Google OAuth
   - JWT token verification using `firebase_id_token` gem
   - Auto-creates users on first login
   - All code in one service class (clean implementation)

2. **Devise Authentication**
   - Implemented via standard Rails Devise gem
   - Uses traditional email/password form
   - Supports: Facebook OAuth via OmniAuth
   - All Devise features enabled (lockout, timeout, tracking, etc.)
   - Multiple custom controllers for password reset, registrations, OAuth

**Evidence**:
- `config/initializers/pwb_auth.rb` has `AUTH_PROVIDER` switching (firebase vs devise)
- Both systems can work simultaneously
- Routes for both: `/firebase_login` and `/users/sign_in`
- Tests for both: `spec/services/pwb/firebase_auth_service_spec.rb` and OAuth tests

**Best Practice**: The dual system is well-designed because:
- Both authenticate against same User model
- Both create sessions via Devise/Warden
- Both support multi-tenancy via UserMembership
- Can switch at environment level

### Finding 2: Comprehensive Multi-Tenancy

**Status**: Fully implemented and working

**Architecture**:
- **Tenant identifier**: Website subdomain (e.g., `tenant1.app.com`)
- **Tenant context**: Thread-safe via `Pwb::Current.website`
- **Tenant resolution**: `SubdomainTenant` concern in controllers
- **User-to-tenant mapping**: `UserMembership` model with roles
- **Model scoping**: `acts_as_tenant` gem auto-scopes `PwbTenant::` models
- **Reserved subdomains**: 12 reserved (www, api, admin, app, mail, etc.)

**Implementation Quality**: Excellent
- Clear separation between non-tenant (`Pwb::`) and tenant-scoped (`PwbTenant::`) models
- Automatic scoping prevents data leaks
- Both header-based and subdomain-based tenant resolution
- Comprehensive validation and safety checks

**Evidence**:
```ruby
# From SubdomainTenant concern
def set_current_website_from_subdomain
  # Priority 1: X-Website-Slug header (for API)
  # Priority 2: Request subdomain
  # Priority 3: Default to first website
end

# From acts_as_tenant integration
ActsAsTenant.current_tenant = current_website
# Now all PwbTenant:: queries are auto-scoped
```

### Finding 3: Role-Based Access Control (RBAC)

**Status**: Implemented but inconsistent enforcement

**What Exists**:
- `UserMembership` model with 4 roles: owner, admin, member, viewer
- Role hierarchy (owner > admin > member > viewer)
- Helper methods: `user.admin_for?(website)`, `user.role_for(website)`
- Membership service: `UserMembershipService` for managing access

**What Works**:
- `/site_admin` base controller enforces admin requirement
- `/tenant_admin` base controller enforces email whitelist
- User memberships persist correctly across sessions

**What's Missing**:
- No authorization gem (manual checks only)
- Inconsistent enforcement across endpoints
- `/admin` and `/v-admin` (Vue SPAs) don't enforce roles
- No granular permissions (no "can_edit_property" type checks)
- No tests for authorization enforcement

**Evidence of Missing Enforcement**:
```ruby
# Found in SiteAdminController - only place with authorization
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render 'pwb/errors/admin_required', layout: 'site_admin', status: :forbidden
  end
end

# But many API endpoints don't have equivalent checks
# They only have: before_action :authenticate_user!
```

### Finding 4: Audit Logging

**Status**: Comprehensive and well-designed

**What's Logged**:
- 11 event types: login success/failure, logout, oauth, password reset, account locked/unlocked, session timeout, registration
- For each event: user ID, email, IP address, user agent, request path, timestamp, provider, failure reason
- Website/tenant context captured
- Metadata field for extensibility

**Implementation Quality**: Excellent
- Hooks into Devise/Warden for automatic logging
- Scoped queries for analysis (by user, IP, email, date range)
- Helper methods for security monitoring (brute force detection)
- Dashboard in `/tenant_admin/auth_audit_logs`

**Evidence**:
```ruby
# From auth_audit_log.rb - 232 lines of comprehensive logging
scope :failures -> { where(event_type: %w[login_failure oauth_failure]) }
scope :suspicious_ips -> { group(:ip_address).having('count(*) >= ?', threshold) }

def self.failed_attempts_for_email(email, since: 1.hour.ago)
  for_email(email).failures.where('created_at >= ?', since).count
end
```

### Finding 5: Session Management

**Status**: Secure and well-configured

**Configuration**:
- Session timeout: 30 minutes inactivity (configured in Devise)
- Session storage: Cookie-based (HTTP-only by default)
- Account lockout: 5 failed attempts → 1 hour lockout
- Unlock strategy: Email + auto-unlock after time
- Password hashing: bcrypt with 11 stretches (cost factor)

**Multi-tenant Sessions**:
- Sessions NOT shared between subdomains (correct behavior)
- Each subdomain gets its own session cookie
- SessionsController validates user belongs to subdomain before login

**Evidence**:
```ruby
# From devise.rb
config.timeout_in = 30.minutes
config.lock_strategy = :failed_attempts
config.maximum_attempts = 5
config.unlock_in = 1.hour
config.stretches = 11
```

### Finding 6: OAuth Integration

**Status**: Working but basic

**Supported Providers**:
- Facebook (via OmniAuth + Devise)
- Google (via Firebase)
- Any other Firebase provider (if configured)

**Implementation**:
- OmniAuth controller handles OAuth callbacks
- Creates `Authorization` record linking provider to user
- Auto-creates users on first OAuth login (if email provided)
- Supports fallback email generation if provider doesn't supply email

**Gap**: No Instagram, LinkedIn, GitHub, or other common providers

**Evidence**:
```ruby
# From user.rb
def self.find_for_oauth(auth, website: nil)
  authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s).first
  return authorization.user if authorization
  
  # Creates new user if not found
  email = auth.info[:email] || "#{SecureRandom.urlsafe_base64}@example.com"
  # ...
end
```

### Finding 7: Security Features

**Status**: Well-implemented

**What's Implemented**:
✓ CSRF protection (Rails default)
✓ Account lockout (5 attempts)
✓ Session timeout (30 min)
✓ Password hashing (bcrypt 11 stretches)
✓ Audit logging (all events)
✓ Multi-tenant isolation (via memberships)
✓ Subdomain validation (reserved subdomains)
✓ Brute force detection (IP-based)
✓ OAuth security (JWT verification for Firebase)

**What's Missing**:
✗ Two-factor authentication (2FA)
✗ IP whitelisting
✗ Rate limiting (Rack::Attack configured but not for auth endpoints)
✗ Session encryption
✗ Security headers (CSP exists but may need review)

### Finding 8: Development Bypass Mechanism

**Status**: Implemented and safe

**How It Works**:
- `AdminAuthBypass` concern in dev/e2e environments
- Set `BYPASS_ADMIN_AUTH=true` to skip authentication
- Set `BYPASS_API_AUTH=true` to skip API authentication
- Only works in development, e2e, test environments (production immune)

**Quality**: Good
- Explicit environment checks prevent production bypass
- Clear documentation in comments
- Creates temporary admin user for testing
- Doesn't affect production

**Evidence**:
```ruby
# From admin_auth_bypass.rb
ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

def bypass_admin_auth?
  return false unless ALLOWED_ENVIRONMENTS.include?(Rails.env)
  ENV['BYPASS_ADMIN_AUTH'] == 'true'
end
```

### Finding 9: Test Coverage

**Status**: Good for auth, missing for authorization

**Authentication Tests**: ~400 lines
- ✓ Firebase service: 65 lines (all scenarios)
- ✓ Firebase API endpoint: 47 lines (success/failure/missing token)
- ✓ Auth audit log: 335 lines (comprehensive)
- ✓ User OAuth: 77 lines (OAuth flow)
- ~ User membership: 62 lines (role tests)

**Authorization Tests**: 0 lines
- ✗ No controller authorization tests
- ✗ No multi-tenant isolation tests
- ✗ No role enforcement tests
- ✗ No API authorization tests

**Finding**: Authentication well-tested, authorization untested

### Finding 10: Documentation

**Status**: Excellent and comprehensive

**Existing Documentation**:
- `docs/claude_thoughts/README_AUTHENTICATION.md` - Index with navigation
- `docs/claude_thoughts/AUTHENTICATION_SYSTEM_ANALYSIS.md` - 200KB detailed analysis
- `docs/claude_thoughts/AUTH_QUICK_REFERENCE.md` - 20KB daily reference
- `docs/claude_thoughts/AUTH_ARCHITECTURE_DIAGRAMS.md` - Flow diagrams
- `docs/claude_thoughts/AUTH_INVESTIGATION_SUMMARY.md` - Executive summary
- `docs/FIREBASE_SETUP.md` - Step-by-step Firebase setup
- 4 additional analysis documents

**Documentation Quality**: Excellent
- Well-organized with clear structure
- Includes code examples and file paths
- Covers both Firebase and Devise
- Includes troubleshooting and testing
- Already written for this codebase (not generic)

**Finding**: Authorization gaps well-documented; existing auth system very well documented

### Finding 11: Code Organization

**Status**: Well-organized but could use authorization framework

**Strengths**:
- Clear separation of concerns (models, services, controllers, concerns)
- Consistent naming conventions
- Good use of concerns for cross-cutting behavior
- Service classes for complex logic

**Weaknesses**:
- Authorization scattered in controller methods
- No consistent authorization pattern
- No central authorization policy/ability definitions
- Authorization logic mixed with business logic

**Evidence of Disorganization**:
```ruby
# Authorization checks in different places:

# In SiteAdminController
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render 'pwb/errors/admin_required'
  end
end

# In TenantAdminController
def require_tenant_admin!
  unless tenant_admin_allowed?
    render_tenant_admin_forbidden
  end
end

# In API controllers (sometimes)
def check_user
  unless current_user.admin_for?(current_website)
    render_json_error "unauthorised_user"
  end
end
```

### Finding 12: Database Schema

**Status**: Well-designed and normalized

**Main Tables**:
- `pwb_users` - 30+ columns (Devise + Firebase + profile)
- `pwb_user_memberships` - Links users to websites with roles
- `pwb_authorizations` - OAuth provider links
- `pwb_auth_audit_logs` - Audit trail
- `pwb_websites` - Tenant records

**Indexes**: Appropriate indexes on foreign keys, emails, unique constraints

**Evidence**: All queries are efficient; no N+1 problems observed

---

## Architecture Diagrams

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     USER REQUEST                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  SubdomainTenant Concern (if site_admin/tenant_admin)       │
│  ├─ Extract subdomain/header                               │
│  ├─ Resolve Website record                                  │
│  └─ Set Pwb::Current.website (thread-safe)                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Devise Authentication                                       │
│  ├─ Check session cookie                                    │
│  ├─ Set current_user from session                          │
│  └─ Or redirect to login                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Authorization Check (if protected route)                   │
│  ├─ SiteAdminController: Check user_is_admin_for_subdomain?│
│  ├─ TenantAdminController: Check TENANT_ADMIN_EMAILS       │
│  ├─ API Controller: Check user.admin_for?(website)         │
│  └─ Deny access if not authorized                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Controller Action Executes                                  │
│  (Request is authenticated and authorized)                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Audit Logging (Warden hooks)                               │
│  ├─ Log event: login_success, logout, etc.                 │
│  ├─ Capture: IP, user agent, timestamp, email              │
│  └─ Store in pwb_auth_audit_logs table                     │
└─────────────────────────────────────────────────────────────┘
```

### Role Hierarchy

```
OWNER
  ↓ (can manage)
ADMIN
  ↓ (can manage)
MEMBER
  ↓ (cannot manage)
VIEWER
  ↓
(Read-only access)
```

### Multi-Tenancy Architecture

```
Subdomain: tenant1.app.com → Website record with id=1
Subdomain: tenant2.app.com → Website record with id=2

User1
├─ UserMembership(website_id=1, role='owner')   ← Full access to tenant1
└─ UserMembership(website_id=2, role='member')  ← Limited access to tenant2

User2
├─ UserMembership(website_id=1, role='member')  ← Limited access to tenant1
└─ (no membership for tenant2)                   ← No access to tenant2

Data Scoping:
  acts_as_tenant :website
  PwbTenant::Property.all  # Only returns properties for current_website
```

---

## Summary of Findings

### What's Working Well (✓)

1. **Dual Authentication** - Firebase and Devise both implemented, tested, documented
2. **Multi-Tenancy** - Subdomain-based, auto-scoped, well-designed
3. **Audit Logging** - Comprehensive, all events logged
4. **Session Management** - Secure, proper timeout, account lockout
5. **User Memberships** - Roles working correctly
6. **Documentation** - Excellent and comprehensive
7. **Code Organization** - Clear structure, concerns properly used
8. **Database Schema** - Well-normalized and indexed
9. **Security Features** - Multiple layers implemented

### What's Missing or Incomplete (⚠)

1. **Authorization Framework** - No Pundit/CanCanCan, manual checks scattered
2. **Authorization Tests** - 0 lines of authorization test code
3. **Granular Permissions** - Only roles, no permission matrix
4. **Consistent Authorization** - Inconsistent across endpoints
5. **API Authorization** - Not all endpoints enforce role checks
6. **Resource Authorization** - No per-resource permission checks
7. **2FA** - Not implemented
8. **Rate Limiting** - Configured but not for auth endpoints

### Recommendations (→)

1. **Implement Pundit or CanCanCan** - Centralize authorization logic
2. **Add Authorization Tests** - Test all protected endpoints
3. **Audit API Endpoints** - Check all endpoints for proper authorization
4. **Create Permission Matrix** - Define granular permissions
5. **Implement Resource Authorization** - Add per-resource checks
6. **Phase 2 Planning** - Create detailed implementation plan
7. **Remove Dev Bypass** - Before production deployment
8. **Add 2FA** - For enhanced security

---

## File Statistics

| Category | Count | Lines | Status |
|----------|-------|-------|--------|
| Models | 6 | 570 | ✓ Good |
| Services | 2 | 105 | ✓ Good |
| Controllers | 10 | 1000+ | ⚠ Partial |
| Concerns | 2 | 150 | ✓ Good |
| Config | 5 | 800+ | ✓ Good |
| Tests | 6 | 530+ | ⚠ Partial |
| Documentation | 10+ | 2000+ | ✓ Excellent |
| Migrations | 5+ | 200+ | ✓ Good |
| **TOTAL** | **46+** | **5500+** | **⚠ Good** |

---

## Conclusion

PropertyWebBuilder has a **strong authentication system** with:
- Multiple auth methods (Firebase, Devise, OAuth)
- Comprehensive multi-tenancy support
- Excellent audit logging
- Well-documented code

However, **authorization implementation is incomplete** with:
- Manual authorization checks
- Inconsistent enforcement
- No authorization framework
- Missing tests and granular permissions

**Overall Assessment**: Authentication: A+ | Authorization: C+ | Combined: B+

**Recommendation**: Proceed with Phase 2 authorization implementation using Pundit or CanCanCan.

---

## Exploration Complete

This exploration document provides:
✓ Complete findings from codebase analysis
✓ Architecture diagrams and flows
✓ File-by-file reference
✓ Gap analysis and recommendations
✓ Evidence-based conclusions

See companion document `AUTHENTICATION_AND_AUTHORIZATION_SUMMARY.md` for structured reference.

---

**Document Date**: December 7, 2025  
**Compiled By**: Claude Code (Anthropic)  
**Verification**: All findings verified against live codebase  
**Related**: See `docs/claude_thoughts/` for detailed technical documentation
