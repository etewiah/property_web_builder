# Plan: Unified Authentication with Firebase (Configurable)

## Executive Summary

This plan outlines how to make Firebase the default authentication method across PropertyWebBuilder while maintaining the ability to switch to Devise-based authentication via a configuration option.

## Current State

### Two Authentication Systems

1. **Firebase Authentication** (`/firebase_login`)
   - Uses FirebaseUI for email/password and Google OAuth
   - Token-based: Client gets Firebase JWT, sends to `/api_public/v1/auth/firebase`
   - `FirebaseAuthService` verifies token and creates/finds user
   - Calls `sign_in(user)` to create Devise session
   - Redirects to `/admin` (Vue SPA)

2. **Devise Authentication** (`/en/users/sign_in`)
   - Traditional server-rendered form
   - Email/password stored in database
   - Supports Facebook OAuth via OmniAuth
   - Redirects to `/admin` after sign-in

### Key Observations

- Both systems ultimately use Devise sessions (Firebase calls `sign_in(user)`)
- Firebase creates users automatically on first login
- Devise requires pre-existing user accounts
- Both redirect to `/admin` after successful auth
- Login links are scattered throughout the codebase

## Proposed Solution

### Configuration Option

Add a website-level or global configuration to toggle auth mode:

```ruby
# In config/initializers/pwb.rb or as Website attribute
Pwb.config.auth_provider = :firebase  # or :devise
```

### Implementation Phases

---

## Phase 1: Create Auth Configuration

### 1.1 Add Configuration Module

**File: `config/initializers/pwb_auth.rb`**

```ruby
# frozen_string_literal: true

module Pwb
  module AuthConfig
    mattr_accessor :provider, default: :firebase

    # Valid providers: :firebase, :devise
    VALID_PROVIDERS = %i[firebase devise].freeze

    def self.firebase?
      provider == :firebase
    end

    def self.devise?
      provider == :devise
    end

    def self.login_path
      firebase? ? '/firebase_login' : '/users/sign_in'
    end

    def self.signup_path
      firebase? ? '/firebase_sign_up' : '/users/sign_up'
    end

    def self.forgot_password_path
      firebase? ? '/firebase_forgot_password' : '/users/password/new'
    end
  end
end

# Load from environment variable
Pwb::AuthConfig.provider = ENV.fetch('AUTH_PROVIDER', 'firebase').to_sym
```

### 1.2 Add Helper Methods

**File: `app/helpers/auth_helper.rb`**

```ruby
# frozen_string_literal: true

module AuthHelper
  def auth_login_path
    Pwb::AuthConfig.login_path
  end

  def auth_signup_path
    Pwb::AuthConfig.signup_path
  end

  def auth_forgot_password_path
    Pwb::AuthConfig.forgot_password_path
  end

  def using_firebase_auth?
    Pwb::AuthConfig.firebase?
  end

  def using_devise_auth?
    Pwb::AuthConfig.devise?
  end
end
```

---

## Phase 2: Unified Login Redirect

### 2.1 Update Devise Failure App

**File: `config/initializers/auth_audit_hooks.rb`** (update existing)

```ruby
# Custom failure app that respects auth provider setting
class Pwb::AuthFailureApp < Devise::FailureApp
  def redirect_url
    if Pwb::AuthConfig.firebase?
      '/firebase_login'
    else
      new_user_session_path
    end
  end

  def respond
    # Log the failure before responding
    Pwb::AuthAuditLog.log_login_failure(
      email: params.dig(:user, :email),
      reason: i18n_message,
      request: request
    )
    super
  end
end
```

### 2.2 Update ApplicationController

**File: `app/controllers/application_controller.rb`** (add/update)

```ruby
class ApplicationController < ActionController::Base
  include AuthHelper
  helper AuthHelper

  # Override Devise's authenticate_user! to redirect to correct login
  def authenticate_user!
    unless user_signed_in?
      store_location_for(:user, request.fullpath) if request.get?
      redirect_to auth_login_path, alert: 'Please sign in to continue.'
    end
  end
end
```

---

## Phase 3: Update All Login Links

### 3.1 Views to Update

Replace hardcoded paths with helper methods:

| File | Change |
|------|--------|
| `app/views/layouts/tenant_admin/_header.html.erb` | Use `auth_login_path` |
| `app/views/layouts/site_admin/_header.html.erb` | Use `auth_login_path` |
| `app/views/pwb/_header.html.erb` | Use `auth_login_path` |
| `app/views/pwb/errors/admin_required.html.erb` | Use `auth_login_path` |
| `app/views/devise/shared/_links.html.erb` | Conditionally show Firebase link |

### 3.2 Example Update

**Before:**
```erb
<%= link_to "Sign In", new_user_session_path %>
```

**After:**
```erb
<%= link_to "Sign In", auth_login_path %>
```

### 3.3 Conditional Links in Devise Views

**File: `app/views/devise/shared/_links.html.erb`**

```erb
<%- if using_firebase_auth? %>
  <p class="text-center mt-3">
    Or <%= link_to "sign in with Firebase", auth_login_path %>
  </p>
<%- end %>
```

---

## Phase 4: Improve Firebase Login Experience

### 4.1 Add Return URL Support

Update Firebase login to support return URLs:

**File: `app/views/pwb/firebase_login/index.html.erb`**

```javascript
// Store return URL
const returnUrl = new URLSearchParams(window.location.search).get('return_to') || '/admin';

// In signInSuccessWithAuthResult callback:
fetch('/api_public/v1/auth/firebase', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ token: accessToken })
})
.then(response => {
  if (response.ok) {
    window.location.assign(returnUrl);
  }
});
```

### 4.2 Update Firebase Controller

**File: `app/controllers/pwb/firebase_login_controller.rb`**

```ruby
module Pwb
  class FirebaseLoginController < ApplicationController
    layout 'pwb/devise'

    before_action :redirect_if_signed_in

    def index
      @return_url = params[:return_to] || stored_location_for(:user) || admin_path
      render "pwb/firebase_login/index"
    end

    # ... rest of methods

    private

    def redirect_if_signed_in
      redirect_to admin_path if user_signed_in?
    end
  end
end
```

---

## Phase 5: Update Admin Panels

### 5.1 Site Admin Controller

**File: `app/controllers/site_admin_controller.rb`**

```ruby
class SiteAdminController < ApplicationController
  before_action :authenticate_user!  # Uses overridden method
  # ... rest unchanged
end
```

### 5.2 Tenant Admin Controller

**File: `app/controllers/tenant_admin_controller.rb`**

```ruby
class TenantAdminController < ActionController::Base
  include AuthHelper
  helper AuthHelper

  before_action :authenticate_user!, unless: :bypass_admin_auth?

  private

  def authenticate_user!
    unless user_signed_in?
      redirect_to auth_login_path, alert: 'Please sign in to continue.'
    end
  end
end
```

---

## Phase 6: Firebase Logout Integration

### 6.1 Create Unified Logout

**File: `app/controllers/pwb/auth_controller.rb`** (new)

```ruby
module Pwb
  class AuthController < ApplicationController
    def logout
      # Log the logout event
      if current_user
        Pwb::AuthAuditLog.log_logout(user: current_user, request: request)
      end

      # Sign out from Devise
      sign_out(current_user)

      # Redirect to home with Firebase sign-out script if using Firebase
      if Pwb::AuthConfig.firebase?
        redirect_to firebase_logout_path
      else
        redirect_to root_path, notice: 'Signed out successfully.'
      end
    end
  end
end
```

### 6.2 Firebase Logout View

**File: `app/views/pwb/auth/firebase_logout.html.erb`**

```erb
<script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-auth-compat.js"></script>
<script>
  const firebaseConfig = {
    apiKey: "<%= ENV['FIREBASE_API_KEY'] %>",
    authDomain: "<%= ENV['FIREBASE_PROJECT_ID'] %>.firebaseapp.com",
    projectId: "<%= ENV['FIREBASE_PROJECT_ID'] %>",
  };
  firebase.initializeApp(firebaseConfig);
  firebase.auth().signOut().then(() => {
    window.location.assign('/');
  });
</script>
<p>Signing out...</p>
```

---

## Phase 7: Environment Configuration

### 7.1 Environment Variables

Add to `.env.example`:

```bash
# Authentication Provider: 'firebase' or 'devise'
AUTH_PROVIDER=firebase

# Firebase Configuration (required if AUTH_PROVIDER=firebase)
FIREBASE_API_KEY=your-api-key
FIREBASE_PROJECT_ID=your-project-id
```

### 7.2 Development vs Production

```bash
# .env.development
AUTH_PROVIDER=devise  # Easier for local dev without Firebase

# .env.production
AUTH_PROVIDER=firebase  # Use Firebase in production
```

---

## File Changes Summary

### New Files
- `config/initializers/pwb_auth.rb` - Auth configuration
- `app/helpers/auth_helper.rb` - Auth helper methods
- `app/controllers/pwb/auth_controller.rb` - Unified auth controller
- `app/views/pwb/auth/firebase_logout.html.erb` - Firebase logout

### Modified Files
- `config/initializers/auth_audit_hooks.rb` - Update failure app
- `app/controllers/application_controller.rb` - Add auth helpers
- `app/controllers/tenant_admin_controller.rb` - Use auth helpers
- `app/controllers/site_admin_controller.rb` - Use auth helpers
- `app/controllers/pwb/firebase_login_controller.rb` - Add return URL
- `app/views/pwb/firebase_login/index.html.erb` - Support return URL
- `app/views/layouts/tenant_admin/_header.html.erb` - Dynamic login link
- `app/views/pwb/_header.html.erb` - Dynamic login link
- `config/routes.rb` - Add unified logout route

---

## Migration Path

### Step 1: Deploy Configuration (No User Impact)
- Add `pwb_auth.rb` initializer
- Add `auth_helper.rb`
- Set `AUTH_PROVIDER=devise` (keeps current behavior)

### Step 2: Update Views (No User Impact)
- Replace hardcoded paths with helpers
- Test thoroughly

### Step 3: Switch to Firebase (User Impact)
- Set `AUTH_PROVIDER=firebase`
- Communicate to users about new login flow

### Step 4: Monitor and Adjust
- Watch audit logs for login issues
- Gather user feedback
- Adjust as needed

---

## Implementation Status (Updated: Dec 7, 2025)

### Completed:
- [x] Phase 1: Auth Configuration Module (`config/initializers/pwb_auth.rb`)
- [x] Phase 2: Auth Helper Methods (`app/helpers/auth_helper.rb`)
- [x] Phase 3: Devise Failure App updated for dynamic redirects
- [x] Phase 4: Firebase Login Controller with return URL support
- [x] Phase 5: Admin Controllers updated with AuthHelper
- [x] Phase 6: Unified Logout Controller (`app/controllers/pwb/auth_controller.rb`)
- [x] Phase 7: All login/logout links updated to use auth helpers

### Files Created:
- `config/initializers/pwb_auth.rb` - Auth configuration module
- `app/helpers/auth_helper.rb` - View helpers for dynamic auth paths
- `app/controllers/pwb/auth_controller.rb` - Unified auth controller
- `app/views/pwb/auth/firebase_logout.html.erb` - Firebase logout page

### Files Modified:
- `config/initializers/auth_audit_hooks.rb` - Added redirect_url override
- `app/controllers/pwb/firebase_login_controller.rb` - Return URL support
- `app/views/pwb/firebase_login/index.html.erb` - Dynamic return URL
- All header partials updated to use auth helpers

---

## Testing Checklist

- [x] `AUTH_PROVIDER=devise` uses Devise login everywhere (config tested)
- [x] `AUTH_PROVIDER=firebase` uses Firebase login everywhere (default)
- [ ] Login redirects work correctly for both modes
- [ ] Logout works correctly for both modes
- [ ] Return URL preserved across login flow
- [ ] Audit logging works for both modes
- [ ] Admin panels accessible after login
- [ ] New user creation works (Firebase auto-creates)
- [ ] Existing users can still login
- [ ] OAuth providers work (Facebook for Devise, Google for Firebase)

---

## Rollback Plan

If issues arise:
1. Set `AUTH_PROVIDER=devise` in environment
2. Restart application
3. All users immediately use Devise authentication
4. No code deployment required

---

## Future Enhancements

1. **Per-tenant auth provider** - Allow each website to choose its auth method
2. **SSO integration** - Add SAML/OIDC support
3. **Magic link login** - Passwordless via email
4. **2FA** - Two-factor authentication for sensitive operations
