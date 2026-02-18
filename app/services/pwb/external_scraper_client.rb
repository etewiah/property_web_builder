# frozen_string_literal: true

module Pwb
  # HTTP client for the Property Web Scraper (PWS) external extraction service.
  # Sends URL + HTML to PWS and receives structured {asset_data, listing_data, images}.
  #
  # Usage:
  #   result = Pwb::ExternalScraperClient.new(url: "https://...", html: "<html>...").call
  #   result.success        # => true
  #   result.extracted_data # => { "asset_data" => {...}, "listing_data" => {...} }
  #   result.extracted_images # => ["https://..."]
  #
  class ExternalScraperClient
    DEFAULT_TIMEOUT = 15

    Result = Struct.new(:success, :extracted_data, :extracted_images, :portal, :extraction_rate, :error, keyword_init: true)

    # Base error class
    class Error < StandardError; end
    class UnsupportedPortalError < Error; end
    class ExtractionFailedError < Error; end
    class ConnectionError < Error; end

    ERROR_CODE_MAP = {
      "UNSUPPORTED_HOST" => UnsupportedPortalError,
      "EXTRACTION_FAILED" => ExtractionFailedError
    }.freeze

    attr_reader :url, :html

    def initialize(url:, html:)
      @url = url
      @html = html
    end

    # POST to PWS extraction endpoint
    # @return [Result]
    def call
      response = connection.post("/public_api/v1/listings") do |req|
        req.params["format"] = "pwb"
        req.headers["X-Api-Key"] = api_key
        req.headers["Content-Type"] = "application/json"
        req.body = { url: url, html: html }.to_json
      end

      parse_response(response)
    rescue Faraday::TimeoutError => e
      raise ConnectionError, "PWS request timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, "PWS connection failed: #{e.message}"
    end

    # Check if the external scraper is enabled
    # Reads from Rails credentials first, falls back to ENV
    def self.enabled?
      config[:api_url].present? && config[:enabled] != "false"
    end

    # Check if the PWS service is healthy
    # @return [Boolean]
    def self.healthy?
      return false unless enabled?

      response = build_connection.get("/public_api/v1/health")
      response.status == 200
    rescue Faraday::Error
      false
    end

    # Fetch supported portals from PWS
    # @return [Array<String>] list of portal identifiers
    def self.supported_portals
      return [] unless enabled?

      response = build_connection.get("/public_api/v1/supported_sites") do |req|
        req.headers["X-Api-Key"] = config[:api_key]
      end

      body = response.body
      body.is_a?(Hash) ? (body["portals"] || body["sites"] || []) : []
    rescue Faraday::Error
      []
    end

    private

    def parse_response(response)
      body = response.body

      if body["success"]
        data = body["data"] || {}
        Result.new(
          success: true,
          extracted_data: {
            "asset_data" => data["asset_data"],
            "listing_data" => data["listing_data"]
          },
          extracted_images: data["images"] || [],
          portal: body["portal"],
          extraction_rate: body["extraction_rate"]
        )
      else
        error_info = body["error"] || {}
        error_code = error_info["code"]
        error_message = error_info["message"] || "Unknown PWS error"

        error_class = ERROR_CODE_MAP[error_code] || Error
        raise error_class, error_message
      end
    end

    def connection
      self.class.build_connection
    end

    def api_key
      self.class.config[:api_key]
    end

    # Loads configuration from Rails credentials, falling back to ENV vars.
    # Rails credentials take precedence when present.
    #
    # config/credentials.yml.enc:
    #   pws:
    #     api_url: https://scraper.yourdomain.com
    #     api_key: your-secure-api-key
    #     timeout: 15
    #     enabled: "true"
    #
    # Or via ENV:
    #   PWS_API_URL, PWS_API_KEY, PWS_TIMEOUT, PWS_ENABLED
    def self.config
      @config ||= begin
        creds = Rails.application.credentials.pws || {}
        {
          api_url: creds[:api_url] || ENV["PWS_API_URL"],
          api_key: creds[:api_key] || ENV["PWS_API_KEY"],
          timeout: creds[:timeout] || ENV["PWS_TIMEOUT"],
          enabled: creds[:enabled] || ENV["PWS_ENABLED"]
        }
      end
    end

    # Reset cached config (useful for testing)
    def self.reset_config!
      @config = nil
    end

    def self.build_connection
      Faraday.new(url: config[:api_url]) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.options.timeout = timeout_seconds
        f.options.open_timeout = 5
      end
    end

    def self.timeout_seconds
      (config[:timeout] || DEFAULT_TIMEOUT).to_i
    end
  end
end
