require_dependency "pwb/application_controller"

module Pwb
  class SetupPanelController < ActionController::Base
    layout 'pwb/setup_panel'
    def show
      unless current_user && current_user.admin
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
      end
    end

  end
end
