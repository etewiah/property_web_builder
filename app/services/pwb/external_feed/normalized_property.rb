# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Normalized property data structure.
    # All providers must return properties in this format to ensure
    # consistent handling across the application.
    class NormalizedProperty
      # Identification
      attr_accessor :reference           # String - Provider's unique ID
      attr_accessor :provider            # Symbol - Provider name
      attr_accessor :provider_url        # String - Original listing URL (if available)

      # Basic Info
      attr_accessor :title               # String - Property title
      attr_accessor :description         # String - Full description (HTML allowed)
      attr_accessor :property_type       # String - Normalized type (apartment, house, etc.)
      attr_accessor :property_type_raw   # String - Provider's original type code
      attr_accessor :property_subtype    # String - More specific type (penthouse, villa, etc.)

      # Location
      attr_accessor :country             # String - Country name
      attr_accessor :region              # String - Region/Province
      attr_accessor :area                # String - Area/District
      attr_accessor :city                # String - City/Town
      attr_accessor :address             # String - Street address (if available)
      attr_accessor :postal_code         # String - Postal code (if available)
      attr_accessor :latitude            # Float
      attr_accessor :longitude           # Float

      # Listing Details
      attr_accessor :listing_type        # Symbol - :sale or :rental
      attr_accessor :status              # Symbol - :available, :reserved, :sold, :rented, :unavailable
      attr_accessor :price               # Integer - Price in cents
      attr_accessor :price_raw           # String - Original price string
      attr_accessor :currency            # String - ISO currency code (EUR, GBP, etc.)
      attr_accessor :price_qualifier     # String - "Asking price", "Guide price", etc.
      attr_accessor :original_price      # Integer - Original price if reduced (cents)

      # Rental-specific
      attr_accessor :rental_period       # Symbol - :monthly, :weekly, :daily
      attr_accessor :available_from      # Date
      attr_accessor :minimum_stay        # Integer - Minimum nights/days

      # Property Details
      attr_accessor :bedrooms            # Integer
      attr_accessor :bathrooms           # Float (allows 1.5 baths)
      attr_accessor :built_area          # Integer - Square meters
      attr_accessor :plot_area           # Integer - Square meters
      attr_accessor :terrace_area        # Integer - Square meters
      attr_accessor :year_built          # Integer
      attr_accessor :floors              # Integer - Number of floors
      attr_accessor :floor_level         # Integer - Which floor (for apartments)
      attr_accessor :orientation         # String - N, S, E, W, NE, etc.

      # Features
      attr_accessor :features            # Array<String> - List of features
      attr_accessor :features_by_category # Hash<String, Array<String>>

      # Energy
      attr_accessor :energy_rating       # String - A, B, C, D, E, F, G
      attr_accessor :energy_value        # Float
      attr_accessor :co2_rating          # String
      attr_accessor :co2_value           # Float

      # Media
      attr_accessor :images              # Array<Hash> - [{url:, caption:, position:}]
      attr_accessor :virtual_tour_url    # String
      attr_accessor :video_url           # String
      attr_accessor :floor_plan_urls     # Array<String>

      # Costs (for sales)
      attr_accessor :community_fees      # Integer - Annual in cents
      attr_accessor :ibi_tax             # Integer - Annual in cents
      attr_accessor :garbage_tax         # Integer - Annual in cents

      # Metadata
      attr_accessor :created_at          # DateTime - When listed
      attr_accessor :updated_at          # DateTime - Last update
      attr_accessor :fetched_at          # DateTime - When we fetched it

      # Additional fields for compatibility
      attr_accessor :location            # String - Alias for city/area
      attr_accessor :province            # String - Alias for region
      attr_accessor :price_frequency     # Symbol - For rentals (:month, :week, :day)
      attr_accessor :parking_spaces      # Integer
      attr_accessor :energy_consumption  # Float

      # Initialize from hash
      # @param attrs [Hash] Property attributes
      def initialize(attrs = {})
        attrs.each do |key, value|
          setter = "#{key}="
          send(setter, value) if respond_to?(setter)
        end

        # Set defaults
        @fetched_at ||= Time.current
        @features ||= []
        @features_by_category ||= {}
        @images ||= []
        @floor_plan_urls ||= []
        @status ||= :available
        @listing_type ||= :sale
        @currency ||= "EUR"
      end

      # Convert to hash for JSON serialization
      # @return [Hash]
      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          key = var.to_s.delete_prefix("@").to_sym
          hash[key] = instance_variable_get(var)
        end
      end

      # Alias for to_h
      def as_json(options = nil)
        to_h
      end

      # Price in major currency units (e.g., euros, not cents)
      # @param area_type [Symbol, nil] :built or :plot to calculate price per m2
      # @return [Float, nil]
      def price_in_units(area_type = nil)
        return nil unless price

        if area_type == :built
          return nil if built_area.nil? || built_area.zero?
          price / built_area.to_f
        elsif area_type == :plot
          return nil if plot_area.nil? || plot_area.zero?
          price / plot_area.to_f
        else
          price.to_f
        end
      end

      # Formatted price string
      # @return [String, nil]
      def formatted_price
        return nil unless price

        curr = currency || "EUR"
        formatted = ActiveSupport::NumberHelper.number_to_delimited(price.round(0))
        "#{curr} #{formatted}"
      end

      # Primary image URL
      # @return [String, nil]
      def primary_image_url
        images&.first&.dig(:url) || images&.first&.dig("url")
      end

      # Alias for primary_image_url
      # @return [String, nil]
      def main_image
        primary_image_url
      end

      # Get image URLs only
      # @param limit [Integer] Maximum number of images
      # @return [Array<String>]
      def image_urls(limit: nil)
        urls = images.map { |img| img[:url] || img["url"] }.compact
        limit ? urls.first(limit) : urls
      end

      # Check if property is available
      # @return [Boolean]
      def available?
        status.nil? || status == :available
      end

      # Check if property is reserved
      # @return [Boolean]
      def reserved?
        status == :reserved
      end

      # Check if property is sold/rented
      # @return [Boolean]
      def sold?
        %i[sold rented].include?(status)
      end

      # Check if this is a sale listing
      # @return [Boolean]
      def for_sale?
        listing_type == :sale
      end

      # Check if this is a rental listing
      # @return [Boolean]
      def for_rent?
        listing_type == :rental
      end

      # Check if price was reduced
      # @return [Boolean]
      def price_reduced?
        original_price.present? && price.present? && price < original_price
      end

      # Price reduction amount in cents
      # @return [Integer, nil]
      def price_reduction_amount
        return nil unless price_reduced?

        original_price - price
      end

      # Price reduction percentage
      # @return [Float, nil]
      def price_reduction_percent
        return nil unless price_reduced?

        ((original_price - price).to_f / original_price * 100).round(1)
      end

      # Check if property has coordinates
      # @return [Boolean]
      def has_coordinates?
        latitude.present? && longitude.present?
      end

      # Full location string
      # @return [String]
      def full_location
        [city, area, region, country].compact.reject(&:blank?).join(", ")
      end

      # Short location (city, region)
      # @return [String]
      def short_location
        [city, region].compact.reject(&:blank?).join(", ")
      end

      # Check if property has images
      # @return [Boolean]
      def has_images?
        images.present? && images.any?
      end

      # Image count
      # @return [Integer]
      def image_count
        images&.size || 0
      end

      # Check if property has a specific feature
      # @param feature [String] Feature name (case-insensitive)
      # @return [Boolean]
      def has_feature?(feature)
        return false unless features

        features.any? { |f| f.to_s.downcase.include?(feature.to_s.downcase) }
      end

      # Get features for a specific category
      # @param category [String] Category name
      # @return [Array<String>]
      def features_for(category)
        features_by_category[category] || features_by_category[category.to_s] || []
      end

      # Property summary for list views
      # @return [Hash]
      def summary
        {
          reference: reference,
          title: title,
          property_type: property_type,
          location: short_location,
          price: formatted_price,
          bedrooms: bedrooms,
          bathrooms: bathrooms,
          built_area: built_area,
          image_url: primary_image_url,
          status: status
        }
      end

      # Comparison for deduplication
      def ==(other)
        other.is_a?(NormalizedProperty) &&
          provider == other.provider &&
          reference == other.reference
      end

      def eql?(other)
        self == other
      end

      def hash
        [provider, reference].hash
      end
    end
  end
end
