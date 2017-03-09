module Pwb
  class Import::WebContentsController < ApplicationApiController

    # http://localhost:3000/import/translations/multiple
    def multiple
      Content.import(params[:file])
      return render json: { "success": true }, status: :ok, head: :no_content

      # redirect_to root_url, notice: "contents imported."
    end

  end
end
