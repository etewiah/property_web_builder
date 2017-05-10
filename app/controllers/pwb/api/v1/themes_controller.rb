module Pwb
  class Api::V1::ThemesController < ApplicationApiController
    def index
      themes = Theme.all
      # Theme is active_hash so have to manually construct json
      @themes_array = []
      themes.each do |theme|
        @themes_array.push theme.as_json["attributes"]
      end
      render json: @themes_array
    end
  end
end
