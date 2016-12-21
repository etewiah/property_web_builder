require_dependency "pwb/application_controller"

module Pwb
  class AdminPanelController < ActionController::Base
    layout 'pwb/admin_panel'
    def show
      unless current_user && current_user.admin 
        render 'pwb/errors/admin_required', :layout => "layouts/pwb/application"
      end
    end
  end
end
