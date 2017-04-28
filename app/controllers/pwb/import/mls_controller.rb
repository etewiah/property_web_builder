module Pwb
  class Import::MlsController < ApplicationApiController

    def retrieve
      [:username, :password, :login_url, :mls_unique_name].each do |param_name|
        unless params[param_name].present?
          return render json: { :error => "Please provide #{param_name}."}, :status => 422
        end
      end
      mls_name = params[:mls_unique_name] 
      # || "mris"
      import_source = Pwb::ImportSource.find_by_unique_name mls_name

      import_source.details[:username] = params[:username]
      import_source.details[:password] = params[:password]
      import_source.details[:login_url] = params[:login_url]

      limit = 25
      properties = Pwb::MlsConnector.new(import_source).retrieve("(ListPrice=0+)", limit)
      retrieved_properties = []
      count = 0
      # return render json: properties.as_json

      properties.each do |property|
        if count < 100
          mapped_property = ImportMapper.new(import_source.import_mapper_name).map_property(property)
          retrieved_properties.push mapped_property
        end
        count += 1
      end

      return render json: retrieved_properties

    end

    # def retrieve2
    #   properties = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/properties_interealty.json") )
    #   retrieved_properties = []
    #   count = 0
    #   properties.each do |property|
    #     if count < 100
    #       mapped_property = ImportMapper.new("mls_interealty").map_property(property)
    #       retrieved_properties.push mapped_property
    #     end
    #     count += 1
    #   end
    #   return render json: retrieved_properties
    # end

  end
end
