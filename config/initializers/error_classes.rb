# frozen_string_literal: true

# Eager load custom error classes
#
# The files in app/errors/ use plural file names (e.g., tenant_errors.rb) but
# contain singular class names (e.g., TenantNotFoundError). This breaks Zeitwerk's
# convention-based autoloading.
#
# We tell Zeitwerk to ignore these files and load them manually at boot.
#
Rails.autoloaders.main.ignore(Rails.root.join('app/errors'))

# Load error classes in dependency order
require Rails.root.join('app/errors/application_error')
require Rails.root.join('app/errors/tenant_errors')
require Rails.root.join('app/errors/external_service_errors')
require Rails.root.join('app/errors/import_export_errors')
require Rails.root.join('app/errors/subscription_errors')
