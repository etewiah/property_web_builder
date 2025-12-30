# Admin API Endpoints Security Audit

**Date**: 2025-12-30
**Status**: PRELIMINARY AUDIT REPORT

## Executive Summary

This document provides a comprehensive security audit of admin and API endpoints in PropertyWebBuilder. The application has multiple security layers with both strong and weak points:

**Positive**: Multi-tenant scoping, environment-based bypass restrictions, CSRF protection in most areas
**Concerns**: Multiple unauthenticated public APIs (intentional), admin bypass mechanisms, several endpoints lacking proper authorization checks

---

## 1. Authentication Mechanisms

### 1.1 Primary Authentication Methods

#### Devise (Session-based)
- **Usage**: Primary authentication for web UI and admin panels
- **Status**: Standard Rails implementation
- **Scope**: Site Admin and Tenant Admin interfaces

#### Firebase Authentication
- **Usage**: Optional alternative authentication provider
- **File**: `app/controllers/api_public/v1/auth_controller.rb`
- **Method**: Firebase tokens verified client-side or via API

#### API Token-based (Signup)
- **Usage**: Temporary tokens for signup flow
- **File**: `app/controllers/api/signup/signups_controller.rb`
- **Method**: Single-use verification tokens

### 1.2 Authentication Bypass Mechanisms

**File**: `app/controllers/concerns/admin_auth_bypass.rb`

#### Bypass Configuration
```ruby
ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

ENV['BYPASS_ADMIN_AUTH'] == 'true'
ENV['BYPASS_API_AUTH'] == 'true'
```

**Status**: PROPERLY GATED
- Only allowed in: `development`, `e2e`, `test` environments
- Will NOT work in production/staging
- Auto-creates mock admin user when bypass is enabled

**Risk Level**: LOW - Environment check is effective

---

## 2. Admin Controller Base Classes

### 2.1 SiteAdminController

**File**: `app/controllers/site_admin_controller.rb`
**Scope**: Single website/tenant management
**Inheritance**: `ActionController::Base` + Devise + SubdomainTenant

#### Security Filters
```ruby
before_action :set_tenant_from_subdomain          # Sets current_website
before_action :require_admin!, unless: :bypass_admin_auth?
```

#### Authorization Logic
```ruby
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render 'pwb/errors/admin_required', status: :forbidden
  end
end

def user_is_admin_for_subdomain?
  current_user.admin_for?(current_website)
end
```

**Authentication**: Requires Devise login
**Authorization**: User must be admin/owner of current website
**Multi-tenant Isolation**: Via SubdomainTenant concern
**Status**: PROPERLY SECURED

---

### 2.2 TenantAdminController

**File**: `app/controllers/tenant_admin_controller.rb`
**Scope**: Cross-tenant management (all websites)

#### Security Filters
```ruby
before_action :authenticate_user!, unless: :bypass_admin_auth?
before_action :require_tenant_admin!, unless: :bypass_admin_auth?
```

#### Authorization Logic
```ruby
def require_tenant_admin!
  unless tenant_admin_allowed?
    render_tenant_admin_forbidden
  end
end

def tenant_admin_allowed?
  allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip).map(&:downcase)
  return false if allowed_emails.empty?
  allowed_emails.include?(current_user.email.downcase)
end
```

**Authentication**: Requires Devise login
**Authorization**: Email whitelist via `TENANT_ADMIN_EMAILS` env var
**Status**: PROPERLY SECURED

---

## 3. API Controllers Architecture

### 3.1 Pwb::ApplicationApiController

**File**: `app/controllers/pwb/application_api_controller.rb`
**Usage**: Base for internal admin API endpoints
**Inheritance**: `ActionController::Base`

#### Security Filters
```ruby
before_action :authenticate_user!, :current_agency, :check_user, 
              unless: :bypass_authentication?
```

#### Bypass Configuration
```ruby
ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

def bypass_authentication?
  return false unless ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env)
  ENV['BYPASS_API_AUTH'] == 'true' || ENV['BYPASS_ADMIN_AUTH'] == 'true'
end
```

#### Authorization Check
```ruby
def check_user
  return if bypass_authentication?
  unless current_user && current_user.admin_for?(current_website)
    render_json_error "unauthorised_user"
  end
end
```

**Status**: PROPERLY SECURED

---

### 3.2 Api::BaseController

**File**: `app/controllers/api/base_controller.rb`
**Usage**: Base for general API endpoints without inherent auth
**Inheritance**: `ActionController::API`

#### Tenant Resolution
```ruby
def resolve_website
  website_from_header || website_from_subdomain || fallback_website
end

def fallback_website
  return nil if Rails.env.production?
  Pwb::Website.first
end
```

**Key Detail**: Fallback to `Website.first` in non-production only
**No Authentication**: Child controllers implement auth as needed
**Status**: Base class properly designed

---

### 3.3 ApiPublic::V1::BaseController

**File**: `app/controllers/api_public/v1/base_controller.rb`
**Usage**: Base for PUBLIC API endpoints
**Authentication**: NONE (intentional)
**CSRF**: Explicitly disabled

```ruby
class BaseController < ActionController::Base
  include SubdomainTenant
  skip_before_action :verify_authenticity_token
end
```

**Status**: Properly designed for public access

---

## 4. Admin API Endpoints (Secured)

### 4.1 Pwb::Api::V1 Controllers

All inherit from `ApplicationApiController` - require admin authentication.

#### Website Management
**Controller**: `Pwb::Api::V1::WebsiteController`

| Endpoint | Method | Auth | Details |
|----------|--------|------|---------|
| `/api/v1/website` | PUT | ✓ Admin | Update website settings |

#### Page Management
**Controller**: `Pwb::Api::V1::PageController`

| Endpoint | Method | Auth | Details |
|----------|--------|------|---------|
| `/api/v1/pages/:page_name` | GET | ✓ Admin | Get page details |
| `/api/v1/pages` | PUT | ✓ Admin | Update page |
| `/api/v1/pages/page_fragment` | PUT | ✓ Admin | Update page fragment |
| `/api/v1/pages/photos/:page_slug/:page_part_key/:block_label` | POST | ✓ Admin | Add page photo |

#### Translation Management
**Controller**: `Pwb::Api::V1::TranslationsController`

| Endpoint | Method | Auth | Details |
|----------|--------|------|---------|
| `/api/v1/translations` | POST | ✓ Admin | Create translation |
| `/api/v1/translations/:id` | PUT | ✓ Admin | Update translation |
| `/api/v1/translations/:id` | DELETE | ✓ Admin | Delete translation |

#### Property Management
**Controller**: `Pwb::Api::V1::PropertiesController`

| Endpoint | Method | Auth | Details |
|----------|--------|------|---------|
| `/api/v1/properties` | GET | ✓ Admin | List properties |
| `/api/v1/properties/:id` | GET | ✓ Admin | Get property |
| `/api/v1/properties/bulk_create` | POST | ✓ Admin | Bulk create |

#### Contacts Management
**Controller**: `Pwb::Api::V1::ContactsController`

| Endpoint | Method | Auth | Details |
|----------|--------|------|---------|
| `/api/v1/contacts` | GET | ✓ Admin | List contacts |
| `/api/v1/contacts` | POST | ✓ Admin | Create contact |

**Status**: All properly authenticated and authorized

---

## 5. Public API Endpoints (Intentional)

### 5.1 ApiPublic::V1 Controllers

All inherit from `ApiPublic::V1::BaseController` - NO authentication (intentional for public listing).

#### Public Property Listing
**Controller**: `ApiPublic::V1::PropertiesController`

| Endpoint | Auth | Data |
|----------|------|------|
| `/api_public/v1/properties/:id` | None | Published properties only |
| `/api_public/v1/properties` | None | Search published properties |

**Status**: PUBLICLY ACCESSIBLE - Intentional for listing display

#### Public Page Display
**Controller**: `ApiPublic::V1::PagesController`

| Endpoint | Auth | Data |
|----------|------|------|
| `/api_public/v1/pages/:id` | None | Published pages |
| `/api_public/v1/pages/by_slug/:slug` | None | Published pages |

**Status**: PUBLICLY ACCESSIBLE - Intentional

#### Public Translations
**Controller**: `ApiPublic::V1::TranslationsController`

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `/api_public/v1/translations` | None | Frontend localization |

**Status**: PUBLICLY ACCESSIBLE - Intentional

#### Widgets
**Controller**: `ApiPublic::V1::WidgetsController`

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `/api_public/v1/widgets/:widget_key` | None | Embeddable widgets |
| `/api_public/v1/widgets/:widget_key/impression` | None | Analytics tracking |

**Status**: PUBLICLY ACCESSIBLE - Intentional for embeddable use

#### Firebase Authentication (Public)
**Controller**: `ApiPublic::V1::AuthController`

| Endpoint | Auth | Notes |
|----------|------|-------|
| `/api_public/v1/auth/firebase` | Firebase Token | Sign in via Firebase |

**Status**: Public but requires valid Firebase token

---

## 6. Special Endpoints

### 6.1 Health Check Endpoints

**File**: `app/controllers/health_controller.rb`

| Endpoint | Auth | Details |
|----------|------|---------|
| `/health` | None | Basic liveness check |
| `/health/live` | None | Same as /health |
| `/health/ready` | None | Readiness check (DB/Redis/Storage) |
| `/health/details` | Token/IP | Detailed system info (protected) |

#### Detailed Health Protection
```ruby
def authorize_detailed_access!
  return true if Rails.env.development? || Rails.env.test?
  return true if valid_health_token?
  return true if allowed_ip?
  render json: { error: 'Unauthorized' }, status: :unauthorized
end
```

**Protection Methods**:
1. Bearer token: `Authorization: Bearer <HEALTH_CHECK_TOKEN>`
2. IP whitelist: `HEALTH_CHECK_ALLOWED_IPS` env var
3. Auto-allowed in dev/test

**Status**: PROPERLY SECURED

---

### 6.2 TLS Certificate Verification Endpoint

**File**: `app/controllers/pwb/tls_controller.rb`

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `/tls/check` | Optional Secret | Domain verification for certificates |

#### Protection
```ruby
def verify_tls_request
  expected_secret = ENV['TLS_CHECK_SECRET']
  if expected_secret.present?
    provided_secret = request.headers['X-TLS-Secret'] || params[:secret]
    unless ActiveSupport::SecurityUtils.secure_compare(provided_secret.to_s, expected_secret)
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
```

**Protection Methods**:
1. Shared secret: `TLS_CHECK_SECRET` env var
2. IP allowlist: `TLS_CHECK_ALLOWED_IPS` (commented out)

**Status**: PROPERLY SECURED

---

### 6.3 E2E Test Support Endpoints

**File**: `app/controllers/e2e/test_support_controller.rb`

| Endpoint | Environment | Auth | Purpose |
|----------|-------------|------|---------|
| `/e2e/health` | e2e only | BYPASS | Health check |
| `/e2e/reset_website_settings` | e2e only | BYPASS | Reset to seed |
| `/e2e/reset_all` | e2e only | BYPASS | Full reset |

#### Protection
```ruby
def verify_e2e_environment
  unless Rails.env.e2e? && ENV['BYPASS_ADMIN_AUTH'] == 'true'
    render json: { error: '...' }, status: :forbidden
  end
end
```

**Status**: PROPERLY GATED - Only in e2e with bypass enabled

---

### 6.4 Signup API Endpoints

**File**: `app/controllers/api/signup/signups_controller.rb`

| Endpoint | Auth | Flow Stage |
|----------|------|-----------|
| `/api/signup/start` | None | Begin signup |
| `/api/signup/configure` | Token | Configure site |
| `/api/signup/provision` | Token | Provision |
| `/api/signup/status` | Token | Check status |

#### Protection Mechanism
```ruby
before_action :load_signup_user_from_token,
              only: [:configure, :provision, :status, ...]
```

**Token-based**: Single-use tokens issued from `/start`
**Status**: PROPERLY SECURED

---

## 7. Potential Security Issues

### FINDING #1: Pwb::PropertiesController Debug Statements

**Severity**: LOW
**File**: `app/controllers/pwb/application_api_controller.rb`

**Issue**: Debug puts() statements in production code

```ruby
def check_user
  puts "ApplicationApiController#check_user reached"
end

def current_agency
  puts "ApplicationApiController#current_agency reached"
end
```

**Action**: Remove these debug statements before production

---

### FINDING #2: ApiPublic PropertiesController TODO

**Severity**: LOW
**File**: `app/controllers/api_public/v1/properties_controller.rb`

```ruby
class PropertiesController < BaseController
  # TODO: Add authentication if needed, similar to other API controllers
```

**Assessment**: This is CORRECT as-is (public listing API)
**Action**: Remove TODO and document intentional public access

---

### FINDING #3: Fallback Website in Development

**Severity**: MEDIUM
**File**: `app/controllers/api/base_controller.rb`

```ruby
def fallback_website
  return nil if Rails.env.production?
  Pwb::Website.first  # <-- Uses first website as fallback
end
```

**Issue**: In non-production, API calls without proper tenant resolution might hit wrong website
**Status**: Only affects non-production (prod returns nil)
**Action**: Add logging when fallback is used

---

### FINDING #4: Deprecated Property Model

**Severity**: LOW (not security-related)
**File**: `app/controllers/pwb/api/v1/properties_controller.rb`

```ruby
# DEPRECATION WARNING: This controller uses the deprecated Pwb::Prop model
```

**Action**: Migrate to new models (out of scope for auth audit)

---

## 8. Multi-Tenant Isolation Analysis

### 8.1 Website Scoping

**Mechanism 1**: SubdomainTenant Concern
- Used in: SiteAdminController, Api::BaseController, ApiPublic::V1::BaseController
- Sets: `Pwb::Current.website` from subdomain
- Sets: `ActsAsTenant.current_tenant` for auto-scoped models

**Mechanism 2**: current_website Resolution (ApplicationApiController)
```ruby
def current_website
  current_website_from_subdomain ||
  current_website_from_header ||
  Pwb::Current.website ||
  fallback_website
end
```

**Mechanism 3**: Explicit Scoping (Api::V1 controllers)
```ruby
contact = current_website.contacts.find_by_id(params[:id])
```

**Status**: PROPERLY ISOLATED

---

### 8.2 Cross-Tenant Access

**TenantAdminController** intentionally bypasses tenant scoping
```ruby
def unscoped_model(model_class)
  model_class.unscoped  # Access all tenants
end
```

**Status**: PROPERLY RESTRICTED - Only authorized admins

---

## 9. CSRF Protection Analysis

| Controller Type | CSRF Protection | Notes |
|-----------------|-----------------|-------|
| SiteAdminController | Default (exception) | Standard Rails |
| TenantAdminController | Default (exception) | Explicit protection |
| ApplicationApiController | ✓ with: :exception | Explicit protection |
| Api::BaseController | Not applicable | ActionController::API (no sessions) |
| ApiPublic::V1::BaseController | ✗ Skip | Intentional - public API |

**Status**: PROPERLY CONFIGURED

---

## 10. Summary of Findings

### Secure
✓ Admin authentication properly enforced
✓ Tenant admin whitelist properly implemented  
✓ ApplicationApiController requires admin auth
✓ Public API endpoints intentionally open
✓ E2E test endpoints properly gated
✓ Health check details endpoint protected
✓ TLS endpoint has secret-based auth
✓ Multi-tenant isolation properly implemented
✓ CSRF protection properly configured
✓ Authentication bypass only in non-production

### Issues to Address
1. Remove debug puts() statements from ApplicationApiController
2. Remove TODO comment from ApiPublic PropertiesController (document intentional public access)
3. Add logging when Api::BaseController uses fallback_website
4. Enable IP allowlist on TLS endpoint (currently commented out, optional)
5. Update Pwb::Api::V1::PropertiesController to use new models

### Critical Issues
**NONE FOUND** - All admin endpoints are properly authenticated and authorized

---

## Appendix A: Complete File List

### Admin Controllers (30+)
- `app/controllers/site_admin_controller.rb`
- `app/controllers/tenant_admin_controller.rb`
- Site Admin children: analytics, billing, contacts, domains, pages, properties, users, etc.
- Tenant Admin children: agencies, domains, users, websites, etc.

### API Base Controllers
- `app/controllers/pwb/application_api_controller.rb`
- `app/controllers/api/base_controller.rb`
- `app/controllers/api_public/v1/base_controller.rb`

### Admin API Controllers (Pwb::Api::V1)
- agency_controller.rb
- contacts_controller.rb
- links_controller.rb
- lite_properties_controller.rb
- mls_controller.rb
- page_controller.rb
- properties_controller.rb
- select_values_controller.rb
- themes_controller.rb
- translations_controller.rb
- web_contents_controller.rb
- website_controller.rb

### Public API Controllers (ApiPublic::V1)
- auth_controller.rb
- links_controller.rb
- pages_controller.rb
- properties_controller.rb
- select_values_controller.rb
- site_details_controller.rb
- translations_controller.rb
- widgets_controller.rb

### Special Purpose Controllers
- `app/controllers/health_controller.rb`
- `app/controllers/pwb/tls_controller.rb`
- `app/controllers/e2e/test_support_controller.rb`
- `app/controllers/api/signup/signups_controller.rb`

---

**Report Completed**: 2025-12-30
**Next Steps**: Review findings and implement recommendations
