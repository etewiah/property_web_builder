# Central Configuration Module - Implementation Guide

**Status:** Design Documentation  
**Related:** `docs/claude_thoughts/configuration_landscape_analysis.md`

---

## Quick Start: What to Centralize

### High-Priority (Quick Wins)

1. **Currency Options** - Currently hardcoded in template
2. **Site Types** - Currently duplicated across 3 files
3. **User Roles** - Centralize for consistency
4. **Supported Locales** - Add accessor methods to initializer constant
5. **Reserved Subdomains** - Remove duplication

### Medium-Priority (Better Organization)

1. **Property Field Categories** - Consolidate from properties settings controller
2. **Settings Tabs** - Move from settings controller
3. **Email Templates** - Define valid keys in one place
4. **Bypass Environments** - Consolidate from multiple concerns

### Lower-Priority (Refactoring)

1. **Feature Flags** - Could wrap subscription/plan features
2. **Validation Rules** - Consolidate validation logic
3. **Integration Config** - Organize notifier, storage, etc.

---

## Implementation Phases

### Phase 1: Create Core Module (2-4 hours)

**File:** `app/lib/pwb/config.rb`

```ruby
module Pwb
  # Central configuration for PropertyWebBuilder
  # 
  # This module consolidates:
  # - Global feature types and enums
  # - Default values and constants
  # - Configuration validation rules
  # - Access to environment-based settings
  #
  class Config
    # =========================================================================
    # ENTITY TYPES
    # =========================================================================

    # Property listing types
    SITE_TYPES = %w[residential commercial vacation_rental].freeze

    # User role hierarchy (owner > admin > member > viewer)
    USER_ROLES = %w[owner admin member viewer].freeze

    # Property measurement units
    AREA_UNITS = {
      sqmt: { label: 'Square Meters', symbol: 'sqm' },
      sqft: { label: 'Square Feet', symbol: 'sqft' }
    }.freeze

    # =========================================================================
    # LOCALIZATION & LANGUAGE
    # =========================================================================

    # Note: SUPPORTED_LOCALES is defined in config/initializers/i18n_globalise.rb
    # Import it here for centralized access
    #
    # def self.supported_locales
    #   ::SUPPORTED_LOCALES
    # end

    # =========================================================================
    # CURRENCIES
    # =========================================================================

    CURRENCIES = [
      { code: 'USD', label: 'US Dollar', symbol: '$' },
      { code: 'EUR', label: 'Euro', symbol: '€' },
      { code: 'GBP', label: 'British Pound', symbol: '£' },
      { code: 'CHF', label: 'Swiss Franc', symbol: 'CHF' },
      { code: 'CAD', label: 'Canadian Dollar', symbol: '$' },
      { code: 'AUD', label: 'Australian Dollar', symbol: '$' },
      { code: 'JPY', label: 'Japanese Yen', symbol: '¥' },
      { code: 'CNY', label: 'Chinese Yuan', symbol: '¥' },
      { code: 'INR', label: 'Indian Rupee', symbol: '₹' },
      { code: 'BRL', label: 'Brazilian Real', symbol: 'R$' },
      { code: 'MXN', label: 'Mexican Peso', symbol: '$' },
      { code: 'PLN', label: 'Polish Zloty', symbol: 'zł' },
      { code: 'RUB', label: 'Russian Ruble', symbol: '₽' }
    ].freeze

    # =========================================================================
    # VALIDATION CONSTRAINTS
    # =========================================================================

    # Subdomains that cannot be used by tenants (reserved for platform)
    RESERVED_SUBDOMAINS = %w[
      www api admin app mail ftp smtp pop imap
      ns1 ns2 localhost staging test
    ].freeze

    # Environments where feature bypasses are allowed (dev/test only)
    ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

    # Maximum length for subdomain
    SUBDOMAIN_MAX_LENGTH = 63

    # Minimum length for subdomain
    SUBDOMAIN_MIN_LENGTH = 2

    # =========================================================================
    # UI CONFIGURATION
    # =========================================================================

    # Valid tabs in website settings
    WEBSITE_SETTINGS_TABS = %w[general appearance navigation home notifications].freeze

    # Property field categories for customization
    # Maps URL-friendly names to database tags
    PROPERTY_FIELD_CATEGORIES = {
      'property_types' => 'property-types',
      'property_states' => 'property-states',
      'property_features' => 'property-features',
      'property_amenities' => 'property-amenities',
      'property_status' => 'property-status',
      'property_highlights' => 'property-highlights',
      'listing_origin' => 'listing-origin'
    }.freeze

    # Human-readable labels for property field categories
    PROPERTY_FIELD_LABELS = {
      'property_types' => 'Property Types',
      'property_states' => 'Property States',
      'property_features' => 'Features',
      'property_amenities' => 'Amenities',
      'property_status' => 'Status Labels',
      'property_highlights' => 'Highlights',
      'listing_origin' => 'Listing Origin'
    }.freeze

    # Descriptions for property field categories
    PROPERTY_FIELD_DESCRIPTIONS = {
      'property_types' => 'Define what types of properties can be listed (e.g., Apartment, Villa, Office)',
      'property_states' => 'Define physical condition options (e.g., New Build, Needs Renovation)',
      'property_features' => 'Define permanent physical attributes (e.g., Pool, Garden, Terrace)',
      'property_amenities' => 'Define equipment and services (e.g., Air Conditioning, Heating, Elevator)',
      'property_status' => 'Define transaction status labels (e.g., Sold, Reserved, Under Offer)',
      'property_highlights' => 'Define marketing highlight labels (e.g., Featured, Luxury, Price Reduced)',
      'listing_origin' => 'Define listing source options (e.g., Direct Entry, MLS Feed, Partner)'
    }.freeze

    # Valid email template keys
    EMAIL_TEMPLATE_KEYS = %w[enquiry.general enquiry.property].freeze

    # =========================================================================
    # ENVIRONMENT-BASED CONFIGURATION
    # =========================================================================

    # Platform domains where subdomains route to tenants
    # Loaded from PLATFORM_DOMAINS env var
    #
    # @return [Array<String>] List of platform domain suffixes
    #
    def self.platform_domains
      @platform_domains ||= ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost')
        .split(',')
        .map(&:strip)
    end

    # Reset cached platform domains (useful for testing)
    def self.reset_platform_domains!
      @platform_domains = nil
    end

    # Base domain for generating URLs in emails
    #
    # @return [String] Domain for links
    #
    def self.base_domain
      @base_domain ||= ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
    end

    def self.reset_base_domain!
      @base_domain = nil
    end

    # Email verification token expiry in days
    #
    # @return [Integer] Number of days until token expires
    #
    def self.email_verification_expiry_days
      @email_expiry_days ||= ENV.fetch('EMAIL_VERIFICATION_EXPIRY_DAYS', '7').to_i
    end

    def self.reset_email_verification_expiry!
      @email_expiry_days = nil
    end

    # Firebase project ID for authentication
    #
    # @return [String, nil] Firebase project ID or nil if not configured
    #
    def self.firebase_project_id
      ENV['FIREBASE_PROJECT_ID']
    end

    # Comma-separated list of emails with tenant admin access
    #
    # @return [Array<String>] List of admin emails
    #
    def self.tenant_admin_emails
      @tenant_admin_emails ||= ENV.fetch('TENANT_ADMIN_EMAILS', '')
        .split(',')
        .map(&:strip)
        .reject(&:blank?)
    end

    def self.reset_tenant_admin_emails!
      @tenant_admin_emails = nil
    end

    # Check if authentication bypass is enabled (dev/test only)
    #
    # @return [Boolean] true if bypass allowed and env var set
    #
    def self.bypass_authentication_enabled?
      ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env) &&
        (ENV['BYPASS_API_AUTH'] == 'true' || ENV['BYPASS_ADMIN_AUTH'] == 'true')
    end

    # Check if admin auth bypass is enabled (dev/test only)
    #
    # @return [Boolean] true if admin bypass allowed and env var set
    #
    def self.bypass_admin_auth_enabled?
      ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env) &&
        ENV['BYPASS_ADMIN_AUTH'] == 'true'
    end

    # =========================================================================
    # HELPER METHODS
    # =========================================================================

    # Get currency options for select dropdowns
    #
    # @return [Array<Array>] Array of [label, code] pairs
    #
    def self.currency_options
      CURRENCIES.map { |c| ["#{c[:label]} (#{c[:code]})", c[:code]] }
    end

    # Get currency by code
    #
    # @param code [String] Currency code (e.g., 'USD')
    # @return [Hash, nil] Currency object or nil if not found
    #
    def self.find_currency(code)
      CURRENCIES.find { |c| c[:code] == code }
    end

    # Get area unit options for select dropdowns
    #
    # @return [Array<Array>] Array of [label, key] pairs
    #
    def self.area_unit_options
      AREA_UNITS.map { |key, data| [data[:label], key.to_s] }
    end

    # Check if a role is valid
    #
    # @param role [String] Role to validate
    # @return [Boolean]
    #
    def self.valid_role?(role)
      USER_ROLES.include?(role)
    end

    # Check if a site type is valid
    #
    # @param site_type [String] Site type to validate
    # @return [Boolean]
    #
    def self.valid_site_type?(site_type)
      SITE_TYPES.include?(site_type)
    end

    # Check if a subdomain is reserved
    #
    # @param subdomain [String] Subdomain to check
    # @return [Boolean]
    #
    def self.reserved_subdomain?(subdomain)
      RESERVED_SUBDOMAINS.include?(subdomain.downcase)
    end

    # Get property field category tag
    #
    # @param category_key [String] URL-friendly category key
    # @return [String] Database tag for category
    #
    def self.property_field_tag(category_key)
      PROPERTY_FIELD_CATEGORIES[category_key]
    end

    # Get all property field categories as select options
    #
    # @return [Hash] Category key => label mapping
    #
    def self.property_field_options
      PROPERTY_FIELD_LABELS
    end

    # Validate website settings tab
    #
    # @param tab [String] Tab name
    # @return [Boolean]
    #
    def self.valid_settings_tab?(tab)
      WEBSITE_SETTINGS_TABS.include?(tab)
    end

    # Validate email template key
    #
    # @param key [String] Template key
    # @return [Boolean]
    #
    def self.valid_email_template_key?(key)
      EMAIL_TEMPLATE_KEYS.include?(key)
    end
  end
end
```

**Tests:** `spec/lib/pwb/config_spec.rb`

```ruby
require 'spec_helper'

RSpec.describe Pwb::Config do
  describe 'constants' do
    it { expect(described_class::SITE_TYPES).to be_a(Array) }
    it { expect(described_class::USER_ROLES).to be_a(Array) }
    it { expect(described_class::CURRENCIES).to be_a(Array) }
    it { expect(described_class::RESERVED_SUBDOMAINS).to be_a(Array) }
  end

  describe '.platform_domains' do
    it 'returns array of platform domains' do
      expect(described_class.platform_domains).to be_a(Array)
      expect(described_class.platform_domains).to include('propertywebbuilder.com')
    end

    it 'can be reset for testing' do
      original = described_class.platform_domains
      described_class.reset_platform_domains!
      expect(described_class.platform_domains).to eq(original)
    end
  end

  describe '.currency_options' do
    it 'returns select-friendly array' do
      options = described_class.currency_options
      expect(options).to be_a(Array)
      expect(options.first).to be_a(Array)
      expect(options.first.length).to eq(2)
    end
  end

  describe '.valid_role?' do
    it 'validates roles' do
      expect(described_class.valid_role?('owner')).to be true
      expect(described_class.valid_role?('invalid')).to be false
    end
  end
end
```

---

### Phase 2: Update High-Impact Areas (4-6 hours)

#### 2a. Update Settings Template

**File:** `app/views/site_admin/website/settings/_general_tab.html.erb`

Replace hardcoded currency list with:

```erb
<!-- Default Currency -->
<div>
  <label for="default_currency" class="block text-sm font-medium text-gray-700 mb-1">
    Default Currency
  </label>
  <%= f.select :default_currency,
      options_for_select(Pwb::Config.currency_options, @website.default_currency),
      {},
      class: "w-full px-4 py-2 border border-gray-300 rounded-lg" %>
</div>

<!-- Default Area Unit -->
<div>
  <label for="default_area_unit" class="block text-sm font-medium text-gray-700 mb-1">
    Default Area Unit
  </label>
  <%= f.select :default_area_unit,
      options_for_select(Pwb::Config.area_unit_options, @website.default_area_unit),
      {},
      class: "w-full px-4 py-2 border border-gray-300 rounded-lg" %>
</div>
```

**Benefits:**
- Currency list now centralized
- Adding new currencies is one-file change
- Can be I18n'd easily

#### 2b. Update Properties Settings Controller

**File:** `app/controllers/site_admin/properties/settings_controller.rb`

Replace inline constants:

```ruby
module SiteAdmin
  module Properties
    class SettingsController < ::SiteAdminController
      # Use centralized config instead of inline constants
      VALID_CATEGORIES = Pwb::Config::PROPERTY_FIELD_CATEGORIES
      CATEGORY_LABELS = Pwb::Config::PROPERTY_FIELD_LABELS
      CATEGORY_DESCRIPTIONS = Pwb::Config::PROPERTY_FIELD_DESCRIPTIONS

      # ... rest of controller
    end
  end
end
```

#### 2c. Update Website Settings Controller

**File:** `app/controllers/site_admin/website/settings_controller.rb`

```ruby
module SiteAdmin
  module Website
    class SettingsController < ::SiteAdminController
      VALID_TABS = Pwb::Config::WEBSITE_SETTINGS_TABS

      # ... rest of controller
    end
  end
end
```

---

### Phase 3: Deprecate Old Patterns (2 hours)

Add deprecation warnings to old locations:

**File:** `app/models/pwb/website.rb`

```ruby
module Pwb
  class Website < ApplicationRecord
    # DEPRECATED: Use Pwb::Config::SITE_TYPES instead
    SITE_TYPES = %w[residential commercial vacation_rental].freeze

    # Add before_validation callback
    before_validation :_warn_old_site_types_usage, if: -> { site_type.present? }

    private

    def _warn_old_site_types_usage
      unless Pwb::Config.valid_site_type?(site_type)
        Rails.logger.warn(
          "[DEPRECATION] Direct SITE_TYPES constant check found. " \
          "Use Pwb::Config.valid_site_type? instead"
        )
      end
    end
  end
end
```

---

### Phase 4: Update Remaining References (3-4 hours)

Update all other files that reference old constants:

**Example Updates:**
1. `app/models/pwb/user_membership.rb` → Reference `Pwb::Config::USER_ROLES`
2. `app/controllers/pwb/application_api_controller.rb` → Reference `Pwb::Config.bypass_authentication_enabled?`
3. `app/controllers/concerns/admin_auth_bypass.rb` → Reference `Pwb::Config.bypass_admin_auth_enabled?`
4. `app/services/pwb/provisioning_service.rb` → Reference `Pwb::Config.valid_site_type?`

---

## Testing Strategy

### Unit Tests for Config Module

```ruby
# spec/lib/pwb/config_spec.rb
RSpec.describe Pwb::Config do
  describe 'constants are frozen' do
    it { expect(Pwb::Config::SITE_TYPES).to be_frozen }
    it { expect(Pwb::Config::USER_ROLES).to be_frozen }
    it { expect(Pwb::Config::CURRENCIES).to be_frozen }
  end

  describe 'helper methods' do
    describe '#currency_options' do
      it 'returns select-compatible format' do
        options = Pwb::Config.currency_options
        expect(options).to all(be_an(Array))
      end
    end

    describe '#valid_site_type?' do
      it 'validates site types' do
        expect(Pwb::Config.valid_site_type?('residential')).to be true
        expect(Pwb::Config.valid_site_type?('invalid')).to be false
      end
    end
  end

  describe 'environment-based config' do
    describe '#platform_domains' do
      before do
        Pwb::Config.reset_platform_domains!
      end

      it 'respects PLATFORM_DOMAINS env var' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('PLATFORM_DOMAINS', anything).and_return('test.local')

        domains = Pwb::Config.platform_domains
        expect(domains).to include('test.local')
      end
    end
  end
end
```

### Integration Tests

Update existing tests to use config:

```ruby
# Before
describe 'user roles' do
  let(:roles) { Pwb::UserMembership::ROLES }
  
  it 'validates role' do
    expect(roles).to include('owner')
  end
end

# After
describe 'user roles' do
  it 'uses centralized config' do
    expect(Pwb::Config::USER_ROLES).to include('owner')
  end
end
```

### Test Helpers

Create test helpers for mocking config:

```ruby
# spec/support/config_helpers.rb
module ConfigHelpers
  def with_platform_domains(domains)
    original = Pwb::Config.platform_domains
    Pwb::Config.reset_platform_domains!
    
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch)
      .with('PLATFORM_DOMAINS', anything)
      .and_return(domains.join(','))

    yield

    Pwb::Config.reset_platform_domains!
  end

  def with_bypass_auth_enabled
    allow(Rails).to receive(:env).and_return(double(development?: true))
    allow(ENV).to receive(:[]).with('BYPASS_API_AUTH').and_return('true')
    
    yield
  end
end

RSpec.configure do |config|
  config.include ConfigHelpers
end
```

Usage:

```ruby
it 'finds tenant by custom domain' do
  with_platform_domains(['myplatform.com']) do
    website = Website.find_by_host('mysite.com')
    expect(website).to be_present
  end
end
```

---

## Migration Checklist

- [ ] Create `app/lib/pwb/config.rb` with Phase 1 structure
- [ ] Write comprehensive tests for Config module
- [ ] Update currency selector template
- [ ] Update property settings controller
- [ ] Update website settings controller
- [ ] Update signup controller to use `Pwb::Config.site_types`
- [ ] Update provisioning service to use `Pwb::Config.valid_site_type?`
- [ ] Update user membership references to `Pwb::Config::USER_ROLES`
- [ ] Update application controller references to `Pwb::Config`
- [ ] Update concern files to use Config helpers
- [ ] Add deprecation warnings to old constant locations
- [ ] Update all tests to reference Config
- [ ] Update documentation
- [ ] Remove old constants after deprecation period
- [ ] Run full test suite
- [ ] Code review and QA

---

## Benefits Checklist

After migration, verify:
- [ ] Single place to find all configuration
- [ ] No duplicate constant definitions
- [ ] Easier to add new options (currencies, site types, etc.)
- [ ] Better test mocking capability
- [ ] Cleaner controller code
- [ ] Better documentation of available options
- [ ] Easier to extend with validation methods
- [ ] Consistent access patterns throughout app

---

## Potential Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking existing code | Use deprecation warnings, maintain backward compatibility initially |
| Missing a reference location | grep for old constant names before cleanup |
| Circular dependencies | Keep Config module simple, no complex dependencies |
| Performance impact | Constants are frozen, access is O(1), minimal impact |
| ENV variable caching issues in tests | Provide reset methods for all cached ENV values |

---

## Documentation Updates Needed

1. **Update CLAUDE.md** - Add Config module to development guidelines
2. **Create docs/architecture/configuration.md** - Architecture overview
3. **Add inline comments** to Config class explaining each section
4. **Update README** - Configuration reference section
5. **Add to developer onboarding** - Where configuration lives

---

## Long-Term Improvements

### Future Enhancements

1. **Dynamic Feature Flags**
   ```ruby
   Pwb::Config.feature_enabled?(:advanced_search, for_website: website)
   ```

2. **Tenant-Specific Configuration Overrides**
   ```ruby
   Pwb::Config.for_website(website).supported_currencies
   ```

3. **Configuration Validation at Startup**
   ```ruby
   Pwb::Config.validate! # Ensure all required ENV vars set
   ```

4. **Admin UI for Configuration**
   - Allow admins to customize some constants
   - Store customizations in database
   - Cache efficiently

5. **Configuration Documentation Generator**
   - Auto-generate config reference from Code
   - Include descriptions and validation rules

---

## Related Documentation

- `docs/claude_thoughts/configuration_landscape_analysis.md` - Full analysis
- `docs/architecture/` - Other architecture decisions
- Project README - Configuration section

