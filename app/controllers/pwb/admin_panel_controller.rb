require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelController < ActionController::Base
    include ::Devise::Controllers::Helpers
    helper_method :current_user
    
    layout 'pwb/admin_panel'
    def show
      unless current_user && current_user.admin && user_matches_subdomain?
        @subdomain = request.subdomain
        @website = Pwb::Website.find_by_subdomain(@subdomain)
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
      end
    end

    def show_legacy_1
      unless current_user && current_user.admin && user_matches_subdomain?
        @subdomain = request.subdomain
        @website = Pwb::Website.find_by_subdomain(@subdomain)
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
        return  # Prevent double render
      end
      render 'pwb/admin_panel/show_legacy_1', layout: "pwb/admin_panel_legacy_1"
    end

    private
  
  def user_matches_subdomain?
    # Ensure user is authenticated
    return false unless current_user
    
    # Ensure subdomain is present
    return false unless request.subdomain.present?
    
    # Find website by subdomain
    website = Pwb::Website.find_by_subdomain(request.subdomain)
    
    # Explicitly check website exists - critical security check
    # Without this, nil == nil could pass if user.website_id is also nil
    return false unless website
    
    # Verify user belongs to this specific website
    current_user.website_id == website.id
  end
  end
end
