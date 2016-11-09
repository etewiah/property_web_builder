require_dependency "pwb/application_controller"

module Pwb
  class WelcomeController < ApplicationController

    # GET /welcomes
    def index
      @carousel_items = Pwb::Content.where(tag: "landing-carousel").includes(:content_photos, :translations)
    end

  end
end
