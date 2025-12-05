module Pwb
  class Import::WebContentsController < ApplicationApiController

    # http://localhost:3000/import/translations/multiple
    def multiple
      # Use tenant-scoped import for multi-tenant isolation
      Content.import_for_website(params[:file], current_website)
      return render json: { "success": true }, status: :ok, head: :no_content

      # redirect_to root_url, notice: "contents imported."
    end

  end
end
