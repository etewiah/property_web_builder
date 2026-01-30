# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ai_generation_requests
# Database name: primary
#
#  id            :bigint           not null, primary key
#  ai_model      :string
#  ai_provider   :string           default("anthropic")
#  cost_cents    :integer
#  error_message :text
#  input_data    :jsonb
#  input_tokens  :integer
#  locale        :string           default("en")
#  output_data   :jsonb
#  output_tokens :integer
#  request_type  :string           not null
#  status        :string           default("pending")
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  prop_id       :bigint
#  user_id       :bigint
#  website_id    :bigint           not null
#
# Indexes
#
#  idx_on_website_id_request_type_fcf3872c0b                     (website_id,request_type)
#  index_pwb_ai_generation_requests_on_prop_id                   (prop_id)
#  index_pwb_ai_generation_requests_on_prop_id_and_request_type  (prop_id,request_type)
#  index_pwb_ai_generation_requests_on_user_id                   (user_id)
#  index_pwb_ai_generation_requests_on_website_id                (website_id)
#  index_pwb_ai_generation_requests_on_website_id_and_status     (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (prop_id => pwb_props.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
