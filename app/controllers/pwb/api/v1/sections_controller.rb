module Pwb
  class Api::V1::SectionsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type
    # later version changes above method name
    # https://github.com/cerebris/jsonapi-resources/pull/806/files
    # https://github.com/cerebris/jsonapi-resources/pull/801

  end
end
