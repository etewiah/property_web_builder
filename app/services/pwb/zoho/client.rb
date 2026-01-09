# frozen_string_literal: true

module Pwb
  module Zoho
    # HTTP client for Zoho CRM API with OAuth token management
    #
    # Handles:
    # - OAuth access token refresh
    # - Token caching to avoid unnecessary refreshes
    # - API error handling and retries
    # - Rate limit awareness
    #
    # Usage:
    #   client = Pwb::Zoho::Client.instance
    #   client.post('/Leads', { data: [{ Email: 'test@example.com' }] })
    #
    class Client
      TOKEN_REFRESH_BUFFER = 5.minutes
      DEFAULT_TIMEOUT = 30
      CACHE_KEY = 'zoho_crm_access_token'

      class << self
        def instance
          @instance ||= new
        end

        # Reset the singleton instance (useful for testing)
        def reset!
          @instance = nil
        end
      end

      def initialize
        @credentials = load_credentials
      end

      # Check if Zoho integration is configured
      #
      # @return [Boolean]
      #
      def configured?
        @credentials[:client_id].present? &&
          @credentials[:client_secret].present? &&
          @credentials[:refresh_token].present?
      end

      # POST request to Zoho CRM API
      #
      # @param endpoint [String] API endpoint (e.g., '/Leads')
      # @param body [Hash] Request body
      # @return [Hash] Parsed JSON response
      #
      def post(endpoint, body)
        request(:post, endpoint, body)
      end

      # PUT request to Zoho CRM API
      #
      # @param endpoint [String] API endpoint (e.g., '/Leads/12345')
      # @param body [Hash] Request body
      # @return [Hash] Parsed JSON response
      #
      def put(endpoint, body)
        request(:put, endpoint, body)
      end

      # GET request to Zoho CRM API
      #
      # @param endpoint [String] API endpoint
      # @param params [Hash] Query parameters
      # @return [Hash] Parsed JSON response
      #
      def get(endpoint, params = {})
        request(:get, endpoint, nil, params)
      end

      # DELETE request to Zoho CRM API
      #
      # @param endpoint [String] API endpoint
      # @return [Hash] Parsed JSON response
      #
      def delete(endpoint)
        request(:delete, endpoint)
      end

      private

      def load_credentials
        creds = Rails.application.credentials.zoho || {}
        {
          client_id: creds[:client_id] || ENV['ZOHO_CLIENT_ID'],
          client_secret: creds[:client_secret] || ENV['ZOHO_CLIENT_SECRET'],
          refresh_token: creds[:refresh_token] || ENV['ZOHO_REFRESH_TOKEN'],
          api_domain: creds[:api_domain] || ENV['ZOHO_API_DOMAIN'] || 'https://www.zohoapis.com',
          accounts_url: creds[:accounts_url] || ENV['ZOHO_ACCOUNTS_URL'] || 'https://accounts.zoho.com'
        }
      end

      def request(method, endpoint, body = nil, params = {})
        ensure_configured!

        response = connection.send(method, endpoint) do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.params = params if params.any?
          req.body = body.to_json if body
        end

        handle_response(response)
      rescue Faraday::TimeoutError => e
        raise TimeoutError, "Zoho API timeout: #{e.message}"
      rescue Faraday::ConnectionFailed => e
        raise ConnectionError, "Zoho API connection failed: #{e.message}"
      end

      def connection
        @connection ||= Faraday.new(url: api_base_url) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
          f.options.timeout = DEFAULT_TIMEOUT
          f.options.open_timeout = 10
        end
      end

      def api_base_url
        "#{@credentials[:api_domain]}/crm/v3"
      end

      def access_token
        cached = Rails.cache.read(CACHE_KEY)
        return cached if cached.present?

        refresh_access_token
      end

      def refresh_access_token
        Rails.logger.info "[Zoho] Refreshing access token"

        response = token_connection.post('/oauth/v2/token') do |req|
          req.params = {
            refresh_token: @credentials[:refresh_token],
            client_id: @credentials[:client_id],
            client_secret: @credentials[:client_secret],
            grant_type: 'refresh_token'
          }
        end

        data = response.body.is_a?(Hash) ? response.body : JSON.parse(response.body)

        if data['access_token']
          expires_in = (data['expires_in'] || 3600).to_i - TOKEN_REFRESH_BUFFER.to_i
          Rails.cache.write(CACHE_KEY, data['access_token'], expires_in: expires_in.seconds)
          Rails.logger.info "[Zoho] Access token refreshed, expires in #{expires_in}s"
          data['access_token']
        else
          error_msg = data['error'] || data['error_description'] || 'Unknown error'
          Rails.logger.error "[Zoho] Token refresh failed: #{error_msg}"
          raise AuthenticationError, "Zoho token refresh failed: #{error_msg}"
        end
      end

      def token_connection
        @token_connection ||= Faraday.new(url: @credentials[:accounts_url]) do |f|
          f.request :url_encoded
          f.response :json
          f.adapter Faraday.default_adapter
          f.options.timeout = 15
        end
      end

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        when 401
          # Token expired, clear cache and raise for retry
          Rails.cache.delete(CACHE_KEY)
          raise AuthenticationError, "Zoho authentication failed (401)"
        when 429
          retry_after = response.headers['Retry-After']&.to_i || 60
          raise RateLimitError.new("Zoho rate limit exceeded", retry_after: retry_after)
        when 400
          error_details = extract_error_details(response.body)
          raise ValidationError, "Zoho validation error: #{error_details}"
        when 404
          raise NotFoundError, "Zoho resource not found"
        else
          error_details = extract_error_details(response.body)
          raise ApiError, "Zoho API error (#{response.status}): #{error_details}"
        end
      end

      def extract_error_details(body)
        return body.to_s unless body.is_a?(Hash)

        if body['data'].is_a?(Array) && body['data'].first
          body['data'].first['message'] || body['data'].first.to_s
        elsif body['message']
          body['message']
        elsif body['error']
          body['error']
        else
          body.to_s
        end
      end

      def ensure_configured!
        return if configured?

        raise ConfigurationError, "Zoho CRM is not configured. Set ZOHO_CLIENT_ID, ZOHO_CLIENT_SECRET, and ZOHO_REFRESH_TOKEN"
      end
    end

    # Error classes are defined in errors.rb
  end
end
