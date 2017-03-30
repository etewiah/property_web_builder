module Pwb
  class Import::PropertiesController < ApplicationApiController

    # http://localhost:3000/import/Properties/retrieve_from_pwb
    def retrieve_from_pwb
      imported_properties = Pwb::ImportProperties.new(params[:file]).import_csv
      return render json: {
        retrieved_items: imported_properties
      }
      # return render json: { "success": true }, status: :ok, head: :no_content
    end

    def retrieve_from_mls
      imported_properties = Pwb::ImportProperties.new(params[:file]).import_mls_tsv
      # Pwb::Prop.import(params[:file])
      return render json: {
        retrieved_items: imported_properties
      }
    end

  end
end
