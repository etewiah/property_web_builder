# Website Integrations System

## Overview

The integrations system provides a flexible, secure, and extensible way for each website (tenant) to connect with external services. Rather than adding provider-specific columns to the website model, this system uses a dedicated integrations table that can accommodate any current or future service integration.

## Goals

1. **Flexibility** - Support any type of external service integration
2. **Multi-provider** - Allow multiple providers within the same category (e.g., different AI providers)
3. **Security** - Encrypt all credentials at rest using Rails ActiveRecord::Encryption
4. **Multi-tenant** - Full isolation between websites
5. **Extensibility** - Easy to add new integration types without schema changes
6. **Discoverability** - Clear categorization and UI organization

## Database Schema

### Table: `pwb_website_integrations`

```ruby
create_table :pwb_website_integrations do |t|
  t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

  # Classification
  t.string :category, null: false      # ai, crm, email_marketing, analytics, payment, etc.
  t.string :provider, null: false      # anthropic, openai, zoho, mailchimp, stripe, etc.

  # Configuration
  t.text :credentials                  # Encrypted JSONB - API keys, secrets, tokens
  t.jsonb :settings, default: {}       # Provider-specific settings (non-sensitive)

  # State
  t.boolean :enabled, default: true
  t.datetime :last_used_at
  t.datetime :last_error_at
  t.text :last_error_message

  t.timestamps
end

add_index :pwb_website_integrations, [:website_id, :category]
add_index :pwb_website_integrations, [:website_id, :category, :provider], unique: true
add_index :pwb_website_integrations, [:website_id, :enabled]
```

### Why This Structure?

| Column | Purpose |
|--------|---------|
| `category` | Groups integrations by function (AI, CRM, etc.) for UI organization and querying |
| `provider` | Identifies the specific service (Anthropic, OpenAI, Zoho, etc.) |
| `credentials` | Encrypted storage for sensitive data (API keys, secrets, OAuth tokens) |
| `settings` | Non-sensitive configuration (model preferences, sync frequency, etc.) |
| `enabled` | Toggle integration without losing configuration |
| `last_used_at` | Track usage for analytics and debugging |
| `last_error_*` | Store error state for troubleshooting |

## Integration Categories

### Current Categories

| Category | Description | Example Providers |
|----------|-------------|-------------------|
| `ai` | AI/LLM services for content generation | Anthropic, OpenAI, Google AI |
| `crm` | Customer relationship management | Zoho, Salesforce, HubSpot |
| `email_marketing` | Email campaigns and automation | Mailchimp, SendGrid, Mailerlite |
| `analytics` | Website and business analytics | Google Analytics, Mixpanel |
| `payment` | Payment processing | Stripe, PayPal |
| `maps` | Mapping and geocoding | Google Maps, Mapbox |
| `storage` | File/media storage | AWS S3, Cloudinary |
| `communication` | Messaging and notifications | Twilio, WhatsApp Business |

### Adding New Categories

Categories are defined in a registry for validation and UI rendering:

```ruby
# app/models/pwb/website_integration.rb
CATEGORIES = {
  ai: {
    name: 'Artificial Intelligence',
    description: 'AI-powered content generation and assistance',
    icon: 'sparkles'
  },
  crm: {
    name: 'CRM',
    description: 'Customer relationship management',
    icon: 'users'
  },
  # ... etc
}.freeze
```

## Provider Definitions

Each provider has a definition that describes its configuration requirements:

```ruby
# app/services/integrations/providers/anthropic.rb
module Integrations
  module Providers
    class Anthropic < Base
      CATEGORY = :ai

      # Credential fields (encrypted)
      credential_field :api_key, required: true, label: 'API Key'

      # Settings fields (not encrypted)
      setting_field :default_model,
                    type: :select,
                    options: ['claude-sonnet-4-20250514', 'claude-opus-4-20250514'],
                    default: 'claude-sonnet-4-20250514',
                    label: 'Default Model'

      setting_field :max_tokens,
                    type: :number,
                    default: 4096,
                    label: 'Max Tokens'

      # Validation
      def validate_connection
        # Test API key validity
        client = RubyLLM.chat(model: settings[:default_model])
        client.ask("test")
        true
      rescue => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end
```

## Model Design

### Pwb::WebsiteIntegration

```ruby
# app/models/pwb/website_integration.rb
module Pwb
  class WebsiteIntegration < ApplicationRecord
    # Encryption for credentials
    encrypts :credentials

    # Associations
    belongs_to :website

    # Serialize credentials as JSON
    serialize :credentials, coder: JSON

    # Validations
    validates :category, presence: true, inclusion: { in: CATEGORIES.keys.map(&:to_s) }
    validates :provider, presence: true
    validates :provider, uniqueness: { scope: [:website_id, :category] }
    validate :provider_valid_for_category

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :for_category, ->(cat) { where(category: cat) }
    scope :by_provider, ->(provider) { where(provider: provider) }

    # Credential accessors with nil safety
    def credential(key)
      credentials&.dig(key.to_s)
    end

    def set_credential(key, value)
      self.credentials ||= {}
      self.credentials[key.to_s] = value
    end

    # Setting accessors
    def setting(key)
      settings&.dig(key.to_s) || provider_definition.default_for(key)
    end

    # Provider definition
    def provider_definition
      Integrations::Registry.provider(category, provider)
    end

    # Connection testing
    def test_connection
      provider_definition.new(self).validate_connection
    end

    # Record usage
    def record_usage!
      touch(:last_used_at)
    end

    def record_error!(message)
      update!(last_error_at: Time.current, last_error_message: message)
    end

    def clear_error!
      update!(last_error_at: nil, last_error_message: nil)
    end
  end
end
```

### Website Association

```ruby
# app/models/pwb/website.rb (addition)
has_many :integrations,
         class_name: 'Pwb::WebsiteIntegration',
         dependent: :destroy

# Convenience method to get enabled integration for a category
def integration_for(category, provider: nil)
  scope = integrations.enabled.for_category(category)
  scope = scope.by_provider(provider) if provider
  scope.first
end

# Check if integration is configured
def integration_configured?(category, provider: nil)
  integration_for(category, provider: provider).present?
end
```

## Service Layer

### Integration Registry

Central registry of all available providers:

```ruby
# app/services/integrations/registry.rb
module Integrations
  class Registry
    class << self
      def providers
        @providers ||= {}
      end

      def register(category, provider, klass)
        providers[category] ||= {}
        providers[category][provider] = klass
      end

      def provider(category, provider)
        providers.dig(category.to_sym, provider.to_sym)
      end

      def providers_for(category)
        providers[category.to_sym] || {}
      end

      def categories
        providers.keys
      end
    end
  end
end

# Auto-registration in provider classes
# app/services/integrations/providers/anthropic.rb
Integrations::Registry.register(:ai, :anthropic, Integrations::Providers::Anthropic)
```

### Using Integrations in Services

Update the AI service to use the integrations system:

```ruby
# app/services/ai/base_service.rb
module Ai
  class BaseService
    def initialize(website:, user: nil)
      @website = website
      @user = user
      @integration = website.integration_for(:ai)
    end

    protected

    def configured?
      @integration.present? && @integration.credential(:api_key).present?
    end

    def api_key
      @integration&.credential(:api_key)
    end

    def default_model
      @integration&.setting(:default_model) || 'claude-sonnet-4-20250514'
    end

    def record_usage!
      @integration&.record_usage!
    end

    def record_error!(message)
      @integration&.record_error!(message)
    end
  end
end
```

## Security Considerations

### Credential Encryption

All credentials are encrypted at rest using Rails 7+ ActiveRecord::Encryption:

```ruby
# config/application.rb
config.active_record.encryption.primary_key = Rails.application.credentials.active_record_encryption[:primary_key]
config.active_record.encryption.deterministic_key = Rails.application.credentials.active_record_encryption[:deterministic_key]
config.active_record.encryption.key_derivation_salt = Rails.application.credentials.active_record_encryption[:key_derivation_salt]
```

### Access Control

- Only website admins can view/edit integrations
- API keys are masked in UI (show only last 4 characters)
- Audit logging for credential changes
- Rate limiting on connection tests

### Credential Rotation

```ruby
# Support for credential rotation
class Pwb::WebsiteIntegration
  def rotate_credential(key, new_value)
    old_value = credential(key)
    set_credential(key, new_value)

    if test_connection
      save!
      AuditLog.record(:credential_rotated, self, key: key)
      true
    else
      set_credential(key, old_value)
      false
    end
  end
end
```

## Admin UI Design

### Navigation

```
Site Admin
├── Dashboard
├── Properties
├── ...
└── Integrations          <-- New section
    ├── AI Services
    │   ├── Anthropic     [Connected]
    │   └── OpenAI        [Not configured]
    ├── CRM
    │   └── Zoho          [Connected]
    ├── Email Marketing
    │   └── Mailchimp     [Not configured]
    └── ...
```

### Integration Card Component

Each integration displays as a card:

```
┌─────────────────────────────────────────────────────┐
│ [Icon] Anthropic                        [Connected] │
│                                                     │
│ AI-powered content generation using Claude models   │
│                                                     │
│ API Key: ••••••••••••sk-abc                        │
│ Default Model: claude-sonnet-4-20250514            │
│ Last used: 2 hours ago                             │
│                                                     │
│ [Test Connection]  [Configure]  [Disable]          │
└─────────────────────────────────────────────────────┘
```

### Configuration Modal

```
┌─────────────────────────────────────────────────────┐
│ Configure Anthropic                            [X]  │
├─────────────────────────────────────────────────────┤
│                                                     │
│ API Key *                                           │
│ ┌─────────────────────────────────────────────────┐ │
│ │ sk-ant-api03-...                                │ │
│ └─────────────────────────────────────────────────┘ │
│ Get your API key from console.anthropic.com         │
│                                                     │
│ Default Model                                       │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Claude Sonnet 4                            [v] │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│ Max Tokens                                          │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 4096                                            │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│              [Cancel]  [Test & Save]                │
└─────────────────────────────────────────────────────┘
```

## API Endpoints

### Site Admin API

```
GET    /api_manage/v1/:locale/integrations
       List all integrations for current website

GET    /api_manage/v1/:locale/integrations/available
       List all available integration providers by category

GET    /api_manage/v1/:locale/integrations/:id
       Get integration details (credentials masked)

POST   /api_manage/v1/:locale/integrations
       Create new integration
       Body: { category, provider, credentials, settings }

PATCH  /api_manage/v1/:locale/integrations/:id
       Update integration
       Body: { credentials, settings, enabled }

DELETE /api_manage/v1/:locale/integrations/:id
       Remove integration

POST   /api_manage/v1/:locale/integrations/:id/test
       Test integration connection
```

## Implementation Phases

### Phase 1: Foundation
- [ ] Create migration for `pwb_website_integrations`
- [ ] Create `Pwb::WebsiteIntegration` model with encryption
- [ ] Create base provider class and registry
- [ ] Add website association

### Phase 2: AI Provider Integration
- [ ] Create Anthropic provider definition
- [ ] Create OpenAI provider definition
- [ ] Update `Ai::BaseService` to use integrations
- [ ] Migrate any existing ENV-based config

### Phase 3: Admin UI
- [ ] Create integrations controller
- [ ] Create integrations index view (by category)
- [ ] Create integration configuration modal
- [ ] Add connection testing UI

### Phase 4: Additional Providers
- [ ] Zoho CRM provider (migrate from existing)
- [ ] Google Maps provider (migrate from `maps_api_key`)
- [ ] Email marketing providers

### Phase 5: Advanced Features
- [ ] Credential rotation support
- [ ] Usage analytics per integration
- [ ] Audit logging
- [ ] Webhook support for OAuth providers

## Example: Adding a New Provider

To add support for a new service (e.g., Mailchimp):

### 1. Create Provider Definition

```ruby
# app/services/integrations/providers/mailchimp.rb
module Integrations
  module Providers
    class Mailchimp < Base
      CATEGORY = :email_marketing

      credential_field :api_key, required: true
      credential_field :server_prefix, required: true  # e.g., "us21"

      setting_field :default_list_id, type: :string
      setting_field :double_optin, type: :boolean, default: true

      def validate_connection
        # Test Mailchimp API
        client = MailchimpMarketing::Client.new
        client.set_config({
          api_key: credential(:api_key),
          server: credential(:server_prefix)
        })
        client.ping.get
        true
      rescue => e
        errors.add(:base, e.message)
        false
      end
    end
  end
end

Integrations::Registry.register(:email_marketing, :mailchimp, Integrations::Providers::Mailchimp)
```

### 2. Create Service to Use Integration

```ruby
# app/services/email_marketing/mailchimp_service.rb
module EmailMarketing
  class MailchimpService
    def initialize(website:)
      @integration = website.integration_for(:email_marketing, provider: :mailchimp)
      raise ConfigurationError, "Mailchimp not configured" unless @integration
    end

    def subscribe(email:, list_id: nil)
      list = list_id || @integration.setting(:default_list_id)
      client.lists.add_list_member(list, {
        email_address: email,
        status: @integration.setting(:double_optin) ? 'pending' : 'subscribed'
      })
      @integration.record_usage!
    end

    private

    def client
      @client ||= begin
        c = MailchimpMarketing::Client.new
        c.set_config({
          api_key: @integration.credential(:api_key),
          server: @integration.credential(:server_prefix)
        })
        c
      end
    end
  end
end
```

## Migration Path for Existing Integrations

### Zoho CRM

Currently configured via Rails credentials. Migration:

```ruby
# Migration task
Website.find_each do |website|
  if Rails.application.credentials.zoho.present?
    website.integrations.create!(
      category: 'crm',
      provider: 'zoho',
      credentials: {
        client_id: Rails.application.credentials.zoho[:client_id],
        client_secret: Rails.application.credentials.zoho[:client_secret],
        refresh_token: Rails.application.credentials.zoho[:refresh_token]
      },
      settings: {
        api_domain: Rails.application.credentials.zoho[:api_domain]
      },
      enabled: true
    )
  end
end
```

### Google Maps

Currently stored in `pwb_websites.maps_api_key`. Migration:

```ruby
Website.where.not(maps_api_key: [nil, '']).find_each do |website|
  website.integrations.create!(
    category: 'maps',
    provider: 'google_maps',
    credentials: { api_key: website.maps_api_key },
    enabled: true
  )
end
```

## Testing

### Model Specs

```ruby
RSpec.describe Pwb::WebsiteIntegration do
  describe 'encryption' do
    it 'encrypts credentials at rest' do
      integration = create(:website_integration,
        credentials: { api_key: 'secret-key' })

      # Raw database value should be encrypted
      raw = integration.class.connection.select_value(
        "SELECT credentials FROM pwb_website_integrations WHERE id = #{integration.id}"
      )
      expect(raw).not_to include('secret-key')

      # But accessible via model
      expect(integration.credential(:api_key)).to eq('secret-key')
    end
  end

  describe '#test_connection' do
    it 'validates provider connection' do
      integration = create(:website_integration, :anthropic)
      allow_any_instance_of(Integrations::Providers::Anthropic)
        .to receive(:validate_connection).and_return(true)

      expect(integration.test_connection).to be true
    end
  end
end
```

## Appendix: Full Provider List

### AI Providers
| Provider | Credentials | Settings |
|----------|-------------|----------|
| Anthropic | api_key | default_model, max_tokens |
| OpenAI | api_key | default_model, max_tokens, organization_id |
| Google AI | api_key | default_model |

### CRM Providers
| Provider | Credentials | Settings |
|----------|-------------|----------|
| Zoho | client_id, client_secret, refresh_token | api_domain, sync_frequency |
| Salesforce | client_id, client_secret, refresh_token | instance_url |
| HubSpot | api_key | portal_id |

### Email Marketing Providers
| Provider | Credentials | Settings |
|----------|-------------|----------|
| Mailchimp | api_key, server_prefix | default_list_id, double_optin |
| SendGrid | api_key | default_sender |
| Mailerlite | api_key | group_id |

### Maps Providers
| Provider | Credentials | Settings |
|----------|-------------|----------|
| Google Maps | api_key | default_zoom, default_center |
| Mapbox | access_token | style_url |

### Payment Providers
| Provider | Credentials | Settings |
|----------|-------------|----------|
| Stripe | secret_key, publishable_key, webhook_secret | currency |
| PayPal | client_id, client_secret | environment |
