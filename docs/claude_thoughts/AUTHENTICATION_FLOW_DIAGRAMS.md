# Authentication & Signup Flow Diagrams

**Visual representations of key flows in the PropertyWebBuilder authentication system**

---

## 1. Complete Signup Flow (4 Steps)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SIGNUP FLOW (Step 1-4)                          │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ STEP 1: Email Capture                                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  User Input: user@example.com                                        │
│      ↓                                                               │
│  POST /api/signup/start { email: "user@example.com" }              │
│      ↓                                                               │
│  SignupApiService.start_signup()                                     │
│      ↓                                                               │
│  ┌─ Pwb::User.new(                                                  │
│  │   email: "user@example.com",                                     │
│  │   password: SecureRandom.hex(16),  # Temp password              │
│  │   confirmed_at: Time.current       # Auto-confirm               │
│  │ ).save                                                           │
│  └─ user.id = 1                                                     │
│      ↓                                                               │
│  ┌─ Subdomain.reserve_for_email("user@example.com", 24.hours)     │
│  └─ subdomain = "sunny-meadow-42"                                   │
│      ↓                                                               │
│  ┌─ user.update_columns(                                            │
│  │   signup_token: "abc123xyz...",                                  │
│  │   signup_token_expires_at: 2025-12-15 10:00:00                  │
│  │ )                                                                │
│  └─ (No validation, direct DB update)                              │
│      ↓                                                               │
│  Response:                                                           │
│  {                                                                  │
│    success: true,                                                   │
│    signup_token: "abc123xyz...",                                    │
│    subdomain: "sunny-meadow-42",                                    │
│    message: "Signup started successfully"                           │
│  }                                                                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ STEP 2: Site Configuration                                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  User Selects:                                                       │
│    - Subdomain: "my-agency"                                          │
│    - Site Type: "residential"                                        │
│      ↓                                                               │
│  POST /api/signup/configure {                                       │
│    signup_token: "abc123xyz...",                                     │
│    subdomain: "my-agency",                                           │
│    site_type: "residential"                                          │
│  }                                                                  │
│      ↓                                                               │
│  SignupApiService.configure_site()                                  │
│      ↓                                                               │
│  ┌─ Validates subdomain (uniqueness, format, reserved words)       │
│  └─ Pwb::Website.create(                                             │
│       subdomain: "my-agency",                                        │
│       site_type: "residential",                                      │
│       provisioning_state: "pending"                                 │
│     ).id = 5                                                        │
│      ↓                                                               │
│  ┌─ Pwb::UserMembership.create(                                     │
│  │   user: user,                                                     │
│  │   website: website,                                               │
│  │   role: "owner",                                                  │
│  │   active: true                                                    │
│  │ )                                                                │
│  └─ (User is now website owner)                                     │
│      ↓                                                               │
│  ┌─ website.may_assign_owner? → true                               │
│  │ website.assign_owner!                                             │
│  └─ provisioning_state: "pending" → "owner_assigned"              │
│      ↓                                                               │
│  Response:                                                           │
│  {                                                                  │
│    success: true,                                                   │
│    website_id: 5,                                                    │
│    subdomain: "my-agency",                                           │
│    site_type: "residential"                                          │
│  }                                                                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ STEP 3: Website Provisioning                                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  POST /api/signup/provision { signup_token: "abc123xyz..." }       │
│      ↓                                                               │
│  SignupApiService.provision_website(website)                        │
│      ↓                                                               │
│  ProvisioningService.provision_website()                            │
│      ↓                                                               │
│  State Machine Transitions:                                          │
│  owner_assigned (15%)                                                │
│    ↓ [guard: has_owner? ✓]                                           │
│  agency_created (30%)                                                │
│    ↓ [guard: has_agency? ✓]                                          │
│  links_created (45%)                                                 │
│    ↓ [guard: has_links? >= 3 ✓]                                      │
│  field_keys_created (60%)                                            │
│    ↓ [guard: has_field_keys? >= 5 ✓]                                │
│  properties_seeded (80%)                                             │
│    ↓ [guard: provisioning_complete? ✓]                              │
│  ready (95%)                                                         │
│    ↓ [guard: can_go_live? ✓]                                         │
│  live (100%)                                                         │
│      ↓                                                               │
│  Response:                                                           │
│  {                                                                  │
│    success: true,                                                   │
│    provisioning_status: "live",                                      │
│    progress: 100,                                                    │
│    complete: true,                                                   │
│    website_url: "https://my-agency.propertywebbuilder.com",        │
│    admin_url: "https://my-agency.propertywebbuilder.com/site_admin"│
│  }                                                                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ STEP 4: Completion                                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  GET /api/signup/status { signup_token: "abc123xyz..." }           │
│      ↓                                                               │
│  Check website.provisioning_state                                    │
│      ↓                                                               │
│  IF state == 'live':                                                 │
│    → Return website URL and admin URL                                │
│    → Signup complete!                                                │
│  ELSE:                                                               │
│    → Return progress percentage                                      │
│    → Continue polling                                                │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. User Authentication Flow (Devise)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    USER LOGIN (Email/Password)                       │
└──────────────────────────────────────────────────────────────────────┘

┌─ Initial Request ─────────────────────────────────────────────────────┐
│                                                                      │
│  GET https://my-agency.propertywebbuilder.com/admin                 │
│      ↓                                                               │
│  ApplicationController#authenticate_user! (before_action)           │
│      ↓                                                               │
│  user_signed_in? → false                                             │
│      ↓                                                               │
│  Redirect to login page                                              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Login Form ──────────────────────────────────────────────────────────┐
│                                                                      │
│  GET /users/sign_in                                                  │
│      ↓                                                               │
│  Devise::SessionsController#new                                      │
│      ↓                                                               │
│  Render login form with email + password                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Authentication ──────────────────────────────────────────────────────┐
│                                                                      │
│  POST /users/sign_in {                                               │
│    user: {                                                           │
│      email: "user@example.com",                                      │
│      password: "secretpassword"                                      │
│    }                                                                │
│  }                                                                  │
│      ↓                                                               │
│  Devise::SessionsController#create                                   │
│      ↓                                                               │
│  User.find_by(email: "user@example.com")                            │
│      ↓                                                               │
│  user.valid_password?("secretpassword") → bcrypt verify             │
│      ↓                                                               │
│  [WEBSITE ACCESS CHECK]                                              │
│  user.active_for_authentication?                                     │
│    ├─ Devise default checks (locked? confirmed?)                     │
│    ├─ Current website check                                          │
│    │   ├─ user.website_id == current_website.id?                     │
│    │   └─ user.user_memberships.active.exists?(website)?             │
│    └─ Return true/false                                              │
│      ↓                                                               │
│  IF authentication succeeds:                                         │
│    ├─ Pwb::AuthAuditLog.log_login_success(user: user)               │
│    ├─ sign_in(user)  # Set session cookie                            │
│    ├─ Redirect to authenticated_root_path                            │
│    └─ Session: { warden: user.id }                                   │
│  ELSE:                                                               │
│    ├─ Pwb::AuthAuditLog.log_login_failure(...)                       │
│    ├─ Render login form with error                                   │
│    └─ If 5 failed attempts: lock account                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Session Maintained ──────────────────────────────────────────────────┐
│                                                                      │
│  GET /admin                                                          │
│      ↓                                                               │
│  Devise reads session cookie                                         │
│      ↓                                                               │
│  current_user = Pwb::User.find(session[:warden])                    │
│      ↓                                                               │
│  user_signed_in? → true                                              │
│      ↓                                                               │
│  Request proceeds                                                    │
│      ↓                                                               │
│  Session timeout: 30 minutes of inactivity                          │
│  → Automatic re-login required                                       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Logout ──────────────────────────────────────────────────────────────┐
│                                                                      │
│  DELETE /users/sign_out                                              │
│      ↓                                                               │
│  Devise::SessionsController#destroy                                  │
│      ↓                                                               │
│  Pwb::AuthAuditLog.log_logout(user: current_user)                   │
│      ↓                                                               │
│  sign_out(current_user)  # Clear session                             │
│      ↓                                                               │
│  Redirect to root_path                                               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Website Access Control (Multi-Tenant)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    WEBSITE ACCESS VERIFICATION                       │
└──────────────────────────────────────────────────────────────────────┘

┌─ Request Arrives ─────────────────────────────────────────────────────┐
│                                                                      │
│  GET https://my-agency.propertywebbuilder.com/admin                 │
│      ↓                                                               │
│  HOST: my-agency.propertywebbuilder.com                              │
│  → Extract subdomain: "my-agency"                                    │
│      ↓                                                               │
│  Website.find_by_subdomain("my-agency") → website.id = 5            │
│      ↓                                                               │
│  Pwb::Current.website = website  [ThreadLocal variable]              │
│      ↓                                                               │
│  Devise authentication check                                         │
│      ↓                                                               │
│  IF user not signed in:                                              │
│    → Redirect to login page                                          │
│  ELSE:                                                               │
│    → Check user.active_for_authentication?                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Access Control Decision ─────────────────────────────────────────────┐
│                                                                      │
│  user.active_for_authentication?                                     │
│                                                                      │
│  ┌─ Check Devise defaults ───────────────────────────────────────┐ │
│  │ - Is user locked? (failed login attempts)                    │ │
│  │ - Is email confirmed?                                         │ │
│  │ - Is account expired?                                         │ │
│  │ → If any fail: return false                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│      ↓                                                             │
│  ┌─ Check Website Access ────────────────────────────────────────┐ │
│  │                                                               │ │
│  │ IF current_website.blank?                                     │ │
│  │   → return true  # No context, allow                          │ │
│  │                                                               │ │
│  │ ELSIF user.website_id == current_website.id                   │ │
│  │   → return true  # Primary website                            │ │
│  │                                                               │ │
│  │ ELSIF user.user_memberships.active.exists?(website: current_website) │
│  │   → return true  # Has active membership                      │ │
│  │                                                               │ │
│  │ ELSIF user.firebase_uid.present?                              │ │
│  │   → return true  # Firebase users auto-allowed               │ │
│  │                                                               │ │
│  │ ELSE                                                           │ │
│  │   → return false  # NO ACCESS                                 │ │
│  │                                                               │ │
│  └────────────────────────────────────────────────────────────── │
│      ↓                                                             │
│  Result: true → Allow request                                      │
│  Result: false → Devise#invalid_message("invalid_website")        │
│          → Redirect to login with error                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Role-Based Permissions ──────────────────────────────────────────────┐
│                                                                      │
│  After access granted, check role for specific action                │
│                                                                      │
│  user.role_for(website) → "owner" / "admin" / "member" / "viewer"  │
│      ↓                                                               │
│  Can user edit properties?                                           │
│    ├─ owner → Yes                                                    │
│    ├─ admin → Yes                                                    │
│    ├─ member → Yes                                                   │
│    └─ viewer → No                                                    │
│      ↓                                                               │
│  Can user manage users?                                              │
│    ├─ owner → Yes                                                    │
│    ├─ admin → Limited (not owners)                                   │
│    ├─ member → No                                                    │
│    └─ viewer → No                                                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Multi-Website User ──────────────────────────────────────────────────┐
│                                                                      │
│  User: john@example.com                                              │
│  ├─ Website A (residential) → owner                                   │
│  ├─ Website B (commercial) → admin                                    │
│  └─ Website C (vacation)   → member                                   │
│      ↓                                                               │
│  GET https://residential.propertywebbuilder.com/admin               │
│    → current_website = Website A                                     │
│    → user.active_for_authentication? → true (website_id match)      │
│    → user.role_for(Website A) = "owner"                             │
│      ↓                                                               │
│  GET https://commercial.propertywebbuilder.com/admin                │
│    → current_website = Website B                                     │
│    → user.active_for_authentication? → true (membership match)       │
│    → user.role_for(Website B) = "admin"                             │
│      ↓                                                               │
│  GET https://vacation.propertywebbuilder.com/admin                  │
│    → current_website = Website C                                     │
│    → user.active_for_authentication? → true (membership match)       │
│    → user.role_for(Website C) = "member"                            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. Magic Link Flow (NEW)

```
┌──────────────────────────────────────────────────────────────────────┐
│                       MAGIC LINK AUTHENTICATION                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ User Requests Magic Link ────────────────────────────────────────────┐
│                                                                      │
│  GET /magic-link                                                     │
│      ↓                                                               │
│  Render form: "Enter your email"                                     │
│      ↓                                                               │
│  POST /magic-link/request { email: "user@example.com" }             │
│      ↓                                                               │
│  MagicLinkService.request_magic_link("user@example.com")            │
│      ↓                                                               │
│  ┌─ Validate email format ──────────────────────────────────────┐   │
│  │ → Return success regardless (security: don't reveal if       │   │
│  │   email exists)                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│      ↓                                                               │
│  ┌─ Find user by email ──────────────────────────────────────────┐  │
│  │ user = Pwb::User.find_by(email: "user@example.com")         │  │
│  │ IF user:                                                      │  │
│  │   → Continue                                                  │  │
│  │ ELSE:                                                         │  │
│  │   → Return success (don't reveal user doesn't exist)         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│      ↓                                                               │
│  ┌─ Generate Token ─────────────────────────────────────────────┐   │
│  │ token = SecureRandom.urlsafe_base64(32)  # ~43 chars        │   │
│  │ user.update_columns(                                         │   │
│  │   magic_link_token: token,                                   │   │
│  │   magic_link_expires_at: 24.hours.from_now                  │   │
│  │ )                                                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
│      ↓                                                               │
│  ┌─ Send Email ─────────────────────────────────────────────────┐   │
│  │ Pwb::UserMailer.magic_link_email(user, token).deliver_later │   │
│  │                                                              │   │
│  │ Email contains:                                              │   │
│  │   Subject: "Your PropertyWebBuilder Login Link"             │   │
│  │   Link: /magic-login/<token>                                │   │
│  │   Expires: 24 hours                                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
│      ↓                                                               │
│  Pwb::AuthAuditLog.log_magic_link_requested(user: user)             │
│      ↓                                                               │
│  Redirect to /users/sign_in with message:                            │
│  "Check your email for the login link"                              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ User Clicks Magic Link ──────────────────────────────────────────────┐
│                                                                      │
│  Email: "Your login link:"                                          │
│  Link: <https://propertywebbuilder.com/magic-login/abc123xyz...>   │
│      ↓                                                               │
│  GET /magic-login/abc123xyz...                                      │
│      ↓                                                               │
│  SessionsController#magic_login                                      │
│      ↓                                                               │
│  MagicLinkService.login_with_token("abc123xyz...")                  │
│      ↓                                                               │
│  ┌─ Find user by token ──────────────────────────────────────────┐  │
│  │ user = User.find_by(magic_link_token: "abc123xyz...")        │  │
│  │ IF not found:                                                 │  │
│  │   → return { success: false, errors: ["Invalid link"] }      │  │
│  │ ELSIF expired:                                                │  │
│  │   IF magic_link_expires_at < Time.current:                   │  │
│  │     → return { success: false, errors: ["Link expired"] }    │  │
│  │                                                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│      ↓                                                               │
│  ┌─ Clear Token (one-time use) ─────────────────────────────────┐  │
│  │ user.update_columns(                                         │  │
│  │   magic_link_token: nil,                                     │  │
│  │   magic_link_expires_at: nil                                 │  │
│  │ )                                                            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│      ↓                                                               │
│  ┌─ Log and Sign In ────────────────────────────────────────────┐   │
│  │ Pwb::AuthAuditLog.log_login_success(                         │   │
│  │   user: user,                                                │   │
│  │   request: request,                                          │   │
│  │   method: 'magic_link'                                       │   │
│  │ )                                                            │   │
│  │                                                              │   │
│  │ sign_in(user)  # Devise helper - sets session               │   │
│  └──────────────────────────────────────────────────────────────┘  │
│      ↓                                                               │
│  Redirect to authenticated_root_path with:                           │
│  "Signed in successfully!"                                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌─ User Now Authenticated ──────────────────────────────────────────────┐
│                                                                      │
│  POST /magic-login/abc123xyz...                                      │
│      ↓                                                               │
│  Session: { warden.user.user_id: 1 }  (Devise session)             │
│      ↓                                                               │
│  GET /admin                                                          │
│      ↓                                                               │
│  current_user = Pwb::User.find(1)                                   │
│      ↓                                                               │
│  user_signed_in? → true                                              │
│      ↓                                                               │
│  Request proceeds normally                                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 5. State Machine: User Onboarding

```
┌─────────────────────────────────────────────────────────────────┐
│ USER ONBOARDING STATE MACHINE                                   │
│ (AASM: app/models/pwb/user.rb)                                  │
└─────────────────────────────────────────────────────────────────┘

                        ┌──────────────┐
                        │     lead     │ ◄─────── Initial state
                        │ (email only) │         (user.create)
                        └──────┬───────┘
                               │
                    .register! │
                               ↓
                        ┌──────────────────┐
                        │   registered     │
                        │ (account created)│
                        └──────┬───────────┘
                               │
              .verify_email! / .start_onboarding!
                               ↓
                        ┌────────────────────┐
                        │  email_verified    │
                        │ (email confirmed)  │
                        └──────┬─────────────┘
                               │
                   .start_onboarding!
                               ↓
                        ┌────────────────────┐
                        │   onboarding       │
                        │ (multi-step wizard)│ ◄───────┐
                        └──────┬─────────────┘         │
                               │                       │
                    .complete_onboarding!              │
              .advance_onboarding_step!    (repeat)    │
                               ↓                       └──
                        ┌────────────────┐
                        │    active      │
                        │ (fully setup)  │
                        └────────────────┘

                        ┌────────────────┐
                        │    churned     │
                        │ (abandoned)    │
                        └────────────────┘
                             ↑
                             │
                      .mark_churned!

ONBOARDING STEPS (tracked in onboarding_step column):
  1 → Verify Email
  2 → Choose Subdomain
  3 → Select Site Type
  4 → Setup Complete
```

---

## 6. State Machine: Website Provisioning

```
┌────────────────────────────────────────────────────────────────┐
│ WEBSITE PROVISIONING STATE MACHINE                             │
│ (AASM: app/models/pwb/website.rb)                              │
└────────────────────────────────────────────────────────────────┘

                    ┌───────────┐
                    │ pending   │  Initial state
                    └─────┬─────┘
                          │
         .assign_owner! (guard: has_owner?)
                          ↓
               ┌──────────────────────┐
               │ owner_assigned (15%)  │
               └──────────┬───────────┘
                          │
       .complete_agency! (guard: has_agency?)
                          ↓
               ┌──────────────────────┐
               │ agency_created (30%) │
               └──────────┬───────────┘
                          │
       .complete_links! (guard: has_links? >= 3)
                          ↓
               ┌──────────────────────┐
               │ links_created (45%)   │
               └──────────┬───────────┘
                          │
     .complete_field_keys! (guard: has_field_keys? >= 5)
                          ↓
               ┌──────────────────────┐
               │ field_keys_created (60%)
               └──────────┬───────────┘
                          │
        .seed_properties! / .skip_properties!
                          ↓
               ┌──────────────────────┐
               │ properties_seeded (80%)
               └──────────┬───────────┘
                          │
        .mark_ready! (guard: provisioning_complete?)
                          ↓
               ┌──────────────────────┐
               │ ready (95%)           │
               └──────────┬───────────┘
                          │
          .go_live! (guard: can_go_live?)
                          ↓
               ┌──────────────────────┐
               │ live (100%)           │  ✓ Publicly accessible
               └──────────────────────┘

GUARDS (must pass for transition):
  - has_owner? → user_memberships.exists?(role: 'owner')
  - has_agency? → agency.present?
  - has_links? → links.count >= 3
  - has_field_keys? → field_keys.count >= 5
  - provisioning_complete? → all of above true
  - can_go_live? → provisioning_complete? && subdomain.present?

ERROR PATH:
  (any state) → .fail_provisioning!(error_msg) → failed
               ↓
               .retry_provisioning! → pending

LIFECYCLE:
  live → .suspend() → suspended
  suspended → .reactivate() → live
  (suspended|failed) → .terminate() → terminated
```

---

## 7. Database Schema: Key Tables

```
┌────────────────────────────────────────────────────────────────┐
│ pwb_users                                                       │
├────────────────────────────────────────────────────────────────┤
│ id                          INTEGER PRIMARY KEY                │
│ email                       STRING UNIQUE INDEX                │
│ encrypted_password          STRING                             │
│ website_id                  INTEGER FK (legacy)                │
│ firebase_uid                STRING                             │
│ onboarding_state            STRING (lead|registered|...)       │
│ onboarding_step             INTEGER (1-4)                      │
│ onboarding_started_at       DATETIME                           │
│ onboarding_completed_at     DATETIME                           │
│ signup_token                STRING UNIQUE INDEX                │
│ signup_token_expires_at     DATETIME                           │
│ magic_link_token            STRING UNIQUE INDEX (NEW)          │
│ magic_link_expires_at       DATETIME (NEW)                     │
│ confirmed_at                DATETIME (Devise)                  │
│ locked_at                   DATETIME (Devise)                  │
│ unlock_token                STRING (Devise)                    │
│ reset_password_token        STRING (Devise)                    │
│ reset_password_sent_at      DATETIME (Devise)                  │
│ last_sign_in_at             DATETIME (Devise)                  │
│ last_sign_in_ip             STRING (Devise)                    │
│ sign_in_count               INTEGER (Devise)                   │
│ created_at                  DATETIME                           │
│ updated_at                  DATETIME                           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ pwb_websites                                                    │
├────────────────────────────────────────────────────────────────┤
│ id                          INTEGER PRIMARY KEY                │
│ subdomain                   STRING UNIQUE INDEX                │
│ custom_domain               STRING UNIQUE INDEX                │
│ custom_domain_verified      BOOLEAN                            │
│ site_type                   STRING (residential|commercial|...) │
│ provisioning_state          STRING (pending|live|...)          │
│ provisioning_started_at     DATETIME                           │
│ provisioning_completed_at   DATETIME                           │
│ provisioning_failed_at      DATETIME                           │
│ provisioning_error          TEXT                               │
│ company_display_name        STRING                             │
│ theme_name                  STRING                             │
│ created_at                  DATETIME                           │
│ updated_at                  DATETIME                           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ pwb_user_memberships                                            │
├────────────────────────────────────────────────────────────────┤
│ id                          INTEGER PRIMARY KEY                │
│ user_id                     INTEGER FK pwb_users               │
│ website_id                  INTEGER FK pwb_websites            │
│ role                        STRING (owner|admin|member|viewer) │
│ active                      BOOLEAN                            │
│ created_at                  DATETIME                           │
│ updated_at                  DATETIME                           │
│ INDEX: (user_id, website_id) UNIQUE                            │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ pwb_auth_audit_logs                                             │
├────────────────────────────────────────────────────────────────┤
│ id                          INTEGER PRIMARY KEY                │
│ user_id                     INTEGER FK pwb_users               │
│ event_type                  STRING (login_success|failure|...) │
│ success                     BOOLEAN                            │
│ ip_address                  STRING                             │
│ user_agent                  STRING                             │
│ details                     JSON                               │
│ created_at                  DATETIME                           │
│ INDEX: (user_id, created_at DESC)                              │
└────────────────────────────────────────────────────────────────┘
```

---

## 8. Controller Flow: Request Handling

```
┌────────────────────────────────────────────────────────────────┐
│ TYPICAL REQUEST HANDLING FLOW                                  │
└────────────────────────────────────────────────────────────────┘

  GET https://my-agency.propertywebbuilder.com/admin
      ↓
  ┌──────────────────────────────┐
  │ Router                        │
  │ - Extract subdomain           │
  │ - Lookup website by subdomain │
  │ - Set Pwb::Current.website    │
  └──────────────┬────────────────┘
                 ↓
  ┌──────────────────────────────────┐
  │ Before Filters (in order)        │
  │ 1. Set current_website           │
  │ 2. authenticate_user!            │
  │    - Check session cookie        │
  │    - Load current_user           │
  │    - If no user: redirect login  │
  │ 3. authorize_user!               │
  │    - Check user.can_access_website? │
  │    - Check role permissions      │
  └──────────────┬───────────────────┘
                 ↓
  ┌──────────────────────────────┐
  │ Action                        │
  │ - Access current_user         │
  │ - Access current_website      │
  │ - Read/write data             │
  └──────────────┬────────────────┘
                 ↓
  ┌──────────────────────────────┐
  │ After Filters                 │
  │ - Log activity                │
  │ - Clear temp data             │
  └──────────────┬────────────────┘
                 ↓
  ┌──────────────────────────────┐
  │ Response                      │
  │ - Render template             │
  │ - Return JSON                 │
  │ - Redirect                    │
  └──────────────────────────────┘
```

---

## Summary

These diagrams show:

1. **Complete 4-step signup** with database changes at each step
2. **Devise login flow** with website access verification
3. **Multi-tenant access control** with role checking
4. **Magic link flow** (new feature) following existing patterns
5. **User onboarding states** (AASM state machine)
6. **Website provisioning states** with guards and transitions
7. **Database schema** for key tables
8. **Request handling** flow with authentication/authorization checks

The key insight: **The signup_token pattern already implements what magic links need!**
