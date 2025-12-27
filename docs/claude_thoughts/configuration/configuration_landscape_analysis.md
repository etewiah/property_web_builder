# PropertyWebBuilder Configuration Landscape Analysis

**Date:** December 2024  
**Objective:** Understand current configuration sources, identify pain points, and evaluate the need for a central configuration module.

---

## Executive Summary

PropertyWebBuilder has **fragmented configuration** spread across multiple sources:
- **Environment variables** (platform-level settings)
- **Rails initializers** (application-wide defaults)
- **Database attributes** on Website model (tenant-specific settings)
- **Hardcoded constants** in controllers and models (validation lists, feature flags)
- **View templates** (inline configuration options for user selection)

**Key Finding:** There is **significant duplication and inconsistency** in how configuration is defined and accessed. A central configuration module would provide substantial benefits in terms of maintainability, discoverability, and consistency.

---

## 1. Current Configuration Sources

### 1.1 Environment Variables (Platform-Level, Global)

**File:** Scattered throughout codebase  
**Access Pattern:** `ENV['KEY']` or `ENV.fetch('KEY', default)`

#### Critical ENV Variables:

| Variable | Purpose | Used In | Current Pattern |
|----------|---------|---------|-----------------|
| `PLATFORM_DOMAINS` | List of platform domains for subdomain routing | Website model, tenant_domains.rb | `ENV.fetch('PLATFORM_DOMAINS', '...')` |
| `EMAIL_VERIFICATION_EXPIRY_DAYS` | Token expiry duration | Website model | Constant defined in model |
| `BASE_DOMAIN` | Domain for email verification links | SignupController, EmailVerificationMailer | `ENV.fetch('BASE_DOMAIN', '...')` |
| `FIREBASE_PROJECT_ID` | Firebase project identifier | FirebaseTokenVerifier | `ENV['FIREBASE_PROJECT_ID']` |
| `BYPASS_API_AUTH` | Dev/test auth bypass | ApplicationApiController | `ENV['BYPASS_API_AUTH'] == 'true'` |
| `BYPASS_ADMIN_AUTH` | Dev/test admin bypass | AdminAuthBypass concern | `ENV['BYPASS_ADMIN_AUTH'] == 'true'` |
| `TENANT_ADMIN_EMAILS` | Comma-separated admin emails | TenantAdminController | `ENV.fetch('TENANT_ADMIN_EMAILS', '')` |
| `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Email delivery config | environments/production.rb | `ENV["SMTP_ADDRESS"]` |
| `AWS_SES_ACCESS_KEY_ID`, `AWS_SES_SECRET_ACCESS_KEY` | AWS SES credentials | amazon_ses.rb initializer | `ENV["AWS_SES_ACCESS_KEY_ID"]` |
| `HEALTH_CHECK_ALLOWED_IPS` | IP whitelist for health checks | HealthController | `ENV.fetch('HEALTH_CHECK_ALLOWED_IPS', '127.0.0.1,::1')` |
| `RAILS_ENV`, `APP_VERSION`, `GIT_COMMIT` | App metadata | HealthController | Various patterns |
| `R2_SEED_IMAGES_BUCKET`, `SEED_IMAGES_BASE_URL` | Image storage config | PagePartManager | `ENV['R2_SEED_IMAGES_BUCKET']` |

**Observation:** Multiple inconsistent access patterns:
- `ENV['KEY']` (raw bracket syntax, risky)
- `ENV.fetch('KEY', default)` (safe with fallback)
- Mixed usage within same file

**Files with ENV Usage:**
- `/app/models/pwb/website.rb` - Email verification expiry, platform domains
- `/app/models/pwb/page.rb` - RAILS_ENV check
- `/app/mailers/pwb/email_verification_mailer.rb` - BASE_DOMAIN
- `/app/mailers/pwb/application_mailer.rb` - DEFAULT_FROM_EMAIL
- `/app/controllers/health_controller.rb` - Multiple config values
- `/app/controllers/pwb/application_api_controller.rb` - BYPASS_API_AUTH
- `/app/services/pwb/firebase_token_verifier.rb` - FIREBASE_PROJECT_ID
- `/config/initializers/*.rb` - Various configurations

---

### 1.2 Rails Initializers (Application-Wide Defaults)

**Files:**
- `config/initializers/i18n_globalise.rb`
- `config/initializers/money.rb`
- `config/initializers/tenant_domains.rb`
- `config/initializers/page_part_definitions.rb`

#### Language Support (`i18n_globalise.rb`)

**Constant:** `SUPPORTED_LOCALES`
```ruby
SUPPORTED_LOCALES = {
  en: 'English',
  es: 'Spanish',
  de: 'German',
  fr: 'French',
  nl: 'Dutch',
  pt: 'Portuguese',
  it: 'Italian'
}.freeze
```

**Access Pattern:** Direct constant reference throughout views and controllers

**Usage Locations:**
- `app/views/site_admin/website/settings/_general_tab.html.erb` - Language selector UI
- `app/controllers/site_admin/website/settings_controller.rb` - Validation logic
- `app/controllers/site_admin/properties/settings_controller.rb` - Locale building

#### Currency Configuration (`money.rb`)

```ruby
MoneyRails.configure do |config|
  config.default_currency = :eur
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
end
```

**Usage:** Hardcoded in initializer, not easily customizable per-tenant

#### Platform Domain Configuration (`tenant_domains.rb`)

```ruby
Rails.application.config.tenant_domains = {
  platform_domains: ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com')
    .split(',').map(&:strip),
  allow_unverified_domains: ENV.fetch('ALLOW_UNVERIFIED_DOMAINS', 'false') == 'true' ||
                            Rails.env.development? ||
                            Rails.env.test?,
  verification_prefix: '_pwb-verification',
  platform_ip: ENV.fetch('PLATFORM_IP', nil)
}
```

**Access Pattern:** `Rails.application.config.tenant_domains`

---

### 1.3 Database-Stored Settings (Tenant-Specific, Per Website)

**Model:** `Pwb::Website` (attributes stored in database)

#### Website Configuration Attributes:

| Attribute | Type | Purpose | Default |
|-----------|------|---------|---------|
| `company_display_name` | String | Organization name | None |
| `theme_name` | String | Selected theme | None |
| `default_client_locale` | String | Default language | `"en-UK"` |
| `supported_locales` | Array (JSON) | Enabled languages | `['en']` |
| `default_currency` | String | Default currency code | None |
| `available_currencies` | Array (JSON) | Available currencies | None |
| `default_area_unit` | Enum (0/1) | sqmt or sqft | None |
| `raw_css` | Text | Custom CSS | None |
| `analytics_id` | String | Analytics tracking ID | None |
| `analytics_id_type` | String | GA4 or UA | None |
| `configuration` | JSON | Generic config storage | Empty hash |
| `social_media` | JSON | Social media links | Empty hash |
| `style_variables_for_theme` | JSON | Theme customization | Default styles |
| `subdomain` | String | Platform subdomain | None |
| `custom_domain` | String | Custom domain | None |
| `external_image_mode` | Boolean | Allow external image URLs | false |
| `ntfy_enabled` | Boolean | Notification system | false |
| `ntfy_server_url`, `ntfy_topic_prefix`, etc. | Strings | Notification config | None |

**Access Pattern:** Direct attribute access on Website instance
```ruby
@website.default_currency
@website.supported_locales
website.style_variables
```

**Note:** The `configuration` column appears to be a catch-all for miscellaneous settings:
```ruby
def admin_page_links
  if configuration["admin_page_links"].present?
    configuration["admin_page_links"]
  else
    update_admin_page_links
  end
end
```

---

### 1.4 Hardcoded Constants (Various Locations)

**Pattern:** Frozen arrays and hashes defined in controllers/models

#### Constants by File:

**Website Model:**
```ruby
SITE_TYPES = %w[residential commercial vacation_rental].freeze
RESERVED_SUBDOMAINS = %w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test].freeze
EMAIL_VERIFICATION_EXPIRY = ENV.fetch('EMAIL_VERIFICATION_EXPIRY_DAYS', '7').to_i.days
```

**UserMembership Model:**
```ruby
ROLES = %w[owner admin member viewer].freeze
```

**Application API Controller:**
```ruby
ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze
```

**Website Settings Controller:**
```ruby
VALID_TABS = %w[general appearance navigation home notifications].freeze
```

**Properties Settings Controller:**
```ruby
VALID_CATEGORIES = {
  'property_types' => 'property-types',
  'property_states' => 'property-states',
  'property_features' => 'property-features',
  'property_amenities' => 'property-amenities',
  'property_status' => 'property-status',
  'property_highlights' => 'property-highlights',
  'listing_origin' => 'listing-origin'
}.freeze

CATEGORY_LABELS = {
  'property_types' => 'Property Types',
  'property_states' => 'Property States',
  # ... etc
}.freeze

CATEGORY_DESCRIPTIONS = { ... }.freeze
```

**Liquid Tag Validators:**
```ruby
VALID_STYLES = %w[default compact inline sidebar].freeze      # ContactFormTag
VALID_TYPES = %w[sale rent all].freeze                        # FeaturedPropertiesTag
VALID_STYLES = %w[default compact card grid].freeze           # FeaturedPropertiesTag
```

**Email Template Validator:**
```ruby
ALLOWED_TEMPLATE_KEYS = %w[enquiry.general enquiry.property].freeze
```

---

### 1.5 Hardcoded Values in View Templates

**Pattern:** Configuration options hardcoded in ERB templates

**File:** `app/views/site_admin/website/settings/_general_tab.html.erb`

```erb
<%= f.select :default_currency,
    options_for_select([
      ['USD - US Dollar', 'USD'],
      ['EUR - Euro', 'EUR'],
      ['GBP - British Pound', 'GBP'],
      ['CHF - Swiss Franc', 'CHF'],
      ['CAD - Canadian Dollar', 'CAD'],
      ['AUD - Australian Dollar', 'AUD'],
      ['JPY - Japanese Yen', 'JPY'],
      ['CNY - Chinese Yuan', 'CNY'],
      ['INR - Indian Rupee', 'INR'],
      ['BRL - Brazilian Real', 'BRL'],
      ['MXN - Mexican Peso', 'MXN'],
      ['PLN - Polish Zloty', 'PLN'],
      ['RUB - Russian Ruble', 'RUB']
    ], @website.default_currency) %>

<%= f.select :default_area_unit,
    options_for_select([
      ['Square Meters (sqm)', 'sqmt'],
      ['Square Feet (sqft)', 'sqft']
    ], @website.default_area_unit) %>
```

**Issues:**
1. Currency list hardcoded in template (13 currencies)
2. Cannot easily extend without template modification
3. Labels duplicated if used elsewhere
4. No I18n/translation for labels

---

## 2. Configuration Patterns Analysis

### 2.1 Duplication Identified

| Configuration | Location 1 | Location 2 | Location 3 | Issue |
|---|---|---|---|---|
| Platform domains | ENV variable | Website model | tenant_domains.rb | Accessed 3 ways |
| Supported locales | i18n_globalise.rb constant | Website DB attribute | Settings controller | Duplicated in code |
| Reserved subdomains | Website::RESERVED_SUBDOMAINS | ApplicationController::RESERVED_SUBDOMAINS | Both defined identically | Duplicate definitions |
| Email verification expiry | ENV variable → Model constant | Not accessible via config | Hardcoded in one place | Inconsistent access |
| Currency options | HTML template | No centralized list | Hardcoded inline | Repeated if used elsewhere |
| Property categories | Properties::SettingsController | Validators | Models | Spread across files |
| Role types | UserMembership constant | Nowhere else (good) | - | Isolated OK |
| Site types | Website model | SignupController reference | ProvisioningService | Referenced but not centralized |
| Area units | Enum in Website | Enum in Prop | Hardcoded in template | Duplicated enums |

### 2.2 Inconsistent Access Patterns

**Pattern 1: ENV Variables with Fetch**
```ruby
ENV.fetch('EMAIL_VERIFICATION_EXPIRY_DAYS', '7').to_i.days
ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost').split(',')
```

**Pattern 2: Direct ENV Bracket Access**
```ruby
ENV['BYPASS_API_AUTH'] == 'true'
ENV['RAILS_ENV']
ENV['FIREBASE_PROJECT_ID']
```

**Pattern 3: Rails Config Object**
```ruby
Rails.application.config.tenant_domains[:platform_domains]
```

**Pattern 4: Constants**
```ruby
Website::SITE_TYPES
UserMembership::ROLES
SUPPORTED_LOCALES[:en]
```

**Pattern 5: Database Attributes**
```ruby
@website.default_currency
website.supported_locales
```

**Pattern 6: JSON Configuration Hash**
```ruby
configuration["admin_page_links"]
```

**Pattern 7: Hardcoded in Templates**
```erb
<%= f.select :default_currency, options_for_select([...hardcoded list...]) %>
```

---

### 2.3 Missing Patterns

**What's NOT Centralized:**

1. **Validation Rules** - Field validation lists scattered in controllers
2. **Feature Flags** - No central feature flag system (only DB attributes like `landing_hide_*`)
3. **UI Configuration** - Settings tabs, form fields defined in controllers
4. **Integration Settings** - Notification config (ntfy) mixed with other settings
5. **Limits & Quotas** - Property limits in Subscription/Plan models, no single source
6. **Security Settings** - Bypass environments, allowed IPs scattered

---

## 3. Pain Points Identified

### 3.1 Discoverability Issues

**Problem:** Finding where a configuration is defined requires searching multiple locations.

**Examples:**
- Where is the list of supported currencies defined? **Template** (hardcoded)
- Where are platform domains configured? **ENV variable** (with fallback in model)
- What are valid site types? **Website model constant**
- What property categories exist? **Properties settings controller**

**Impact:** New developers spend time searching; prone to missing updates.

---

### 3.2 Duplication & Maintenance Burden

**Problem:** Same configuration defined in multiple places.

**Examples:**
- `RESERVED_SUBDOMAINS` defined in both:
  - `Pwb::Website` (12 items)
  - `Pwb::ApplicationController` (3 items)
  - These might diverge over time

- `SITE_TYPES` referenced in:
  - `Website model` (definition)
  - `SignupController` (display)
  - `ProvisioningService` (validation)
  - If new type added, all 3 must change

- Supported locales in:
  - `i18n_globalise.rb` (7 languages)
  - `Website.supported_locales` (custom per-site)
  - `Settings controller` (validation)
  - View template (selector UI)

---

### 3.3 Environment-Specific Configuration Issues

**Problem:** ENV variables not validated at startup; values scattered.

**Examples:**
- `PLATFORM_DOMAINS` used in:
  - `Website.platform_domains` (ENV.fetch with fallback)
  - `Website.find_by_host` (lookup)
  - `tenant_domains.rb` (Rails config)
  - If ENV not set, different fallbacks apply

- `BYPASS_API_AUTH` checked via `ENV['BYPASS_API_AUTH'] == 'true'`
  - No validation that it's a boolean-like value
  - No single place showing all bypass-able features

---

### 3.4 Hard to Extend

**Problem:** Adding new options requires touching multiple files.

**Example - Adding a new currency:**
1. Update HTML template hardcoded list
2. If used elsewhere, update that code too
3. No single file showing all supported currencies

**Example - Adding a new site type:**
1. Update `Website::SITE_TYPES`
2. Update `ProvisioningService` validation
3. Update `SignupController` display logic
4. Update any forms/selectors using it

---

### 3.5 Testing & Consistency Issues

**Problem:** Hard to override configuration in tests without side effects.

**Example:** To test with different `PLATFORM_DOMAINS`:
```ruby
# Current approach:
ENV['PLATFORM_DOMAINS'] = 'test.local'
# But Website.platform_domains is called during initialization...
```

**Missing:** No clear way to test configuration without ENV mutation.

---

## 4. Recommendation: Centralization is BENEFICIAL

### 4.1 What Should Be Centralized?

**YES - Centralize:**

1. **Feature Lists** (enums, static lists)
   - Site types (residential, commercial, vacation_rental)
   - Roles (owner, admin, member, viewer)
   - User membership statuses
   - Area units (sqmt, sqft)
   - Currency codes
   - Supported locales
   - Property field categories & tags
   - Email template keys

2. **Global Constants & Validations**
   - Reserved subdomains
   - Allowed bypass environments
   - Valid settings tabs
   - Health check IP allowlist format

3. **Feature Flags & Limits**
   - Bypass authentication conditions
   - Feature availability rules
   - Quota limits (consolidated from Subscription/Plan)

4. **Default Values**
   - Default currency (currently in money.rb)
   - Default locale (currently in Website model)
   - Default area unit
   - Email verification expiry

**MAYBE - Consider Centralizing:**

1. **Tenant-Specific Settings** (currently in Website DB model)
   - Could create a `Website::Configuration` wrapper for better organization
   - But these are properly scoped and changed via settings UI

2. **Integration Credentials** (currently mixed in Website attributes)
   - These are properly encrypted and scoped per-tenant
   - Could use better organization with a `Website::Integrations` module

**NO - Don't Centralize:**

1. **Per-Website Database Attributes** - Properly scoped already
2. **Infrastructure Config** (SMTP, AWS, etc.) - Belongs in ENV/credentials
3. **External API Credentials** - Should stay in encrypted storage

---

### 4.2 Proposed Central Configuration Module

**Location:** `app/lib/pwb/config.rb` (or `app/config/configuration.rb`)

**Structure:**

```ruby
module Pwb
  class Config
    # Feature/Entity Types
    SITE_TYPES = %w[residential commercial vacation_rental].freeze
    USER_ROLES = %w[owner admin member viewer].freeze
    AREA_UNITS = %w[sqmt sqft].freeze

    # Locales (sourced from i18n_globalise.rb)
    SUPPORTED_LOCALES = SUPPORTED_LOCALES # Reference from initializer

    # Currencies
    CURRENCIES = [
      { code: 'USD', label: 'US Dollar' },
      { code: 'EUR', label: 'Euro' },
      { code: 'GBP', label: 'British Pound' },
      # ... more currencies
    ].freeze

    # Validation Rules
    RESERVED_SUBDOMAINS = %w[www api admin ...].freeze
    ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

    # Settings/UI Organization
    WEBSITE_SETTINGS_TABS = %w[general appearance navigation home notifications].freeze
    PROPERTY_FIELD_CATEGORIES = {
      'property_types' => 'property-types',
      'property_states' => 'property-states',
      # ... etc
    }.freeze

    # Class Methods for Access
    def self.site_types
      SITE_TYPES
    end

    def self.currencies
      CURRENCIES
    end

    def self.platform_domains
      ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com')
        .split(',').map(&:strip)
    end

    # ... etc
  end
end
```

---

### 4.3 Benefits of Centralization

| Benefit | Impact |
|---------|--------|
| **Single Source of Truth** | When adding "villa" to site types, update one place |
| **Better Discoverability** | `Pwb::Config.site_types` vs searching codebase |
| **Easier Testing** | `allow(Pwb::Config).to receive(:currencies).and_return([...])` |
| **Cleaner Controllers** | Remove inline constant definitions |
| **Easier Documentation** | Single file showing all global configuration |
| **Better Validation** | Centralized validation rules |
| **Consistent Access** | `Pwb::Config::SITE_TYPES` vs `Website::SITE_TYPES` vs `SITE_TYPES` constant |
| **Supports i18n** | Can build label maps for UI easily |
| **Easier Auditing** | Track what's configurable vs what's hardcoded |
| **Cleaner Views** | Can use `Pwb::Config.currency_options` instead of hardcoded list |

---

### 4.4 Migration Path

**Phase 1: Create Central Config Module**
- Extract constants to `app/lib/pwb/config.rb`
- Add accessors for ENV-based values
- Ensure backward compatibility with existing code

**Phase 2: Update High-Impact Areas**
- Update templates to use `Pwb::Config.currency_list`
- Update controllers to reference `Pwb::Config`
- Update tests to mock configuration

**Phase 3: Deprecate Old Patterns**
- Mark old constant locations as deprecated
- Add warnings for direct constant access
- Update documentation

**Phase 4: Full Migration**
- Remove old constants after deprecation period
- Update all references
- Full test coverage

---

## 5. Current State Summary

### 5.1 Configuration by Type

```
Platform-Level (Global):
├── Environment Variables (scattered)
├── Rails Initializers (i18n, money, tenant_domains)
├── Hardcoded Constants (multiple files)
└── Application Config Object

Tenant-Level (Per Website):
├── Database Attributes (Website model)
├── Configuration JSON column (catch-all)
└── Integration Credentials (ntfy, etc.)

Feature Flags:
├── Boolean attributes (landing_hide_*, external_image_mode)
├── ENV-based bypasses (BYPASS_API_AUTH)
└── Plan-based features (has_feature?)

UI/Validation:
├── Controller Constants (VALID_CATEGORIES, VALID_TABS)
├── Hardcoded in Templates (currency selector)
├── Model Constants (SITE_TYPES, ROLES)
└── Inline validators (in properties settings)
```

### 5.2 Scatteredness Score

**Overall Configuration Scatteredness: 7/10** (High fragmentation)

- **Environment Variables:** 4/10 (scattered but manageable)
- **Constants:** 8/10 (multiple redundant definitions)
- **Database Settings:** 5/10 (reasonably organized in Website model)
- **Validation Rules:** 7/10 (spread across multiple controllers)
- **UI Configuration:** 8/10 (inline in templates and controllers)

---

## 6. Next Steps

### Recommended Actions

1. **Immediate (Low Risk):**
   - Document current configuration in central location
   - Identify all configuration sources
   - Create mapping of what's used where

2. **Short Term (Medium Effort):**
   - Create `Pwb::Config` module structure
   - Migrate high-duplication constants first (site types, roles, currencies)
   - Update one area (settings UI) as proof of concept

3. **Medium Term (Larger Effort):**
   - Full migration of all global constants
   - Update tests to use configuration mocks
   - Update documentation

4. **Long Term (Architectural):**
   - Consider tenant-specific configuration overrides
   - Consider feature flag library integration
   - Consider environment validation at startup

---

## Appendix A: File Reference Guide

### Configuration Source Files

| File | Configuration | Type | Status |
|------|---|---|---|
| `config/initializers/i18n_globalise.rb` | Supported locales | Global constant | Active |
| `config/initializers/money.rb` | Currency/rounding | Gem configuration | Active |
| `config/initializers/tenant_domains.rb` | Platform domains | Rails config + ENV | Active |
| `app/models/pwb/website.rb` | Site types, reserved subdomains, email expiry | Model constants + ENV | Active |
| `app/models/pwb/user_membership.rb` | Roles | Model constant | Active |
| `app/controllers/site_admin/website/settings_controller.rb` | Settings tabs | Controller constant | Active |
| `app/controllers/site_admin/properties/settings_controller.rb` | Property categories, labels | Controller constants | Active |
| `app/views/site_admin/website/settings/_general_tab.html.erb` | Currency list | Hardcoded in template | Active |
| `app/controllers/pwb/application_api_controller.rb` | Bypass environments | Controller constant | Active |
| `app/controllers/concerns/admin_auth_bypass.rb` | Bypass environments | Concern constant | Active |
| Various service files | Feature-specific config | Scattered | Active |

---

## Conclusion

**YES, a centralized configuration module would be beneficial.** The current fragmented approach creates:
- Maintenance burden through duplication
- Discoverability challenges
- Inconsistent access patterns
- Difficulty extending features

A central `Pwb::Config` module would improve code organization, testability, and developer experience while requiring modest implementation effort with a clear migration path.
