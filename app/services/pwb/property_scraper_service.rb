# frozen_string_literal: true

module Pwb
  # Orchestrates the scraping process for importing properties from URLs.
  # Handles connector selection, content retrieval, and pasarela dispatch.
  class PropertyScraperService
    attr_reader :url, :website, :scraped_property

    # @param url [String] The property listing URL to scrape
    # @param website [Pwb::Website] The website to associate the scraped property with
    def initialize(url, website:)
      @url = url.to_s.strip
      @website = website
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

        # Parse and extract data using appropriate pasarela
        pasarela = select_pasarela
        pasarela.call

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

      # Parse and extract data
      pasarela = select_pasarela
      pasarela.call

      scraped_property.update!(import_status: "previewing")
      scraped_property
    end

    private

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
      connector = ScraperConnectors::Http.new(@url)
      connector.fetch
    end

    def select_pasarela
      portal = scraped_property.source_portal

      # Currently only Generic pasarela is implemented.
      # Add portal-specific pasarelas here as they're created:
      #
      # pasarela_class = case portal
      # when "rightmove" then Pasarelas::Rightmove
      # when "zoopla" then Pasarelas::Zoopla
      # when "idealista" then Pasarelas::Idealista
      # else Pasarelas::Generic
      # end

      Pasarelas::Generic.new(scraped_property)
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
