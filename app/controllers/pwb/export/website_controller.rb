module Pwb
  class Export::WebsiteController < ApplicationApiController
    def all
      # Use current_website for proper multi-tenant isolation
      # Do NOT fallback to Website.first as that could leak data from another tenant
      @website = current_website
      unless @website
        return render json: { error: "Website not found" }, status: :not_found
      end
      headers['Content-Disposition'] = "attachment; filename=\"pwb-website.csv\""
      headers['Content-Type'] ||= 'text/csv'
      render "all.csv"
    end
  end
end
