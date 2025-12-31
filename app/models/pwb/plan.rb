# frozen_string_literal: true

module Pwb
  # Plan represents a subscription tier with pricing, limits, and features
  #
  # Features are stored as a JSON array of feature keys, e.g.:
  #   ['basic_themes', 'premium_themes', 'analytics', 'custom_domain', 'api_access', 'white_label']
  #
  # Example plans:
  #   starter:      $29/mo, 25 properties, basic_themes
  #   professional: $79/mo, 100 properties, premium_themes, analytics, custom_domain
  #   enterprise:   $199/mo, unlimited, all features
# == Schema Information
#
# Table name: pwb_plans
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  billing_interval :string           default("month"), not null
#  description      :text
#  display_name     :string           not null
#  features         :jsonb            not null
#  name             :string           not null
#  position         :integer          default(0), not null
#  price_cents      :integer          default(0), not null
#  price_currency   :string           default("USD"), not null
#  property_limit   :integer
#  public           :boolean          default(TRUE), not null
#  slug             :string           not null
#  trial_days       :integer          default(14), not null
#  trial_unit       :string           default("days")
#  trial_value      :integer          default(14)
#  user_limit       :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_pwb_plans_on_active_and_position  (active,position)
#  index_pwb_plans_on_slug                 (slug) UNIQUE
#
  class Plan < ApplicationRecord
    self.table_name = 'pwb_plans'

    # Associations
    has_many :subscriptions, dependent: :restrict_with_error

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true,
              format: { with: /\A[a-z0-9\-]+\z/, message: 'only allows lowercase letters, numbers, and hyphens' }
    validates :display_name, presence: true
    validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :price_currency, presence: true
    validates :billing_interval, presence: true, inclusion: { in: %w[month year] }
    validates :trial_days, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true # deprecated
    validates :trial_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :trial_unit, inclusion: { in: %w[days weeks months] }, allow_nil: true

    # Valid trial units
    TRIAL_UNITS = %w[days weeks months].freeze

    # Scopes
    scope :active, -> { where(active: true) }
    scope :public_plans, -> { where(public: true) }
    scope :ordered, -> { order(position: :asc) }
    scope :for_display, -> { active.public_plans.ordered }

    # Feature keys - define all possible features here
    FEATURES = {
      # Themes
      default_theme: 'Default theme only',
      all_themes: 'Access to all themes',
      custom_theme: 'Custom theme design',

      # Domain
      subdomain_only: 'PWB subdomain (yourname.propertywebbuilder.com)',
      custom_domain: 'Use your own custom domain',

      # Languages
      single_language: 'English only',
      multi_language_3: 'Up to 3 languages',
      multi_language_8: 'Up to 8 languages',

      # Support
      email_support: 'Email support',
      priority_support: 'Priority support',
      dedicated_support: 'Dedicated account manager',

      # Features
      ssl_included: 'SSL certificate included',
      analytics: 'Analytics dashboard',
      custom_integrations: 'Custom 3rd party integrations',
      api_access: 'API access for integrations',
      white_label: 'Remove PropertyWebBuilder branding'
    }.freeze

    # Check if this plan includes a specific feature
    #
    # @param feature_key [Symbol, String] The feature to check
    # @return [Boolean]
    #
    def has_feature?(feature_key)
      features.include?(feature_key.to_s)
    end

    # Get list of enabled features with descriptions
    #
    # @return [Array<Hash>] Array of { key:, description: } hashes
    #
    def enabled_features
      features.map do |key|
        { key: key, description: FEATURES[key.to_sym] || key.humanize }
      end
    end

    # Check if this plan has unlimited properties
    #
    # @return [Boolean]
    #
    def unlimited_properties?
      property_limit.nil?
    end

    # Check if this plan has unlimited users
    #
    # @return [Boolean]
    #
    def unlimited_users?
      user_limit.nil?
    end

    # Get formatted price string
    #
    # @return [String] e.g., "$29/month" or "$290/year"
    #
    def formatted_price
      return 'Free' if price_cents.zero?

      price = price_cents / 100.0
      currency_symbol = case price_currency.upcase
                        when 'USD' then '$'
                        when 'EUR' then '€'
                        when 'GBP' then '£'
                        else price_currency
                        end

      "#{currency_symbol}#{price.to_i}/#{billing_interval}"
    end

    # Get monthly equivalent price (for annual plans)
    #
    # @return [Integer] Price in cents per month
    #
    def monthly_price_cents
      billing_interval == 'year' ? (price_cents / 12.0).round : price_cents
    end

    # Class method to find by slug
    #
    # @param slug [String] The plan slug
    # @return [Plan, nil]
    #
    def self.find_by_slug(slug)
      find_by(slug: slug.to_s.downcase)
    end

    # Class method to get the default/starter plan
    #
    # @return [Plan]
    #
    def self.default_plan
      find_by(slug: 'starter') || active.ordered.first
    end

    # Calculate trial end date from a start date
    # Uses trial_value + trial_unit for flexible duration
    #
    # @param start_date [Date, Time] The trial start date
    # @return [Date] The trial end date
    #
    def trial_end_date(start_date = Date.current)
      start_date = start_date.to_date if start_date.respond_to?(:to_date)
      return start_date unless has_trial?

      start_date + trial_duration
    end

    # Get the trial duration as an ActiveSupport::Duration
    #
    # @return [ActiveSupport::Duration]
    #
    def trial_duration
      return 0.days unless has_trial?

      value = effective_trial_value
      unit = effective_trial_unit

      case unit
      when 'months' then value.months
      when 'weeks' then value.weeks
      else value.days
      end
    end

    # Check if this plan has a trial period
    #
    # @return [Boolean]
    #
    def has_trial?
      effective_trial_value.present? && effective_trial_value > 0
    end

    # Get formatted trial period string
    #
    # @return [String] e.g., "1 month", "2 weeks", "14 days", "No trial"
    #
    def formatted_trial_period
      return 'No trial' unless has_trial?

      value = effective_trial_value
      unit = effective_trial_unit

      # Singularize unit if value is 1
      unit_label = value == 1 ? unit.singularize : unit
      "#{value} #{unit_label}"
    end

    private

    # Get effective trial value (new field or legacy)
    def effective_trial_value
      trial_value.presence || trial_days
    end

    # Get effective trial unit (new field or legacy default)
    def effective_trial_unit
      trial_unit.presence || 'days'
    end
  end
end
