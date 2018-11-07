module Pwb
  class PwbSyncController < ActionController::Base
    layout 'pwb/pwb_sync'
    def show
      unless current_user && current_user.admin
        render 'pwb/errors/admin_required', layout: "layouts/pwb/admin_panel_error"
      end
    end

  end
end
