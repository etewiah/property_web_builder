# frozen_string_literal: true

module Pwb
  # Stores user-saved (favorited) external properties.
  # Users can save properties without logging in (email-only).
  # Property data is cached to display without API calls.
# == Schema Information
#
# Table name: pwb_saved_properties
#
#  id                   :bigint           not null, primary key
#  current_price_cents  :integer
#  email                :string           not null
#  external_reference   :string           not null
#  manage_token         :string           not null
#  notes                :text
#  original_price_cents :integer
#  price_changed_at     :datetime
#  property_data        :jsonb            not null
#  provider             :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  website_id           :bigint           not null
#
# Indexes
#
#  index_pwb_saved_properties_on_email                 (email)
#  index_pwb_saved_properties_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_properties_on_website_id            (website_id)
#  index_pwb_saved_properties_on_website_id_and_email  (website_id,email)
#  index_saved_properties_on_provider_ref              (website_id,provider,external_reference)
#  index_saved_properties_unique_per_email             (email,provider,external_reference) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
      raw_price = property_data_hash[:price]
      return nil unless raw_price

      # Handle Money-like hash format from internal properties: {"cents" => 27500000, "currency_iso" => "USD"}
      if raw_price.is_a?(Hash)
        cents = raw_price[:cents] || raw_price["cents"]
        cents.to_i / 100 if cents
      else
        raw_price.to_i
      end
    end

    def price_formatted
      return nil unless price

      # Get currency - check both formats
      raw_price = property_data_hash[:price]
      currency = if raw_price.is_a?(Hash)
                   raw_price[:currency_iso] || raw_price["currency_iso"] || property_data_hash[:currency] || "EUR"
                 else
                   property_data_hash[:currency] || "EUR"
                 end

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
      data = data.is_a?(Hash) ? data.deep_symbolize_keys : data.to_h.deep_symbolize_keys
      raw_price = data[:price]
      return nil unless raw_price

      # Handle Money-like hash format: {"cents" => 27500000, "currency_iso" => "USD"}
      if raw_price.is_a?(Hash)
        raw_price[:cents] || raw_price["cents"]
      else
        # Price might already be in cents or whole units
        raw_price.to_i
      end
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
