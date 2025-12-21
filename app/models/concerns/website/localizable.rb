# frozen_string_literal: true

# Website::Localizable
#
# Manages locale and internationalization settings.
# Handles supported locales, default locale, and multilingual detection.
#
module Website
  module Localizable
    extend ActiveSupport::Concern

    included do
      validate :default_locale_in_supported_locales
    end

    # Check if website supports multiple languages
    def is_multilingual
      supported_locales.reject(&:blank?).length > 1
    end

    # Get supported locales with their variants
    def supported_locales_with_variants
      result = []
      supported_locales.reject(&:blank?).each do |supported_locale|
        slwv_array = supported_locale.split("-")
        locale = slwv_array[0] || "en"
        variant = slwv_array[1] || slwv_array[0] || "UK"
        result.push({ "locale" => locale, "variant" => variant.downcase })
      end
      result
    end

    # Get the effective default client locale
    def default_client_locale_to_use
      locale = default_client_locale || "en-UK"
      if supported_locales && supported_locales.count == 1
        locale = supported_locales.first
      end
      locale.split("-")[0]
    end

    private

    def default_locale_in_supported_locales
      return if default_client_locale.blank?
      return if supported_locales.blank?

      default_base = default_client_locale.to_s.split('-').first.downcase
      supported_bases = supported_locales.reject(&:blank?).map { |l| l.to_s.split('-').first.downcase }

      unless supported_bases.include?(default_base)
        errors.add(:default_client_locale, "must be one of the supported languages")
      end
    end
  end
end
