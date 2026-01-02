# frozen_string_literal: true

module Pwb
  # Stores saved search criteria for external property feeds.
  # Users can save searches without logging in (email-only) and
# == Schema Information
#
# Table name: pwb_saved_searches
#
#  id                 :bigint           not null, primary key
#  alert_frequency    :integer          default("none"), not null
#  email              :string           not null
#  email_verified     :boolean          default(FALSE), not null
#  enabled            :boolean          default(TRUE), not null
#  last_result_count  :integer          default(0)
#  last_run_at        :datetime
#  manage_token       :string           not null
#  name               :string
#  search_criteria    :jsonb            not null
#  seen_property_refs :jsonb            not null
#  unsubscribe_token  :string           not null
#  verification_token :string
#  verified_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_saved_searches_on_email                 (email)
#  index_pwb_saved_searches_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_searches_on_unsubscribe_token     (unsubscribe_token) UNIQUE
#  index_pwb_saved_searches_on_verification_token    (verification_token) UNIQUE
#  index_pwb_saved_searches_on_website_id            (website_id)
#  index_pwb_saved_searches_on_website_id_and_email  (website_id,email)
#  index_saved_searches_for_alerts                   (website_id,enabled,alert_frequency)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  # receive daily or weekly email alerts for new properties.
  class SavedSearch < ApplicationRecord
    self.table_name = "pwb_saved_searches"

    # Associations
    belongs_to :website
    has_many :alerts, class_name: "Pwb::SearchAlert",
             foreign_key: :saved_search_id, dependent: :destroy

    # Enums
    enum :alert_frequency, {
      none: 0,
      daily: 1,
      weekly: 2
    }, prefix: :frequency

    # Validations
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :search_criteria, presence: true
    validates :unsubscribe_token, presence: true, uniqueness: true
    validates :manage_token, presence: true, uniqueness: true

    # Callbacks
    before_validation :generate_tokens, on: :create
    before_validation :generate_name, on: :create
    before_validation :normalize_email

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :with_alerts, -> { where.not(alert_frequency: :none) }
    scope :daily_alerts, -> { enabled.where(alert_frequency: :daily) }
    scope :weekly_alerts, -> { enabled.where(alert_frequency: :weekly) }
    scope :for_email, ->(email) { where(email: email.to_s.downcase.strip) }
    scope :verified, -> { where(email_verified: true) }
    scope :needs_run, ->(frequency) {
      enabled
        .where(alert_frequency: frequency)
        .where("last_run_at IS NULL OR last_run_at < ?", frequency_cutoff(frequency))
    }

    # Class methods
    def self.frequency_cutoff(frequency)
      case frequency.to_sym
      when :daily then 23.hours.ago
      when :weekly then 6.days.ago
      else Time.current
      end
    end

    # Instance methods
    def search_criteria_hash
      (search_criteria || {}).deep_symbolize_keys
    end

    def listing_type
      search_criteria_hash[:listing_type] || "sale"
    end

    def location
      search_criteria_hash[:location]
    end

    def price_range
      min = search_criteria_hash[:min_price]
      max = search_criteria_hash[:max_price]
      return nil unless min || max

      "#{min || '0'} - #{max || 'unlimited'}"
    end

    def bedrooms_range
      min = search_criteria_hash[:min_bedrooms]
      max = search_criteria_hash[:max_bedrooms]
      return nil unless min || max

      if max
        "#{min || 0}-#{max}"
      else
        "#{min}+"
      end
    end

    def criteria_summary
      parts = []
      parts << listing_type.to_s.titleize
      parts << location if location.present?
      parts << price_range if price_range
      parts << "#{bedrooms_range} beds" if bedrooms_range
      parts.join(", ")
    end

    def record_new_properties!(property_refs)
      return if property_refs.empty?

      current_refs = seen_property_refs || []
      new_refs = (current_refs + property_refs).uniq.last(1000) # Keep last 1000
      update!(seen_property_refs: new_refs)
    end

    def find_new_properties(current_refs)
      seen = seen_property_refs || []
      current_refs.reject { |ref| seen.include?(ref) }
    end

    def mark_run!(result_count:)
      update!(
        last_run_at: Time.current,
        last_result_count: result_count
      )
    end

    def unsubscribe!
      update!(enabled: false, alert_frequency: :none)
    end

    def verify_email!
      update!(
        email_verified: true,
        verified_at: Time.current,
        verification_token: nil
      )
    end

    def generate_verification_token!
      update!(verification_token: SecureRandom.urlsafe_base64(32))
      verification_token
    end

    def verification_url(host:)
      "#{host}/my/saved_searches/verify?token=#{verification_token}"
    end

    def manage_url(host:)
      "#{host}/my/saved_searches?token=#{manage_token}"
    end

    def unsubscribe_url(host:)
      "#{host}/my/saved_searches/unsubscribe?token=#{unsubscribe_token}"
    end

    private

    def generate_tokens
      self.unsubscribe_token ||= SecureRandom.urlsafe_base64(32)
      self.manage_token ||= SecureRandom.urlsafe_base64(32)
    end

    def generate_name
      return if name.present?

      self.name = criteria_summary.presence || "Property Search"
    end

    def normalize_email
      self.email = email.to_s.downcase.strip if email.present?
    end
  end
end
