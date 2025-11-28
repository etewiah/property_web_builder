# frozen_string_literal: true

# Base controller for Tenant Admin functionality.
# This controller bypasses all tenant scoping to allow cross-tenant management.
#
# CRITICAL: This controller does NOT include the SubdomainTenant concern,
# which means it operates across all tenants/websites without restriction.
#
# For this initial implementation, we use only Devise authentication.
# Full authorization with super_admin flag will be added in a future phase.
class TenantAdminController < ActionController::Base
  protect_from_forgery with: :exception

  # Require user authentication (Devise)
  # Note: Authorization will be added in Phase 2
  before_action :authenticate_user!

  layout 'tenant_admin'

  # Helper method to bypass tenant scoping when querying models
  # Usage: unscoped_model(Pwb::Website).all
  def unscoped_model(model_class)
    model_class.unscoped
  end

  helper_method :unscoped_model
end
