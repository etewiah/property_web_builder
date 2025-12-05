require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelVueController < ActionController::Base
    include ::Devise::Controllers::Helpers
    include ::AdminAuthBypass
    helper_method :current_user

    layout "pwb/admin_panel_vue"

    def show
      @subdomain = request.subdomain
      @website = Pwb::Website.find_by_subdomain(@subdomain)
      unless bypass_admin_auth? || (current_user && @website && current_user.admin_for?(@website))
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
      end
    end

    def show_legacy_1
      @subdomain = request.subdomain
      @website = Pwb::Website.find_by_subdomain(@subdomain)
      unless bypass_admin_auth? || (current_user && @website && current_user.admin_for?(@website))
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
        return
      end
      render "pwb/admin_panel/show_legacy_1", layout: "pwb/admin_panel_legacy_1"
    end

    private

    def current_website
      @current_website ||= Pwb::Website.find_by_subdomain(request.subdomain)
    end
  end
end
