# Authentication & Signup Analysis - Executive Summary

**Date**: December 14, 2025  
**Scope**: Complete analysis of signup flow, authentication, and website access control  
**Status**: Ready for implementation

---

## Overview

PropertyWebBuilder is a **multi-tenant SaaS platform** where each website is a tenant. The system has:

- **4-step signup process** (email → configure → provision → live)
- **Dual authentication** (Devise + Firebase)
- **Multi-website support** (users can have multiple websites)
- **Role-based access control** (owner/admin/member/viewer per website)
- **Token-based state tracking** (signup_token for API-driven signup)

---

## Key Findings

### 1. Signup is Already Token-Based

The app already implements **exactly the pattern needed for magic links** through the `signup_token` system:

```ruby
# Generated during signup:
user.update_columns(
  signup_token: SecureRandom.urlsafe_base64(32),
  signup_token_expires_at: 24.hours.from_now
)

# Verified in API requests:
user = User.find_by(signup_token: token)
return nil if user.signup_token_expires_at < Time.current
```

**Magic links would use the same pattern** with different column names (`magic_link_token` instead of `signup_token`).

### 2. Website Access Control is Robust

The system isolates access using:

1. **Primary website** (legacy): `user.website_id`
2. **Multi-website memberships**: `user_memberships` with roles
3. **Access verification**: `user.active_for_authentication?` checks both

```ruby
def active_for_authentication?
  # Must have membership for requested website OR
  # Must have it as primary website OR
  # Must be Firebase user
  return true if user_memberships.active.exists?(website: current_website)
  return true if website_id == current_website.id
  return true if firebase_uid.present?
  false
end
```

### 3. User Onboarding Has State Tracking

Users progress through states:
- `lead` (email captured)
- `registered` (account created)
- `email_verified` (optional)
- `onboarding` (4-step wizard)
- `active` (fully onboarded)

Each step is tracked in `onboarding_step` (1-4) and can be queried for progress display.

### 4. Website Provisioning is Guard-Protected

Websites transition through 8 states with **guards** that ensure data integrity:

```
pending → owner_assigned → agency_created → links_created 
→ field_keys_created → properties_seeded → ready → live

Each transition has guards like:
  - has_owner? (membership exists)
  - has_agency? (agency record exists)
  - has_links? (3+ navigation links)
  - has_field_keys? (5+ field keys)
```

Websites cannot reach "live" state without passing all guards.

### 5. Authentication has Audit Logging

All auth events are logged in `pwb_auth_audit_logs`:
- login_success / login_failure
- oauth_success / oauth_failure
- password_reset_request / password_reset_success
- account_locked / account_unlocked
- session_timeout
- registration

This provides complete audit trail for security/compliance.

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                   USER REGISTRATION                         │
│  Email → create user, reserve subdomain (signup_token)     │
├─────────────────────────────────────────────────────────────┤
│                   USER AUTHENTICATION                       │
│  Option A: Email/Password (Devise)                         │
│  Option B: Magic Link (can implement)                       │
│  Option C: Google/Facebook OAuth (Firebase + OmniAuth)     │
├─────────────────────────────────────────────────────────────┤
│              WEBSITE CONFIGURATION                          │
│  Select subdomain, site type → create website + owner role │
├─────────────────────────────────────────────────────────────┤
│              WEBSITE PROVISIONING                           │
│  Create agency, links, field_keys → seed content → go live │
├─────────────────────────────────────────────────────────────┤
│            MULTI-WEBSITE ACCESS CONTROL                     │
│  User → Memberships → Websites (owner/admin/member/viewer) │
├─────────────────────────────────────────────────────────────┤
│            MULTI-TENANT ISOLATION                           │
│  Subdomain → Website lookup → Current.website (thread-safe)│
│  All queries scoped to current_website                      │
└─────────────────────────────────────────────────────────────┘
```

---

## File Organization

### Signup & Provisioning
- **API Controller**: `/app/controllers/api/signup/signups_controller.rb`
- **API Service**: `/app/services/pwb/signup_api_service.rb`
- **Provisioning**: `/app/services/pwb/provisioning_service.rb`
- **UI Controller**: `/app/controllers/pwb/signup_controller.rb`

### Authentication
- **User Model**: `/app/models/pwb/user.rb` (Devise + AASM)
- **Devise Config**: `/config/initializers/devise.rb`
- **Devise Controllers**: `/app/controllers/pwb/devise/*.rb`
- **Firebase Service**: `/app/services/pwb/firebase_auth_service.rb`
- **Auth Controller**: `/app/controllers/pwb/auth_controller.rb`

### Access Control
- **UserMembership**: `/app/models/pwb/user_membership.rb` (roles)
- **UserMembership Service**: `/app/services/pwb/user_membership_service.rb`
- **Website Model**: `/app/models/pwb/website.rb` (AASM provisioning)
- **Current Context**: `/app/models/pwb/current.rb` (Pwb::Current.website)

### Audit & Security
- **AuthAuditLog**: `/app/models/pwb/auth_audit_log.rb`
- **Audit Hooks**: `/config/initializers/auth_audit_hooks.rb`

---

## Documents Created

This analysis includes three detailed documents:

### 1. `AUTHENTICATION_SIGNUP_ANALYSIS.md` (Main Document)
**Content**:
- Complete signup flow (4 steps) with code samples
- Authentication system (Devise + Firebase)
- User model & onboarding states
- Website access control & multi-website support
- Existing token patterns (signup_token)
- **Magic link implementation recommendation**
- Website provisioning & seeding
- Key files summary
- Security considerations

**Use when**: Understanding the complete system architecture

### 2. `MAGIC_LINKS_IMPLEMENTATION_GUIDE.md` (How-To Guide)
**Content**:
- Step-by-step implementation (7 steps)
- Code templates (ready to copy)
- Service class pattern
- Controller actions
- Email mailer setup
- Route configuration
- Test examples
- Security checklist
- Rate limiting (optional)
- Background job cleanup (optional)

**Use when**: Actually implementing magic links

### 3. `AUTHENTICATION_FLOW_DIAGRAMS.md` (Visual Reference)
**Content**:
- 4-step signup flow (detailed)
- Devise login flow (with website access check)
- Website access control verification
- Magic link flow (new feature)
- User onboarding state machine
- Website provisioning state machine
- Database schema (key tables)
- Request handling flow

**Use when**: Visualizing data flow or explaining to others

---

## Current State Summary

### What Works ✓

1. **Signup API** - Complete 4-step signup with token tracking
2. **Devise Authentication** - Email/password login with all security features
3. **Firebase Authentication** - OAuth integration with auto-user creation
4. **Multi-Website Support** - Users can own/manage multiple websites
5. **Role-Based Access** - owner/admin/member/viewer roles per website
6. **Audit Logging** - All auth events logged for compliance
7. **State Machines** - Both users and websites have AASM state tracking
8. **Provisioning Guards** - Websites can't go live without data

### What's Missing ⚠️

1. **Magic Links** - Not implemented (but easy to add - same pattern as signup_token)
2. **Public Website Access** - No indication of "public" vs "restricted" access mode
3. **Invite System** - Adding new users to websites requires manual membership creation
4. **Social Login UI** - Firebase OAuth exists but may not be exposed to users
5. **Email Templates** - Devise password reset exists but could be enhanced

### What's Configurable 🔧

1. **Authentication Provider** - Switch between Devise/Firebase via `Pwb::AuthConfig`
2. **Token Expiry** - Currently 24 hours (can adjust)
3. **Session Timeout** - 30 minutes (in Devise config)
4. **Lockout Settings** - 5 attempts, 1 hour auto-unlock (in Devise config)
5. **Theme/Branding** - Customizable per website

---

## Magic Links: Quick Implementation

### The Pattern

1. Add two columns to users table:
   ```ruby
   add_column :pwb_users, :magic_link_token, :string
   add_column :pwb_users, :magic_link_expires_at, :datetime
   ```

2. Generate and verify tokens (same as signup_token):
   ```ruby
   token = SecureRandom.urlsafe_base64(32)
   user.update_columns(
     magic_link_token: token,
     magic_link_expires_at: 24.hours.from_now
   )
   ```

3. Create service to handle requests and logins (follow SignupApiService pattern)

4. Create email with link and send via ActionMailer

5. Add login action that verifies token and signs user in (uses Devise)

**Total effort**: ~2-4 hours (migration, service, controller, email, tests)

---

## Multi-Website User Example

A user with multiple websites shows the architecture:

```
User: jane@example.com
├─ Website: residential.propertywebbuilder.com
│  └─ Role: owner
│     └─ Can: Edit everything, manage users
│
├─ Website: commercial.propertywebbuilder.com
│  └─ Role: admin
│     └─ Can: Edit content, manage limited users
│
└─ Website: vacation.propertywebbuilder.com
   └─ Role: member
      └─ Can: Edit content only

When jane accesses residential.propertywebbuilder.com:
  ✓ Has membership
  ✓ Role is owner
  ✓ All admin features available

When jane accesses vacation.propertywebbuilder.com:
  ✓ Has membership
  ✓ Role is member
  ✓ Only content editing available
  ✗ User management disabled
```

---

## Testing Patterns

The codebase includes excellent test patterns:

**Signup API Tests**: `spec/requests/api/signup/signups_spec.rb`
- Tests each API endpoint
- Uses factories for data creation
- Mocks subdomain pool
- Checks response format

**Auth Tests**: `spec/controllers/`, `spec/requests/api_public/v1/auth_spec.rb`
- Tests Devise flows
- Tests Firebase integration
- Tests audit logging

**Recommended for Magic Links**: Follow signup API test pattern

---

## Security Considerations

### Already Implemented ✓
- HTTPS enforcement (in production)
- Password hashing (bcrypt, 11 stretches)
- Account lockout (5 attempts)
- Session timeout (30 minutes)
- CSRF protection
- SQL injection prevention (ActiveRecord)
- Audit logging of all auth events
- Time-constant comparison for token verification

### Recommended for Magic Links
- Rate limiting (3 requests per minute per IP)
- Unique tokens (indexed in database)
- One-time use (clear after login)
- Short expiry (24 hours)
- No email enumeration (return success regardless)

---

## Next Steps

### Immediate (Ready to implement)
1. Read `MAGIC_LINKS_IMPLEMENTATION_GUIDE.md`
2. Create migration adding token columns
3. Implement `MagicLinkService` (copy from guide)
4. Add controller actions
5. Create email template
6. Test manually

### Short-term (Recommended)
1. Add magic link option to login page UI
2. Add tests for magic link flow
3. Document for end users
4. Monitor usage and audit logs

### Long-term (Future enhancements)
1. Add rate limiting
2. Add background job to clean expired tokens
3. Add "Remember this device" option
4. Add WebAuthn/FIDO2 support
5. Add two-factor authentication

---

## Key Insights

1. **Token-based auth is already the pattern** - Signup uses tokens, so magic links fit naturally

2. **AASM state machines provide guard rails** - State transitions can't happen without proper data

3. **Multi-tenancy is enforced at multiple levels** - Thread-local Current.website + memberships + database scoping

4. **Audit logging is built-in** - Every auth event is logged automatically

5. **Devise is configured but flexible** - Can coexist with custom auth methods like magic links

6. **The codebase is well-structured** - Services handle business logic, controllers are thin, models define behavior

---

## Questions Answered

**Q: How does the signup process track state across requests without sessions?**  
A: Via `signup_token` - stateless, token-based tracking that works across domains/APIs

**Q: How does the system prevent users from accessing other websites?**  
A: Via `active_for_authentication?` which checks `user_memberships` + `Current.website` context

**Q: How are new users added to websites by invitation?**  
A: Via `UserMembershipService.grant_access(user, website, role)` - not yet exposed as UI feature

**Q: Can a user be an admin on one website and viewer on another?**  
A: Yes - roles are per-membership, not global

**Q: What happens if a user's subdomain/custom domain conflicts?**  
A: Website lookup is unique on both, and `find_by_host` tries custom domain first, then subdomain

**Q: How do Firebase and Devise users coexist?**  
A: Both create same User model. Firebase users get `firebase_uid`. Both go through `active_for_authentication?` check.

**Q: Can websites be in "draft" or "unlisted" mode?**  
A: Currently: pending (not accessible), ready (not accessible), live (accessible). Could add public/private flag.

---

## Conclusion

PropertyWebBuilder has a **solid, secure authentication architecture** with:
- Multi-tenant isolation ✓
- Role-based access ✓
- Audit logging ✓
- Flexible authentication ✓
- Guard-protected provisioning ✓

**Magic links** can be added in ~2-4 hours by following the existing `signup_token` pattern. The infrastructure is already in place!

---

## Reading Order

1. **Start**: This summary (you are here)
2. **Understand**: `AUTHENTICATION_FLOW_DIAGRAMS.md` (visual overview)
3. **Details**: `AUTHENTICATION_SIGNUP_ANALYSIS.md` (complete architecture)
4. **Implement**: `MAGIC_LINKS_IMPLEMENTATION_GUIDE.md` (step-by-step code)

---

## File Locations (Quick Reference)

| Component | Location |
|-----------|----------|
| Signup API | `/app/controllers/api/signup/signups_controller.rb` |
| Signup Service | `/app/services/pwb/signup_api_service.rb` |
| User Model | `/app/models/pwb/user.rb` |
| User Membership | `/app/models/pwb/user_membership.rb` |
| Website Model | `/app/models/pwb/website.rb` |
| Devise Config | `/config/initializers/devise.rb` |
| Firebase Service | `/app/services/pwb/firebase_auth_service.rb` |
| Auth Logging | `/app/models/pwb/auth_audit_log.rb` |
| Current Context | `/app/models/pwb/current.rb` |
| Specs | `/spec/requests/api/signup/signups_spec.rb` |

---

**Created**: 2025-12-14  
**Status**: Ready for implementation  
**Confidence**: High (verified against codebase)
