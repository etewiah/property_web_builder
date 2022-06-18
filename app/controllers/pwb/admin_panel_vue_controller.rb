require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelVueController < ActionController::Base
    layout "pwb/admin_panel_vue"

    def show
      unless current_user && current_user.admin
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
      end
    end

    def show_legacy_1
      unless current_user && current_user.admin
        render "pwb/errors/admin_required", layout: "layouts/pwb/admin_panel_error"
      end
      render "pwb/admin_panel/show_legacy_1", layout: "pwb/admin_panel_legacy_1"
    end
  end
end
