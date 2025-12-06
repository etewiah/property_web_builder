# frozen_string_literal: true

module Pwb
  # Theme model representing available themes.
  # Uses ActiveJSON (active_hash gem) to load themes from config.json
  #
  # @see https://github.com/zilkey/active_hash
  #
  class Theme < ActiveJSON::Base
    set_root_path "#{Rails.root}/app/themes"
    set_filename "config"

    include ActiveHash::Associations
    has_one :website, foreign_key: "theme_name", class_name: "Pwb::Website", primary_key: "name"

    # ===== Parent Theme Support =====

    # Get the parent theme if this theme extends another
    # @return [Theme, nil] the parent theme or nil
    def parent
      parent_name = attributes["parent_theme"] || attributes[:parent_theme]
      return nil unless parent_name.present?

      Theme.find_by(name: parent_name)
    end

    # Check if this theme has a parent
    # @return [Boolean]
    def has_parent?
      parent.present?
    end

    # Get the full inheritance chain
    # @return [Array<Theme>] array of themes from current to root
    def inheritance_chain
      chain = [self]
      current = self
      while current.parent
        chain << current.parent
        current = current.parent
      end
      chain
    end

    # ===== View Paths =====

    # Get all view paths for this theme in priority order
    # @return [Array<Pathname>] array of view paths
    def view_paths
      paths = [Rails.root.join("app/themes/#{name}/views")]
      paths += parent.view_paths if parent
      paths << Rails.root.join("app/views")
      paths.flatten.uniq
    end

    # ===== Page Part Support =====

    # Check if this theme has a custom template for a given page part
    # @param page_part_key [String, Symbol] the page part key
    # @return [Boolean]
    def has_custom_template?(page_part_key)
      custom_template_path(page_part_key).present?
    end

    # Get the path to a custom template for a page part
    # @param page_part_key [String, Symbol] the page part key
    # @return [Pathname, nil] path to the template or nil
    def custom_template_path(page_part_key)
      # Check in theme's page_parts directory
      theme_path = Rails.root.join("app/themes/#{name}/page_parts/#{page_part_key}.liquid")
      return theme_path if File.exist?(theme_path)

      # Check parent theme
      return parent.custom_template_path(page_part_key) if parent

      nil
    end

    # Get all available page parts for this theme
    # @return [Array<String>] array of page part keys
    def available_page_parts
      own_parts = supported_page_parts
      parent_parts = parent&.available_page_parts || []
      default_parts = PagePartLibrary.all_keys

      (own_parts + parent_parts + default_parts).uniq
    end

    # Get explicitly supported page parts from config
    # @return [Array<String>]
    def supported_page_parts
      attributes.dig("supports", "page_parts") || []
    end

    # ===== Layout Support =====

    # Get supported layout types
    # @return [Array<String>]
    def supported_layouts
      own_layouts = attributes.dig("supports", "layouts") || []
      parent_layouts = parent&.supported_layouts || []
      default_layouts = %w[full_width sidebar_left sidebar_right]

      (own_layouts + parent_layouts + default_layouts).uniq
    end

    # ===== Color Scheme Support =====

    # Get supported color schemes
    # @return [Array<String>]
    def supported_color_schemes
      own_schemes = attributes.dig("supports", "color_schemes") || []
      parent_schemes = parent&.supported_color_schemes || []
      default_schemes = %w[light dark]

      (own_schemes + parent_schemes + default_schemes).uniq
    end

    # ===== Style Variables =====

    # Get default style variables for this theme
    # @return [Hash]
    def default_style_variables
      theme_vars = attributes["style_variables"] || {}

      # Convert to flat hash with defaults
      theme_vars.each_with_object({}) do |(key, config), hash|
        if config.is_a?(Hash) && config["default"]
          hash[key] = config["default"]
        else
          hash[key] = config
        end
      end
    end

    # Get style variable schema for this theme
    # @return [Hash]
    def style_variable_schema
      base_schema = ThemeSettingsSchema.to_json_schema

      # Merge theme-specific overrides if present
      theme_vars = attributes["style_variables"] || {}
      theme_vars.each do |key, config|
        next unless config.is_a?(Hash)

        # Find and update the field in base schema
        base_schema[:sections].each do |section|
          field = section[:fields].find { |f| f[:name].to_s == key.to_s }
          field&.merge!(config.slice("default", "label", "description", "options"))
        end
      end

      base_schema
    end

    # ===== Page Part Configuration =====

    # Get configuration for a specific page part
    # @param page_part_key [String, Symbol]
    # @return [Hash]
    def page_part_config(page_part_key)
      config = attributes.dig("page_parts_config", page_part_key.to_s) || {}
      parent_config = parent&.page_part_config(page_part_key) || {}

      parent_config.merge(config)
    end

    # Get available variants for a page part
    # @param page_part_key [String, Symbol]
    # @return [Array<String>]
    def page_part_variants(page_part_key)
      page_part_config(page_part_key)["variants"] || []
    end

    # ===== Theme Info =====

    # Get screenshots for this theme
    # @return [Array<String>] URLs to screenshot images
    def screenshots
      attributes["screenshots"] || []
    end

    # Get the version of this theme
    # @return [String]
    def version
      attributes["version"] || "1.0.0"
    end

    # Get the description of this theme
    # @return [String]
    def description
      attributes["description"] || ""
    end

    # Get theme tags for categorization
    # @return [Array<String>]
    def tags
      attributes["tags"] || []
    end

    # ===== Asset Paths =====

    # Get the main stylesheet path for this theme
    # @return [String]
    def stylesheet_path
      "pwb/themes/#{name}"
    end

    # Get the main JavaScript path for this theme
    # @return [String, nil]
    def javascript_path
      js_path = Rails.root.join("app/assets/javascripts/pwb/themes/#{name}.js")
      return "pwb/themes/#{name}" if File.exist?(js_path)

      js_erb_path = Rails.root.join("app/assets/javascripts/pwb/themes/#{name}.js.erb")
      return "pwb/themes/#{name}" if File.exist?(js_erb_path)

      nil
    end

    # ===== Serialization =====

    # Convert to JSON for API responses
    # @return [Hash]
    def as_api_json
      {
        name: name,
        friendly_name: friendly_name,
        version: version,
        description: description,
        screenshots: screenshots,
        tags: tags,
        parent_theme: attributes["parent_theme"],
        supports: {
          page_parts: available_page_parts,
          layouts: supported_layouts,
          color_schemes: supported_color_schemes
        },
        style_variable_schema: style_variable_schema,
        default_style_variables: default_style_variables
      }
    end
  end
end
