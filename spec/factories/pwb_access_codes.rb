# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_access_codes
# Database name: primary
#
#  id         :uuid             not null, primary key
#  active     :boolean          default(TRUE), not null
#  code       :string           not null
#  expires_at :datetime
#  max_uses   :integer
#  uses_count :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_access_codes_on_website_id           (website_id)
#  index_pwb_access_codes_on_website_id_and_code  (website_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_access_code, class: 'Pwb::AccessCode' do
    association :website, factory: :pwb_website
    sequence(:code) { |n| "CODE#{n}" }
    active { true }
    uses_count { 0 }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :exhausted do
      max_uses { 1 }
      uses_count { 1 }
    end

    trait :inactive do
      active { false }
    end

    trait :limited do
      max_uses { 10 }
    end
  end
end
