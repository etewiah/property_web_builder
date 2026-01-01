# frozen_string_literal: true

require "csv"

module Pwb
  # Service for batch importing properties from multiple URLs.
  # Supports CSV upload or direct URL list input.
  #
  # CSV Format:
  #   url,bedrooms,bathrooms,city,price,notes
  #   https://rightmove.co.uk/...,3,2,London,450000,Main property
  #
  # Usage:
  #   service = Pwb::BatchUrlImportService.new(website, urls: ["url1", "url2"])
  #   result = service.call
  #
  #   service = Pwb::BatchUrlImportService.new(website, csv_content: csv_string)
  #   result = service.call
  #
  class BatchUrlImportService
    Result = Struct.new(:success, :total, :successful, :failed, :results, keyword_init: true) do
      def success?
        success
      end

      def summary
        "Processed #{total}: #{successful} succeeded, #{failed} failed"
      end
    end

    UrlResult = Struct.new(:url, :success, :scraped_property, :error, keyword_init: true)

    MAX_URLS_PER_BATCH = 50
    DELAY_BETWEEN_REQUESTS = 2 # seconds

    attr_reader :website, :urls, :overrides_map

    # @param website [Pwb::Website] The website to import properties to
    # @param urls [Array<String>] List of URLs to process
    # @param csv_content [String] CSV content with URLs and optional overrides
    # @param connector [Symbol] Force a specific connector (:http or :playwright)
    def initialize(website, urls: nil, csv_content: nil, connector: nil)
      @website = website
      @connector = connector
      @overrides_map = {}

      if csv_content.present?
        parse_csv(csv_content)
      elsif urls.present?
        @urls = urls.map(&:strip).reject(&:blank?).first(MAX_URLS_PER_BATCH)
      else
        @urls = []
      end
    end

    # Process all URLs and return aggregated results.
    #
    # @return [Result] Aggregated result with success/fail counts
    def call
      if urls.empty?
        return Result.new(
          success: false,
          total: 0,
          successful: 0,
          failed: 0,
          results: [],
          error: "No valid URLs provided"
        )
      end

      results = []
      successful_count = 0
      failed_count = 0

      urls.each_with_index do |url, index|
        Rails.logger.info "[BatchUrlImport] Processing #{index + 1}/#{urls.count}: #{url.truncate(80)}"

        result = process_url(url)
        results << result

        if result.success
          successful_count += 1
        else
          failed_count += 1
        end

        # Delay between requests to be respectful to target servers
        sleep(DELAY_BETWEEN_REQUESTS) if index < urls.count - 1
      end

      Result.new(
        success: failed_count == 0,
        total: urls.count,
        successful: successful_count,
        failed: failed_count,
        results: results
      )
    end

    private

    def parse_csv(csv_content)
      @urls = []

      csv = CSV.parse(csv_content, headers: true, liberal_parsing: true)

      csv.each do |row|
        url = row["url"] || row["URL"] || row[0]
        next if url.blank?

        url = url.strip
        @urls << url

        # Parse optional override columns
        overrides = {}

        # Asset data overrides
        asset_overrides = {}
        asset_overrides[:count_bedrooms] = row["bedrooms"].to_i if row["bedrooms"].present?
        asset_overrides[:count_bathrooms] = row["bathrooms"].to_i if row["bathrooms"].present?
        asset_overrides[:city] = row["city"] if row["city"].present?
        asset_overrides[:region] = row["region"] if row["region"].present?
        asset_overrides[:postal_code] = row["postal_code"] || row["postcode"] if (row["postal_code"] || row["postcode"]).present?
        asset_overrides[:prop_type_key] = row["property_type"] if row["property_type"].present?

        # Listing data overrides
        listing_overrides = {}
        listing_overrides[:price_sale_current] = row["price"].to_f if row["price"].present?
        listing_overrides[:currency] = row["currency"] if row["currency"].present?
        listing_overrides[:title] = row["title"] if row["title"].present?

        overrides[:asset_data] = asset_overrides if asset_overrides.any?
        overrides[:listing_data] = listing_overrides if listing_overrides.any?
        overrides[:notes] = row["notes"] if row["notes"].present?

        @overrides_map[url] = overrides if overrides.any?
      end

      @urls = @urls.first(MAX_URLS_PER_BATCH)
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "[BatchUrlImport] CSV parsing error: #{e.message}"
      @urls = []
    end

    def process_url(url)
      # Check for duplicate
      existing = find_existing(url)
      if existing&.already_imported?
        return UrlResult.new(
          url: url,
          success: false,
          scraped_property: existing,
          error: "Already imported"
        )
      end

      # Scrape the URL
      scraper = PropertyScraperService.new(url, website: website, connector: @connector)
      scraped_property = scraper.call

      unless scraped_property.scrape_successful?
        return UrlResult.new(
          url: url,
          success: false,
          scraped_property: scraped_property,
          error: scraped_property.scrape_error_message || "Scraping failed"
        )
      end

      UrlResult.new(
        url: url,
        success: true,
        scraped_property: scraped_property,
        error: nil
      )
    rescue StandardError => e
      Rails.logger.error "[BatchUrlImport] Error processing #{url}: #{e.message}"
      UrlResult.new(
        url: url,
        success: false,
        scraped_property: nil,
        error: e.message
      )
    end

    def find_existing(url)
      normalized = normalize_url(url)
      ScrapedProperty.find_by(website: website, source_url_normalized: normalized)
    end

    def normalize_url(url_string)
      uri = URI.parse(url_string.strip)
      "#{uri.host}#{uri.path}".downcase.gsub(%r{/$}, "")
    rescue URI::InvalidURIError
      url_string.downcase.strip
    end
  end
end
