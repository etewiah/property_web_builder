# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_ai_generation_request, class: 'Pwb::AiGenerationRequest' do
    association :website, factory: :pwb_website

    request_type { 'listing_description' }
    ai_provider { 'anthropic' }
    ai_model { 'claude-sonnet-4-20250514' }
    status { 'pending' }
    locale { 'en' }
    input_data { {} }
    output_data { {} }

    trait :pending do
      status { 'pending' }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
      input_tokens { 150 }
      output_tokens { 200 }
      output_data do
        {
          title: 'Test Property Title',
          description: 'Test property description.',
          meta_description: 'Test meta description.',
          compliance: { compliant: true, violations: [] }
        }
      end
    end

    trait :failed do
      status { 'failed' }
      error_message { 'AI API error: Request failed' }
    end

    trait :with_property_context do
      transient do
        property { nil }
      end

      input_data do
        if property
          {
            property_id: property.id,
            property_class: property.class.name,
            type: property.prop_type_key,
            bedrooms: property.count_bedrooms,
            bathrooms: property.count_bathrooms
          }
        else
          {
            property_id: SecureRandom.uuid,
            property_class: 'Pwb::RealtyAsset',
            type: 'apartment',
            bedrooms: 2,
            bathrooms: 1
          }
        end
      end
    end

    trait :for_listing_description do
      request_type { 'listing_description' }
    end

    trait :for_social_post do
      request_type { 'social_post' }
    end
  end
end
