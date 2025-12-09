# frozen_string_literal: true

# Base controller for Tenant Admin functionality.
# This controller bypasses all tenant scoping to allow cross-tenant management.
#
# CRITICAL: This controller does NOT include the SubdomainTenant concern,
# which means it operates across all tenants/websites without restriction.
#
# Authorization: Access is restricted to email addresses listed in the
# TENANT_ADMIN_EMAILS environment variable (comma-separated list).
# Example: TENANT_ADMIN_EMAILS="admin@example.com,super@example.com"
#
# Dev/E2E bypass: Set BYPASS_ADMIN_AUTH=true to skip authentication
class TenantAdminController < ActionController::Base
  include AdminAuthBypass
  include Pagy::Method
  helper AuthHelper

  protect_from_forgery with: :exception

  # Require user authentication (Devise)
  before_action :authenticate_user!, unless: :bypass_admin_auth?
  # Require user to be in the allowed tenant admins list
  before_action :require_tenant_admin!, unless: :bypass_admin_auth?

  layout 'tenant_admin'

  # Helper method to bypass tenant scoping when querying models
  # Usage: unscoped_model(Pwb::Website).all
  def unscoped_model(model_class)
    model_class.unscoped
  end

  helper_method :unscoped_model

  private

  # Check if current user's email is in the TENANT_ADMIN_EMAILS list
  def require_tenant_admin!
    unless tenant_admin_allowed?
      render_tenant_admin_forbidden
    end
  end

  def tenant_admin_allowed?
    return false unless current_user

    allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip).map(&:downcase)
    return false if allowed_emails.empty?

    allowed_emails.include?(current_user.email.downcase)
  end

  def render_tenant_admin_forbidden
    respond_to do |format|
      format.html { render 'pwb/errors/tenant_admin_required', layout: 'tenant_admin', status: :forbidden }
      format.json { render json: { error: 'Access denied. Your email is not authorized for tenant admin access.' }, status: :forbidden }
    end
  end
end
