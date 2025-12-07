# PropertyWebBuilder Authentication Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          External Services                          │
├──────────────────────────────────────────────────────────────────────┤
│  Firebase                              OAuth Providers               │
│  (Authentication)                      (Facebook, Google)           │
│  ├─ Auth API                          ├─ Facebook Graph API        │
│  ├─ Token Verification                ├─ Google OAuth              │
│  └─ User Management                   └─ User Info Endpoint        │
└──────────────────────────────────────────────────────────────────────┘
                                    ↓ (HTTP Requests)
┌─────────────────────────────────────────────────────────────────────┐
│                    PropertyWebBuilder Rails App                     │
├──────────────────────────────────────────────────────────────────────┤
│
│  ┌──── Public Routes ─────────────────────────────────────────────┐
│  │                                                                  │
│  │  GET /firebase_login           (FirebaseUI login page)         │
│  │  GET /firebase_sign_up         (FirebaseUI signup page)        │
│  │  GET /firebase_forgot_password (Password reset page)           │
│  │  GET /firebase_change_password (Change password page)          │
│  │                                                                  │
│  │  POST /api_public/v1/auth/firebase (API endpoint, no auth)    │
│  │       └─→ FirebaseAuthService.call(token)                      │
│  │           ├─ FirebaseIdToken::Signature.verify(token)         │
│  │           ├─ Extract user_id, email from JWT payload          │
│  │           ├─ User.find_or_create_by(firebase_uid/email)       │
│  │           └─ UserMembershipService.grant_access(role: member) │
│  │                                                                  │
│  └────────────────────────────────────────────────────────────────┘
│
│  ┌──── Devise Routes (Localized) ─────────────────────────────────┐
│  │                                                                  │
│  │  GET  /users/sign_in                                           │
│  │  POST /users/sign_in                                           │
│  │  └─→ Pwb::Devise::SessionsController#create                    │
│  │      ├─ validate_user_website (check subdomain match)         │
│  │      ├─ sign_in_params (email/password)                        │
│  │      └─ Devise authenticates credentials                       │
│  │          ├─ Find user by email                                 │
│  │          ├─ Check password (bcrypt)                            │
│  │          ├─ Check account not locked/timed out                │
│  │          └─ Warden hooks log success                           │
│  │                                                                  │
│  │  GET  /users/sign_out                                          │
│  │  DELETE /users/sign_out                                        │
│  │  └─→ Devise::SessionsController#destroy                        │
│  │      └─ Warden hooks log logout                                │
│  │                                                                  │
│  │  POST /users (registration)                                    │
│  │  GET  /users/password/new                                      │
│  │  POST /users/password (reset request)                          │
│  │  PATCH /users/password (reset with token)                      │
│  │                                                                  │
│  │  GET  /omniauth/:provider                                      │
│  │  GET  /users/auth/:provider/callback                           │
│  │  └─→ Pwb::Devise::OmniauthCallbacksController#facebook        │
│  │      ├─ User.find_for_oauth(auth)                             │
│  │      ├─ Create Authorization if new                            │
│  │      └─ sign_in_and_redirect                                   │
│  │                                                                  │
│  └────────────────────────────────────────────────────────────────┘
│
│  ┌──── Admin Panel Routes ────────────────────────────────────────┐
│  │                                                                  │
│  │  /admin (Vue SPA)                                               │
│  │  └─ Client-side routing                                        │
│  │     └─ API calls (require authentication)                      │
│  │                                                                  │
│  │  /v-admin (Vue SPA)                                             │
│  │  └─ Client-side routing                                        │
│  │     └─ API calls (require authentication)                      │
│  │                                                                  │
│  │  /site_admin/* (Single website admin)                          │
│  │  └─ SiteAdminController < ActionController::Base              │
│  │     ├─ include SubdomainTenant                                 │
│  │     │  └─ before_action :set_current_website_from_subdomain   │
│  │     ├─ before_action :authenticate_user!                      │
│  │     └─ All queries auto-scoped to Pwb::Current.website        │
│  │                                                                  │
│  │  /tenant_admin/* (Cross-tenant admin)                          │
│  │  └─ TenantAdminController < ActionController::Base            │
│  │     ├─ NOT SubdomainTenant (no scoping)                       │
│  │     ├─ before_action :authenticate_user!                      │
│  │     └─ Access all websites via unscoped_model()               │
│  │                                                                  │
│  └────────────────────────────────────────────────────────────────┘
│
│  ┌──── API Routes ────────────────────────────────────────────────┐
│  │                                                                  │
│  │  authenticate :user do                                         │
│  │    namespace :import { ... }                                   │
│  │    namespace :export { ... }                                   │
│  │  end                                                             │
│  │                                                                  │
│  │  /api/v1/* (Authenticated)                                     │
│  │  └─ ApplicationApiController                                   │
│  │     ├─ before_action :authenticate_user!                      │
│  │     ├─ before_action :check_user (admin check)                │
│  │     └─ unless :bypass_authentication?                         │
│  │         └─ ENV['BYPASS_API_AUTH'] == 'true' (dev/e2e only)   │
│  │                                                                  │
│  └────────────────────────────────────────────────────────────────┘
│
└────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                        Database Layer                              │
├──────────────────────────────────────────────────────────────────────┤
│
│  pwb_users                     (User accounts)
│  ├─ id, email, encrypted_password
│  ├─ firebase_uid (unique)
│  ├─ admin, website_id
│  ├─ reset_password_token, unlock_token, confirmation_token
│  ├─ locked_at, failed_attempts, sign_in_count
│  └─ Devise fields...
│
│  pwb_user_memberships          (User-Website associations)
│  ├─ user_id, website_id
│  ├─ role (owner, admin, member, viewer)
│  ├─ active (boolean)
│  └─ unique index: [user_id, website_id]
│
│  pwb_authorizations            (OAuth provider links)
│  ├─ user_id, provider, uid
│  └─ Links user to Facebook, Google, etc.
│
│  pwb_auth_audit_logs           (Security audit trail)
│  ├─ user_id, email, website_id
│  ├─ event_type (login_success, login_failure, logout, etc.)
│  ├─ provider, ip_address, user_agent, request_path
│  ├─ failure_reason, metadata (JSONB)
│  └─ Indexed: event_type, email, ip, created_at, [user_id, event_type]
│
│  pwb_websites                  (Tenants)
│  ├─ id, subdomain (unique, reserved list)
│  └─ Various configuration fields
│
└────────────────────────────────────────────────────────────────────────┘
```

---

## Authentication Flow - Firebase Path

```
┌──────────────────┐
│  User Browser    │
│ (unauthenticated)│
└────────┬─────────┘
         │
         │ GET /firebase_login
         ↓
┌──────────────────────────────────┐
│  FirebaseLoginController#index   │
│  (renders index.html.erb)        │
└────────┬──────────────────────────┘
         │
         │ Returns HTML with:
         │ - FirebaseUI script tags
         │ - Firebase config (from ENV)
         │ - JavaScript initialization
         ↓
┌──────────────────────────────────────────────────┐
│  Browser: FirebaseUI Widget Loads               │
│  (firebase-ui-auth.js v6.0.1)                   │
│                                                   │
│  ┌─────────────────────────────────────────┐    │
│  │ Email/Password Input                    │    │
│  │ OR "Sign in with Google" Button         │    │
│  └─────────────────────────────────────────┘    │
└────────────────┬──────────────────────────────────┘
                 │
                 │ User enters credentials or clicks Google
                 │
                 ↓
         ┌──────────────────────┐
         │  Firebase Backend    │
         │  (Google's servers)  │
         │                      │
         │ ├─ Verify password   │
         │ ├─ Or OAuth flow     │
         │ └─ Generate JWT      │
         └────────────┬─────────┘
                      │
                      │ Returns ID Token (JWT)
                      │
                      ↓
         ┌────────────────────────────────┐
         │  Browser JavaScript Handler   │
         │  (signInSuccessWithAuthResult) │
         │                                 │
         │ authResult.user.getIdToken()  │
         │    → token = "eyJhbG..."       │
         └────────────┬────────────────────┘
                      │
                      │ POST /api_public/v1/auth/firebase
                      │ with {token: "eyJhbG..."}
                      │
                      ↓
    ┌─────────────────────────────────────────┐
    │  ApiPublic::V1::AuthController#firebase │
    │                                          │
    │  params[:token] = "eyJhbG..."           │
    └─────────────┬──────────────────────────┘
                  │
                  ↓
    ┌──────────────────────────────────────────────────┐
    │  Pwb::FirebaseAuthService.new(token).call       │
    │                                                   │
    │  1. FirebaseIdToken::Signature.verify(token)    │
    │     └─ Uses firebase_id_token gem               │
    │        └─ Fetches Google's public keys          │
    │           └─ Verifies JWT signature             │
    │                                                   │
    │  2. Extract payload                              │
    │     └─ user_id = payload['user_id']             │
    │     └─ email = payload['email']                 │
    │                                                   │
    │  3. Find or create User                          │
    │     ├─ Try: User.find_by(firebase_uid: uid)    │
    │     ├─ Or: User.find_by(email: email)          │
    │     ├─ If exists: Update firebase_uid if blank │
    │     └─ If not exists: Create new User           │
    │         ├─ password = random 20 chars           │
    │         ├─ website = Pwb::Current.website       │
    │         └─ user.save!                           │
    │                                                   │
    │  4. Grant membership                             │
    │     └─ UserMembershipService.grant_access(     │
    │           user: user,                          │
    │           website: website,                    │
    │           role: 'member'                       │
    │         )                                       │
    │                                                   │
    │  5. Return user object                           │
    └─────────────┬──────────────────────────────────┘
                  │
                  │ user object or nil
                  │
                  ↓
    ┌─────────────────────────────────────────┐
    │  Back in AuthController#firebase        │
    │                                          │
    │  if user                                 │
    │    sign_in(user)  ← Devise signs in    │
    │                                          │
    │    render json: {                       │
    │      user: {id, email, firebase_uid}, │
    │      message: "Logged in successfully" │
    │    }                                     │
    │                                          │
    │  else                                   │
    │    render json: {error: "Invalid token"}│
    │  end                                    │
    └─────────────┬──────────────────────────┘
                  │
                  │ JSON response + Set-Cookie header
                  │ (Devise session cookie)
                  │
                  ↓
    ┌──────────────────────────────────────┐
    │  Browser JavaScript Handler         │
    │                                       │
    │  if (response.ok) {                 │
    │    window.location.assign('/admin') │
    │  }                                   │
    └──────────────┬──────────────────────┘
                   │
                   │ Redirect to /admin
                   │
                   ↓
    ┌────────────────────────────────────────────┐
    │  Admin Panel (Vue SPA or Server-rendered) │
    │                                             │
    │  Request includes:                         │
    │  - Cookie: _pwb_session=XXXXX (from sign_in)
    │                                             │
    │  ✓ User authenticated in Rails session    │
    │  ✓ current_user available in controllers  │
    │  ✓ Devise helpers work (user_signed_in?)  │
    └─────────────────────────────────────────────┘
```

---

## Authentication Flow - Devise Path

```
┌──────────────────┐
│  User Browser    │
│ (unauthenticated)│
└────────┬─────────┘
         │
         │ GET /users/sign_in
         │ (includes locale: /en/users/sign_in)
         │
         ↓
┌────────────────────────────────────────┐
│  Devise::SessionsController#new        │
│  (via devise gem routing)              │
│                                         │
│  Renders:                              │
│  /app/views/devise/sessions/new.html.erb
│                                         │
│  Shows login form:                     │
│  - Email input                         │
│  - Password input                      │
│  - Remember me checkbox                │
│  - Submit button                       │
└────────┬───────────────────────────────┘
         │
         │ User fills form and clicks submit
         │
         │ POST /users/sign_in
         │ data: {email: "user@example.com", password: "..."}
         │
         ↓
┌────────────────────────────────────────────────────┐
│  Pwb::Devise::SessionsController#create           │
│  (custom override)                                 │
│                                                     │
│  1. before_action :validate_user_website          │
│     ├─ Get email from sign_in_params             │
│     ├─ Find User by email                         │
│     ├─ Get current_website_from_subdomain        │
│     └─ If user.website_id != current_site.id:   │
│         └─ Reject (flash alert + redirect)      │
│                                                     │
│  2. Call parent class (Devise::SessionsController)│
│     └─ Warden authentication                      │
│         ├─ Find user by email                     │
│         ├─ Check password (bcrypt verify)        │
│         ├─ Check locked_at is nil                │
│         ├─ Check timeout not exceeded             │
│         └─ If all good: create session           │
│                                                     │
│  3. Warden::Manager hooks trigger                 │
│     ├─ after_authentication:                      │
│     │  └─ AuthAuditLog.log_login_success()       │
│     ├─ Update user tracking:                      │
│     │  ├─ sign_in_count += 1                     │
│     │  ├─ current_sign_in_at = now               │
│     │  └─ current_sign_in_ip = request.remote_ip │
│     └─ Set Devise remember-me cookie if selected │
│                                                     │
│  4. Create Rails session                          │
│     └─ Set cookie: _pwb_session=ENCRYPTED_JWT   │
│        ├─ HTTP only (not accessible via JS)      │
│        ├─ Secure flag (HTTPS only)               │
│        └─ Same-site=Lax (CSRF protection)        │
│                                                     │
└────────┬─────────────────────────────────────────┘
         │
         │ Redirect to after_sign_in_path_for
         │ (default: /admin)
         │
         ↓
┌────────────────────────────────────────┐
│  /admin (or wherever configured)      │
│                                         │
│  Browser sends:                        │
│  - Cookie: _pwb_session=ENCRYPTED_JWT │
│  - Cookie: remember_me=TOKEN (maybe)  │
│                                         │
│  ✓ User authenticated in Rails session│
│  ✓ current_user available             │
│  ✓ user_signed_in? returns true       │
│  ✓ Devise helpers work                │
└─────────────────────────────────────────┘
```

---

## Multi-Tenancy Flow

```
Request comes in:
  GET http://tenant1.myapp.com/site_admin/dashboard
  
  ↓

SubdomainTenant concern processes:
  
  ├─ Extract subdomain from request
  │  request.subdomain = "tenant1"
  │
  ├─ Check if it's reserved
  │  "tenant1" NOT in [www, api, admin, ...]
  │  ✓ Valid tenant subdomain
  │
  ├─ Find website by subdomain
  │  Pwb::Website.find_by(subdomain: "tenant1")
  │
  ├─ Set context
  │  Pwb::Current.website = website_record
  │  (stores in RequestContext)
  │
  └─ ActsAsTenant scopes all queries
     PwbTenant::User
       .where(website_id: website_record.id)
     
     ✓ All PwbTenant:: queries auto-scoped
     ✓ No manual where(website_id: ...) needed

After authentication:
  
  current_user.website_id = website_record.id
  ✓ User belongs to same tenant
  
  User can access:
  ├─ Their own resources
  ├─ Team resources
  └─ Tenant-specific settings
  
  User CANNOT access:
  ├─ Other tenant's data
  ├─ Switch to different subdomain/tenant
  └─ See cross-tenant info
```

---

## Session Lifecycle

```
LOGIN:
  Pwb::Devise::SessionsController#create
    ↓
  Warden authenticates
    ↓
  Devise session created
    ↓
  Set-Cookie: _pwb_session=XXXXX
    ↓
  Browser stores secure HTTP-only cookie
    ↓
  Redirect to /admin

SUBSEQUENT REQUESTS:
  Browser sends:
    Cookie: _pwb_session=XXXXX
    ↓
  Devise::SessionsController
    ↓
  Warden decrypts and validates session
    ↓
  current_user = User.find(session_id)
    ↓
  Request has user context
    ↓
  Continue processing

INACTIVITY TIMEOUT (30 minutes):
  User idle for 30+ minutes
    ↓
  Next request comes in
    ↓
  Warden::Manager.after_failed_fetch
    ↓
  Session invalid (timed out)
    ↓
  Devise redirects to sign_in
    ↓
  AuthAuditLog.log_session_timeout
    ↓
  User sees login page

FAILED LOGIN ATTEMPT (5+ tries):
  User submits wrong password
    ↓
  Failed attempt logged
    ↓
  failed_attempts counter incremented
    ↓
  If failed_attempts >= 5:
    ├─ locked_at = now
    ├─ Account locked
    └─ User shown "Account locked" message
    
  User can unlock via:
  ├─ Wait 1 hour (unlock_in)
  └─ Click unlock link in email

LOGOUT:
  User clicks Sign Out button
    ↓
  DELETE /users/sign_out
    ↓
  Warden::Manager.before_logout
    ↓
  AuthAuditLog.log_logout(user, request)
    ↓
  Devise clears session
    ↓
  Delete-Cookie: _pwb_session
    ↓
  Expire remember-me cookie
    ↓
  Redirect to home_path
    ↓
  User no longer authenticated
```

---

## Authorization Check Flow

```
API Request comes in:
  GET /api/v1/protected_endpoint
  Cookie: _pwb_session=XXXXX
  
  ↓

ApplicationApiController#authenticate_user!
  ├─ Check: ENV['BYPASS_API_AUTH'] == 'true'?
  │  ├─ Yes (dev/e2e): Skip authentication
  │  └─ No (prod): Continue
  │
  └─ Check: Is user in Devise session?
     ├─ Yes: Set current_user = ...
     └─ No: Redirect to sign_in
  
  ↓

ApplicationApiController#check_user
  ├─ Get current_website from subdomain
  │
  ├─ Check: current_user.admin_for?(current_website)?
  │  ├─ Yes: User is owner or admin
  │  │  └─ Continue to action
  │  │
  │  └─ No: User is member, viewer, or not member
  │     └─ render_json_error "unauthorised_user"
  
  ↓

Action executes:
  @current_website = current_website  ← Automatically set
  @current_agency = @current_website.agency
  
  Model queries auto-scoped via ActsAsTenant:
  PwbTenant::User.all
    → WHERE website_id = current_website.id
  
  ✓ Data isolation maintained
  ✓ No cross-tenant data leakage
```

---

## Database Schema Relationships

```
pwb_websites (tenants)
  │
  ├─── has_many :user_memberships
  │    └─ id, user_id, website_id, role, active
  │
  └─── has_many :members (through user_memberships)
       └─ Refers to pwb_users


pwb_users
  │
  ├─── has_many :user_memberships
  │    └─ Links to websites with roles
  │
  ├─── has_many :websites (through user_memberships)
  │    └─ All websites user is member of
  │
  ├─── has_many :authorizations
  │    └─ OAuth provider links
  │
  ├─── has_many :auth_audit_logs
  │    └─ All auth events for this user
  │
  ├─── belongs_to :website (legacy, optional)
  │    └─ Primary website
  │
  └─── Devise tables:
       ├─ encrypted_password
       ├─ reset_password_token, reset_password_sent_at
       ├─ confirmation_token, confirmed_at
       ├─ unlock_token, locked_at, failed_attempts
       ├─ remember_created_at
       └─ Sign-in tracking...


pwb_user_memberships
  │
  ├─── belongs_to :user (pwb_users)
  │
  ├─── belongs_to :website (pwb_websites)
  │
  └─── Fields:
       ├─ role: 'owner' | 'admin' | 'member' | 'viewer'
       ├─ active: true | false
       └─ Unique index on [user_id, website_id]


pwb_authorizations (OAuth)
  │
  ├─── belongs_to :user
  │
  └─── Fields:
       ├─ provider: 'facebook' | 'google' | ...
       └─ uid: OAuth provider's user ID


pwb_auth_audit_logs
  │
  ├─── belongs_to :user (optional)
  ├─── belongs_to :website (optional)
  │
  └─── Fields:
       ├─ event_type: various
       ├─ email, provider, ip_address, user_agent
       ├─ failure_reason, metadata (JSONB)
       └─ created_at (for time-based queries)
```

---

## Request Processing Pipeline

```
                    ┌─────────────┐
                    │ HTTP Request│
                    └──────┬──────┘
                           │
                    ┌──────▼──────────────────┐
                    │ RouterConstraints      │
                    │ (Devise route matchers)│
                    └──────┬──────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
    ┌────▼──────────────────┐    ┌──────────▼────────┐
    │ Devise Routes         │    │ Custom Routes     │
    │ /users/sign_in        │    │ /admin            │
    │ /users/password       │    │ /site_admin       │
    │ /users/auth/:provider │    │ /tenant_admin     │
    │ /users (register)     │    │ /api_public       │
    └────┬──────────────────┘    │ /api              │
         │                       └──────┬────────────┘
         │                              │
         └──────────────────┬───────────┘
                            │
                    ┌───────▼──────────┐
                    │ Controller Hooks │
                    │ before_action    │
                    └───────┬──────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼─────────┐  ┌─────▼──────────┐  ┌──▼─────────────┐
    │ SubdomainTenant│  │AdminAuthBypass │  │ Authenticate  │
    │ concern        │  │ concern        │  │ User!         │
    └────┬─────────┘  └─────┬──────────┘  └──┬─────────────┘
         │                  │                  │
         │ Sets             │ Checks ENV       │ Checks
         │ Pwb::Current     │ Variables        │ Devise session
         │ .website         │                  │
         │ from subdomain   │ Checks                │
         │                  │ Rails.env            │
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                    ┌───────▼───────────┐
                    │ Authorization     │
                    │ (Phase 2)         │
                    └───────┬───────────┘
                            │
                    ┌───────▼───────────┐
                    │ Action Executes   │
                    │ (controller code) │
                    └───────┬───────────┘
                            │
                    ┌───────▼───────────┐
                    │ Response          │
                    │ Rendered          │
                    └───────┬───────────┘
                            │
                    ┌───────▼───────────┐
                    │ HTTP Response     │
                    │ + Cookies         │
                    │ + Headers         │
                    └───────────────────┘
```

---

## Gems & Dependencies

```
Authentication & Authorization:
  devise ~> 4.8
    └─ Rails authentication framework
    
  omniauth ~> 2.1
    └─ OAuth framework
    
  omniauth-facebook
    └─ Facebook OAuth strategy
    
Firebase Integration:
  firebase
    └─ Firebase REST client
    
  firebase_id_token ~> 2.5
    └─ Firebase JWT verification
    └─ Fetches Google public keys for signature verification
    └─ Can cache certificates in Redis
    
Multi-Tenancy:
  acts_as_tenant
    └─ Auto-scopes queries to tenant
    
Session Management:
  (Built-in to Rails)
    └─ Secure cookie-based sessions
    └─ Can use cache store for testing
    
Authorization (Planned):
  (TBD in Phase 2)
```

This comprehensive architecture ensures:
1. **Security**: Password hashing, account lockout, CSRF protection
2. **Multi-tenancy**: Data isolation by subdomain
3. **Flexibility**: Support for multiple auth methods (Firebase, Devise, OAuth)
4. **Audit Trail**: All auth events logged
5. **Development Ease**: Auth bypass for dev/e2e testing
