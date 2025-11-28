# frozen_string_literal: true

# This concern provides subdomain-based multi-tenancy support.
# It resolves the current tenant (Pwb::Website) based on the request subdomain
# and ensures data isolation between different subdomains.
#
# Usage:
#   include SubdomainTenant
#
# This will automatically set Pwb::Current.website based on the subdomain
# before each action.
module SubdomainTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_website_from_subdomain
  end

  private

  # Resolves the current website based on the request subdomain.
  # Priority:
  # 1. X-Website-Slug header (for API/GraphQL requests)
  # 2. Request subdomain
  # 3. Fallback to default website
  def set_current_website_from_subdomain
    # First check for explicit header (useful for API clients)
    slug = request.headers["X-Website-Slug"]
    if slug.present?
      Pwb::Current.website = Pwb::Website.find_by(slug: slug)
    end

    # If no header, try subdomain resolution
    if Pwb::Current.website.blank? && request_subdomain.present?
      Pwb::Current.website = Pwb::Website.find_by(subdomain: request_subdomain)
    end

    # Fallback to default if not found
    Pwb::Current.website ||= Pwb::Website.first
  end

  # Extracts the subdomain from the request.
  # Handles cases like:
  # - site1.example.com -> "site1"
  # - www.example.com -> nil (www is ignored)
  # - example.com -> nil
  # - site1.staging.example.com -> "site1" (for multi-level domains)
  def request_subdomain
    subdomain = request.subdomain

    # Ignore common non-tenant subdomains
    return nil if subdomain.blank?
    return nil if subdomain == "www"
    return nil if subdomain == "api"
    return nil if subdomain == "admin"

    # For multi-level subdomains, take the first part
    # e.g., "site1.staging" -> "site1"
    subdomain.split(".").first
  end

  # Helper method to get the current website
  def current_website
    Pwb::Current.website
  end
end
