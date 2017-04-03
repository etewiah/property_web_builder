module Pwb
  class Import::MlsController < ApplicationApiController

    def retrieve
      # TODO - implement this
      return render json: {
        error: "Unable to retrieve MLS properties"
      }, status: :error
    end

    def experiment
      # property = Pwb::MlsConnector.new("interealty").get_property("(ListPrice=0+)")

      property = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/property_mris.json") )
      mapped_property = ImportMapper.new("mls_mris").map_property(property)

      # property = JSON.parse( File.read("#{Pwb::Engine.root}/spec/fixtures/mls/property_interealty.json") )
      # mapped_property = ImportMapper.new("mls_interealty").map_property(property)

      return render json: [mapped_property]
    end

  end
end
