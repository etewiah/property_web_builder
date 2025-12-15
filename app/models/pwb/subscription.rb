# frozen_string_literal: true

module Pwb
  # Subscription links a Website to a Plan and tracks its billing status
  #
  # Status flow:
  #   trialing -> active (when trial ends or payment received)
  #   trialing -> expired (if trial ends without payment)
  #   active -> past_due (if payment fails)
  #   active -> canceled (if user cancels)
  #   past_due -> active (if payment succeeds)
  #   past_due -> canceled (if payment continues to fail)
  #   canceled -> active (if user resubscribes)
  #
  class Subscription < ApplicationRecord
    include AASM

    self.table_name = 'pwb_subscriptions'

    # Associations
    belongs_to :website
    belongs_to :plan
    has_many :events, class_name: 'Pwb::SubscriptionEvent', dependent: :destroy

    # Validations
    validates :status, presence: true
    validates :website_id, uniqueness: true

    # Scopes
    scope :trialing, -> { where(status: 'trialing') }
    scope :active_subscriptions, -> { where(status: 'active') }
    scope :past_due, -> { where(status: 'past_due') }
    scope :canceled, -> { where(status: 'canceled') }
    scope :expired, -> { where(status: 'expired') }
    scope :active_or_trialing, -> { where(status: %w[active trialing]) }
    scope :expiring_soon, ->(days = 3) { where('trial_ends_at <= ?', days.days.from_now) }
    scope :trial_expired, -> { trialing.where('trial_ends_at < ?', Time.current) }

    # AASM State Machine
    aasm column: :status do
      state :trialing, initial: true
      state :active
      state :past_due
      state :canceled
      state :expired

      # Trial ends successfully (payment received or converted)
      event :activate do
        transitions from: [:trialing, :past_due, :canceled], to: :active
        after do
          log_event('activated')
          set_billing_period
        end
      end

      # Trial ends without payment
      event :expire_trial do
        transitions from: :trialing, to: :expired, guard: :trial_ended?
        after { log_event('trial_expired') }
      end

      # Payment fails
      event :mark_past_due do
        transitions from: :active, to: :past_due
        after { log_event('past_due') }
      end

      # User cancels subscription
      event :cancel do
        transitions from: [:active, :trialing, :past_due], to: :canceled
        after do
          update!(canceled_at: Time.current)
          log_event('canceled')
        end
      end

      # Subscription period ends after cancellation
      event :expire do
        transitions from: [:canceled, :past_due], to: :expired
        after { log_event('expired') }
      end

      # Reactivate a canceled subscription
      event :reactivate do
        transitions from: [:canceled, :expired], to: :active
        after do
          update!(canceled_at: nil, cancel_at_period_end: false)
          log_event('reactivated')
        end
      end
    end

    # Check if subscription is in good standing (can use the service)
    #
    # @return [Boolean]
    #
    def in_good_standing?
      trialing? || active?
    end

    # Check if subscription allows access (includes grace period for past_due)
    #
    # @return [Boolean]
    #
    def allows_access?
      trialing? || active? || past_due?
    end

    # Check if trial has ended
    #
    # @return [Boolean]
    #
    def trial_ended?
      trial_ends_at.present? && trial_ends_at < Time.current
    end

    # Days remaining in trial
    #
    # @return [Integer, nil] Days remaining or nil if not trialing
    #
    def trial_days_remaining
      return nil unless trialing? && trial_ends_at.present?

      days = ((trial_ends_at - Time.current) / 1.day).ceil
      [days, 0].max
    end

    # Check if approaching trial end
    #
    # @param days [Integer] Threshold in days
    # @return [Boolean]
    #
    def trial_ending_soon?(days: 3)
      trialing? && trial_days_remaining.present? && trial_days_remaining <= days
    end

    # Check property limit
    #
    # @param count [Integer] Current or proposed property count
    # @return [Boolean] True if within limit
    #
    def within_property_limit?(count)
      plan.unlimited_properties? || count <= plan.property_limit
    end

    # Check user limit
    #
    # @param count [Integer] Current or proposed user count
    # @return [Boolean] True if within limit
    #
    def within_user_limit?(count)
      plan.unlimited_users? || count <= plan.user_limit
    end

    # Remaining properties allowed
    #
    # @return [Integer, nil] Remaining count or nil if unlimited
    #
    def remaining_properties
      return nil if plan.unlimited_properties?

      current = website.realty_assets.count
      [plan.property_limit - current, 0].max
    end

    # Check if plan includes a feature
    #
    # @param feature_key [Symbol, String] Feature to check
    # @return [Boolean]
    #
    def has_feature?(feature_key)
      plan.has_feature?(feature_key)
    end

    # Change to a different plan
    #
    # @param new_plan [Plan] The new plan to switch to
    # @return [Boolean] Success status
    #
    def change_plan(new_plan)
      return false if new_plan == plan

      old_plan = plan
      self.plan = new_plan
      save.tap do |success|
        log_event('plan_changed', old_plan_id: old_plan.id, new_plan_id: new_plan.id) if success
      end
    end

    # Start a trial for this subscription
    #
    # @param days [Integer] Trial duration (uses plan default if not specified)
    #
    def start_trial(days: nil)
      trial_duration = days || plan.trial_days
      update!(
        status: 'trialing',
        trial_ends_at: trial_duration.days.from_now,
        current_period_starts_at: Time.current,
        current_period_ends_at: trial_duration.days.from_now
      )
      log_event('trial_started', trial_days: trial_duration)
    end

    private

    # Set the billing period based on plan interval
    #
    def set_billing_period
      interval = plan.billing_interval == 'year' ? 1.year : 1.month
      update!(
        current_period_starts_at: Time.current,
        current_period_ends_at: interval.from_now
      )
    end

    # Log a subscription event
    #
    # @param event_type [String] Type of event
    # @param metadata [Hash] Additional event data
    #
    def log_event(event_type, metadata = {})
      events.create!(
        event_type: event_type,
        metadata: metadata.merge(
          plan_id: plan_id,
          plan_slug: plan.slug,
          status: status
        )
      )
    end
  end
end
