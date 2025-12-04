# frozen_string_literal: true

# SiteAdminController
# Base controller for site admin functionality
#
# Unlike TenantAdminController which manages all tenants, SiteAdminController
# is scoped to a single website/tenant using the SubdomainTenant concern.
#
# Authentication: Requires logged in user (via Devise)
# Authorization: Phase 2 - currently available to any logged in user
class SiteAdminController < ActionController::Base
  include SubdomainTenant

  before_action :authenticate_user!

  layout 'site_admin'

  # Helper method to get the current website from the SubdomainTenant concern
  def current_website
    Pwb::Current.website
  end
  helper_method :current_website
end
