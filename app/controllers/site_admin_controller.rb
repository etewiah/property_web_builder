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
# Authorization: Requires user to be admin/owner for the current website
#
# Dev/E2E bypass: Set BYPASS_ADMIN_AUTH=true to skip authentication
class SiteAdminController < ActionController::Base
  include ::Devise::Controllers::Helpers
  include SubdomainTenant
  include AdminAuthBypass
  include Pagy::Method
  helper AuthHelper
  helper_method :current_user

  # Set tenant for acts_as_tenant - all PwbTenant:: queries auto-scoped
  before_action :set_tenant_from_subdomain

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :require_admin!, unless: :bypass_admin_auth?
  before_action :check_subscription_access, unless: :bypass_admin_auth?
  before_action :set_nav_counts

  layout 'site_admin'

  # Helper method to get the current website from the SubdomainTenant concern
  def current_website
    Pwb::Current.website
  end
  helper_method :current_website

  private

  # Require user to be authenticated and admin for the current website
  # Same authorization as /admin (AdminPanelController)
  def require_admin!
    unless current_user && user_is_admin_for_subdomain?
      @subdomain = request.subdomain
      @website = current_website
      # Use minimal layout without navigation for error page
      render 'pwb/errors/admin_required', layout: 'pwb/admin_panel_error', status: :forbidden
    end
  end

  # Check if current user is admin/owner for the current website
  def user_is_admin_for_subdomain?
    return false unless current_user
    return false unless current_website

    current_user.admin_for?(current_website)
  end

  # Handle record not found errors with a user-friendly message
  # Preserves the URL and shows an error page instead of redirecting
  def record_not_found
    @resource_type = controller_name.singularize.titleize
    render 'site_admin/shared/record_not_found', status: :not_found
  end

  # Set the current tenant for acts_as_tenant from the subdomain
  def set_tenant_from_subdomain
    ActsAsTenant.current_tenant = current_website
  end

  # Set navigation counts for badges (unread messages, etc.)
  def set_nav_counts
    return unless current_website

    @unread_messages_count = Pwb::Message.where(website_id: current_website.id, read: false).count
  end

  # Check if subscription allows access to admin functionality
  # Allows access if:
  # - No subscription (legacy/free tier)
  # - Subscription is trialing or active
  # - Subscription is past_due (grace period)
  def check_subscription_access
    return if current_website.nil?
    return if current_website.subscription.nil? # No subscription = legacy access

    unless current_website.subscription.allows_access?
      redirect_to billing_path,
                  alert: 'Your subscription has expired. Please upgrade to continue using the admin panel.'
    end
  end

  # Helper method to check if subscription is in good standing
  # More strict than allows_access? - blocks on past_due
  def subscription_in_good_standing?
    current_website&.subscription.nil? || current_website&.subscription&.in_good_standing?
  end
  helper_method :subscription_in_good_standing?
end
