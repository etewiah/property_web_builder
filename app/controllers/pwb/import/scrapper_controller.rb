require 'faraday'

module Pwb
  class Import::ScrapperController < ApplicationApiController

    def from_webpage
      # just a proof of concept at this stage
      unless params[:url].present?
        return render json: { :error => "Please provide url."}, :status => 422
      end

      target_url = params[:url]

      retrieved_properties = Pwb::SiteScrapper.new(target_url).retrieve()

      return render json: retrieved_properties
    end

    def from_api
      unless params[:url].present?
        return render json: { :error => "Please provide url."}, :status => 422
      end
      target_url = params[:url]

      conn = Faraday.new(:url => 'http://www.laventa-mallorca.com') do |faraday|
        # faraday.basic_auth('', '')
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get "/api_public/v1/props.json"
      
      response_as_json = JSON.parse response.body
      retrieved_properties = []
      count = 0
      response_as_json["data"].each do |property|
        if count < 100
          mapped_property = ImportMapper.new("api_pwb").map_property(property["attributes"])
          retrieved_properties.push mapped_property
        end
        count += 1
      end
      return render json: retrieved_properties
    end


  end
end
