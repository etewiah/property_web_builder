# frozen_string_literal: true

# Routing constraint to identify requests for client-rendered websites
# Used to route requests to the Astro proxy for websites using A themes
class ClientRenderingConstraint
  # Paths that should always go to Rails, even for client-rendered sites
  EXCLUDED_PATHS = %w[
    /site_admin
    /tenant_admin
    /api
    /api_public
    /users
    /rails
    /assets
    /packs
    /cable
    /active_storage
    /health
    /setup
    /signup
    /pwb_login
    /pwb_sign_up
    /pwb_forgot_password
    /pwb_change_password
    /auth
    /graphql
    /graphiql
    /api-docs
    /.well-known
    /reports
  ].freeze

  # Check if request should be handled by Astro proxy
  def matches?(request)
    return false if excluded_path?(request.path)

    website = website_from_request(request)

    if Rails.env.development?
      Rails.logger.debug "[ClientRenderingConstraint] Path: #{request.path}"
      Rails.logger.debug "[ClientRenderingConstraint] Website: #{website&.id}"
      Rails.logger.debug "[ClientRenderingConstraint] rendering_mode: #{website&.rendering_mode}"
      Rails.logger.debug "[ClientRenderingConstraint] client_rendering?: #{website&.client_rendering?}"
    end

    website&.client_rendering? || false
  end

  private

  # Find website from request (by custom domain, subdomain, or fallback)
  # Mirrors the logic in SubdomainTenant concern
  def website_from_request(request)
    host = request.host.to_s.downcase
    website = nil

    # Use the unified find_by_host method if available
    if Pwb::Website.respond_to?(:find_by_host)
      website = Pwb::Website.find_by_host(host)
    else
      # Fallback: Try custom domain first
      website = Pwb::Website.find_by(custom_domain: host)

      # Try subdomain if custom domain not found
      if website.nil?
        subdomain = extract_subdomain(host)
        website = Pwb::Website.find_by(subdomain: subdomain) if subdomain
      end
    end

    # Fallback to first website for localhost/development
    website || (Rails.env.development? || Rails.env.test? ? Pwb::Website.first : nil)
  end

  # Extract subdomain from host
  def extract_subdomain(host)
    # Skip if it's an IP address
    return nil if host.match?(/\A\d+\.\d+\.\d+\.\d+\z/)

    parts = host.split('.')
    return nil if parts.length < 3

    # Handle cases like tenant.propertywebbuilder.com
    parts.first
  end

  # Check if path should be excluded from proxy
  def excluded_path?(path)
    EXCLUDED_PATHS.any? { |prefix| path.start_with?(prefix) }
  end
end
