# frozen_string_literal: true

module Pwb
  # Service for creating a property (RealtyAsset + SaleListing) from scraped data.
  # Takes a ScrapedProperty with extracted_data and creates the actual property records.
  class PropertyImportFromScrapeService
    Result = Struct.new(:success, :realty_asset, :error, keyword_init: true) do
      def success?
        success
      end
    end

    attr_reader :scraped_property, :website, :overrides

    # @param scraped_property [Pwb::ScrapedProperty] The scraped property with extracted data
    # @param overrides [Hash] Optional user overrides for extracted data
    def initialize(scraped_property, overrides: {})
      @scraped_property = scraped_property
      @website = scraped_property.website
      @overrides = overrides.deep_symbolize_keys
    end

    # Creates the property from scraped data.
    #
    # @return [Result] Result object with success status and created asset or error
    def call
      return already_imported_result if scraped_property.already_imported?

      asset_data = merge_data(scraped_property.asset_data, overrides[:asset_data])
      listing_data = merge_data(scraped_property.listing_data, overrides[:listing_data])

      ActiveRecord::Base.transaction do
        # Create RealtyAsset
        realty_asset = create_realty_asset(asset_data)

        # Create SaleListing (default to sale listing for scraped properties)
        create_sale_listing(realty_asset, listing_data)

        # Import images as PropPhotos
        import_images(realty_asset)

        # Mark as imported
        scraped_property.mark_as_imported!(realty_asset)

        Result.new(success: true, realty_asset: realty_asset)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, error: e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Rails.logger.error("[PropertyImportFromScrapeService] Import failed: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      Result.new(success: false, error: e.message)
    end

    private

    def merge_data(extracted, overrides)
      return extracted&.deep_symbolize_keys || {} if overrides.blank?

      (extracted&.deep_symbolize_keys || {}).merge(overrides.compact)
    end

    def already_imported_result
      Result.new(
        success: false,
        error: "Property has already been imported",
        realty_asset: scraped_property.realty_asset
      )
    end

    def create_realty_asset(data)
      RealtyAsset.create!(
        website: website,
        reference: data[:reference] || generate_reference,
        street_address: data[:street_address],
        city: data[:city],
        region: data[:region],
        postal_code: data[:postal_code],
        country: data[:country] || "ES",
        latitude: data[:latitude],
        longitude: data[:longitude],
        prop_type_key: data[:prop_type_key] || "apartment",
        prop_state_key: data[:prop_state_key] || "good",
        count_bedrooms: data[:count_bedrooms] || 0,
        count_bathrooms: data[:count_bathrooms] || 0,
        count_garages: data[:count_garages] || 0,
        constructed_area: data[:constructed_area] || 0,
        plot_area: data[:plot_area] || 0,
        year_construction: data[:year_construction],
        energy_rating: data[:energy_rating],
        energy_performance: data[:energy_performance]
      )
    end

    def create_sale_listing(realty_asset, data)
      price_cents = calculate_price_cents(data[:price_sale_current])
      currency = data[:currency] || website.default_currency || "EUR"

      listing = realty_asset.sale_listings.build(
        active: true,
        visible: data[:visible].nil? ? true : data[:visible],
        highlighted: data[:highlighted] || false,
        furnished: data[:furnished] || false,
        price_sale_current_cents: price_cents,
        price_sale_current_currency: currency
      )

      # Set title and description (use default locale)
      if data[:title].present?
        listing.title = data[:title]
      end

      if data[:description].present?
        listing.description = data[:description]
      end

      listing.save!
      listing
    end

    def calculate_price_cents(price)
      return 0 if price.blank?

      # If price is already in cents (large number), use as-is
      # Otherwise convert from whole units to cents
      price_value = price.to_f
      if price_value > 100_000
        # Likely already in cents or a very expensive property
        # Use heuristic: if divisible by 100, assume whole units
        if (price_value % 100).zero?
          (price_value * 100).to_i
        else
          price_value.to_i
        end
      else
        (price_value * 100).to_i
      end
    end

    def import_images(realty_asset)
      images = scraped_property.images
      return if images.blank?

      images.first(20).each_with_index do |url, index|
        next if url.blank?

        # Create PropPhoto with external URL
        # Note: Could download and attach to ActiveStorage instead
        PropPhoto.create!(
          realty_asset: realty_asset,
          sort_order: index,
          external_url: url
        )
      rescue StandardError => e
        Rails.logger.warn("[PropertyImportFromScrapeService] Failed to import image #{url}: #{e.message}")
        # Continue with other images
      end
    end

    def generate_reference
      "IMP-#{SecureRandom.hex(4).upcase}"
    end
  end
end
