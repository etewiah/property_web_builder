# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_subdomains
#
#  id                :bigint           not null, primary key
#  aasm_state        :string           default("available"), not null
#  name              :string           not null
#  reserved_at       :datetime
#  reserved_by_email :string
#  reserved_until    :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  website_id        :bigint
#
# Indexes
#
#  index_pwb_subdomains_on_aasm_state           (aasm_state)
#  index_pwb_subdomains_on_aasm_state_and_name  (aasm_state,name)
#  index_pwb_subdomains_on_name                 (name) UNIQUE
#  index_pwb_subdomains_on_website_id           (website_id)
#  index_subdomains_unique_reserved_email       (reserved_by_email) UNIQUE WHERE (((aasm_state)::text = 'reserved'::text) AND (reserved_by_email IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_subdomain, class: 'Pwb::Subdomain' do
    sequence(:name) { |n| "test-site-#{n}" }
    aasm_state { 'available' }

    trait :reserved do
      aasm_state { 'reserved' }
      reserved_at { Time.current }
      reserved_until { 24.hours.from_now }
      sequence(:reserved_by_email) { |n| "reserved-user-#{n}@example.com" }
    end

    trait :allocated do
      aasm_state { 'allocated' }
      association :website, factory: :pwb_website
    end

    trait :expired do
      reserved
      reserved_until { 1.hour.ago }
    end
  end
end
