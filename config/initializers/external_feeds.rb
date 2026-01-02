# frozen_string_literal: true

# External Feed Provider Registration
#
# This initializer registers all available external feed providers.
# Providers must be registered here to be available for use by websites.
#
# To add a new provider:
# 1. Create the provider class in app/services/pwb/external_feed/providers/
# 2. Register it here with Pwb::ExternalFeed::Registry.register
#
# Example:
#   Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::MyProvider)

# Use to_prepare to ensure providers are registered after each code reload in development
# This is necessary because the Registry class gets reloaded and loses its state
Rails.application.config.to_prepare do
  # Register Resales Online provider for Costa del Sol properties
  Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::ResalesOnline)

  # Log registered providers in development
  if Rails.env.development?
    providers = Pwb::ExternalFeed::Registry.available_providers
    Rails.logger.info "[ExternalFeeds] Registered providers: #{providers.join(', ')}"
  end
end
