# Integrations System Roadmap

This document details the next phases for expanding the integrations system beyond the current AI providers.

## Table of Contents

1. [Phase 4: Additional Providers](#phase-4-additional-providers)
2. [Phase 5: Migration from ENV-based Configs](#phase-5-migration-from-env-based-configs)
3. [Phase 6: Usage Analytics](#phase-6-usage-analytics)
4. [Phase 7: Audit Logging](#phase-7-audit-logging)

---

## Phase 4: Additional Providers

### Overview

Expand the integrations system to support CRM, Maps, Email Marketing, and other service categories.

### 4.1 Zoho CRM Provider

Zoho CRM is currently configured via Rails credentials. Moving to the integrations system provides per-tenant configuration and better visibility.

#### Provider Definition

```ruby
# app/services/integrations/providers/zoho_crm.rb
module Integrations
  module Providers
    class ZohoCrm < Base
      self.category = :crm
      self.display_name = 'Zoho CRM'
      self.description = 'Sync leads and contacts with Zoho CRM'

      # OAuth2 credentials
      credential_field :client_id,
                       required: true,
                       label: 'Client ID',
                       help: 'OAuth Client ID from Zoho API Console'

      credential_field :client_secret,
                       required: true,
                       label: 'Client Secret',
                       help: 'OAuth Client Secret from Zoho API Console'

      credential_field :refresh_token,
                       required: true,
                       label: 'Refresh Token',
                       help: 'OAuth Refresh Token (obtained after authorization)'

      # Settings
      setting_field :api_domain,
                    type: :select,
                    options: [
                      ['US (zohoapis.com)', 'https://www.zohoapis.com'],
                      ['EU (zohoapis.eu)', 'https://www.zohoapis.eu'],
                      ['India (zohoapis.in)', 'https://www.zohoapis.in'],
                      ['Australia (zohoapis.com.au)', 'https://www.zohoapis.com.au'],
                      ['China (zohoapis.com.cn)', 'https://www.zohoapis.com.cn']
                    ],
                    default: 'https://www.zohoapis.com',
                    label: 'API Region',
                    help: 'Select the Zoho data center for your account'

      setting_field :sync_frequency,
                    type: :select,
                    options: [
                      ['Real-time', 'realtime'],
                      ['Every 15 minutes', '15min'],
                      ['Every hour', 'hourly'],
                      ['Every 6 hours', '6hours'],
                      ['Daily', 'daily']
                    ],
                    default: 'realtime',
                    label: 'Sync Frequency',
                    help: 'How often to sync data with Zoho'

      setting_field :sync_leads,
                    type: :boolean,
                    default: true,
                    label: 'Sync Leads',
                    help: 'Automatically create leads in Zoho from inquiries'

      setting_field :sync_contacts,
                    type: :boolean,
                    default: true,
                    label: 'Sync Contacts',
                    help: 'Sync contact information with Zoho'

      setting_field :lead_source,
                    type: :string,
                    default: 'Website',
                    label: 'Lead Source',
                    help: 'Value for Lead Source field in Zoho'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'All OAuth credentials are required')
          return false
        end

        # Test API access by fetching org info
        client = build_client
        response = client.get('/crm/v2/org')

        if response.success?
          true
        else
          errors.add(:base, "API error: #{response.body['message']}")
          false
        end
      rescue OAuth2::Error => e
        if e.message.include?('invalid_grant')
          errors.add(:base, 'Invalid or expired refresh token')
        else
          errors.add(:base, "OAuth error: #{e.message}")
        end
        false
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end

      private

      def build_client
        Zoho::CrmClient.new(
          client_id: credential(:client_id),
          client_secret: credential(:client_secret),
          refresh_token: credential(:refresh_token),
          api_domain: setting(:api_domain)
        )
      end
    end
  end
end

Integrations::Registry.register(:crm, :zoho_crm, Integrations::Providers::ZohoCrm)
```

#### Service Integration

```ruby
# app/services/crm/zoho_service.rb
module Crm
  class ZohoService
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end

    def initialize(website:)
      @website = website
      @integration = website.integration_for(:crm, provider: :zoho_crm)
      raise ConfigurationError, 'Zoho CRM not configured' unless @integration
    end

    def create_lead(inquiry)
      data = {
        'First_Name' => inquiry.first_name,
        'Last_Name' => inquiry.last_name || 'Unknown',
        'Email' => inquiry.email,
        'Phone' => inquiry.phone,
        'Lead_Source' => @integration.setting(:lead_source),
        'Description' => build_description(inquiry)
      }

      response = client.post('/crm/v2/Leads', { data: [data] })

      if response.success?
        @integration.record_usage!
        response.body.dig('data', 0, 'details', 'id')
      else
        @integration.record_error!(response.body['message'])
        raise ApiError, response.body['message']
      end
    end

    def sync_contact(contact)
      # Implementation for contact sync
    end

    private

    def client
      @client ||= Zoho::CrmClient.new(
        client_id: @integration.credential(:client_id),
        client_secret: @integration.credential(:client_secret),
        refresh_token: @integration.credential(:refresh_token),
        api_domain: @integration.setting(:api_domain)
      )
    end

    def build_description(inquiry)
      parts = ["Property Inquiry from #{@website.company_display_name}"]
      parts << "Property: #{inquiry.prop&.reference}" if inquiry.prop
      parts << "Message: #{inquiry.message}" if inquiry.message.present?
      parts.join("\n\n")
    end
  end
end
```

### 4.2 Google Maps Provider

Currently using `pwb_websites.maps_api_key`. Moving to integrations provides better organization and the ability to add more map providers.

#### Provider Definition

```ruby
# app/services/integrations/providers/google_maps.rb
module Integrations
  module Providers
    class GoogleMaps < Base
      self.category = :maps
      self.display_name = 'Google Maps'
      self.description = 'Property location maps and geocoding'

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from Google Cloud Console'

      setting_field :default_zoom,
                    type: :number,
                    default: 14,
                    label: 'Default Zoom Level',
                    help: 'Map zoom level (1-20, where 20 is most zoomed in)'

      setting_field :map_type,
                    type: :select,
                    options: [
                      ['Road Map', 'roadmap'],
                      ['Satellite', 'satellite'],
                      ['Hybrid', 'hybrid'],
                      ['Terrain', 'terrain']
                    ],
                    default: 'roadmap',
                    label: 'Default Map Type'

      setting_field :show_street_view,
                    type: :boolean,
                    default: true,
                    label: 'Enable Street View',
                    help: 'Show Street View option on property pages'

      setting_field :geocoding_enabled,
                    type: :boolean,
                    default: true,
                    label: 'Enable Geocoding',
                    help: 'Automatically geocode property addresses'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'API key is required')
          return false
        end

        # Test with a simple geocoding request
        url = "https://maps.googleapis.com/maps/api/geocode/json?address=London&key=#{credential(:api_key)}"
        response = HTTP.get(url)
        result = JSON.parse(response.body)

        case result['status']
        when 'OK', 'ZERO_RESULTS'
          true
        when 'REQUEST_DENIED'
          errors.add(:base, 'Invalid API key or API not enabled')
          false
        when 'OVER_QUERY_LIMIT'
          errors.add(:base, 'API quota exceeded')
          false
        else
          errors.add(:base, "API error: #{result['status']}")
          false
        end
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

Integrations::Registry.register(:maps, :google_maps, Integrations::Providers::GoogleMaps)
```

### 4.3 Mapbox Provider (Alternative Maps)

```ruby
# app/services/integrations/providers/mapbox.rb
module Integrations
  module Providers
    class Mapbox < Base
      self.category = :maps
      self.display_name = 'Mapbox'
      self.description = 'Beautiful custom maps for property listings'

      credential_field :access_token,
                       required: true,
                       label: 'Access Token',
                       help: 'Get your access token from mapbox.com'

      setting_field :style_url,
                    type: :select,
                    options: [
                      ['Streets', 'mapbox://styles/mapbox/streets-v12'],
                      ['Light', 'mapbox://styles/mapbox/light-v11'],
                      ['Dark', 'mapbox://styles/mapbox/dark-v11'],
                      ['Satellite', 'mapbox://styles/mapbox/satellite-v9'],
                      ['Satellite Streets', 'mapbox://styles/mapbox/satellite-streets-v12']
                    ],
                    default: 'mapbox://styles/mapbox/streets-v12',
                    label: 'Map Style'

      setting_field :default_zoom,
                    type: :number,
                    default: 14,
                    label: 'Default Zoom Level'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'Access token is required')
          return false
        end

        # Validate token with a simple geocoding request
        url = "https://api.mapbox.com/geocoding/v5/mapbox.places/London.json?access_token=#{credential(:access_token)}&limit=1"
        response = HTTP.get(url)

        if response.status.success?
          true
        elsif response.status.code == 401
          errors.add(:base, 'Invalid access token')
          false
        else
          errors.add(:base, "API error: #{response.status}")
          false
        end
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

Integrations::Registry.register(:maps, :mapbox, Integrations::Providers::Mapbox)
```

### 4.4 Mailchimp Provider (Email Marketing)

```ruby
# app/services/integrations/providers/mailchimp.rb
module Integrations
  module Providers
    class Mailchimp < Base
      self.category = :email_marketing
      self.display_name = 'Mailchimp'
      self.description = 'Email marketing and subscriber management'

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from Mailchimp account settings'

      # Server prefix is extracted from API key (e.g., us21)
      # Format: xxxxxxxx-us21

      setting_field :default_list_id,
                    type: :string,
                    label: 'Default Audience ID',
                    help: 'The Mailchimp Audience/List ID for new subscribers'

      setting_field :double_optin,
                    type: :boolean,
                    default: true,
                    label: 'Double Opt-in',
                    help: 'Require email confirmation before adding to list'

      setting_field :auto_subscribe_inquiries,
                    type: :boolean,
                    default: false,
                    label: 'Auto-subscribe Inquiries',
                    help: 'Automatically add inquiry senders to mailing list'

      setting_field :tags,
                    type: :string,
                    default: 'website-lead',
                    label: 'Default Tags',
                    help: 'Comma-separated tags to apply to new subscribers'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'API key is required')
          return false
        end

        # Extract server prefix from API key
        server = credential(:api_key).split('-').last

        unless server.present?
          errors.add(:base, 'Invalid API key format')
          return false
        end

        # Test connection
        url = "https://#{server}.api.mailchimp.com/3.0/ping"
        response = HTTP.basic_auth(user: 'anystring', pass: credential(:api_key)).get(url)

        if response.status.success?
          true
        elsif response.status.code == 401
          errors.add(:base, 'Invalid API key')
          false
        else
          body = JSON.parse(response.body) rescue {}
          errors.add(:base, body['detail'] || "API error: #{response.status}")
          false
        end
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

Integrations::Registry.register(:email_marketing, :mailchimp, Integrations::Providers::Mailchimp)
```

### 4.5 Stripe Provider (Payments)

```ruby
# app/services/integrations/providers/stripe.rb
module Integrations
  module Providers
    class Stripe < Base
      self.category = :payment
      self.display_name = 'Stripe'
      self.description = 'Accept payments for deposits, booking fees, and more'

      credential_field :secret_key,
                       required: true,
                       label: 'Secret Key',
                       help: 'Your Stripe secret key (starts with sk_)'

      credential_field :publishable_key,
                       required: true,
                       label: 'Publishable Key',
                       help: 'Your Stripe publishable key (starts with pk_)'

      credential_field :webhook_secret,
                       required: false,
                       label: 'Webhook Secret',
                       help: 'Webhook signing secret for verifying events'

      setting_field :currency,
                    type: :select,
                    options: [
                      ['US Dollar (USD)', 'usd'],
                      ['Euro (EUR)', 'eur'],
                      ['British Pound (GBP)', 'gbp'],
                      ['Australian Dollar (AUD)', 'aud'],
                      ['Canadian Dollar (CAD)', 'cad']
                    ],
                    default: 'usd',
                    label: 'Default Currency'

      setting_field :payment_methods,
                    type: :string,
                    default: 'card',
                    label: 'Payment Methods',
                    help: 'Comma-separated: card, ideal, sepa_debit, etc.'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'Secret and publishable keys are required')
          return false
        end

        # Validate secret key format
        unless credential(:secret_key).start_with?('sk_')
          errors.add(:base, 'Invalid secret key format')
          return false
        end

        unless credential(:publishable_key).start_with?('pk_')
          errors.add(:base, 'Invalid publishable key format')
          return false
        end

        # Test connection
        ::Stripe.api_key = credential(:secret_key)
        ::Stripe::Balance.retrieve

        true
      rescue ::Stripe::AuthenticationError
        errors.add(:base, 'Invalid API key')
        false
      rescue ::Stripe::StripeError => e
        errors.add(:base, "Stripe error: #{e.message}")
        false
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

Integrations::Registry.register(:payment, :stripe, Integrations::Providers::Stripe)
```

### Implementation Steps for Each Provider

1. **Create Provider File**: `app/services/integrations/providers/{name}.rb`
2. **Define Credentials**: Required secrets (API keys, tokens)
3. **Define Settings**: Non-sensitive configuration options
4. **Implement `validate_connection`**: Test API access
5. **Register Provider**: `Integrations::Registry.register(...)`
6. **Create Service Class**: `app/services/{category}/{name}_service.rb`
7. **Add Tests**: Provider and service specs
8. **Update Documentation**: Add to provider list

---

## Phase 5: Migration from ENV-based Configs

### Overview

Migrate existing configuration from environment variables and Rails credentials to the integrations system for per-tenant configuration.

### 5.1 Current Configuration Locations

| Service | Current Location | Target Integration |
|---------|------------------|-------------------|
| Anthropic | `ENV['ANTHROPIC_API_KEY']` | `:ai, :anthropic` |
| OpenAI | `ENV['OPENAI_API_KEY']` | `:ai, :openai` |
| Zoho CRM | `Rails.credentials.zoho` | `:crm, :zoho_crm` |
| Google Maps | `pwb_websites.maps_api_key` | `:maps, :google_maps` |
| Google Analytics | `pwb_websites.analytics_id` | `:analytics, :google_analytics` |
| Stripe | `Rails.credentials.stripe` | `:payment, :stripe` |

### 5.2 Migration Strategy

#### Option A: One-Time Data Migration

Create a migration task that moves existing configs to integrations:

```ruby
# lib/tasks/integrations_migration.rake
namespace :integrations do
  desc 'Migrate existing configurations to integrations system'
  task migrate: :environment do
    puts "Starting integrations migration..."

    # Migrate Google Maps API keys
    migrate_maps_api_keys

    # Migrate Zoho CRM (global to first website or all)
    migrate_zoho_crm

    # Migrate Analytics IDs
    migrate_analytics

    puts "Migration complete!"
  end

  def migrate_maps_api_keys
    puts "\nMigrating Google Maps API keys..."

    Pwb::Website.where.not(maps_api_key: [nil, '']).find_each do |website|
      next if website.integration_for(:maps, provider: :google_maps)

      website.integrations.create!(
        category: 'maps',
        provider: 'google_maps',
        credentials: { api_key: website.maps_api_key },
        settings: { default_zoom: 14 },
        enabled: true
      )

      puts "  Migrated maps for website #{website.id} (#{website.subdomain})"
    end
  end

  def migrate_zoho_crm
    puts "\nMigrating Zoho CRM..."

    zoho_creds = Rails.application.credentials.zoho
    return puts "  No Zoho credentials found" unless zoho_creds.present?

    # Option 1: Apply to all websites
    # Option 2: Apply only to websites with zoho_enabled flag
    # For now, we'll create for websites that have used Zoho sync

    Pwb::Website.find_each do |website|
      next if website.integration_for(:crm, provider: :zoho_crm)

      website.integrations.create!(
        category: 'crm',
        provider: 'zoho_crm',
        credentials: {
          client_id: zoho_creds[:client_id],
          client_secret: zoho_creds[:client_secret],
          refresh_token: zoho_creds[:refresh_token]
        },
        settings: {
          api_domain: zoho_creds[:api_domain] || 'https://www.zohoapis.com',
          sync_frequency: 'realtime'
        },
        enabled: true
      )

      puts "  Created Zoho integration for website #{website.id}"
    end
  end

  def migrate_analytics
    puts "\nMigrating Analytics..."

    Pwb::Website.where.not(analytics_id: [nil, '']).find_each do |website|
      next if website.integration_for(:analytics, provider: :google_analytics)

      # Determine analytics type from ID format
      provider = website.analytics_id.start_with?('G-') ? 'google_analytics_4' : 'google_analytics_ua'

      website.integrations.create!(
        category: 'analytics',
        provider: provider,
        credentials: {},
        settings: { measurement_id: website.analytics_id },
        enabled: true
      )

      puts "  Migrated analytics for website #{website.id}"
    end
  end
end
```

#### Option B: Dual-Read with Gradual Migration

Keep backward compatibility while encouraging migration through UI:

```ruby
# app/services/ai/base_service.rb
module Ai
  class BaseService
    def initialize(website: nil, user: nil)
      @website = website
      @user = user
      @integration = website&.integration_for(:ai)
    end

    protected

    def configured?
      # Check integration first (new system)
      if @integration&.credentials_present?
        true
      else
        # Fall back to ENV (legacy)
        legacy_configured?
      end
    end

    def api_key
      @integration&.credential(:api_key) || legacy_api_key
    end

    private

    def legacy_configured?
      ENV['ANTHROPIC_API_KEY'].present? || ENV['OPENAI_API_KEY'].present?
    end

    def legacy_api_key
      ENV['ANTHROPIC_API_KEY'] || ENV['OPENAI_API_KEY']
    end
  end
end
```

### 5.3 Migration UI Prompt

Show a migration prompt in the admin UI when legacy config is detected:

```ruby
# app/helpers/site_admin/integrations_helper.rb
def legacy_config_warning(category)
  case category.to_sym
  when :ai
    if ENV['ANTHROPIC_API_KEY'].present? || ENV['OPENAI_API_KEY'].present?
      content_tag(:div, class: 'p-4 bg-yellow-50 border border-yellow-200 rounded-lg mb-4') do
        content_tag(:p, class: 'text-sm text-yellow-800') do
          'AI is configured via environment variables. We recommend migrating to the integrations system for better security and per-website configuration.'
        end
      end
    end
  when :maps
    if current_website.maps_api_key.present? && !current_website.integration_for(:maps)
      content_tag(:div, class: 'p-4 bg-yellow-50 border border-yellow-200 rounded-lg mb-4') do
        content_tag(:p, class: 'text-sm text-yellow-800') do
          'Maps is configured in website settings. Click "Set Up" to migrate to the new integrations system.'
        end
      end
    end
  end
end
```

### 5.4 Post-Migration Cleanup

After migration is complete and verified:

1. Remove deprecated columns (via migration)
2. Remove legacy ENV fallback code
3. Update documentation

```ruby
# db/migrate/TIMESTAMP_remove_legacy_integration_columns.rb
class RemoveLegacyIntegrationColumns < ActiveRecord::Migration[7.1]
  def change
    # Only run after migration is complete and verified
    safety_assured do
      remove_column :pwb_websites, :maps_api_key, :string
      remove_column :pwb_websites, :analytics_id, :string
      remove_column :pwb_websites, :analytics_id_type, :string
    end
  end
end
```

---

## Phase 6: Usage Analytics

### Overview

Track integration usage to provide insights into API consumption, costs, and patterns.

### 6.1 Database Schema

```ruby
# db/migrate/TIMESTAMP_create_pwb_integration_usage_logs.rb
class CreatePwbIntegrationUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_integration_usage_logs do |t|
      t.references :integration, null: false,
                   foreign_key: { to_table: :pwb_website_integrations }
      t.references :user, foreign_key: { to_table: :users }

      t.string :action, null: false          # 'api_call', 'sync', 'webhook'
      t.string :endpoint                      # API endpoint called
      t.string :method                        # HTTP method (GET, POST, etc.)
      t.integer :response_status              # HTTP status code
      t.integer :duration_ms                  # Request duration
      t.integer :input_tokens                 # For AI: input tokens
      t.integer :output_tokens                # For AI: output tokens
      t.decimal :cost_cents, precision: 10, scale: 4  # Estimated cost
      t.jsonb :metadata, default: {}          # Additional context
      t.boolean :success, default: true

      t.timestamps
    end

    add_index :pwb_integration_usage_logs, [:integration_id, :created_at]
    add_index :pwb_integration_usage_logs, [:integration_id, :action]
    add_index :pwb_integration_usage_logs, :created_at
  end
end
```

### 6.2 Usage Tracking Model

```ruby
# app/models/pwb/integration_usage_log.rb
module Pwb
  class IntegrationUsageLog < ApplicationRecord
    self.table_name = 'pwb_integration_usage_logs'

    belongs_to :integration, class_name: 'Pwb::WebsiteIntegration'
    belongs_to :user, optional: true

    validates :action, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :for_action, ->(action) { where(action: action) }
    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }
    scope :in_period, ->(start_date, end_date) { where(created_at: start_date..end_date) }

    # Aggregation methods
    class << self
      def total_cost
        sum(:cost_cents) / 100.0
      end

      def total_tokens
        {
          input: sum(:input_tokens),
          output: sum(:output_tokens),
          total: sum(:input_tokens) + sum(:output_tokens)
        }
      end

      def average_duration
        average(:duration_ms)
      end

      def success_rate
        return 0 if count.zero?
        (successful.count.to_f / count * 100).round(2)
      end

      def by_day
        group("DATE(created_at)").count
      end

      def by_action
        group(:action).count
      end
    end
  end
end
```

### 6.3 Usage Tracking Service

```ruby
# app/services/integrations/usage_tracker.rb
module Integrations
  class UsageTracker
    # Token costs per provider (USD per 1M tokens)
    TOKEN_COSTS = {
      'anthropic' => {
        'claude-sonnet-4-20250514' => { input: 3.0, output: 15.0 },
        'claude-opus-4-20250514' => { input: 15.0, output: 75.0 },
        'claude-3-5-haiku-20241022' => { input: 0.80, output: 4.0 }
      },
      'openai' => {
        'gpt-4o' => { input: 2.50, output: 10.0 },
        'gpt-4o-mini' => { input: 0.15, output: 0.60 },
        'gpt-4-turbo' => { input: 10.0, output: 30.0 }
      }
    }.freeze

    def initialize(integration)
      @integration = integration
    end

    def track(action:, user: nil, **options)
      start_time = options[:start_time] || Time.current
      duration = options[:duration_ms] || ((Time.current - start_time) * 1000).to_i

      log = Pwb::IntegrationUsageLog.create!(
        integration: @integration,
        user: user,
        action: action,
        endpoint: options[:endpoint],
        method: options[:method],
        response_status: options[:status],
        duration_ms: duration,
        input_tokens: options[:input_tokens],
        output_tokens: options[:output_tokens],
        cost_cents: calculate_cost(options),
        metadata: options[:metadata] || {},
        success: options[:success] != false
      )

      # Update integration last_used_at
      @integration.record_usage!

      log
    end

    def track_ai_response(response, user: nil, start_time: nil)
      track(
        action: 'ai_generation',
        user: user,
        start_time: start_time,
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        success: true
      )
    end

    def track_error(action:, error:, user: nil)
      track(
        action: action,
        user: user,
        success: false,
        metadata: { error: error.message, error_class: error.class.name }
      )
    end

    private

    def calculate_cost(options)
      return nil unless options[:input_tokens] || options[:output_tokens]

      provider = @integration.provider
      model = @integration.setting(:default_model)

      rates = TOKEN_COSTS.dig(provider, model)
      return nil unless rates

      input_cost = (options[:input_tokens].to_i / 1_000_000.0) * rates[:input]
      output_cost = (options[:output_tokens].to_i / 1_000_000.0) * rates[:output]

      ((input_cost + output_cost) * 100).round(4)  # Convert to cents
    end
  end
end
```

### 6.4 Integration with AI Services

```ruby
# app/services/ai/base_service.rb (updated)
module Ai
  class BaseService
    def initialize(website: nil, user: nil)
      @website = website
      @user = user
      @integration = website&.integration_for(:ai)
      @usage_tracker = Integrations::UsageTracker.new(@integration) if @integration
    end

    protected

    def chat(messages:, model: nil, **options)
      ensure_configured!
      configure_ruby_llm!

      start_time = Time.current
      selected_model = model || default_model

      begin
        response = perform_chat(messages, selected_model)

        # Track usage
        @usage_tracker&.track_ai_response(response, user: @user, start_time: start_time)

        response
      rescue => e
        @usage_tracker&.track_error(action: 'ai_generation', error: e, user: @user)
        raise
      end
    end
  end
end
```

### 6.5 Usage Dashboard UI

```ruby
# app/controllers/site_admin/integrations_controller.rb (add action)
def usage
  @integration = current_website.integrations.find(params[:id])
  @period = params[:period] || '30days'

  @start_date = case @period
                when '7days' then 7.days.ago
                when '30days' then 30.days.ago
                when '90days' then 90.days.ago
                else 30.days.ago
                end

  @logs = @integration.usage_logs.in_period(@start_date, Time.current)
  @daily_usage = @logs.by_day
  @total_cost = @logs.total_cost
  @total_tokens = @logs.total_tokens
  @success_rate = @logs.success_rate
end
```

```erb
<%# app/views/site_admin/integrations/usage.html.erb %>
<div class="max-w-4xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">
    <%= @integration.provider_name %> Usage Analytics
  </h1>

  <!-- Summary Cards -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
    <div class="bg-white rounded-lg shadow p-4">
      <div class="text-sm text-gray-500">Total Requests</div>
      <div class="text-2xl font-bold"><%= @logs.count %></div>
    </div>
    <div class="bg-white rounded-lg shadow p-4">
      <div class="text-sm text-gray-500">Success Rate</div>
      <div class="text-2xl font-bold"><%= @success_rate %>%</div>
    </div>
    <div class="bg-white rounded-lg shadow p-4">
      <div class="text-sm text-gray-500">Total Tokens</div>
      <div class="text-2xl font-bold"><%= number_with_delimiter(@total_tokens[:total]) %></div>
    </div>
    <div class="bg-white rounded-lg shadow p-4">
      <div class="text-sm text-gray-500">Estimated Cost</div>
      <div class="text-2xl font-bold">$<%= sprintf('%.2f', @total_cost) %></div>
    </div>
  </div>

  <!-- Usage Chart -->
  <div class="bg-white rounded-lg shadow p-6 mb-8">
    <h2 class="text-lg font-semibold mb-4">Daily Usage</h2>
    <div id="usage-chart" data-usage="<%= @daily_usage.to_json %>"></div>
  </div>

  <!-- Recent Activity -->
  <div class="bg-white rounded-lg shadow">
    <h2 class="text-lg font-semibold p-4 border-b">Recent Activity</h2>
    <div class="divide-y">
      <% @logs.recent.limit(20).each do |log| %>
        <div class="p-4 flex items-center justify-between">
          <div>
            <span class="font-medium"><%= log.action %></span>
            <span class="text-sm text-gray-500 ml-2">
              <%= time_ago_in_words(log.created_at) %> ago
            </span>
          </div>
          <div class="flex items-center space-x-4">
            <% if log.input_tokens %>
              <span class="text-sm text-gray-600">
                <%= number_with_delimiter(log.input_tokens + log.output_tokens) %> tokens
              </span>
            <% end %>
            <% if log.cost_cents %>
              <span class="text-sm text-gray-600">
                $<%= sprintf('%.4f', log.cost_cents / 100.0) %>
              </span>
            <% end %>
            <span class="<%= log.success? ? 'text-green-600' : 'text-red-600' %>">
              <%= log.success? ? '✓' : '✗' %>
            </span>
          </div>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

---

## Phase 7: Audit Logging

### Overview

Track all changes to integration configurations for security and compliance.

### 7.1 Database Schema

```ruby
# db/migrate/TIMESTAMP_create_pwb_integration_audit_logs.rb
class CreatePwbIntegrationAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_integration_audit_logs do |t|
      t.references :integration, null: false,
                   foreign_key: { to_table: :pwb_website_integrations }
      t.references :user, null: false, foreign_key: { to_table: :users }

      t.string :action, null: false          # created, updated, deleted, credentials_changed, etc.
      t.string :ip_address
      t.string :user_agent
      t.jsonb :changes, default: {}          # What changed (sanitized)
      t.jsonb :metadata, default: {}         # Additional context

      t.timestamps
    end

    add_index :pwb_integration_audit_logs, [:integration_id, :created_at]
    add_index :pwb_integration_audit_logs, [:user_id, :created_at]
    add_index :pwb_integration_audit_logs, :action
  end
end
```

### 7.2 Audit Log Model

```ruby
# app/models/pwb/integration_audit_log.rb
module Pwb
  class IntegrationAuditLog < ApplicationRecord
    self.table_name = 'pwb_integration_audit_logs'

    belongs_to :integration, class_name: 'Pwb::WebsiteIntegration'
    belongs_to :user

    validates :action, presence: true

    ACTIONS = %w[
      created
      updated
      deleted
      enabled
      disabled
      credentials_changed
      credentials_rotated
      connection_tested
      connection_failed
    ].freeze

    validates :action, inclusion: { in: ACTIONS }

    scope :recent, -> { order(created_at: :desc) }
    scope :for_action, ->(action) { where(action: action) }
    scope :credential_changes, -> {
      where(action: %w[credentials_changed credentials_rotated])
    }

    # Sanitize changes to never include actual credential values
    def self.sanitize_changes(changes_hash)
      sensitive_keys = %w[api_key secret_key client_secret refresh_token access_token webhook_secret]

      changes_hash.transform_values do |change|
        if change.is_a?(Hash)
          change.transform_values do |v|
            if sensitive_keys.any? { |k| v.to_s.downcase.include?(k) }
              '[REDACTED]'
            else
              v
            end
          end
        elsif change.is_a?(Array) && change.length == 2
          # ActiveRecord style [old, new]
          change.map { |v| v.is_a?(String) && v.length > 8 ? '[REDACTED]' : v }
        else
          change
        end
      end
    end
  end
end
```

### 7.3 Audit Service

```ruby
# app/services/integrations/audit_service.rb
module Integrations
  class AuditService
    def initialize(integration, user:, request: nil)
      @integration = integration
      @user = user
      @request = request
    end

    def log_created
      create_log('created', changes: {
        category: @integration.category,
        provider: @integration.provider,
        settings: @integration.settings
      })
    end

    def log_updated(previous_attributes)
      changes = calculate_changes(previous_attributes)
      return if changes.empty?

      action = changes.key?('credentials') ? 'credentials_changed' : 'updated'
      create_log(action, changes: sanitize(changes))
    end

    def log_deleted
      create_log('deleted', changes: {
        category: @integration.category,
        provider: @integration.provider
      })
    end

    def log_enabled
      create_log('enabled')
    end

    def log_disabled
      create_log('disabled')
    end

    def log_connection_tested(success:, error: nil)
      action = success ? 'connection_tested' : 'connection_failed'
      metadata = error ? { error: error } : {}
      create_log(action, metadata: metadata)
    end

    def log_credentials_rotated(key)
      create_log('credentials_rotated', changes: { rotated_key: key })
    end

    private

    def create_log(action, changes: {}, metadata: {})
      Pwb::IntegrationAuditLog.create!(
        integration: @integration,
        user: @user,
        action: action,
        ip_address: @request&.remote_ip,
        user_agent: @request&.user_agent&.truncate(500),
        changes: changes,
        metadata: metadata
      )
    end

    def calculate_changes(previous)
      current = @integration.attributes
      changes = {}

      # Track attribute changes
      %w[enabled settings].each do |attr|
        if previous[attr] != current[attr]
          changes[attr] = [previous[attr], current[attr]]
        end
      end

      # Track credential changes (without values)
      if credentials_changed?(previous['credentials'])
        changes['credentials'] = '[CHANGED]'
      end

      changes
    end

    def credentials_changed?(previous_credentials)
      # Decrypt and compare
      current = @integration.credentials
      previous = previous_credentials

      return true if previous.blank? != current.blank?
      return false if previous.blank?

      previous.keys.sort != current.keys.sort ||
        previous.values.map(&:to_s).sort != current.values.map(&:to_s).sort
    end

    def sanitize(changes)
      Pwb::IntegrationAuditLog.sanitize_changes(changes)
    end
  end
end
```

### 7.4 Controller Integration

```ruby
# app/controllers/site_admin/integrations_controller.rb (updated)
class IntegrationsController < ::SiteAdminController
  def create
    @integration = current_website.integrations.build(integration_params)
    set_credentials_from_params
    set_settings_from_params

    if @integration.save
      audit_service.log_created
      redirect_to site_admin_integrations_path,
                  notice: "#{@integration.provider_name} integration configured successfully"
    else
      # ... error handling
    end
  end

  def update
    previous_attributes = @integration.attributes.deep_dup

    set_credentials_from_params
    set_settings_from_params
    @integration.enabled = params.dig(:integration, :enabled) != '0' if params.dig(:integration, :enabled)

    if @integration.save
      audit_service(previous_attributes).log_updated(previous_attributes)
      redirect_to site_admin_integrations_path,
                  notice: "#{@integration.provider_name} integration updated successfully"
    else
      # ... error handling
    end
  end

  def destroy
    audit_service.log_deleted
    provider_name = @integration.provider_name
    @integration.destroy
    redirect_to site_admin_integrations_path,
                notice: "#{provider_name} integration removed"
  end

  def toggle
    previous_enabled = @integration.enabled?
    @integration.update(enabled: !@integration.enabled?)

    if @integration.enabled?
      audit_service.log_enabled
    else
      audit_service.log_disabled
    end

    # ... rest of action
  end

  def test_connection
    result = @integration.test_connection
    audit_service.log_connection_tested(
      success: result,
      error: result ? nil : @integration.last_error_message
    )

    # ... rest of action
  end

  private

  def audit_service(previous_attributes = nil)
    Integrations::AuditService.new(
      @integration,
      user: current_user,
      request: request
    )
  end
end
```

### 7.5 Audit Log Viewer

```ruby
# Add route
resources :integrations do
  member do
    get :audit_log
  end
end
```

```erb
<%# app/views/site_admin/integrations/audit_log.html.erb %>
<div class="max-w-4xl mx-auto">
  <nav class="flex items-center text-sm text-gray-500 mb-4">
    <%= link_to 'Integrations', site_admin_integrations_path, class: 'hover:text-gray-700' %>
    <svg class="w-4 h-4 mx-2" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
    </svg>
    <span><%= @integration.provider_name %> Audit Log</span>
  </nav>

  <h1 class="text-2xl font-bold mb-6">Audit Log</h1>

  <div class="bg-white rounded-lg shadow divide-y">
    <% @logs.each do |log| %>
      <div class="p-4">
        <div class="flex items-start justify-between">
          <div>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
                         <%= audit_action_badge_class(log.action) %>">
              <%= log.action.titleize %>
            </span>
            <span class="text-sm text-gray-500 ml-2">
              by <%= log.user.email %>
            </span>
          </div>
          <span class="text-sm text-gray-500">
            <%= log.created_at.strftime('%B %d, %Y at %I:%M %p') %>
          </span>
        </div>

        <% if log.changes.present? %>
          <div class="mt-2 text-sm text-gray-600">
            <pre class="bg-gray-50 p-2 rounded text-xs overflow-x-auto"><%= JSON.pretty_generate(log.changes) %></pre>
          </div>
        <% end %>

        <% if log.ip_address.present? %>
          <div class="mt-2 text-xs text-gray-400">
            IP: <%= log.ip_address %>
          </div>
        <% end %>
      </div>
    <% end %>

    <% if @logs.empty? %>
      <div class="p-8 text-center text-gray-500">
        No audit log entries yet.
      </div>
    <% end %>
  </div>
</div>
```

### 7.6 Security Notifications

For critical actions, send notifications to admins:

```ruby
# app/services/integrations/audit_service.rb (addition)
def log_credentials_changed
  create_log('credentials_changed')
  notify_admins_of_credential_change
end

private

def notify_admins_of_credential_change
  return unless should_notify?

  IntegrationMailer.credentials_changed(
    integration: @integration,
    changed_by: @user,
    ip_address: @request&.remote_ip
  ).deliver_later
end

def should_notify?
  # Notify for production environments
  Rails.env.production? && @integration.website.notification_enabled?(:security)
end
```

---

## Implementation Priority

### High Priority (Immediate Value)
1. **Zoho CRM Provider** - Already in use, needs per-tenant config
2. **Google Maps Migration** - Simple migration, high usage
3. **Usage Analytics** - Cost visibility for AI features

### Medium Priority
4. **Audit Logging** - Security compliance
5. **Mailchimp Provider** - Common request
6. **Stripe Provider** - Enable payment features

### Lower Priority
7. **Mapbox Provider** - Alternative to Google Maps
8. **Additional CRM providers** - Based on customer requests
9. **Additional analytics providers** - Based on customer requests

---

## Testing Strategy

### Unit Tests
- Provider validation logic
- Usage tracking calculations
- Audit log sanitization

### Integration Tests
- Full CRUD with audit trails
- Migration tasks
- Multi-tenant isolation

### End-to-End Tests
- Complete setup flow in browser
- Connection testing with mocked APIs
- Usage dashboard rendering

---

## Security Considerations

1. **Never log actual credentials** - Always sanitize
2. **Rate limit connection tests** - Prevent API abuse
3. **Encrypt credentials at rest** - Already implemented
4. **Audit all credential access** - Track who, when, what
5. **Notify on suspicious activity** - Multiple failed connections, credential changes

---

## Related Documentation

- [Integrations System Overview](./integrations_system.md)
- [AI Features Documentation](../features/ai_descriptions.md)
- [Multi-Tenancy Guide](../multi_tenancy/overview.md)
