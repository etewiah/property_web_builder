# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_subscription_events
# Database name: primary
#
#  id              :bigint           not null, primary key
#  event_type      :string           not null
#  metadata        :jsonb            not null
#  created_at      :datetime         not null
#  subscription_id :bigint           not null
#
# Indexes
#
#  idx_on_subscription_id_created_at_3fabb76699      (subscription_id,created_at)
#  index_pwb_subscription_events_on_event_type       (event_type)
#  index_pwb_subscription_events_on_subscription_id  (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (subscription_id => pwb_subscriptions.id)
#
FactoryBot.define do
  factory :pwb_subscription_event, class: 'Pwb::SubscriptionEvent' do
    association :subscription, factory: :pwb_subscription
    event_type { 'trial_started' }
    metadata { {} }

    trait :trial_started do
      event_type { 'trial_started' }
      metadata { { 'trial_days' => 14 } }
    end

    trait :activated do
      event_type { 'activated' }
      metadata { { 'source' => 'subscription_start' } }
    end

    trait :trial_expired do
      event_type { 'trial_expired' }
    end

    trait :past_due do
      event_type { 'past_due' }
      metadata { { 'days_past_due' => 3 } }
    end

    trait :canceled do
      event_type { 'canceled' }
      metadata { { 'reason' => 'user_requested' } }
    end

    trait :expired do
      event_type { 'expired' }
    end

    trait :reactivated do
      event_type { 'reactivated' }
    end

    trait :plan_changed do
      event_type { 'plan_changed' }
      metadata { { 'old_plan_id' => 1, 'new_plan_id' => 2 } }
    end

    trait :payment_received do
      event_type { 'payment_received' }
      metadata { { 'amount_cents' => 9900, 'currency' => 'USD' } }
    end

    trait :payment_failed do
      event_type { 'payment_failed' }
      metadata { { 'reason' => 'card_declined' } }
    end

    trait :with_plan do
      transient do
        plan { nil }
      end

      after(:build) do |event, evaluator|
        if evaluator.plan
          event.metadata['plan_id'] = evaluator.plan.id
        end
      end
    end
  end
end
