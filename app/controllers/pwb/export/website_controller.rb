module Pwb
  class Export::WebsiteController < ApplicationApiController
    def all
      @website = Website.unique_instance
      headers['Content-Disposition'] = "attachment; filename=\"pwb-website.csv\""
      headers['Content-Type'] ||= 'text/csv'
      render "all.csv"
    end

  end
end
