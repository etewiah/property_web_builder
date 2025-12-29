# frozen_string_literal: true

# Register the custom R2 service for Active Storage
# This allows using `service: R2` in storage.yml
#
# The R2 service file is at lib/active_storage/service/r2_service.rb
# which is the standard location ActiveStorage expects for custom services.
# Rails adds lib/ to the load path, so ActiveStorage's require will find it.
#
# We explicitly require it here to ensure it's loaded early enough,
# before ActiveStorage configures services during eager_load_all.

require "active_storage/service/r2_service"
