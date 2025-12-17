# frozen_string_literal: true

# =============================================================================
# I18n Configuration
# =============================================================================
# Configures I18n available locales and fallbacks.
#
# Language configuration is centralized in Pwb::Config (app/lib/pwb/config.rb).
# This initializer sets up Rails I18n using that central config.
#
# To add/remove languages, update Pwb::Config::SUPPORTED_LOCALES
# =============================================================================

# Load Pwb::Config early since initializers run before autoloading
require_relative '../../app/lib/pwb/config'

# Set available locales from Pwb::Config::BASE_LOCALES
# BASE_LOCALES contains language codes without regional variants (en, es, de, etc.)
# This is used for I18n translation file loading
I18n.available_locales = Pwb::Config::BASE_LOCALES

# Configure I18n fallbacks
# Ensures that if a translation is not found in the current locale,
# it falls back to English
#
# In Rails 8.1+, we need to use the proper I18n::Locale::Fallbacks class
# instead of a plain hash
Rails.application.config.after_initialize do
  # Build fallbacks hash: all non-English locales fall back to English
  fallback_config = Pwb::Config::BASE_LOCALES.reject { |l| l == :en }.index_with { [:en] }
  I18n.fallbacks = I18n::Locale::Fallbacks.new(fallback_config)
end
