module Pwb
  class Import::PropertiesController < ApplicationApiController

    # http://localhost:3000/import/Properties/multiple
    def multiple

      imported_properties = Pwb::ImportProperties.new(params[:file]).import_csv
      byebug
      # Pwb::Prop.import(params[:file])
      return render json: { "success": true }, status: :ok, head: :no_content

    end

  end
end
