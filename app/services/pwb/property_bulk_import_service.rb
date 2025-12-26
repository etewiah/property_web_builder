# frozen_string_literal: true

require 'csv'

module Pwb
  # Service for bulk importing properties from CSV files.
  #
  # Handles:
  # - CSV parsing with flexible column mapping
  # - RealtyAsset creation
  # - SaleListing/RentalListing creation based on listing type
  # - Error tracking and reporting
  # - Duplicate detection via reference field
  #
  # Usage:
  #   result = Pwb::PropertyBulkImportService.new(
  #     file: uploaded_file,
  #     website: current_website,
  #     options: { update_existing: false }
  #   ).import
  #
  #   result.success?      # => true/false
  #   result.imported      # => [array of created properties]
  #   result.errors        # => [array of error messages]
  #   result.skipped       # => [array of skipped rows]
  #
  class PropertyBulkImportService
    Result = Struct.new(:success, :imported, :errors, :skipped, :total_rows, keyword_init: true) do
      def success?
        success
      end
    end

    # Standard CSV column mappings
    COLUMN_MAPPINGS = {
      # Required
      'reference' => :reference,
      
      # Location
      'street_address' => :street_address,
      'street_name' => :street_name,
      'street_number' => :street_number,
      'city' => :city,
      'region' => :region,
      'postal_code' => :postal_code,
      'country' => :country,
      'latitude' => :latitude,
      'longitude' => :longitude,
      
      # Property details
      'prop_type_key' => :prop_type_key,
      'prop_state_key' => :prop_state_key,
      'prop_origin_key' => :prop_origin_key,
      'count_bedrooms' => :count_bedrooms,
      'count_bathrooms' => :count_bathrooms,
      'count_toilets' => :count_toilets,
      'count_garages' => :count_garages,
      'constructed_area' => :constructed_area,
      'plot_area' => :plot_area,
      'year_construction' => :year_construction,
      'energy_rating' => :energy_rating,
      'energy_performance' => :energy_performance,
      
      # Listing type flags
      'for_sale' => :for_sale,
      'for_rent' => :for_rent,
      'for_rent_long_term' => :for_rent_long_term,
      'for_rent_short_term' => :for_rent_short_term,
      
      # Sale pricing (in cents or whole units)
      'price_sale' => :price_sale,
      'price_sale_cents' => :price_sale_cents,
      'currency' => :currency,
      
      # Rental pricing (in cents or whole units)
      'price_rental_monthly' => :price_rental_monthly,
      'price_rental_monthly_cents' => :price_rental_monthly_cents,
      'price_rental_high_season' => :price_rental_high_season,
      'price_rental_low_season' => :price_rental_low_season,
      
      # Marketing text (supports _en, _es, etc. suffixes)
      'title' => :title,
      'title_en' => :title_en,
      'title_es' => :title_es,
      'description' => :description,
      'description_en' => :description_en,
      'description_es' => :description_es,
      
      # Visibility
      'visible' => :visible,
      'highlighted' => :highlighted,
      'furnished' => :furnished,
      
      # Features (comma-separated list)
      'features' => :features
    }.freeze

    attr_reader :file, :website, :options, :results

    def initialize(file:, website:, options: {})
      @file = file
      @website = website
      @options = default_options.merge(options)
      @results = { imported: [], errors: [], skipped: [] }
    end

    def import
      rows = parse_csv
      return error_result("Failed to parse CSV file") if rows.nil?
      return error_result("CSV file is empty") if rows.empty?

      process_rows(rows)

      Result.new(
        success: @results[:errors].empty?,
        imported: @results[:imported],
        errors: @results[:errors],
        skipped: @results[:skipped],
        total_rows: rows.size
      )
    rescue StandardError => e
      Rails.logger.error "PropertyBulkImportService error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      error_result("Import failed: #{e.message}")
    end

    private

    def default_options
      {
        update_existing: false,     # Update properties with same reference
        skip_duplicates: true,      # Skip rows with duplicate references
        default_currency: 'EUR',    # Default currency if not specified
        create_visible: false,      # Create listings as visible by default
        dry_run: false              # If true, validate only without saving
      }
    end

    def parse_csv
      content = file.respond_to?(:read) ? file.read : File.read(file)
      # Try to detect delimiter (comma or tab)
      delimiter = content.lines.first&.include?("\t") ? "\t" : ","
      
      CSV.parse(content, headers: true, col_sep: delimiter, liberal_parsing: true)
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "CSV parsing error: #{e.message}"
      nil
    end

    def process_rows(rows)
      rows.each.with_index(2) do |row, line_number| # Line 2 = first data row (after header)
        process_row(row, line_number)
      end
    end

    def process_row(row, line_number)
      data = normalize_row(row)
      
      # Validate required fields
      if data[:reference].blank?
        @results[:errors] << { line: line_number, error: "Missing required field: reference" }
        return
      end

      # Check for duplicates
      existing = Pwb::RealtyAsset.find_by(website: website, reference: data[:reference])
      if existing
        if options[:update_existing]
          update_property(existing, data, line_number)
        elsif options[:skip_duplicates]
          @results[:skipped] << { line: line_number, reference: data[:reference], reason: "Duplicate reference" }
        else
          @results[:errors] << { line: line_number, error: "Duplicate reference: #{data[:reference]}" }
        end
        return
      end

      # Create new property
      create_property(data, line_number)
    end

    def normalize_row(row)
      data = {}
      row_hash = row.to_h.transform_keys { |k| k&.strip&.downcase&.gsub(/[\s-]/, '_') }
      
      COLUMN_MAPPINGS.each do |csv_col, attr|
        value = row_hash[csv_col]
        data[attr] = normalize_value(attr, value) if value.present?
      end

      # Also check for locale-specific title/description columns
      row_hash.each do |key, value|
        next unless value.present?
        if key =~ /^(title|description)_(\w{2})$/
          data["#{$1}_#{$2}".to_sym] = value.strip
        end
      end

      data
    end

    def normalize_value(attr, value)
      return nil if value.nil?
      value = value.to_s.strip

      case attr
      when :count_bedrooms, :count_toilets, :count_garages, :year_construction, :energy_rating
        value.to_i
      when :count_bathrooms, :constructed_area, :plot_area, :latitude, :longitude, :energy_performance
        value.to_f
      when :for_sale, :for_rent, :for_rent_long_term, :for_rent_short_term, :visible, :highlighted, :furnished
        truthy?(value)
      when :price_sale, :price_rental_monthly, :price_rental_high_season, :price_rental_low_season
        (value.to_f * 100).to_i # Convert to cents
      when :price_sale_cents, :price_rental_monthly_cents
        value.to_i
      else
        value
      end
    end

    def truthy?(value)
      %w[true 1 yes y].include?(value.to_s.downcase)
    end

    def create_property(data, line_number)
      ActiveRecord::Base.transaction do
        # Build RealtyAsset
        asset = build_realty_asset(data)
        
        if options[:dry_run]
          if asset.valid?
            @results[:imported] << { line: line_number, reference: data[:reference], status: 'validated' }
          else
            @results[:errors] << { line: line_number, error: asset.errors.full_messages.join(', ') }
          end
          return
        end

        unless asset.save
          @results[:errors] << { line: line_number, error: asset.errors.full_messages.join(', ') }
          raise ActiveRecord::Rollback
        end

        # Create listings based on flags
        create_listings(asset, data)

        # Create features
        create_features(asset, data[:features]) if data[:features].present?

        @results[:imported] << { 
          line: line_number, 
          reference: data[:reference], 
          id: asset.id,
          status: 'created'
        }
      end
    rescue ActiveRecord::Rollback
      # Already logged error
    rescue StandardError => e
      @results[:errors] << { line: line_number, error: e.message }
    end

    def update_property(asset, data, line_number)
      ActiveRecord::Base.transaction do
        # Update RealtyAsset attributes
        asset_attrs = extract_asset_attributes(data)
        
        if options[:dry_run]
          @results[:imported] << { line: line_number, reference: data[:reference], status: 'would_update' }
          return
        end

        unless asset.update(asset_attrs)
          @results[:errors] << { line: line_number, error: asset.errors.full_messages.join(', ') }
          raise ActiveRecord::Rollback
        end

        # Update listings
        update_listings(asset, data)

        @results[:imported] << { 
          line: line_number, 
          reference: data[:reference], 
          id: asset.id,
          status: 'updated'
        }
      end
    rescue ActiveRecord::Rollback
      # Already logged error
    rescue StandardError => e
      @results[:errors] << { line: line_number, error: e.message }
    end

    def build_realty_asset(data)
      Pwb::RealtyAsset.new(
        website: website,
        **extract_asset_attributes(data)
      )
    end

    def extract_asset_attributes(data)
      {
        reference: data[:reference],
        street_address: data[:street_address],
        street_name: data[:street_name],
        street_number: data[:street_number],
        city: data[:city],
        region: data[:region],
        postal_code: data[:postal_code],
        country: data[:country],
        latitude: data[:latitude],
        longitude: data[:longitude],
        prop_type_key: data[:prop_type_key],
        prop_state_key: data[:prop_state_key],
        prop_origin_key: data[:prop_origin_key],
        count_bedrooms: data[:count_bedrooms],
        count_bathrooms: data[:count_bathrooms],
        count_toilets: data[:count_toilets],
        count_garages: data[:count_garages],
        constructed_area: data[:constructed_area],
        plot_area: data[:plot_area],
        year_construction: data[:year_construction],
        energy_rating: data[:energy_rating],
        energy_performance: data[:energy_performance]
      }.compact
    end

    def create_listings(asset, data)
      currency = data[:currency] || options[:default_currency]
      visible = data[:visible].nil? ? options[:create_visible] : data[:visible]

      # Create sale listing if for_sale flag is set
      if data[:for_sale]
        create_sale_listing(asset, data, currency, visible)
      end

      # Create rental listing if for_rent flag is set
      if data[:for_rent] || data[:for_rent_long_term] || data[:for_rent_short_term]
        create_rental_listing(asset, data, currency, visible)
      end
    end

    def create_sale_listing(asset, data, currency, visible)
      price_cents = data[:price_sale_cents] || data[:price_sale] || 0
      
      listing = asset.sale_listings.build(
        active: true,
        visible: visible,
        highlighted: data[:highlighted] || false,
        furnished: data[:furnished] || false,
        price_sale_current_cents: price_cents,
        price_sale_current_currency: currency
      )

      # Set translations
      set_listing_translations(listing, data)
      
      listing.save!
    end

    def create_rental_listing(asset, data, currency, visible)
      price_cents = data[:price_rental_monthly_cents] || data[:price_rental_monthly] || 0
      
      listing = asset.rental_listings.build(
        active: true,
        visible: visible,
        highlighted: data[:highlighted] || false,
        furnished: data[:furnished] || false,
        for_rent_long_term: data[:for_rent_long_term] || data[:for_rent] || false,
        for_rent_short_term: data[:for_rent_short_term] || false,
        price_rental_monthly_current_cents: price_cents,
        price_rental_monthly_current_currency: currency,
        price_rental_monthly_high_season_cents: data[:price_rental_high_season] || 0,
        price_rental_monthly_low_season_cents: data[:price_rental_low_season] || 0
      )

      # Set translations
      set_listing_translations(listing, data)
      
      listing.save!
    end

    def set_listing_translations(listing, data)
      # Set title translations
      %i[title title_en title_es title_de title_fr title_pt title_it].each do |key|
        next unless data[key].present?
        locale = key == :title ? I18n.default_locale : key.to_s.split('_').last.to_sym
        Mobility.with_locale(locale) do
          listing.title = data[key]
        end
      end

      # Set description translations
      %i[description description_en description_es description_de description_fr description_pt description_it].each do |key|
        next unless data[key].present?
        locale = key == :description ? I18n.default_locale : key.to_s.split('_').last.to_sym
        Mobility.with_locale(locale) do
          listing.description = data[key]
        end
      end
    end

    def update_listings(asset, data)
      # Update or create sale listing
      if data[:for_sale]
        listing = asset.active_sale_listing || asset.sale_listings.build(active: true)
        update_sale_listing(listing, data)
      end

      # Update or create rental listing
      if data[:for_rent] || data[:for_rent_long_term] || data[:for_rent_short_term]
        listing = asset.active_rental_listing || asset.rental_listings.build(active: true)
        update_rental_listing(listing, data)
      end
    end

    def update_sale_listing(listing, data)
      currency = data[:currency] || listing.price_sale_current_currency || options[:default_currency]
      price_cents = data[:price_sale_cents] || data[:price_sale]
      
      attrs = {}
      attrs[:price_sale_current_cents] = price_cents if price_cents
      attrs[:price_sale_current_currency] = currency
      attrs[:visible] = data[:visible] unless data[:visible].nil?
      attrs[:highlighted] = data[:highlighted] unless data[:highlighted].nil?
      attrs[:furnished] = data[:furnished] unless data[:furnished].nil?
      
      listing.update!(attrs.compact)
      set_listing_translations(listing, data)
      listing.save!
    end

    def update_rental_listing(listing, data)
      currency = data[:currency] || listing.price_rental_monthly_current_currency || options[:default_currency]
      price_cents = data[:price_rental_monthly_cents] || data[:price_rental_monthly]
      
      attrs = {}
      attrs[:price_rental_monthly_current_cents] = price_cents if price_cents
      attrs[:price_rental_monthly_current_currency] = currency
      attrs[:for_rent_long_term] = data[:for_rent_long_term] unless data[:for_rent_long_term].nil?
      attrs[:for_rent_short_term] = data[:for_rent_short_term] unless data[:for_rent_short_term].nil?
      attrs[:visible] = data[:visible] unless data[:visible].nil?
      attrs[:highlighted] = data[:highlighted] unless data[:highlighted].nil?
      attrs[:furnished] = data[:furnished] unless data[:furnished].nil?
      
      if data[:price_rental_high_season]
        attrs[:price_rental_monthly_high_season_cents] = data[:price_rental_high_season]
      end
      if data[:price_rental_low_season]
        attrs[:price_rental_monthly_low_season_cents] = data[:price_rental_low_season]
      end
      
      listing.update!(attrs.compact)
      set_listing_translations(listing, data)
      listing.save!
    end

    def create_features(asset, features_string)
      feature_keys = features_string.to_s.split(',').map(&:strip).reject(&:blank?)
      
      feature_keys.each do |feature_key|
        asset.features.find_or_create_by(feature_key: feature_key)
      end
    end

    def error_result(message)
      Result.new(
        success: false,
        imported: [],
        errors: [{ error: message }],
        skipped: [],
        total_rows: 0
      )
    end
  end
end
