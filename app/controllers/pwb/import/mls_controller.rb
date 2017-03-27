module Pwb
  class Import::MlsController < ApplicationApiController

    # http://localhost:3000/import/Properties/standard
    def exp
      property = Pwb::MlsConnector.new("interealty").get_property("(ListPrice=0+)")

      return render json: property
      #  {
      #   imported_items: property.to_json
      # }
      # return render json: { "success": true }, status: :ok, head: :no_content
    end

  end
end
