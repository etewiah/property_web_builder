# frozen_string_literal: true

module Pwb
  module ScraperConnectors
    # Base class for scraper connectors.
    # Connectors handle the retrieval of raw HTML content from property URLs.
    class Base
      attr_reader :url, :options

      def initialize(url, options = {})
        @url = url.to_s.strip
        @options = options
      end

      # Fetches content from the URL.
      # Returns a hash with:
      #   success: boolean
      #   html: string (if successful)
      #   error: string (if failed)
      #   error_class: string (if failed)
      #   final_url: string (the URL after any redirects)
      def fetch
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end

      protected

      def default_headers
        {
          "User-Agent" => user_agent,
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language" => "en-US,en;q=0.9",
          "Cache-Control" => "no-cache",
          "Pragma" => "no-cache"
        }
      end

      def user_agent
        # Modern Chrome user agent
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
          "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      end

      def parse_uri
        URI.parse(@url)
      rescue URI::InvalidURIError => e
        raise ScrapeError, "Invalid URL: #{e.message}"
      end
    end

    # Base error class for scraping errors
    class ScrapeError < StandardError; end

    # Raised when a site blocks the request (Cloudflare, bot detection, etc.)
    class BlockedError < ScrapeError; end

    # Raised when content is too short or appears invalid
    class InvalidContentError < ScrapeError; end

    # Raised on HTTP errors (4xx, 5xx)
    class HttpError < ScrapeError
      attr_reader :status_code

      def initialize(message, status_code = nil)
        @status_code = status_code
        super(message)
      end
    end
  end
end
