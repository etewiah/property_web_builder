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
          Rails.logger.info "[PWB Version] Running latest version (#{version_with_revision})"
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

      # Get the current git revision (short SHA)
      #
      # Checks in order:
      # 1. REVISION file in Rails root (created at deploy time)
      # 2. Environment variables (GIT_REVISION, HEROKU_SLUG_COMMIT, SOURCE_VERSION, GIT_REV)
      # 3. Git command (development only, may not work in production)
      #
      # @return [String, nil] the git revision or nil if unavailable
      def git_revision
        @git_revision ||= read_revision_file || read_env_revision || read_git_revision
      end

      # Get version with git revision for display
      #
      # @return [String] version string with optional revision suffix
      # @example "2.2.0" or "2.2.0 (abc1234)"
      def version_with_revision
        rev = git_revision
        rev.present? ? "#{current_version} (#{rev})" : current_version
      end

      private

      def fetch_version_info
        params = { version: current_version }
        params[:revision] = git_revision if git_revision.present?

        uri = URI("#{VERSION_CHECK_URL}?#{URI.encode_www_form(params)}")

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
        request['User-Agent'] = user_agent_string

        response = http.request(request)

        return nil unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def user_agent_string
        rev = git_revision
        base = "PropertyWebBuilder/#{current_version}"
        rev.present? ? "#{base} (#{rev})" : base
      end

      def read_revision_file
        revision_file = Rails.root.join('REVISION')
        return nil unless File.exist?(revision_file)

        File.read(revision_file).strip.presence&.slice(0, 7)
      rescue StandardError
        nil
      end

      # Check common CI/CD environment variables for git revision
      def read_env_revision
        # Common env vars set by various platforms:
        # - GIT_REVISION: Custom/manual
        # - HEROKU_SLUG_COMMIT: Heroku
        # - SOURCE_VERSION: Heroku buildpacks
        # - GIT_REV: Dokku
        # - RENDER_GIT_COMMIT: Render
        # - RAILWAY_GIT_COMMIT_SHA: Railway
        %w[GIT_REVISION HEROKU_SLUG_COMMIT SOURCE_VERSION GIT_REV RENDER_GIT_COMMIT RAILWAY_GIT_COMMIT_SHA].each do |var|
          value = ENV[var]
          return value.strip.slice(0, 7) if value.present?
        end
        nil
      end

      def read_git_revision
        return nil unless File.directory?(Rails.root.join('.git'))

        `git rev-parse --short HEAD 2>/dev/null`.strip.presence
      rescue StandardError
        nil
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
        current_display = version_with_revision
        message = <<~MSG.squish
          [PWB Version] Update available!
          Current: #{current_display},
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
