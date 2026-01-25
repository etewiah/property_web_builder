# frozen_string_literal: true

require_dependency 'pwb/application_controller'

module Pwb
  # Proxy controller for client-rendered websites (A themes)
  # Routes requests through Rails to the Astro client server while maintaining
  # authentication and tenant context
  class ClientProxyController < ApplicationController
    include SubdomainTenant

    # Skip standard Rails processing for proxied requests
    skip_before_action :verify_authenticity_token, only: [:public_proxy, :admin_proxy]

    before_action :ensure_client_rendering_mode
    before_action :authenticate_for_admin_routes!, only: [:admin_proxy]

    # Proxy public pages to Astro client
    def public_proxy
      proxy_to_astro_client(request.fullpath)
    end

    # Proxy admin/management pages to Astro client (requires auth)
    def admin_proxy
      proxy_to_astro_client(request.fullpath, with_auth: true)
    end

    private

    # Ensure this controller only handles client-rendered websites
    def ensure_client_rendering_mode
      unless current_website&.client_rendering?
        # Fall through to normal Rails rendering
        raise ActionController::RoutingError, 'Not Found'
      end
    end

    # Require authentication for client admin routes
    def authenticate_for_admin_routes!
      return if user_signed_in?

      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path, alert: 'Please sign in to access this page.'
    end

    # Main proxy method - forwards requests to Astro client
    def proxy_to_astro_client(path, with_auth: false)
      astro_url = build_astro_url(path)

      # Build request headers
      headers = proxy_headers
      headers.merge!(auth_headers) if with_auth

      begin
        response = HTTP
          .timeout(connect: 5, read: 30)
          .headers(headers)
          .request(request.method.downcase.to_sym, astro_url, body: request.body.read)

        render_proxy_response(response)
      rescue HTTP::Error, HTTP::TimeoutError => e
        Rails.logger.error "Astro proxy error: #{e.message}"
        render_proxy_error
      end
    end

    # Build the full URL to the Astro client
    def build_astro_url(path)
      "#{astro_client_url}#{path}"
    end

    # Get Astro client URL - per-tenant config takes precedence
    def astro_client_url
      # Per-tenant URL from client_theme_config takes precedence
      tenant_url = current_website&.client_theme_config&.dig('astro_client_url')
      return tenant_url if tenant_url.present?

      # Fall back to environment variable or default
      ENV.fetch('ASTRO_CLIENT_URL', 'http://localhost:4321')
    end

    # Headers to forward to Astro client
    def proxy_headers
      {
        'X-Forwarded-Host' => request.host,
        'X-Forwarded-Proto' => request.protocol.chomp('://'),
        'X-Forwarded-For' => request.remote_ip,
        'X-Website-Slug' => current_website&.subdomain,
        'X-Website-Id' => current_website&.id.to_s,
        'X-Rendering-Mode' => 'client',
        'X-Client-Theme' => current_website&.client_theme_name,
        'Accept' => request.headers['Accept'] || '*/*',
        'Accept-Language' => request.headers['Accept-Language'],
        'Content-Type' => request.content_type
      }.compact
    end

    # Authentication headers for Astro to verify
    def auth_headers
      {
        'X-User-Id' => current_user&.id.to_s,
        'X-User-Email' => current_user&.email,
        'X-User-Role' => current_user_role,
        'X-Auth-Token' => generate_proxy_auth_token
      }.compact
    end

    # Get current user's role for this website
    def current_user_role
      return 'guest' unless current_user

      membership = current_user.user_memberships.find_by(website: current_website)
      membership&.role || 'member'
    end

    # Generate short-lived JWT for Astro to verify request authenticity
    def generate_proxy_auth_token
      payload = {
        user_id: current_user&.id,
        website_id: current_website&.id,
        exp: 5.minutes.from_now.to_i,
        iat: Time.current.to_i
      }
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end

    # Render the response from Astro client
    def render_proxy_response(response)
      # Copy relevant response headers
      response.headers.each do |key, value|
        # Skip hop-by-hop headers
        next if hop_by_hop_header?(key)

        headers[key] = value
      end

      # Handle content type
      content_type = response.content_type&.mime_type || 'text/html'

      render body: response.body.to_s,
             status: response.status,
             content_type: content_type
    end

    # Check if header is a hop-by-hop header (should not be forwarded)
    def hop_by_hop_header?(header_name)
      %w[
        connection
        keep-alive
        transfer-encoding
        te
        trailer
        upgrade
        proxy-authorization
        proxy-authenticate
      ].include?(header_name.downcase)
    end

    # Render error page when Astro client is unavailable
    def render_proxy_error
      if request.format.html?
        render 'pwb/errors/proxy_unavailable', status: :service_unavailable, layout: false
      else
        render json: { error: 'Client application unavailable' },
               status: :service_unavailable
      end
    end
  end
end
