# frozen_string_literal: true

module Pwb
  # Custom Firebase ID token verification service.
  #
  # Replaces the firebase_id_token gem to:
  # - Allow redis 5.x and jwt 3.x upgrades
  # - Use Rails.cache instead of direct Redis dependency
  # - Reduce external dependencies
  #
  # Usage:
  #   verifier = Pwb::FirebaseTokenVerifier.new(token)
  #   payload = verifier.verify
  #   # payload contains: user_id, email, name, etc.
  #
  class FirebaseTokenVerifier
    CERTIFICATES_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com'
    CACHE_KEY = 'firebase/google_certificates'
    DEFAULT_CACHE_TTL = 1.hour
    JWT_ALGORITHM = 'RS256'

    class VerificationError < StandardError; end
    class CertificateError < StandardError; end
    class ExpiredTokenError < VerificationError; end
    class InvalidTokenError < VerificationError; end
    class InvalidAudienceError < VerificationError; end
    class InvalidIssuerError < VerificationError; end

    def initialize(token, project_id: nil)
      @token = token
      @project_id = project_id || ENV['FIREBASE_PROJECT_ID']
    end

    # Verify the Firebase ID token and return the payload if valid.
    # Returns nil if verification fails.
    def verify
      return nil if @token.blank?
      return nil if @project_id.blank?

      begin
        verify!
      rescue VerificationError, JWT::DecodeError => e
        Rails.logger.warn "FirebaseTokenVerifier: Verification failed - #{e.message}"
        nil
      end
    end

    # Verify the Firebase ID token and return the payload if valid.
    # Raises an error if verification fails.
    def verify!
      raise InvalidTokenError, 'Token is blank' if @token.blank?
      raise InvalidTokenError, 'Project ID not configured' if @project_id.blank?

      # Decode header to get kid (key ID)
      header = decode_header(@token)
      kid = header['kid']
      raise InvalidTokenError, 'Token missing kid header' if kid.blank?

      # Get the certificate for this kid
      certificate = find_certificate(kid)
      raise CertificateError, "No certificate found for kid: #{kid}" unless certificate

      # Decode and verify the JWT
      public_key = OpenSSL::X509::Certificate.new(certificate).public_key
      payload, = JWT.decode(
        @token,
        public_key,
        true,
        {
          algorithm: JWT_ALGORITHM,
          verify_iat: true,
          verify_expiration: true
        }
      )

      # Validate Firebase-specific claims
      validate_claims!(payload)

      payload
    end

    # Fetch certificates from Google (useful for warming cache)
    def self.fetch_certificates!
      new('').send(:fetch_certificates)
    end

    private

    def decode_header(token)
      # JWT.decode_header is not available, so we decode manually
      header_segment = token.split('.').first
      return {} if header_segment.blank?

      # Add padding if needed (Base64 requires padding to be multiple of 4)
      padded = header_segment + '=' * ((4 - header_segment.length % 4) % 4)
      JSON.parse(Base64.urlsafe_decode64(padded))
    rescue JSON::ParserError, ArgumentError
      {}
    end

    def find_certificate(kid)
      certificates = cached_certificates
      certificates[kid]
    end

    def cached_certificates
      Rails.cache.fetch(CACHE_KEY, expires_in: DEFAULT_CACHE_TTL) do
        fetch_certificates
      end
    end

    def fetch_certificates
      Rails.logger.info 'FirebaseTokenVerifier: Fetching certificates from Google'

      response = Faraday.get(CERTIFICATES_URL)

      unless response.success?
        raise CertificateError, "Failed to fetch certificates: HTTP #{response.status}"
      end

      # Parse cache-control header for TTL
      cache_control = response.headers['cache-control']
      if cache_control && (match = cache_control.match(/max-age=(\d+)/))
        ttl = match[1].to_i.seconds
        # Re-write cache with proper TTL from Google's response
        certificates = JSON.parse(response.body)
        Rails.cache.write(CACHE_KEY, certificates, expires_in: ttl)
        Rails.logger.info "FirebaseTokenVerifier: Cached certificates for #{ttl.to_i} seconds"
        return certificates
      end

      JSON.parse(response.body)
    rescue Faraday::Error => e
      raise CertificateError, "Network error fetching certificates: #{e.message}"
    rescue JSON::ParserError => e
      raise CertificateError, "Invalid JSON in certificates response: #{e.message}"
    end

    def validate_claims!(payload)
      # Validate audience (aud) - must be our project ID
      unless payload['aud'] == @project_id
        raise InvalidAudienceError, "Invalid audience: expected #{@project_id}, got #{payload['aud']}"
      end

      # Validate issuer (iss) - must be Firebase auth
      expected_issuer = "https://securetoken.google.com/#{@project_id}"
      unless payload['iss'] == expected_issuer
        raise InvalidIssuerError, "Invalid issuer: expected #{expected_issuer}, got #{payload['iss']}"
      end

      # Validate subject (sub) - must be non-empty (this is the user's Firebase UID)
      if payload['sub'].blank?
        raise InvalidTokenError, 'Token subject (sub) is empty'
      end

      # auth_time must be in the past
      if payload['auth_time'] && payload['auth_time'] > Time.now.to_i
        raise InvalidTokenError, 'auth_time is in the future'
      end

      true
    end
  end
end
