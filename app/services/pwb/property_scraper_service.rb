# frozen_string_literal: true

module Pwb
  # Orchestrates the scraping process for importing properties from URLs.
  # Handles connector selection, content retrieval, and pasarela dispatch.
  class PropertyScraperService
    attr_reader :url, :website, :scraped_property

    # @param url [String] The property listing URL to scrape
    # @param website [Pwb::Website] The website to associate the scraped property with
    # @param connector [Symbol] Force a specific connector (:http or :playwright)
    def initialize(url, website:, connector: nil)
      @url = url.to_s.strip
      @website = website
      @preferred_connector = connector
    end

    # Attempts to automatically scrape the URL.
    # Creates a ScrapedProperty record and attempts to fetch/parse content.
    #
    # @return [Pwb::ScrapedProperty] The scraped property record (check scrape_successful?)
    def call
      # Check for existing successful scrape of same URL
      existing = find_existing_scrape
      if existing&.scrape_successful? && existing.can_preview?
        return existing
      end

      # Create or find the scraped_property record
      @scraped_property = create_or_update_scraped_property

      # Attempt to fetch content
      result = attempt_scrape

      if result[:success]
        # Save raw HTML
        scraped_property.update!(
          raw_html: result[:html],
          scrape_method: "auto",
          connector_used: "http",
          scrape_successful: true,
          scrape_error_message: nil
        )

        # Extract data: try external PWS first, fall back to local pasarela
        extract_data

        # Reload to get the extracted_data saved by extraction
        scraped_property.reload
        scraped_property.update!(import_status: "previewing")
      else
        scraped_property.update!(
          scrape_successful: false,
          scrape_error_message: result[:error],
          import_status: "pending"
        )
      end

      scraped_property
    end

    # Imports manually pasted HTML when automatic scraping fails.
    #
    # @param html [String] The raw HTML content
    # @return [Pwb::ScrapedProperty] The scraped property record
    def import_from_manual_html(html)
      @scraped_property = create_or_update_scraped_property

      scraped_property.update!(
        raw_html: html,
        scrape_method: "manual_html",
        connector_used: nil,
        scrape_successful: true,
        scrape_error_message: nil
      )

      # Manual HTML always uses local pasarela (skip PWS)
      extract_with_local_pasarela

      # Reload to get the extracted_data saved by pasarela
      scraped_property.reload
      scraped_property.update!(import_status: "previewing", extraction_source: "manual")
      scraped_property
    end

    private

    # Try external PWS extraction first, fall back to local pasarela
    def extract_data
      if ExternalScraperClient.enabled?
        begin
          result = ExternalScraperClient.new(
            url: scraped_property.source_url,
            html: scraped_property.raw_html
          ).call

          scraped_property.update!(
            extracted_data: result.extracted_data,
            extracted_images: result.extracted_images,
            extraction_source: "external"
          )
          return
        rescue ExternalScraperClient::UnsupportedPortalError => e
          Rails.logger.info "[PWS] Unsupported portal, falling back to local: #{e.message}"
        rescue ExternalScraperClient::ConnectionError => e
          Rails.logger.warn "[PWS] Connection error, falling back to local: #{e.message}"
        rescue ExternalScraperClient::Error => e
          Rails.logger.warn "[PWS] Extraction error, falling back to local: #{e.message}"
        end
      end

      extract_with_local_pasarela
    end

    # Parse with local pasarela and set extraction_source
    def extract_with_local_pasarela
      pasarela = select_pasarela
      pasarela.call
      scraped_property.reload
      scraped_property.update!(extraction_source: "local") unless scraped_property.extraction_source.present?
    end

    def normalize_url(url_string)
      uri = URI.parse(url_string.strip)
      "#{uri.host}#{uri.path}".downcase.gsub(%r{/$}, "")
    rescue URI::InvalidURIError
      url_string.downcase.strip
    end

    def find_existing_scrape
      ScrapedProperty.find_by(
        website: website,
        source_url_normalized: normalize_url(url)
      )
    end

    def create_or_update_scraped_property
      uri = begin
        URI.parse(@url)
      rescue URI::InvalidURIError
        nil
      end

      ScrapedProperty.find_or_initialize_by(
        website: website,
        source_url_normalized: normalize_url(url)
      ).tap do |sp|
        sp.source_url = @url
        sp.source_host = uri&.host&.downcase
        sp.source_portal = detect_portal(uri&.host)
        sp.import_status ||= "pending"
        sp.save!
      end
    end

    def attempt_scrape
      connector = select_connector
      result = connector.fetch

      # If HTTP fails with blocking error and Playwright is available, try Playwright
      if !result[:success] && should_retry_with_playwright?(result)
        playwright_connector = ScraperConnectors::Playwright.new(@url)
        result = playwright_connector.fetch
      end

      result
    end

    def select_connector
      case @preferred_connector
      when :playwright
        ScraperConnectors::Playwright.new(@url)
      when :http
        ScraperConnectors::Http.new(@url)
      else
        # Default to HTTP, Playwright will be tried as fallback if needed
        ScraperConnectors::Http.new(@url)
      end
    end

    def should_retry_with_playwright?(result)
      return false if @preferred_connector == :http # User explicitly chose HTTP
      return false unless ScraperConnectors::Playwright.available?

      error = result[:error].to_s.downcase
      error.include?("cloudflare") ||
        error.include?("blocked") ||
        error.include?("bot protection")
    end

    def select_pasarela
      portal = scraped_property.source_portal

      pasarela_class = case portal
                       when "rightmove" then Pasarelas::Rightmove
                       when "zoopla" then Pasarelas::Zoopla
                       when "idealista" then Pasarelas::Idealista
                       else Pasarelas::Generic
                       end

      pasarela_class.new(scraped_property)
    end

    def detect_portal(host)
      return "generic" if host.blank?

      portal_patterns = {
        "rightmove" => /rightmove/i,
        "zoopla" => /zoopla/i,
        "idealista" => /idealista/i,
        "onthemarket" => /onthemarket/i,
        "zillow" => /zillow/i,
        "redfin" => /redfin/i,
        "realtor" => /realtor\.com/i,
        "trulia" => /trulia/i,
        "daft" => /daft\.ie/i,
        "domain" => /domain\.com\.au/i
      }

      portal_patterns.each do |name, pattern|
        return name if host.match?(pattern)
      end

      "generic"
    end
  end
end
