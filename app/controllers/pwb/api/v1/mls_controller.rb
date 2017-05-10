module Pwb
  class Api::V1::MlsController < ApplicationApiController
    def index
      mlses = ImportSource.all
      # ImportSource is active_hash so have to manually construct json
      @mls_array = []
      mlses.each do |mls|
        # labelText and value allow creation on radiolist in admin interface
        @mls_array.push ({
          value: mls.as_json["attributes"]["unique_name"],
          labelText: mls.as_json["attributes"]["displayName"],
          mls_unique_name: mls.as_json["attributes"]["unique_name"],
          username: mls.as_json["attributes"]["details"]["username"],
          password: mls.as_json["attributes"]["details"]["password"],
          login_url: mls.as_json["attributes"]["details"]["login_url"]
        })
        # when I stop displaying username above I can just use:
        # mls.as_json["attributes"].slice("value","labelText")
      end
      render json: @mls_array
    end
  end
end
