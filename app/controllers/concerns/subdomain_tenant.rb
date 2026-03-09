# frozen_string_literal: true

# This concern provides multi-tenancy support based on subdomain OR custom domain.
# It resolves the current tenant (Pwb::Website) based on the request host
# and ensures data isolation between different tenants.
#
# Routing Priority:
# 1. X-Website-Slug header (for API/GraphQL requests)
# 2. Custom domain match (for non-platform domains like www.myrealestate.com)
# 3. Subdomain match (for platform domains like tenant.propertywebbuilder.com)
# 4. Localhost root fallback to the explicit `default` website only
#
# Usage:
#   include SubdomainTenant
#
# This will automatically set Pwb::Current.website based on the request
# before each action.
module SubdomainTenant
  extend ActiveSupport::Concern
  include LocalhostDefaultWebsite

  included do
    before_action :set_current_website_from_request
  end

  private

  # Resolves the current website based on the request.
  # Supports both subdomain-based routing (for platform domains) and
  # custom domain routing (for tenant's own domains).
  def set_current_website_from_request
    host = request.host.to_s.downcase
    Pwb::Current.website = website_from_slug_header || website_from_host || localhost_default_website

    # Set ActsAsTenant for PwbTenant:: models
    ActsAsTenant.current_tenant = Pwb::Current.website

    # Log tenant resolution for debugging (only in development)
    if Rails.env.development? && Pwb::Current.website
      Rails.logger.debug { "[Tenant] Resolved #{host} -> Website##{Pwb::Current.website.id} (#{Pwb::Current.website.subdomain || Pwb::Current.website.custom_domain})" }
    end
  end

  def website_from_slug_header
    slug = request.headers["X-Website-Slug"]
    return nil if slug.blank?

    Pwb::Website.find_by(slug: slug) || Pwb::Website.find_by_subdomain(slug)
  end

  def website_from_host
    Pwb::Website.find_by_host(request.host.to_s.downcase)
  end

  # Helper method to get the current website
  def current_website
    Pwb::Current.website
  end

  # Check if the current request is via custom domain
  def custom_domain_request?
    return false unless current_website&.custom_domain.present?

    host = request.host.to_s.downcase
    normalized_custom = Pwb::Website.normalize_domain(current_website.custom_domain)

    host == normalized_custom ||
      host == "www.#{normalized_custom}" ||
      host.sub(/\Awww\./, '') == normalized_custom
  end

  # Check if the current request is via platform subdomain
  def platform_subdomain_request?
    !custom_domain_request?
  end
end
