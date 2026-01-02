# frozen_string_literal: true

module Pwb
  # Stores user-saved (favorited) external properties.
  # Users can save properties without logging in (email-only).
  # Property data is cached to display without API calls.
  # Price tracking is included for future notification support.
  class SavedProperty < ApplicationRecord
    self.table_name = "pwb_saved_properties"

    # Associations
    belongs_to :website

    # Validations
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :provider, presence: true
    validates :external_reference, presence: true
    validates :manage_token, presence: true, uniqueness: true
    validates :external_reference, uniqueness: {
      scope: [:email, :provider],
      message: "has already been saved"
    }

    # Callbacks
    before_validation :generate_manage_token, on: :create
    before_validation :normalize_email
    before_save :track_price_change

    # Scopes
    scope :for_email, ->(email) { where(email: email.to_s.downcase.strip) }
    scope :for_provider, ->(provider) { where(provider: provider) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_price_change, -> { where.not(price_changed_at: nil) }

    # Instance methods
    def property_data_hash
      (property_data || {}).deep_symbolize_keys
    end

    def title
      property_data_hash[:title] || "Property #{external_reference}"
    end

    def price
      property_data_hash[:price]
    end

    def price_formatted
      return nil unless price

      currency = property_data_hash[:currency] || "EUR"
      "#{currency} #{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    def location
      property_data_hash[:city] || property_data_hash[:location]
    end

    def bedrooms
      property_data_hash[:bedrooms]
    end

    def bathrooms
      property_data_hash[:bathrooms]
    end

    def main_image
      images = property_data_hash[:images] || []
      images.first
    end

    def listing_type
      property_data_hash[:listing_type] || :sale
    end

    def price_changed?
      price_changed_at.present? && original_price_cents != current_price_cents
    end

    def price_increased?
      price_changed? && current_price_cents.to_i > original_price_cents.to_i
    end

    def price_decreased?
      price_changed? && current_price_cents.to_i < original_price_cents.to_i
    end

    def price_change_percentage
      return 0 unless price_changed? && original_price_cents.to_i > 0

      ((current_price_cents.to_i - original_price_cents.to_i) / original_price_cents.to_f * 100).round(1)
    end

    def update_property_data!(data)
      update!(property_data: data.is_a?(Hash) ? data : data.to_h)
    end

    def manage_url(host:)
      "#{host}/my/favorites?token=#{manage_token}"
    end

    # Class method to find or create a saved property
    def self.save_property!(website:, email:, provider:, reference:, property_data:)
      normalized_email = email.to_s.downcase.strip

      find_or_create_by!(
        website: website,
        email: normalized_email,
        provider: provider,
        external_reference: reference
      ) do |sp|
        sp.property_data = property_data.is_a?(Hash) ? property_data : property_data.to_h
        sp.original_price_cents = extract_price_cents(property_data)
        sp.current_price_cents = sp.original_price_cents
      end
    end

    def self.extract_price_cents(data)
      data = data.is_a?(Hash) ? data : data.to_h
      price = data[:price] || data["price"]
      return nil unless price

      # Price might already be in cents or whole units
      price.to_i
    end

    private

    def generate_manage_token
      self.manage_token ||= SecureRandom.urlsafe_base64(32)
    end

    def normalize_email
      self.email = email.to_s.downcase.strip if email.present?
    end

    def track_price_change
      return unless property_data_changed?
      return unless persisted?

      new_price = self.class.extract_price_cents(property_data)
      return unless new_price && current_price_cents && new_price != current_price_cents

      self.current_price_cents = new_price
      self.price_changed_at = Time.current
    end
  end
end
