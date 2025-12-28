# frozen_string_literal: true

module Pwb
  # Service for checking if a newer version of PropertyWebBuilder is available.
  #
  # Calls the PWB version check API endpoint to compare the current version
  # against the latest release.
  #
  # Usage:
  #   # Check for updates and log if available
  #   Pwb::VersionCheckService.check_and_log
  #
  #   # Get version info without logging
  #   info = Pwb::VersionCheckService.check
  #   puts info[:latest_version] if info[:update_available]
  #
  class VersionCheckService
    VERSION_CHECK_URL = 'https://propertywebbuilder.com/api_public/v4/version_check'
    REQUEST_TIMEOUT = 5 # seconds

    class << self
      # Check for updates and log a message if a new version is available
      #
      # @return [Hash, nil] version info hash or nil if check failed
      def check_and_log
        info = check
        return nil unless info

        if info[:update_available]
          log_update_available(info)
        else
          Rails.logger.info "[PWB Version] Running latest version (#{Pwb::VERSION})"
        end

        info
      rescue StandardError => e
        Rails.logger.debug "[PWB Version] Check failed: #{e.message}"
        nil
      end

      # Check for updates by calling the version check API
      #
      # @return [Hash, nil] version info hash or nil if check failed
      # @example Return value
      #   {
      #     incoming_version: "2.1.0",
      #     latest_version: "2.2.0",
      #     latest_release_date: "2025-12-21",
      #     is_latest: false,
      #     update_available: true,
      #     versions_behind: 1
      #   }
      def check
        response = fetch_version_info
        return nil unless response

        parse_response(response)
      rescue StandardError => e
        Rails.logger.debug "[PWB Version] API call failed: #{e.message}"
        nil
      end

      # Get the current PWB version
      #
      # @return [String] the current version string
      def current_version
        Pwb::VERSION
      end

      private

      def fetch_version_info
        uri = URI("#{VERSION_CHECK_URL}?version=#{current_version}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = REQUEST_TIMEOUT
        http.read_timeout = REQUEST_TIMEOUT

        # Skip strict SSL verification for version check (read-only, non-sensitive)
        # This works around OpenSSL 3.6+ CRL verification issues on macOS
        # See: config/initializers/ssl_crl_fix.rb
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'application/json'
        request['User-Agent'] = "PropertyWebBuilder/#{current_version}"

        response = http.request(request)

        return nil unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def parse_response(json_string)
        data = JSON.parse(json_string, symbolize_names: true)

        {
          incoming_version: data[:incoming_version],
          latest_version: data[:latest_version],
          latest_release_date: data[:latest_release_date],
          is_latest: data[:is_latest],
          is_known_version: data[:is_known_version],
          update_available: data[:update_available],
          versions_behind: data[:versions_behind]
        }
      rescue JSON::ParserError => e
        Rails.logger.debug "[PWB Version] Failed to parse response: #{e.message}"
        nil
      end

      def log_update_available(info)
        message = <<~MSG.squish
          [PWB Version] Update available!
          Current: #{info[:incoming_version]},
          Latest: #{info[:latest_version]}
          (#{info[:versions_behind]} version(s) behind,
          released #{info[:latest_release_date]}).
          Visit https://github.com/etewiah/property_web_builder for upgrade instructions.
        MSG

        Rails.logger.info message
      end
    end
  end
end
