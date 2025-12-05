# frozen_string_literal: true

# LocaleHelper
#
# Provides utilities for handling locale codes consistently across the application.
#
# The application uses two locale formats:
# - Full locale codes (e.g., "en-UK", "en-US", "pt-BR") - used in URLs and user-facing settings
# - Base locale codes (e.g., "en", "pt") - used internally for content storage (block_contents, translations)
#
# This helper ensures consistent conversion between these formats.
#
# @example Converting a full locale to base locale
#   locale_to_base("en-UK")  # => "en"
#   locale_to_base("pt-BR")  # => "pt"
#   locale_to_base("es")     # => "es"
#
# @example Getting supported locales in different formats
#   supported_locales_for_content(["en-UK", "es", "pt-BR"])
#   # => ["en", "es", "pt"]
#
# @example Building locale details for display
#   build_locale_details(["en-UK", "es"])
#   # => [
#   #      { full: "en-UK", base: "en", label: "English (UK)" },
#   #      { full: "es", base: "es", label: "Spanish" }
#   #    ]
#
module LocaleHelper
  # Mapping of base locales to their display labels
  LOCALE_LABELS = {
    'en' => 'English',
    'es' => 'Spanish',
    'fr' => 'French',
    'de' => 'German',
    'it' => 'Italian',
    'pt' => 'Portuguese',
    'nl' => 'Dutch',
    'pl' => 'Polish',
    'ru' => 'Russian',
    'tr' => 'Turkish',
    'ar' => 'Arabic',
    'zh' => 'Chinese',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'sv' => 'Swedish',
    'no' => 'Norwegian',
    'da' => 'Danish',
    'fi' => 'Finnish',
    'el' => 'Greek',
    'ca' => 'Catalan',
    'ro' => 'Romanian',
    'bg' => 'Bulgarian',
    'vi' => 'Vietnamese'
  }.freeze

  # Variant labels for full locale codes
  VARIANT_LABELS = {
    'UK' => 'UK',
    'US' => 'US',
    'BR' => 'Brazil',
    'PT' => 'Portugal',
    'MX' => 'Mexico',
    'AR' => 'Argentina',
    'CA' => 'Canada',
    'AU' => 'Australia'
  }.freeze

  # Converts a full locale code to its base form.
  # This is the primary method for normalizing locales for content storage access.
  #
  # @param locale [String, nil] The locale code (e.g., "en-UK", "en", nil)
  # @return [String] The base locale code (e.g., "en")
  #
  # @example
  #   locale_to_base("en-UK")  # => "en"
  #   locale_to_base("pt-BR")  # => "pt"
  #   locale_to_base("es")     # => "es"
  #   locale_to_base(nil)      # => "en"
  #   locale_to_base("")       # => "en"
  #
  def locale_to_base(locale)
    return 'en' if locale.blank?

    locale.to_s.split('-').first.downcase
  end

  # Alias for locale_to_base for semantic clarity when accessing content
  alias normalize_locale_for_content locale_to_base

  # Extracts the variant from a full locale code.
  #
  # @param locale [String] The full locale code (e.g., "en-UK")
  # @return [String, nil] The variant (e.g., "UK") or nil if no variant
  #
  # @example
  #   locale_variant("en-UK")  # => "UK"
  #   locale_variant("es")     # => nil
  #
  def locale_variant(locale)
    return nil if locale.blank?

    parts = locale.to_s.split('-')
    parts.length > 1 ? parts[1] : nil
  end

  # Converts an array of full locale codes to base locale codes for content access.
  # Removes duplicates that would result from different variants of the same language.
  #
  # @param locales [Array<String>] Array of full locale codes
  # @return [Array<String>] Array of unique base locale codes
  #
  # @example
  #   supported_locales_for_content(["en-UK", "en-US", "es", "pt-BR"])
  #   # => ["en", "es", "pt"]
  #
  def supported_locales_for_content(locales)
    return ['en'] if locales.blank?

    locales
      .reject(&:blank?)
      .map { |l| locale_to_base(l) }
      .uniq
  end

  # Builds detailed locale information for display in the UI.
  # Returns both the full locale (for URLs) and base locale (for content).
  #
  # @param locales [Array<String>] Array of full locale codes from website.supported_locales
  # @return [Array<Hash>] Array of locale detail hashes
  #
  # @example
  #   build_locale_details(["en-UK", "es"])
  #   # => [
  #   #      { full: "en-UK", base: "en", label: "English (UK)" },
  #   #      { full: "es", base: "es", label: "Spanish" }
  #   #    ]
  #
  def build_locale_details(locales)
    return [{ full: 'en', base: 'en', label: 'English' }] if locales.blank?

    locales.reject(&:blank?).map do |full_locale|
      base = locale_to_base(full_locale)
      variant = locale_variant(full_locale)
      label = build_locale_label(base, variant)

      {
        full: full_locale,
        base: base,
        label: label
      }
    end
  end

  # Builds a human-readable label for a locale.
  #
  # @param base [String] The base locale code
  # @param variant [String, nil] The variant code (optional)
  # @return [String] Human-readable label
  #
  # @example
  #   build_locale_label("en", "UK")  # => "English (UK)"
  #   build_locale_label("es", nil)   # => "Spanish"
  #
  def build_locale_label(base, variant = nil)
    base_label = LOCALE_LABELS[base] || base.upcase

    if variant.present?
      variant_label = VARIANT_LABELS[variant] || variant
      "#{base_label} (#{variant_label})"
    else
      base_label
    end
  end

  # Finds the full locale code that matches a given base locale.
  # Useful when you have content keyed by base locale and need the full locale for URLs.
  #
  # @param base_locale [String] The base locale to find
  # @param supported_locales [Array<String>] The website's supported locales
  # @return [String] The matching full locale, or the base locale if no match
  #
  # @example
  #   base_to_full_locale("en", ["en-UK", "es", "fr"])  # => "en-UK"
  #   base_to_full_locale("es", ["en-UK", "es", "fr"])  # => "es"
  #
  def base_to_full_locale(base_locale, supported_locales)
    return base_locale if supported_locales.blank?

    # Find a supported locale that starts with the base locale
    match = supported_locales.find { |l| locale_to_base(l) == base_locale }
    match || base_locale
  end

  # Returns the base locale for URL path construction.
  # For the default locale (en), returns nil to omit from URL.
  #
  # @param locale [String] The locale code
  # @param default_locale [String] The default locale (defaults to "en")
  # @return [String, nil] The locale for URL or nil if default
  #
  # @example
  #   locale_for_url_path("es")     # => "es"
  #   locale_for_url_path("en-UK")  # => nil (default, omit from URL)
  #   locale_for_url_path("en")     # => nil
  #
  def locale_for_url_path(locale, default_locale = 'en')
    base = locale_to_base(locale)
    base == locale_to_base(default_locale) ? nil : base
  end
end
