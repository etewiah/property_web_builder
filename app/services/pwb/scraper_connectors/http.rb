# frozen_string_literal: true

require "net/http"
require "uri"

module Pwb
  module ScraperConnectors
    # HTTP connector for fetching property pages using Net::HTTP.
    # This is the primary connector - simple and works for most sites.
    # Falls back to manual HTML entry if blocked.
    class Http < Base
      TIMEOUT = 30
      MIN_CONTENT_LENGTH = 1000
      MAX_REDIRECTS = 3

      # Patterns that indicate Cloudflare or bot protection
      BLOCKED_PATTERNS = [
        /cloudflare/i,
        /checking your browser/i,
        /please wait while we verify/i,
        /just a moment/i,
        /attention required/i,
        /ray id/i
      ].freeze

      def fetch
        uri = parse_uri
        response = make_request_with_redirects(uri)

        validate_response!(response)
        html = response.body

        check_for_blocking!(html)
        validate_content_length!(html)

        {
          success: true,
          html: html,
          content_type: response["Content-Type"],
          final_url: uri.to_s
        }
      rescue BlockedError, InvalidContentError, HttpError => e
        {
          success: false,
          error: e.message,
          error_class: e.class.name
        }
      rescue StandardError => e
        {
          success: false,
          error: "Connection error: #{e.message}",
          error_class: e.class.name
        }
      end

      private

      def make_request_with_redirects(uri, redirect_count = 0)
        raise HttpError.new("Too many redirects", 302) if redirect_count > MAX_REDIRECTS

        http = build_http_client(uri)
        request = build_request(uri)
        response = http.request(request)

        case response
        when Net::HTTPRedirection
          new_uri = URI.parse(response["Location"])
          # Handle relative redirects
          new_uri = URI.join(uri, new_uri) unless new_uri.host
          make_request_with_redirects(new_uri, redirect_count + 1)
        else
          response
        end
      end

      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http
      end

      def build_request(uri)
        request = Net::HTTP::Get.new(uri)
        default_headers.each { |key, value| request[key] = value }

        # Add host-specific headers if needed
        request["Authority"] = uri.host
        request["Upgrade-Insecure-Requests"] = "1"

        request
      end

      def validate_response!(response)
        case response
        when Net::HTTPSuccess
          # OK
        when Net::HTTPForbidden, Net::HTTPServiceUnavailable
          raise BlockedError, "Access blocked by server (HTTP #{response.code}). " \
                              "The site may be using Cloudflare or bot protection."
        when Net::HTTPClientError
          raise HttpError.new("Client error: #{response.code} #{response.message}", response.code.to_i)
        when Net::HTTPServerError
          raise HttpError.new("Server error: #{response.code} #{response.message}", response.code.to_i)
        else
          raise HttpError.new("Unexpected response: #{response.code} #{response.message}", response.code.to_i)
        end
      end

      def check_for_blocking!(html)
        return if html.nil?

        # Check if the response looks like a Cloudflare challenge page
        BLOCKED_PATTERNS.each do |pattern|
          if html.match?(pattern) && html.length < 50_000
            raise BlockedError, "Request blocked by Cloudflare or bot protection. " \
                                "Please use the manual HTML entry option."
          end
        end
      end

      def validate_content_length!(html)
        return if html.nil?

        if html.length < MIN_CONTENT_LENGTH
          raise InvalidContentError, "Content too short (#{html.length} bytes). " \
                                     "The page may not have loaded properly."
        end
      end
    end
  end
end
