# frozen_string_literal: true

# Register the custom R2 service for Active Storage
# This allows using `service: R2` in storage.yml
#
# IMPORTANT: This must be required BEFORE Rails initialization completes,
# because ActiveStorage configures services during eager_load_all.
# Using after_initialize is too late.

require_relative "../../app/services/active_storage/service/r2_service"
