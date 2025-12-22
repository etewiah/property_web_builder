# frozen_string_literal: true

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
