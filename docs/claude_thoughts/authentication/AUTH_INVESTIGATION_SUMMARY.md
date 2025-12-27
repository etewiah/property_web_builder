# PropertyWebBuilder Authentication System - Investigation Summary

## Overview

I have completed a comprehensive exploration of the authentication systems in PropertyWebBuilder. This document summarizes the key findings and provides references to the detailed documentation.

---

## What I Found

### Dual Authentication Systems

The application implements **two independent authentication systems**:

1. **Firebase Authentication** (modern, API-driven)
   - For admin panel login via `/firebase_login`
   - Uses FirebaseUI for user interface
   - Email/Password + Google OAuth
   - Token-based verification

2. **Devise Authentication** (traditional Rails)
   - Email/Password login
   - Facebook OAuth via OmniAuth
   - Account lockout, password recovery, email confirmation
   - Session-based (secure HTTP-only cookies)

Both integrate seamlessly with the same Rails user model and share the multi-tenancy infrastructure.

---

## Key Findings

### 1. Firebase Authentication Architecture

**Main Files:**
- `app/controllers/pwb/firebase_login_controller.rb` - Views and routing
- `app/views/pwb/firebase_login/index.html.erb` - FirebaseUI integration
- `app/services/pwb/firebase_auth_service.rb` - Token verification service
- `config/initializers/firebase_id_token.rb` - Firebase gem configuration

**How It Works:**
1. User visits `/firebase_login` (shows FirebaseUI widget)
2. User authenticates with Firebase (email/password or Google OAuth)
3. Firebase returns ID token (JWT)
4. JavaScript sends token to `POST /api_public/v1/auth/firebase`
5. Backend verifies JWT signature using Firebase public keys
6. Creates/updates user and membership in Rails database
7. Signs user in via Devise (creates session cookie)
8. Redirects to `/admin`

**Key Service:**
```ruby
# Token verification extracts: user_id, email from JWT payload
Pwb::FirebaseAuthService.new(token, website: nil).call
  └─ FirebaseIdToken::Signature.verify(token)
  └─ Create User + UserMembership (role: 'member')
```

**Configuration:**
- `FIREBASE_API_KEY` - Client-side API key
- `FIREBASE_PROJECT_ID` - Project ID for token verification
- Uses `firebase_id_token` gem (handles JWT verification)
- Can cache certificates in Redis for performance

### 2. Devise Authentication Architecture

**Main Files:**
- `app/models/pwb/user.rb` - User model with Devise modules
- `config/initializers/devise.rb` - Devise configuration
- `app/controllers/pwb/devise/sessions_controller.rb` - Login controller
- `app/controllers/pwb/devise/omniauth_callbacks_controller.rb` - OAuth handler
- `app/controllers/pwb/devise/passwords_controller.rb` - Password reset
- `app/controllers/pwb/devise/registrations_controller.rb` - User registration

**Enabled Modules:**
```ruby
devise :database_authenticatable,    # Email/password
        :registerable,               # Registration
        :recoverable,                # Password reset
        :rememberable,               # Remember me
        :trackable,                  # Sign-in tracking
        :validatable,                # Validation
        :lockable,                   # Account lockout
        :timeoutable,                # Session timeout
        :omniauthable                # OAuth
```

**Key Features:**
- Session timeout: 30 minutes
- Account lockout: 5 failed attempts → 1 hour
- Password hashing: bcrypt with cost 11
- Remember me cookie support
- Sign-in tracking: count, IP, timestamps

### 3. Multi-Tenancy Implementation

**Core Mechanism:**
- Subdomain-based tenant resolution (`SubdomainTenant` concern)
- User memberships with role-based access control
- Automatic query scoping via `ActsAsTenant`

**User Roles (Hierarchical):**
- `owner` - Full control
- `admin` - Admin access
- `member` - Regular member
- `viewer` - Read-only (lowest)

**Key Models:**
- `Pwb::User` - User accounts (Devise)
- `Pwb::UserMembership` - User-Website associations with roles
- `Pwb::Website` - Tenants with subdomain and reserved subdomain validation

**Tenant Resolution:**
```ruby
# Priority:
1. X-Website-Slug HTTP header
2. Request subdomain (case-insensitive)
3. Default website (first record)

# Reserved subdomains (cannot be tenant IDs):
%w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo]
```

### 4. Authentication Checks in Admin Panels

**SiteAdmin** (`/site_admin`)
- Scoped to single website via subdomain
- Requires `authenticate_user!`
- All model queries auto-scoped to current website
- Authorization checks NOT yet implemented (Phase 2)

**TenantAdmin** (`/tenant_admin`)
- Cross-tenant access (no subdomain scoping)
- Requires `authenticate_user!`
- Can access all websites via `unscoped_model`
- Authorization checks NOT yet implemented (Phase 2)

**Public Admin** (`/admin`, `/v-admin`)
- Vue SPAs with client-side routing
- Authentication enforced at API endpoint level
- API controllers check user is admin

### 5. API Authentication

**Authenticated Routes:**
- `authenticate :user` blocks in routes
- `ApplicationApiController` checks:
  - User is signed in (via Devise)
  - User is admin for current website
- Can bypass with `BYPASS_API_AUTH=true` (dev/e2e only)

**Firebase API Endpoint:**
- `POST /api_public/v1/auth/firebase`
- Public endpoint (no authentication required)
- Takes Firebase ID token
- Returns authenticated session

### 6. Audit Logging

**AuthAuditLog Model:**
- Logs all authentication events
- Event types: login_success, login_failure, logout, oauth_success, oauth_failure, password_reset_request, password_reset_success, account_locked, account_unlocked, session_timeout, registration

**Logged Information:**
- User ID and email
- Event type and provider
- IP address and user agent
- Request path and failure reason
- Website/tenant context

**Access:**
- `Pwb::AuthAuditLog` model
- `/tenant_admin/auth_audit_logs` dashboard
- Scopes: `for_user`, `for_email`, `for_ip`, `failures`, `last_hour`, etc.

---

## Current State

### What Works
- Firebase authentication (email/password + Google)
- Devise authentication (email/password)
- Facebook OAuth via OmniAuth
- Session management (secure HTTP-only cookies)
- Multi-tenancy via subdomains
- User memberships with roles
- Account lockout (5 attempts → 1 hour)
- Session timeout (30 minutes)
- Audit logging of all auth events
- Admin auth bypass for dev/e2e

### What's Not Yet Implemented (Phase 2)
- Authorization enforcement in admin panels
- Super admin flag for cross-tenant access
- Granular permission system
- Resource-level access control
- Some authorization checks in API

### Limitations
- Admin flag exists but not consistently enforced
- Some admin pages accessible to any authenticated user
- No per-resource permissions
- Bypass mechanisms must be removed for production

---

## Key Files Generated for You

I've created three comprehensive documentation files:

### 1. `AUTHENTICATION_SYSTEM_ANALYSIS.md` (Main Document)
- **Size**: ~5000 lines
- **Content**: 
  - Complete analysis of both auth systems
  - Code examples and file paths
  - Database schema
  - Configuration details
  - Testing instructions
  - References

**Topics Covered:**
- Firebase authentication (UI, service, configuration, routes, API)
- Devise authentication (modules, controllers, configurations)
- User model and user memberships
- Role-based access control
- Multi-tenancy and subdomain resolution
- Admin panels and authentication requirements
- API authentication
- Audit logging
- Session management
- Security features
- Database tables and relationships

### 2. `AUTH_QUICK_REFERENCE.md` (Cheat Sheet)
- **Size**: ~400 lines
- **Content**:
  - Quick overview of both systems
  - Key file locations
  - Authentication checks
  - User methods
  - Admin panel matrix
  - Multi-tenancy rules
  - Environment variables
  - Routes summary
  - Console commands

**Perfect for**: Quick lookups, team reference, onboarding

### 3. `AUTH_ARCHITECTURE_DIAGRAMS.md` (Visual Guide)
- **Size**: ~800 lines
- **Content**:
  - System architecture diagram
  - Firebase authentication flow (visual + step-by-step)
  - Devise authentication flow (visual + step-by-step)
  - Multi-tenancy flow
  - Session lifecycle
  - Authorization check flow
  - Database schema relationships
  - Request processing pipeline
  - Gems and dependencies

**Perfect for**: Understanding flows, architecture discussions, design decisions

---

## File Locations

All documentation is in: `/Users/etewiah/dev/sites-older/property_web_builder/docs/claude_thoughts/`

```
AUTH_INVESTIGATION_SUMMARY.md          ← You are here
AUTHENTICATION_SYSTEM_ANALYSIS.md      ← Comprehensive analysis
AUTH_QUICK_REFERENCE.md                ← Quick cheat sheet
AUTH_ARCHITECTURE_DIAGRAMS.md          ← Visual flows and diagrams
```

---

## Questions Answered

### 1. Firebase Authentication
- **How Firebase login works**: FirebaseUI widget → Firebase backend → ID token → POST to Rails → verify JWT → sign in with Devise
- **Token validation**: Using `firebase_id_token` gem, which verifies JWT signature against Google's public keys
- **FirebaseAuthService**: Verifies token, extracts user_id/email, creates/updates user and membership
- **Integration with Devise**: Token verification endpoint calls `sign_in(user)` to create Devise session
- **Config location**: Environment variables `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID`, plus `config/initializers/firebase_id_token.rb`

### 2. Devise Authentication
- **Setup**: 8 modules enabled (database_authenticatable, registerable, recoverable, lockable, timeoutable, omniauthable, etc.)
- **Custom controllers**: SessionsController (validates subdomain), RegistrationsController, PasswordsController, OmniauthCallbacksController
- **Session management**: Secure HTTP-only cookies, 30-minute timeout, NOT shared between subdomains
- **OAuth**: Facebook configured via OmniAuth, also used for Firebase

### 3. Authentication Checks
- **SiteAdminController**: `authenticate_user!` with SubdomainTenant concern (single website)
- **TenantAdminController**: `authenticate_user!` without SubdomainTenant (cross-tenant)
- **ApplicationApiController**: `authenticate_user!` + `check_user` (verify admin for website)
- **current_user**: Devise helper available in all controllers

### 4. Admin Panels
- **/admin** (Vue): No auth in controller, enforced at API
- **/v-admin** (Vue): No auth in controller, enforced at API
- **/site_admin**: Requires auth, scoped to one website
- **/tenant_admin**: Requires auth, cross-tenant access

### 5. Configuration
- **Auth config**: `config/initializers/devise.rb` (Devise), `config/initializers/firebase_id_token.rb` (Firebase)
- **Website settings**: `app/models/pwb/website.rb` (subdomain, reserved list, admins method)
- **Environment variables**: `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `BYPASS_ADMIN_AUTH`, `BYPASS_API_AUTH`

---

## Next Steps (Recommendations)

### Immediate
1. Review the comprehensive analysis document
2. Understand the flows (use architecture diagrams)
3. Bookmark the quick reference for daily use

### Short-term (Phase 2)
1. Implement authorization checks in site_admin and tenant_admin
2. Add super_admin flag for cross-tenant access
3. Create granular permission system
4. Enforce resource-level access control

### Before Production
1. Remove/disable auth bypass mechanisms
2. Ensure all authorization checks are in place
3. Review and harden Firebase security rules
4. Set up monitoring for auth_audit_logs
5. Configure Firebase in production environment

---

## Technical Debt & Improvements

### Security
- [ ] Enforce authorization in all admin controllers (Phase 2)
- [ ] Remove auth bypass from production builds
- [ ] Implement rate limiting on login endpoints
- [ ] Add CAPTCHA to password reset
- [ ] Monitor for brute force attacks

### Code Quality
- [ ] Consolidate auth concerns/helpers
- [ ] Add comprehensive auth integration tests
- [ ] Document permission model clearly
- [ ] Create admin user management interface

### Operations
- [ ] Set up auth audit log alerting
- [ ] Create user provisioning/deprovisioning workflows
- [ ] Document admin onboarding process
- [ ] Create runbooks for common auth issues

---

## Summary

PropertyWebBuilder has a **well-architected dual authentication system** combining modern Firebase authentication with traditional Devise authentication. The multi-tenancy implementation using subdomains is clean and effective. The main gap is the lack of authorization enforcement (Phase 2), which means currently any authenticated user can access admin panels.

The system is **production-ready from an authentication perspective** but requires authorization work before being fully secure. All auth events are logged, and the audit trail is available for security monitoring.

---

## Questions?

Refer to the appropriate document:

- **"How do I...?"** → `AUTH_QUICK_REFERENCE.md`
- **"Can you explain the code for...?"** → `AUTHENTICATION_SYSTEM_ANALYSIS.md`
- **"What does the flow look like for...?"** → `AUTH_ARCHITECTURE_DIAGRAMS.md`
- **"Overall understanding"** → This summary

Good luck with your authentication work!
