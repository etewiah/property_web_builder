I18n.available_locales = [:ar, :ca, :de, :en, :es,
                          :fr, :it, :nl, :pl, :pt,
                          :ro, :ru, :tr, :vi, :ko,
                          :bg ]
# I18n.available_locales = [:en, :es, :fr, :de, :ru, :pt]

# Configure I18n fallbacks (previously Globalize.fallbacks)
# This ensures that if a translation is not found in the current locale,
# it falls back to English
I18n.fallbacks = {
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
}
