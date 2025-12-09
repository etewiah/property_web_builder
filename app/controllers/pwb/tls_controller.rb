module Pwb
  # Controller for on-demand TLS certificate verification.
  #

  class TlsController < ApplicationController
    # Skip authentication - this is called by the TLS proxy, not users
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    # Optional: Add IP-based or secret-based authentication
    before_action :verify_tls_request

    # GET /tls/check?domain=example.com
    #
    # The TLS proxy sends the domain as a query parameter.
    # Returns:
    #   200 OK - Domain is valid, proceed with certificate issuance
    #   403 Forbidden - Domain exists but is not allowed (suspended, etc.)
    #   404 Not Found - Domain does not exist in our system
    #
    def check
      domain = params[:domain]

      if domain.blank?
        render plain: "Missing domain parameter", status: :bad_request
        return
      end

      # Normalize the domain
      normalized_domain = domain.to_s.downcase.strip

      # Check if it's a valid domain for our platform
      result = verify_domain(normalized_domain)

      case result[:status]
      when :ok
        Rails.logger.info("[TLS] Approved certificate for: #{normalized_domain}")
        render plain: "OK", status: :ok
      when :forbidden
        Rails.logger.warn("[TLS] Forbidden domain: #{normalized_domain} - #{result[:reason]}")
        render plain: result[:reason], status: :forbidden
      when :not_found
        Rails.logger.info("[TLS] Unknown domain: #{normalized_domain}")
        render plain: "Domain not found", status: :not_found
      end
    end

    private

    def verify_domain(domain)
      # Check 1: Is this a platform subdomain? (e.g., tenant.propertywebbuilder.com)
      if platform_subdomain?(domain)
        return verify_platform_subdomain(domain)
      end

      # Check 2: Is this a custom domain?
      return verify_custom_domain(domain)
    end

    def platform_subdomain?(domain)
      Website.platform_domains.any? { |pd| domain.end_with?(".#{pd}") || domain == pd }
    end

    def verify_platform_subdomain(domain)
      # Extract subdomain from the domain
      subdomain = Website.extract_subdomain_from_host(domain)

      if subdomain.blank?
        # This is a bare platform domain (e.g., propertywebbuilder.com)
        # Allow it - it's our main platform
        return { status: :ok, reason: "Platform domain" }
      end

      # Check if subdomain is reserved (admin, www, api, etc.)
      if Website::RESERVED_SUBDOMAINS.include?(subdomain.downcase)
        return { status: :ok, reason: "Reserved subdomain" }
      end

      # Look up the website
      website = Website.find_by_subdomain(subdomain)

      if website.nil?
        return { status: :not_found, reason: "Subdomain not registered" }
      end

      # Check website status
      validate_website_status(website)
    end

    def verify_custom_domain(domain)
      # Look up website by custom domain
      website = Website.find_by_custom_domain(domain)

      if website.nil?
        return { status: :not_found, reason: "Custom domain not registered" }
      end

      # Check if custom domain is verified (or allow in development)
      unless website.custom_domain_active?
        return { status: :forbidden, reason: "Custom domain not verified" }
      end

      # Check website status
      validate_website_status(website)
    end

    def validate_website_status(website)
      # Check provisioning state
      case website.provisioning_state
      when 'live', 'ready'
        { status: :ok, reason: "Website active" }
      when 'suspended'
        { status: :forbidden, reason: "Website suspended" }
      when 'terminated'
        { status: :forbidden, reason: "Website terminated" }
      when 'failed'
        { status: :forbidden, reason: "Website provisioning failed" }
      else
        # Still provisioning - allow certificate but website may not be ready
        { status: :ok, reason: "Website provisioning in progress" }
      end
    end

    def verify_tls_request
      # Option 1: Check for a shared secret in headers
      expected_secret = ENV['TLS_CHECK_SECRET']
      if expected_secret.present?
        provided_secret = request.headers['X-TLS-Secret'] || params[:secret]
        unless ActiveSupport::SecurityUtils.secure_compare(provided_secret.to_s, expected_secret)
          Rails.logger.warn("[TLS] Invalid secret from #{request.remote_ip}")
          render plain: "Unauthorized", status: :unauthorized
          return
        end
      end

      # Option 2: IP allowlist (uncomment to enable)
      # allowed_ips = ENV.fetch('TLS_CHECK_ALLOWED_IPS', '127.0.0.1,::1').split(',').map(&:strip)
      # unless allowed_ips.include?(request.remote_ip)
      #   Rails.logger.warn("[TLS] Request from unauthorized IP: #{request.remote_ip}")
      #   render plain: "Unauthorized", status: :unauthorized
      #   return
      # end
    end
  end
end
