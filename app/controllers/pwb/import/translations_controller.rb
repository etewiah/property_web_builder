module Pwb
  class Import::TranslationsController < ApplicationApiController

    # http://localhost:3000/import/translations/multiple
    def multiple

      I18n::Backend::ActiveRecord::Translation.import(params[:file])
      return render json: { "success": true }, status: :ok, head: :no_content

      # redirect_to root_url, notice: "I18n::Backend::ActiveRecord::Translations imported."
    end

  end
end
