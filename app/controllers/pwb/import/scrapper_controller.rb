module Pwb
  class Import::ScrapperController < ApplicationApiController

    def retrieve
      # just a proof of concept at this stage
      target_url = params[:url] || ""

      retrieved_properties = Pwb::SiteScrapper.new(target_url).retrieve()

      return render json: retrieved_properties
    end

  end
end
