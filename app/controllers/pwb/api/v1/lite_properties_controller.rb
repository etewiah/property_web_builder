module Pwb
  class Api::V1::LitePropertiesController < JSONAPI::ResourceController
    # skip_before_action :verify_content_type_header
    skip_before_action :ensure_valid_accept_media_type
  end
end
