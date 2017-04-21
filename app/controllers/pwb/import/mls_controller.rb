module Pwb
  class Import::MlsController < ApplicationApiController

    def retrieve
      mls_name = params["mls_unique_name"]
      # "interealty"
      import_source = Pwb::ImportSource.find_by_unique_name mls_name

      import_source.details[:username] = params[:username]
      import_source.details[:password] = params[:password]

      limit = 25
      properties = Pwb::MlsConnector.new(import_source).retrieve("(ListPrice=0+)", limit)
      retrieved_properties = []
      count = 0

      properties.each do |property|
        if count < 100
          mapped_property = ImportMapper.new(import_source.import_mapper_name).map_property(property)
          retrieved_properties.push mapped_property
        end
        count += 1
      end

      return render json: retrieved_properties
      # return render json: {
      #   error: "Unable to retrieve MLS properties"
      # }, status: :error
    end

    def retrieve2

      # property = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/property_mris.json") )
      # mapped_property = ImportMapper.new("mls_mris").map_property(property)

      # property = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/property_interealty.json") )
      # mapped_property = ImportMapper.new("mls_interealty").map_property(property)

      # return render json: [mapped_property]

      properties = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/properties_interealty.json") )
      retrieved_properties = []
      count = 0
      properties.each do |property|
        if count < 100
          mapped_property = ImportMapper.new("mls_interealty").map_property(property)
          retrieved_properties.push mapped_property
        end
        count += 1
      end
      return render json: retrieved_properties


    end

  end
end
