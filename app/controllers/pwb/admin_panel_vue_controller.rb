require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelVueController < ActionController::Base
    include ::Devise::Controllers::Helpers
    helper_method :current_user
    
    layout "pwb/admin_panel_vue"

    def show
      @subdomain = request.subdomain
      @website = Pwb::Website.find_by_subdomain(@subdomain)
      unless current_user && @website && current_user.admin_for?(@website)
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
      end
    end

    def show_legacy_1
      @subdomain = request.subdomain
      @website = Pwb::Website.find_by_subdomain(@subdomain)
      unless current_user && @website && current_user.admin_for?(@website)
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
        return
      end
      render "pwb/admin_panel/show_legacy_1", layout: "pwb/admin_panel_legacy_1"
    end

    private
  end
end
