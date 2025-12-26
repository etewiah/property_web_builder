# frozen_string_literal: true

require 'csv'

module Pwb
  # Service for exporting properties to CSV format.
  #
  # Exports RealtyAsset data along with associated SaleListing/RentalListing
  # information in a format compatible with PropertyBulkImportService.
  #
  # Usage:
  #   csv_string = Pwb::PropertyExportService.new(
  #     website: current_website,
  #     options: { include_inactive: false }
  #   ).export
  #
  #   # Or export to file
  #   Pwb::PropertyExportService.new(website: current_website).export_to_file('/path/to/file.csv')
  #
  class PropertyExportService
    # CSV columns in export order (matches import service expectations)
    EXPORT_COLUMNS = [
      # Identity
      'reference',
      
      # Location
      'street_address',
      'street_number',
      'street_name',
      'city',
      'region',
      'postal_code',
      'country',
      'latitude',
      'longitude',
      
      # Property details
      'prop_type_key',
      'prop_state_key',
      'prop_origin_key',
      'count_bedrooms',
      'count_bathrooms',
      'count_toilets',
      'count_garages',
      'constructed_area',
      'plot_area',
      'year_construction',
      'energy_rating',
      'energy_performance',
      
      # Listing flags
      'for_sale',
      'for_rent',
      'for_rent_long_term',
      'for_rent_short_term',
      
      # Sale pricing
      'price_sale',
      'currency',
      
      # Rental pricing
      'price_rental_monthly',
      'price_rental_high_season',
      'price_rental_low_season',
      
      # Marketing text (English)
      'title_en',
      'description_en',
      
      # Marketing text (Spanish)
      'title_es',
      'description_es',
      
      # Status
      'visible',
      'highlighted',
      'furnished',
      
      # Features
      'features'
    ].freeze

    attr_reader :website, :options

    def initialize(website:, options: {})
      @website = website
      @options = default_options.merge(options)
    end

    # Export properties to CSV string
    def export
      properties = fetch_properties
      generate_csv(properties)
    end

    # Export properties to a file
    def export_to_file(filepath)
      File.write(filepath, export)
    end

    # Get count of properties that would be exported
    def count
      fetch_properties.count
    end

    private

    def default_options
      {
        include_inactive: false,    # Include properties without active listings
        include_archived: false,    # Include archived listings
        locales: %w[en es],         # Locales to export for title/description
        delimiter: ','              # CSV delimiter
      }
    end

    def fetch_properties
      scope = Pwb::RealtyAsset.where(website: website)
      
      unless options[:include_inactive]
        # Only include properties with at least one active listing
        scope = scope.joins(
          "LEFT JOIN pwb_sale_listings ON pwb_sale_listings.realty_asset_id = pwb_realty_assets.id AND pwb_sale_listings.active = true
           LEFT JOIN pwb_rental_listings ON pwb_rental_listings.realty_asset_id = pwb_realty_assets.id AND pwb_rental_listings.active = true"
        ).where("pwb_sale_listings.id IS NOT NULL OR pwb_rental_listings.id IS NOT NULL").distinct
      end

      scope.includes(:sale_listings, :rental_listings, :features).order(:reference)
    end

    def generate_csv(properties)
      CSV.generate(col_sep: options[:delimiter]) do |csv|
        csv << EXPORT_COLUMNS
        
        properties.each do |property|
          csv << property_to_row(property)
        end
      end
    end

    def property_to_row(property)
      sale_listing = property.active_sale_listing
      rental_listing = property.active_rental_listing
      
      # Determine primary listing for shared attributes
      primary_listing = sale_listing || rental_listing

      [
        # Identity
        property.reference,
        
        # Location
        property.street_address,
        property.street_number,
        property.street_name,
        property.city,
        property.region,
        property.postal_code,
        property.country,
        property.latitude,
        property.longitude,
        
        # Property details
        property.prop_type_key,
        property.prop_state_key,
        property.prop_origin_key,
        property.count_bedrooms,
        property.count_bathrooms,
        property.count_toilets,
        property.count_garages,
        property.constructed_area,
        property.plot_area,
        property.year_construction,
        property.energy_rating,
        property.energy_performance,
        
        # Listing flags
        boolean_to_string(sale_listing.present?),
        boolean_to_string(rental_listing.present?),
        boolean_to_string(rental_listing&.for_rent_long_term),
        boolean_to_string(rental_listing&.for_rent_short_term),
        
        # Sale pricing (convert cents to whole units)
        sale_listing ? (sale_listing.price_sale_current_cents / 100.0).round(2) : nil,
        primary_listing&.respond_to?(:price_sale_current_currency) ? 
          sale_listing&.price_sale_current_currency : 
          rental_listing&.price_rental_monthly_current_currency,
        
        # Rental pricing (convert cents to whole units)
        rental_listing ? (rental_listing.price_rental_monthly_current_cents / 100.0).round(2) : nil,
        rental_listing ? (rental_listing.price_rental_monthly_high_season_cents / 100.0).round(2) : nil,
        rental_listing ? (rental_listing.price_rental_monthly_low_season_cents / 100.0).round(2) : nil,
        
        # Marketing text (English)
        get_translation(primary_listing, :title, :en),
        get_translation(primary_listing, :description, :en),
        
        # Marketing text (Spanish)
        get_translation(primary_listing, :title, :es),
        get_translation(primary_listing, :description, :es),
        
        # Status
        boolean_to_string(primary_listing&.visible),
        boolean_to_string(primary_listing&.highlighted),
        boolean_to_string(primary_listing&.furnished),
        
        # Features (comma-separated)
        property.features.pluck(:feature_key).join(',')
      ]
    end

    def boolean_to_string(value)
      value ? 'true' : 'false'
    end

    def get_translation(listing, attribute, locale)
      return nil unless listing
      
      Mobility.with_locale(locale) do
        listing.send(attribute)
      end
    rescue StandardError
      nil
    end
  end
end
