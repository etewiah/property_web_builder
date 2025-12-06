# frozen_string_literal: true

# SiteAdminController
# Base controller for site admin functionality
#
# Unlike TenantAdminController which manages all tenants, SiteAdminController
# is scoped to a single website/tenant using the SubdomainTenant concern.
#
# All PwbTenant:: models are automatically scoped to current_website via
# acts_as_tenant. No manual where(website_id: ...) needed.
#
# Authentication: Requires logged in user (via Devise)
# Authorization: Phase 2 - currently available to any logged in user
#
# Dev/E2E bypass: Set BYPASS_ADMIN_AUTH=true to skip authentication
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  include AdminAuthBypass

  # Set tenant for acts_as_tenant - all PwbTenant:: queries auto-scoped
  set_current_tenant_through_filter
  before_action :set_current_tenant

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :authenticate_user!, unless: :bypass_admin_auth?

  layout 'site_admin'

  # Helper method to get the current website from the SubdomainTenant concern
  def current_website
    Pwb::Current.website
  end
  helper_method :current_website

  private

  # Handle record not found errors with a user-friendly message
  # Preserves the URL and shows an error page instead of redirecting
  def record_not_found
    @resource_type = controller_name.singularize.titleize
    render 'site_admin/shared/record_not_found', status: :not_found
  end

  # Set the current tenant for acts_as_tenant
  def set_current_tenant
    set_current_tenant_to(current_website)
  end
end
