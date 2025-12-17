# frozen_string_literal: true

# Supported languages (7 total):
# en - English
# es - Spanish
# de - German
# fr - French
# nl - Dutch
# pt - Portuguese
# it - Italian
I18n.available_locales = [:en, :es, :de, :fr, :nl, :pt, :it]

# Configure I18n fallbacks (previously Globalize.fallbacks)
# This ensures that if a translation is not found in the current locale,
# it falls back to English
#
# In Rails 8.1+, we need to use the proper I18n::Locale::Fallbacks class
# instead of a plain hash
Rails.application.config.after_initialize do
  I18n.fallbacks = I18n::Locale::Fallbacks.new(
    es: [:en],
    de: [:en],
    fr: [:en],
    nl: [:en],
    pt: [:en],
    it: [:en]
  )
end
