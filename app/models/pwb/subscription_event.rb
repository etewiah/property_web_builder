# frozen_string_literal: true

module Pwb
  # SubscriptionEvent is an audit log for subscription changes
  #
  # Event types:
  #   - trial_started: Trial period began
  #   - activated: Subscription became active
  #   - trial_expired: Trial ended without conversion
  #   - past_due: Payment failed
  #   - canceled: User canceled subscription
  #   - expired: Subscription period ended
  #   - reactivated: Subscription was reactivated
  #   - plan_changed: User switched plans
  #
  class SubscriptionEvent < ApplicationRecord
    self.table_name = 'pwb_subscription_events'

    # Associations
    belongs_to :subscription

    # Validations
    validates :event_type, presence: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(event_type: type) }

    # Known event types
    EVENT_TYPES = %w[
      trial_started
      activated
      trial_expired
      past_due
      canceled
      expired
      reactivated
      plan_changed
      payment_received
      payment_failed
    ].freeze

    # Get the plan associated with this event (from metadata)
    #
    # @return [Plan, nil]
    #
    def plan
      return nil unless metadata['plan_id']

      Pwb::Plan.find_by(id: metadata['plan_id'])
    end
  end
end
