require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PropsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type
  end
end
