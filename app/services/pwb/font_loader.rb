# frozen_string_literal: true

module Pwb
  # Loads and manages web fonts for themes
  # Generates Google Fonts URLs and CSS for dynamic font loading
  #
  # Usage:
  #   loader = Pwb::FontLoader.new
  #   url = loader.google_fonts_url(["Open Sans", "Montserrat"])
  #   css = loader.font_face_css("Open Sans")
  #
  #   # With a website object
  #   loader = Pwb::FontLoader.new
  #   loader.fonts_for_website(website)
  #   # => { primary: "Open Sans", heading: "Montserrat" }
  #
  class FontLoader
    GOOGLE_FONTS_BASE_URL = "https://fonts.googleapis.com/css2"
    FONTS_CONFIG_PATH = Rails.root.join("app/themes/shared/fonts.json")

    attr_reader :fonts_config

    def initialize
      @fonts_config = load_fonts_config
      @cache = {}
    end

    # Get font configuration for a specific font
    # @param font_name [String] The font name (e.g., "Open Sans")
    # @return [Hash, nil] Font configuration or nil if not found
    def get_font(font_name)
      return nil if font_name.blank?

      fonts_config.dig("fonts", font_name) || fonts_config.dig("system_fonts", font_name)
    end

    # Check if a font is a system font (doesn't need loading)
    # @param font_name [String] The font name
    # @return [Boolean]
    def system_font?(font_name)
      fonts_config.dig("system_fonts", font_name).present?
    end

    # Check if a font requires loading from Google Fonts
    # @param font_name [String] The font name
    # @return [Boolean]
    def google_font?(font_name)
      font = get_font(font_name)
      font&.dig("provider") == "google"
    end

    # Get fonts needed for a website based on its style variables
    # @param website [Pwb::Website] The website object
    # @return [Hash] { primary: font_name, heading: font_name }
    def fonts_for_website(website)
      style_vars = website.style_variables || {}
      {
        primary: style_vars["font_primary"] || "Open Sans",
        heading: style_vars["font_heading"] || style_vars["font_secondary"] || style_vars["font_primary"] || "Montserrat"
      }
    end

    # Get unique fonts that need to be loaded for a website
    # @param website [Pwb::Website] The website object
    # @return [Array<String>] List of font names that need loading
    def fonts_to_load(website)
      fonts = fonts_for_website(website)
      unique_fonts = [fonts[:primary], fonts[:heading]].compact.uniq

      # Filter to only Google fonts (system fonts don't need loading)
      unique_fonts.select { |font| google_font?(font) }
    end

    # Generate Google Fonts URL for multiple fonts
    # @param font_names [Array<String>] List of font names
    # @return [String, nil] Google Fonts URL or nil if no fonts
    def google_fonts_url(font_names)
      return nil if font_names.blank?

      families = font_names.filter_map do |font_name|
        font = get_font(font_name)
        next unless font&.dig("provider") == "google"

        font["google_family"]
      end

      return nil if families.empty?

      "#{GOOGLE_FONTS_BASE_URL}?family=#{families.join('&family=')}&display=swap"
    end

    # Generate Google Fonts URL for a website
    # @param website [Pwb::Website] The website object
    # @return [String, nil] Google Fonts URL or nil if no fonts to load
    def google_fonts_url_for_website(website)
      fonts = fonts_to_load(website)
      google_fonts_url(fonts)
    end

    # Generate preconnect link tags for Google Fonts
    # @return [String] HTML for preconnect tags
    def preconnect_tags
      <<~HTML.html_safe
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      HTML
    end

    # Generate the font-family CSS value for a font
    # @param font_name [String] The font name
    # @return [String] CSS font-family value with fallbacks
    def font_family_css(font_name)
      font = get_font(font_name)
      return "system-ui, sans-serif" unless font

      fallback = font["fallback"] || "sans-serif"
      "'#{font_name}', #{fallback}"
    end

    # Generate CSS custom properties for fonts
    # @param website [Pwb::Website] The website object
    # @return [String] CSS with --pwb-font-* variables
    def font_css_variables(website)
      fonts = fonts_for_website(website)
      primary_family = font_family_css(fonts[:primary])
      heading_family = font_family_css(fonts[:heading])

      <<~CSS
        :root {
          --pwb-font-primary: #{primary_family};
          --pwb-font-heading: #{heading_family};
          --font-primary: #{primary_family};
          --font-heading: #{heading_family};
        }
        body {
          font-family: var(--pwb-font-primary);
        }
        h1, h2, h3, h4, h5, h6 {
          font-family: var(--pwb-font-heading);
        }
      CSS
    end

    # Generate complete font loading HTML for a website
    # Includes preconnect, Google Fonts link, and CSS variables
    # @param website [Pwb::Website] The website object
    # @return [String] Complete HTML for font loading
    def font_loading_html(website)
      fonts_url = google_fonts_url_for_website(website)

      html = []

      if fonts_url
        # Preconnect for Google Fonts
        html << preconnect_tags

        # Google Fonts stylesheet with preload for performance
        html << %(<link rel="preload" href="#{fonts_url}" as="style" onload="this.onload=null;this.rel='stylesheet'">)
        html << %(<noscript><link href="#{fonts_url}" rel="stylesheet"></noscript>)
      end

      # CSS variables for font-family
      html << "<style>#{font_css_variables(website)}</style>"

      html.join("\n").html_safe
    end

    # List all available fonts grouped by category
    # @return [Hash] { "sans-serif" => [...], "serif" => [...], ... }
    def fonts_by_category
      result = Hash.new { |h, k| h[k] = [] }

      fonts_config["fonts"]&.each do |name, config|
        category = config["category"] || "sans-serif"
        result[category] << {
          name: name,
          provider: config["provider"],
          weights: config["weights"]
        }
      end

      result
    end

    # Get all available font names
    # @return [Array<String>]
    def available_fonts
      (fonts_config["fonts"]&.keys || []) + (fonts_config["system_fonts"]&.keys || [])
    end

    # Clear cached data
    def clear_cache!
      @cache = {}
    end

    private

    def load_fonts_config
      return {} unless File.exist?(FONTS_CONFIG_PATH)

      JSON.parse(File.read(FONTS_CONFIG_PATH))
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse fonts.json: #{e.message}")
      {}
    end
  end
end
