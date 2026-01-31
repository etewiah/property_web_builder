# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_website_integrations
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  category           :string           not null
#  credentials        :text
#  enabled            :boolean          default(TRUE)
#  last_error_at      :datetime
#  last_error_message :text
#  last_used_at       :datetime
#  provider           :string           not null
#  settings           :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  idx_website_integrations_unique_provider                   (website_id,category,provider) UNIQUE
#  index_pwb_website_integrations_on_website_id               (website_id)
#  index_pwb_website_integrations_on_website_id_and_category  (website_id,category)
#  index_pwb_website_integrations_on_website_id_and_enabled   (website_id,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_website_integration, class: 'Pwb::WebsiteIntegration' do
    website

    category { 'ai' }
    provider { 'anthropic' }
    credentials { { 'api_key' => 'test-api-key-12345' } }
    settings { { 'default_model' => 'claude-sonnet-4-20250514' } }
    enabled { true }

    trait :anthropic do
      category { 'ai' }
      provider { 'anthropic' }
      credentials { { 'api_key' => 'test-anthropic-key' } }
      settings { { 'default_model' => 'claude-sonnet-4-20250514', 'max_tokens' => 4096 } }
    end

    trait :openai do
      category { 'ai' }
      provider { 'openai' }
      credentials { { 'api_key' => 'test-openai-key', 'organization_id' => 'org-123' } }
      settings { { 'default_model' => 'gpt-4o-mini', 'max_tokens' => 4096 } }
    end

    trait :open_router do
      category { 'ai' }
      provider { 'open_router' }
      credentials { { 'api_key' => 'sk-or-test-key-12345' } }
      settings { { 'default_model' => 'anthropic/claude-3.5-sonnet', 'max_tokens' => 4096 } }
    end

    trait :disabled do
      enabled { false }
    end

    trait :with_error do
      last_error_at { 1.hour.ago }
      last_error_message { 'Connection failed: Invalid API key' }
    end

    trait :recently_used do
      last_used_at { 5.minutes.ago }
    end

    trait :without_credentials do
      credentials { {} }
    end
  end
end
