module Pwb
  class Import::PropertiesController < ApplicationApiController

    # http://localhost:3000/import/Properties/standard
    def standard
      imported_properties = Pwb::ImportProperties.new(params[:file]).import_csv
      # Pwb::Prop.import(params[:file])
      return render json: { "success": true }, status: :ok, head: :no_content
    end

    def from_mls
      imported_properties = Pwb::ImportProperties.new(params[:file]).import_mls_tsv
      # Pwb::Prop.import(params[:file])
      return render json: imported_properties.to_json
       # { "success": true }, status: :ok, head: :no_content
    end

  end
end
