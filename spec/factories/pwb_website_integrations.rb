# frozen_string_literal: true

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
