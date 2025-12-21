# frozen_string_literal: true

module Pwb
  # Central configuration module for PropertyWebBuilder
  #
  # This module serves as the single source of truth for application-wide
  # configuration that was previously scattered across initializers,
  # controllers, and views.
  #
  # Usage:
  #   Pwb::Config::SUPPORTED_LOCALES
  #   Pwb::Config.locale_options_for_select
  #   Pwb::Config.currency_options_for_select
  #
  module Config
    # ==========================================================================
    # LOCALES
    # ==========================================================================
    # Supported languages with their display labels
    # Keys are locale codes, values are human-readable labels
    SUPPORTED_LOCALES = {
      'en' => 'English',
      'es' => 'Spanish',
      'de' => 'German',
      'fr' => 'French',
      'nl' => 'Dutch',
      'pt' => 'Portuguese',
      'it' => 'Italian'
    }.freeze

    # Base locales for I18n configuration
    # Used for translation file loading and fallbacks
    BASE_LOCALES = %i[en es de fr nl pt it].freeze

    # ==========================================================================
    # CURRENCIES
    # ==========================================================================
    # Supported currencies with code, label, and symbol
    CURRENCIES = {
      'USD' => { label: 'US Dollar', symbol: '$' },
      'EUR' => { label: 'Euro', symbol: "\u20AC" },
      'GBP' => { label: 'British Pound', symbol: "\u00A3" },
      'CHF' => { label: 'Swiss Franc', symbol: 'CHF' },
      'CAD' => { label: 'Canadian Dollar', symbol: 'CA$' },
      'AUD' => { label: 'Australian Dollar', symbol: 'A$' },
      'JPY' => { label: 'Japanese Yen', symbol: "\u00A5" },
      'CNY' => { label: 'Chinese Yuan', symbol: "\u00A5" },
      'INR' => { label: 'Indian Rupee', symbol: "\u20B9" },
      'BRL' => { label: 'Brazilian Real', symbol: 'R$' },
      'MXN' => { label: 'Mexican Peso', symbol: 'MX$' },
      'PLN' => { label: 'Polish Zloty', symbol: "z\u0142" },
      'RUB' => { label: 'Russian Ruble', symbol: "\u20BD" },
      'SEK' => { label: 'Swedish Krona', symbol: 'kr' },
      'NOK' => { label: 'Norwegian Krone', symbol: 'kr' },
      'DKK' => { label: 'Danish Krone', symbol: 'kr' },
      'TRY' => { label: 'Turkish Lira', symbol: "\u20BA" },
      'ZAR' => { label: 'South African Rand', symbol: 'R' },
      'AED' => { label: 'UAE Dirham', symbol: 'AED' },
      'SGD' => { label: 'Singapore Dollar', symbol: 'S$' },
      'HKD' => { label: 'Hong Kong Dollar', symbol: 'HK$' },
      'NZD' => { label: 'New Zealand Dollar', symbol: 'NZ$' }
    }.freeze

    # ==========================================================================
    # AREA UNITS
    # ==========================================================================
    # Supported area measurement units
    AREA_UNITS = {
      'sqmt' => { label: 'Square Meters', abbreviation: 'sqm', symbol: 'm\u00B2' },
      'sqft' => { label: 'Square Feet', abbreviation: 'sqft', symbol: 'ft\u00B2' }
    }.freeze

    # ==========================================================================
    # PROPERTY FIELD KEY CATEGORIES
    # ==========================================================================
    # Categories for organizing property field keys
    # Used by both settings_controller and props_controller
    FIELD_KEY_CATEGORIES = {
      'property-types' => {
        url_key: 'property_types',
        title: 'Property Types',
        short_title: 'Property Type',
        description: 'Define what types of properties can be listed (e.g., Apartment, Villa, Office)',
        short_description: 'What type of property is this?'
      },
      'property-states' => {
        url_key: 'property_states',
        title: 'Property States',
        short_title: 'Property State',
        description: 'Define physical condition options (e.g., New Build, Needs Renovation)',
        short_description: 'Physical condition of the property'
      },
      'property-features' => {
        url_key: 'property_features',
        title: 'Features',
        short_title: 'Features',
        description: 'Define permanent physical attributes (e.g., Pool, Garden, Terrace)',
        short_description: 'Permanent physical attributes'
      },
      'property-amenities' => {
        url_key: 'property_amenities',
        title: 'Amenities',
        short_title: 'Amenities',
        description: 'Define equipment and services (e.g., Air Conditioning, Heating, Elevator)',
        short_description: 'Equipment and services'
      },
      'property-status' => {
        url_key: 'property_status',
        title: 'Status Labels',
        short_title: 'Status',
        description: 'Define transaction status labels (e.g., Sold, Reserved, Under Offer)',
        short_description: 'Transaction status'
      },
      'property-highlights' => {
        url_key: 'property_highlights',
        title: 'Highlights',
        short_title: 'Highlights',
        description: 'Define marketing highlight labels (e.g., Featured, Luxury, Price Reduced)',
        short_description: 'Marketing flags'
      },
      'listing-origin' => {
        url_key: 'listing_origin',
        title: 'Listing Origin',
        short_title: 'Listing Origin',
        description: 'Define listing source options (e.g., Direct Entry, MLS Feed, Partner)',
        short_description: 'Source of the listing'
      }
    }.freeze

    # ==========================================================================
    # HELPER METHODS
    # ==========================================================================

    class << self
      # Returns locale options formatted for Rails select helpers
      # @return [Array<Array<String>>] Array of [label, code] pairs
      def locale_options_for_select
        SUPPORTED_LOCALES.map { |code, label| [label, code] }
      end

      # Returns locale label for a given code
      # @param code [String] The locale code
      # @return [String] The human-readable label
      def locale_label(code)
        SUPPORTED_LOCALES[code.to_s] || code.to_s.upcase
      end

      # Returns the base locale from a regional variant
      # @param code [String] The locale code (e.g., 'en-UK')
      # @return [String] The base locale (e.g., 'en')
      def base_locale(code)
        code.to_s.split('-').first&.downcase
      end

      # Returns currency options formatted for Rails select helpers
      # @return [Array<Array<String>>] Array of ["CODE - Label", "CODE"] pairs
      def currency_options_for_select
        CURRENCIES.map { |code, info| ["#{code} - #{info[:label]}", code] }
      end

      # Returns currency info for a given code
      # @param code [String] The currency code
      # @return [Hash, nil] Hash with :label and :symbol keys
      def currency_info(code)
        CURRENCIES[code.to_s.upcase]
      end

      # Returns area unit options formatted for Rails select helpers
      # @return [Array<Array<String>>] Array of ["Label (abbr)", "code"] pairs
      def area_unit_options_for_select
        AREA_UNITS.map { |code, info| ["#{info[:label]} (#{info[:abbreviation]})", code] }
      end

      # Returns area unit info for a given code
      # @param code [String] The area unit code
      # @return [Hash, nil] Hash with :label, :abbreviation, and :symbol keys
      def area_unit_info(code)
        AREA_UNITS[code.to_s]
      end

      # Returns field key category info by database tag
      # @param tag [String] The database tag (e.g., 'property-types')
      # @return [Hash, nil] Category configuration hash
      def field_key_category(tag)
        FIELD_KEY_CATEGORIES[tag]
      end

      # Returns field key category info by URL key
      # @param url_key [String] The URL-friendly key (e.g., 'property_types')
      # @return [Hash, nil] Category configuration hash with :tag added
      def field_key_category_by_url(url_key)
        FIELD_KEY_CATEGORIES.each do |tag, info|
          return info.merge(tag: tag) if info[:url_key] == url_key
        end
        nil
      end

      # Returns mapping of URL keys to database tags
      # @return [Hash<String, String>] URL key => database tag
      def field_key_url_to_tag_mapping
        FIELD_KEY_CATEGORIES.transform_values { |info| info[:url_key] }.invert
      end

      # Returns all field key category tags
      # @return [Array<String>] Array of database tags
      def field_key_category_tags
        FIELD_KEY_CATEGORIES.keys
      end

      # Builds locale details for multi-language UI
      # Filters out blank values and handles regional variants
      # @param locales [Array<String>] Array of locale codes
      # @return [Array<Hash>] Array of locale detail hashes
      def build_locale_details(locales)
        return [] if locales.blank?

        locales.reject(&:blank?).filter_map do |full_locale|
          parts = full_locale.to_s.split('-')
          base = parts[0]&.downcase
          next if base.blank?

          {
            locale: base,
            variant: parts[1],
            full: full_locale,
            # Use hash lookup directly for proper fallback (locale_label always returns truthy)
            label: SUPPORTED_LOCALES[full_locale.to_s] || SUPPORTED_LOCALES[base] || base.upcase
          }
        end
      end
    end
  end
end
