# frozen_string_literal: true

module Integrations
  module Providers
    # Shotstack video rendering integration provider.
    #
    # Provides access to Shotstack's cloud-based video editing API
    # for automated property listing video generation.
    #
    # Required credentials:
    # - api_key: Shotstack API key from dashboard.shotstack.io
    #
    # Settings:
    # - environment: sandbox or production
    # - default_quality: Video quality preset
    #
    class Shotstack < Base
      self.category = :video
      self.display_name = 'Shotstack'
      self.description = 'Automated video rendering for property listings'

      ENVIRONMENTS = [
        ['Sandbox (Testing)', 'sandbox'],
        ['Production', 'production']
      ].freeze

      QUALITY_OPTIONS = [
        ['Standard (720p)', 'sd'],
        ['High Definition (1080p)', 'hd'],
        ['Ultra HD (4K)', '4k']
      ].freeze

      API_URLS = {
        'sandbox' => 'https://api.shotstack.io/stage',
        'production' => 'https://api.shotstack.io/v1'
      }.freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from dashboard.shotstack.io'

      setting_field :environment,
                    type: :select,
                    options: ENVIRONMENTS,
                    default: 'sandbox',
                    label: 'Environment',
                    help: 'Use sandbox for testing, production for live videos'

      setting_field :default_quality,
                    type: :select,
                    options: QUALITY_OPTIONS,
                    default: 'hd',
                    label: 'Default Quality',
                    help: 'Video resolution for generated videos'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'API key is required')
          return false
        end

        # Test API connection with a simple probe request
        response = connection.get('/probe')

        if response.success?
          true
        else
          errors.add(:base, "API returned status #{response.status}")
          false
        end
      rescue Faraday::UnauthorizedError
        errors.add(:base, 'Invalid API key')
        false
      rescue Faraday::Error => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      rescue StandardError => e
        errors.add(:base, "Unexpected error: #{e.message}")
        false
      end

      def api_base_url
        API_URLS[setting(:environment)] || API_URLS['sandbox']
      end

      private

      def connection
        @connection ||= Faraday.new(url: api_base_url) do |f|
          f.request :json
          f.response :json
          f.response :raise_error
          f.headers['x-api-key'] = credential(:api_key)
        end
      end
    end
  end
end

# Register with the integrations registry
Integrations::Registry.register(:video, :shotstack, Integrations::Providers::Shotstack)
