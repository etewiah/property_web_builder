require_dependency "pwb/application_controller"

module Pwb
  class VuePublicController < ActionController::Base
    layout "pwb/vue_public"

    def show
    end
  end
end
