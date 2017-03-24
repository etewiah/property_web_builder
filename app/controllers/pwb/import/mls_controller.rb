module Pwb
  class Import::MlsController < ApplicationApiController

    # http://localhost:3000/import/Properties/standard
    def exp
      imported_properties = Pwb::ImportProperties.new(params[:file]).import_csv

      return render json: {
        imported_items: imported_properties.to_json
      }
      # return render json: { "success": true }, status: :ok, head: :no_content
    end

  end
end
