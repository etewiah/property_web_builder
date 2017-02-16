module Pwb
  class Api::V1::LitePropertiesController < JSONAPI::ResourceController
    # skip_before_action :verify_content_type_header
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type
    # skip_before_action :verify_accept_header
  end
end
