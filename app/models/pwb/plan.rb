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
    validates :trial_days, presence: true, numericality: { greater_than_or_equal_to: 0 }

    # Scopes
    scope :active, -> { where(active: true) }
    scope :public_plans, -> { where(public: true) }
    scope :ordered, -> { order(position: :asc) }
    scope :for_display, -> { active.public_plans.ordered }

    # Feature keys - define all possible features here
    FEATURES = {
      basic_themes: 'Access to basic themes',
      premium_themes: 'Access to premium themes',
      analytics: 'Website analytics dashboard',
      custom_domain: 'Use your own custom domain',
      api_access: 'API access for integrations',
      white_label: 'Remove PropertyWebBuilder branding',
      priority_support: 'Priority email support',
      dedicated_support: 'Dedicated account manager'
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
  end
end
