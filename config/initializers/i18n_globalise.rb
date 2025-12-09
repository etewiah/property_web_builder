# frozen_string_literal: true

I18n.available_locales = [:ar, :ca, :de, :en, :es,
                          :fr, :it, :nl, :pl, :pt,
                          :ro, :ru, :tr, :vi, :ko,
                          :bg]

# Configure I18n fallbacks (previously Globalize.fallbacks)
# This ensures that if a translation is not found in the current locale,
# it falls back to English
#
# In Rails 8.1+, we need to use the proper I18n::Locale::Fallbacks class
# instead of a plain hash
Rails.application.config.after_initialize do
  I18n.fallbacks = I18n::Locale::Fallbacks.new(
    de: [:en],
    es: [:en],
    pl: [:en],
    ro: [:en],
    ru: [:en],
    ko: [:en],
    bg: [:en],
    ar: [:en],
    ca: [:en],
    fr: [:en],
    it: [:en],
    nl: [:en],
    pt: [:en],
    tr: [:en],
    vi: [:en]
  )
end
