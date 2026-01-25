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

  # Exception Handling
  #
  # Handle ParameterMissing (raised when params.require(:key) fails)
  # This happens when form submissions are missing required param keys,
  # typically due to form_with missing the `scope:` parameter.
  #
  # Returns 422 Unprocessable Entity with diagnostic info in logs.
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

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

  # Handle ActionController::ParameterMissing exceptions
  #
  # This exception is raised when params.require(:key) fails, typically due to:
  # 1. Form is missing `scope:` parameter in form_with (most common)
  # 2. Client is sending malformed/incomplete request body
  # 3. CSRF token issues causing form data to be rejected
  #
  # Logs detailed diagnostic info to help troubleshoot production issues.
  #
  # @param exception [ActionController::ParameterMissing] the caught exception
  def handle_parameter_missing(exception)
    Rails.logger.error("[TenantAdmin] ParameterMissing: #{exception.message}")
    Rails.logger.error("[TenantAdmin] This usually indicates a form is missing 'scope:' parameter")
    Rails.logger.error("[TenantAdmin] Controller: #{controller_name}##{action_name}")
    Rails.logger.error("[TenantAdmin] Request path: #{request.path}")
    Rails.logger.error("[TenantAdmin] Request params keys: #{params.keys.inspect}")

    # Log any form-like params at top level (helps identify form scope issues)
    form_like_params = params.to_unsafe_h.except(:controller, :action, :id, :authenticity_token)
    if form_like_params.any?
      Rails.logger.error("[TenantAdmin] Top-level params (possible form scope issue): #{form_like_params.keys.inspect}")
    end

    respond_to do |format|
      format.html do
        flash[:alert] = "Form submission error: #{exception.param} parameter is missing. Please try again."
        redirect_back(fallback_location: tenant_admin_root_path)
      end
      format.json do
        render json: {
          error: 'Parameter missing',
          details: exception.message,
          hint: 'If this is a form submission, ensure the form uses scope: :resource_name'
        }, status: :unprocessable_entity
      end
      format.any do
        head :unprocessable_entity
      end
    end
  end
end
