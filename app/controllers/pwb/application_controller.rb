module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_filter :current_agency, :sections

    private

    def current_agency
      @current_agency ||= (Agency.last || Agency.create)
    end

    def sections
      @sections ||= []
    end

  end
end
