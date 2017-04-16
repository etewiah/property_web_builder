module Pwb
  class Api::V1::MlsController < ApplicationApiController
    def index
      mls = ImportSource.all
      # ImportSource is active_hash so have to manually construct json
      @mls_array = []
      mls.each do |theme|
        @mls_array.push theme.as_json['attributes']
      end
      return render json: @mls_array
    end
  end
end
