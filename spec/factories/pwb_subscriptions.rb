# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_subscriptions
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  cancel_at_period_end     :boolean          default(FALSE), not null
#  canceled_at              :datetime
#  current_period_ends_at   :datetime
#  current_period_starts_at :datetime
#  external_provider        :string
#  metadata                 :jsonb            not null
#  status                   :string           default("trialing"), not null
#  trial_ends_at            :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_customer_id     :string
#  external_id              :string
#  plan_id                  :bigint           not null
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_subscriptions_on_current_period_ends_at  (current_period_ends_at)
#  index_pwb_subscriptions_on_external_id             (external_id) UNIQUE WHERE (external_id IS NOT NULL)
#  index_pwb_subscriptions_on_plan_id                 (plan_id)
#  index_pwb_subscriptions_on_status                  (status)
#  index_pwb_subscriptions_on_trial_ends_at           (trial_ends_at)
#  index_pwb_subscriptions_on_website_unique          (website_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (plan_id => pwb_plans.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
