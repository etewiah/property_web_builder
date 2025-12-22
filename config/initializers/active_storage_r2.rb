# frozen_string_literal: true

# Register the custom R2 service for Active Storage
# This allows using `service: R2` in storage.yml

Rails.application.config.after_initialize do
  require_relative "../../app/services/active_storage/service/r2_service"
end
