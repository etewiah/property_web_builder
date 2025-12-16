# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_subscription, class: 'Pwb::Subscription' do
    association :website, factory: :pwb_website
    association :plan, factory: :pwb_plan
    status { "trialing" }
    trial_ends_at { 14.days.from_now }
    current_period_starts_at { Time.current }
    current_period_ends_at { 14.days.from_now }

    trait :trialing do
      status { "trialing" }
      trial_ends_at { 14.days.from_now }
    end

    trait :trial_ending_soon do
      status { "trialing" }
      trial_ends_at { 2.days.from_now }
    end

    trait :trial_expired do
      status { "trialing" }
      trial_ends_at { 1.day.ago }
    end

    trait :active do
      status { "active" }
      trial_ends_at { nil }
      current_period_starts_at { Time.current }
      current_period_ends_at { 1.month.from_now }
    end

    trait :past_due do
      status { "past_due" }
      trial_ends_at { nil }
      current_period_starts_at { 1.month.ago }
      current_period_ends_at { Time.current }
    end

    trait :canceled do
      status { "canceled" }
      canceled_at { Time.current }
    end

    trait :expired do
      status { "expired" }
      trial_ends_at { 30.days.ago }
    end

    trait :with_external_ids do
      external_id { "sub_#{SecureRandom.hex(8)}" }
      external_customer_id { "cus_#{SecureRandom.hex(8)}" }
    end

    trait :cancel_at_period_end do
      cancel_at_period_end { true }
    end

    trait :yearly do
      association :plan, factory: [:pwb_plan, :yearly]
      current_period_ends_at { 1.year.from_now }
    end
  end
end
