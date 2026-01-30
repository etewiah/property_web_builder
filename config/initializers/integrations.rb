# frozen_string_literal: true

# Load all integration providers
# Providers register themselves with the Integrations::Registry when loaded

Rails.application.config.to_prepare do
  # Load the base classes first
  require_dependency 'integrations/registry'
  require_dependency 'integrations/providers/base'

  # Load all provider definitions
  Dir[Rails.root.join('app/services/integrations/providers/*.rb')].each do |file|
    require_dependency file
  end
end
