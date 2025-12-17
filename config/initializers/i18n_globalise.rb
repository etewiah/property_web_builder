# frozen_string_literal: true

# =============================================================================
# Supported Languages Configuration
# =============================================================================
# This is the central configuration for all supported languages in the application.
# All language-related UI elements should reference this configuration.
#
# To add/remove languages:
# 1. Update SUPPORTED_LOCALES below
# 2. Update I18n.available_locales
# 3. Update I18n.fallbacks
# =============================================================================

# Central locale configuration with labels
# This hash is the single source of truth for supported languages
SUPPORTED_LOCALES = {
  en: 'English',
  es: 'Spanish',
  de: 'German',
  fr: 'French',
  nl: 'Dutch',
  pt: 'Portuguese',
  it: 'Italian'
}.freeze

# Set available locales from the central config
I18n.available_locales = SUPPORTED_LOCALES.keys

# Configure I18n fallbacks (previously Globalize.fallbacks)
# This ensures that if a translation is not found in the current locale,
# it falls back to English
#
# In Rails 8.1+, we need to use the proper I18n::Locale::Fallbacks class
# instead of a plain hash
Rails.application.config.after_initialize do
  # Build fallbacks hash: all non-English locales fall back to English
  fallback_config = SUPPORTED_LOCALES.keys.reject { |l| l == :en }.index_with { [:en] }
  I18n.fallbacks = I18n::Locale::Fallbacks.new(fallback_config)
end
