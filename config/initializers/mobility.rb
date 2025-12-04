# frozen_string_literal: true

Mobility.configure do
  plugins do
    # Core plugins
    active_record

    # Use container backend - stores all translations in a single JSONB column
    # The column_name option specifies the column (defaults to :translations)
    backend :container

    # Accessor plugins
    reader
    writer
    backend_reader

    # Locale accessors - provides title_en, title_es, etc.
    # This replaces globalize_accessors functionality
    locale_accessors I18n.available_locales

    # Query plugin for searching translated content
    query

    # Performance plugins
    cache

    # Behavior plugins
    presence       # Treat blank strings as nil
    fallbacks(     # Enable locale fallbacks - all fall back to English
      ar: :en,
      ca: :en,
      de: :en,
      es: :en,
      fr: :en,
      it: :en,
      nl: :en,
      pl: :en,
      pt: :en,
      ro: :en,
      ru: :en,
      tr: :en,
      vi: :en,
      ko: :en,
      bg: :en
    )
  end
end
