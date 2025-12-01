require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelController < ActionController::Base
    include ::Devise::Controllers::Helpers
    helper_method :current_user
    
    layout 'pwb/admin_panel'
    def show
      unless current_user && user_is_admin_for_subdomain?
        @subdomain = request.subdomain
        @website = Pwb::Website.find_by_subdomain(@subdomain)
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
      end
    end

    def show_legacy_1
      unless current_user && user_is_admin_for_subdomain?
        @subdomain = request.subdomain
        @website = Pwb::Website.find_by_subdomain(@subdomain)
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
        return  # Prevent double render
      end
      render 'pwb/admin_panel/show_legacy_1', layout: "pwb/admin_panel_legacy_1"
    end

    private
  
    def user_is_admin_for_subdomain?
      # Ensure user is authenticated
      return false unless current_user
      
      # Ensure subdomain is present
      return false unless request.subdomain.present?
      
      # Find website by subdomain
      website = Pwb::Website.find_by_subdomain(request.subdomain)
      
      # Explicitly check website exists
      return false unless website
      
      # Check if user has admin/owner role for this specific website
      current_user.admin_for?(website)
    end
  end
end
