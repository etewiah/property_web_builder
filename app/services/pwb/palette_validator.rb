# frozen_string_literal: true

module Pwb
  # Validates theme color palettes against the standardized schema
  # Supports both single color set (colors) and multi-mode (modes.light/dark)
  #
  # Usage:
  #   validator = Pwb::PaletteValidator.new
  #   result = validator.validate(palette_hash)
  #   result.valid?      # => true/false
  #   result.errors      # => ["error message", ...]
  #   result.warnings    # => ["warning message", ...]
  #
  class PaletteValidator
    REQUIRED_KEYS = %w[id name].freeze

    REQUIRED_COLORS = %w[
      primary_color
      secondary_color
      accent_color
      background_color
      text_color
      header_background_color
      header_text_color
      footer_background_color
      footer_text_color
    ].freeze

    OPTIONAL_COLORS = %w[
      card_background_color
      card_text_color
      border_color
      surface_color
      surface_alt_color
      success_color
      warning_color
      error_color
      muted_text_color
      link_color
      link_hover_color
      button_primary_background
      button_primary_text
      button_secondary_background
      button_secondary_text
      input_background_color
      input_border_color
      input_focus_color
      light_color
      action_color
    ].freeze

    # Legacy key mappings for backward compatibility
    LEGACY_KEY_MAPPINGS = {
      "footer_main_text_color" => "footer_text_color",
      "header_bg_color" => "header_background_color",
      "footer_bg_color" => "footer_background_color"
    }.freeze

    HEX_COLOR_PATTERN = /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/
    ID_PATTERN = /\A[a-z][a-z0-9_]*\z/

    Result = Struct.new(:valid?, :errors, :warnings, :normalized_palette, keyword_init: true)

    def initialize(schema_path: nil)
      @schema_path = schema_path || default_schema_path
    end

    # Validate a single palette
    # @param palette [Hash] The palette to validate
    # @param normalize [Boolean] Whether to normalize legacy keys
    # @return [Result] Validation result with errors and warnings
    def validate(palette, normalize: true)
      errors = []
      warnings = []
      normalized = normalize ? normalize_palette(palette.deep_dup, warnings) : palette

      validate_structure(normalized, errors)
      validate_id(normalized, errors)
      validate_name(normalized, errors)
      validate_color_structure(normalized, errors, warnings)
      validate_preview_colors(normalized, errors, warnings)

      Result.new(
        valid?: errors.empty?,
        errors: errors,
        warnings: warnings,
        normalized_palette: normalized
      )
    end

    # Validate all palettes for a theme
    # @param palettes [Hash] Hash of palette_id => palette_data
    # @return [Hash] Hash of palette_id => Result
    def validate_theme_palettes(palettes)
      results = {}
      default_count = 0

      palettes.each do |id, palette|
        results[id] = validate(palette)
        default_count += 1 if palette["is_default"]
      end

      # Check for exactly one default palette
      if default_count == 0
        results.values.first&.errors&.push("Theme should have at least one default palette")
      elsif default_count > 1
        results.values.each do |result|
          result.warnings.push("Multiple default palettes found - only one should be default")
        end
      end

      results
    end

    # Normalize legacy color keys to standard names
    # @param palette [Hash] The palette to normalize
    # @param warnings [Array] Array to append warnings to
    # @return [Hash] Normalized palette
    def normalize_palette(palette, warnings = [])
      # Handle both `colors` and `modes` structures
      if palette["colors"].is_a?(Hash)
        normalize_color_set(palette["colors"], warnings)
      elsif palette["modes"].is_a?(Hash)
        normalize_color_set(palette.dig("modes", "light"), warnings, "modes.light") if palette.dig("modes", "light")
        normalize_color_set(palette.dig("modes", "dark"), warnings, "modes.dark") if palette.dig("modes", "dark")
      end

      palette
    end

    # Check if a color value is valid hex
    # @param color [String] Color value to check
    # @return [Boolean]
    def valid_hex_color?(color)
      color.is_a?(String) && HEX_COLOR_PATTERN.match?(color)
    end

    # Get all known color keys (required + optional)
    def all_color_keys
      REQUIRED_COLORS + OPTIONAL_COLORS
    end

    # Check if palette has modes structure
    # @param palette [Hash]
    # @return [Boolean]
    def has_modes?(palette)
      palette["modes"].is_a?(Hash) && palette.dig("modes", "light").is_a?(Hash)
    end

    # Check if palette has explicit dark mode
    # @param palette [Hash]
    # @return [Boolean]
    def has_dark_mode?(palette)
      has_modes?(palette) && palette.dig("modes", "dark").is_a?(Hash)
    end

    private

    def default_schema_path
      Rails.root.join("app/themes/shared/color_schema.json")
    end

    def validate_structure(palette, errors)
      REQUIRED_KEYS.each do |key|
        errors << "Missing required key: '#{key}'" unless palette.key?(key)
      end

      # Must have either `colors` or `modes.light`
      has_colors = palette["colors"].is_a?(Hash)
      has_light_mode = palette.dig("modes", "light").is_a?(Hash)

      unless has_colors || has_light_mode
        errors << "Palette must have either 'colors' or 'modes.light'"
      end

      if has_colors && has_light_mode
        errors << "Palette cannot have both 'colors' and 'modes' - use one or the other"
      end
    end

    def validate_id(palette, errors)
      id = palette["id"]
      return if id.nil? # Already reported as missing

      errors << "Invalid id format: must be snake_case (got '#{id}')" unless ID_PATTERN.match?(id)
    end

    def validate_name(palette, errors)
      name = palette["name"]
      return if name.nil? # Already reported as missing

      errors << "Name cannot be empty" if name.to_s.strip.empty?
      errors << "Name too long (max 50 characters)" if name.to_s.length > 50
    end

    def validate_color_structure(palette, errors, warnings)
      if palette["colors"].is_a?(Hash)
        validate_colors(palette["colors"], errors, warnings)
      elsif palette["modes"].is_a?(Hash)
        validate_modes(palette["modes"], errors, warnings)
      end
    end

    def validate_modes(modes, errors, warnings)
      unless modes["light"].is_a?(Hash)
        errors << "modes.light is required"
        return
      end

      # Validate light mode colors
      validate_colors(modes["light"], errors, warnings, "modes.light")

      # Validate dark mode colors if present
      if modes["dark"].is_a?(Hash)
        validate_colors(modes["dark"], errors, warnings, "modes.dark")
      end
    end

    def validate_colors(colors, errors, warnings, prefix = nil)
      prefix_str = prefix ? "#{prefix}." : ""

      # Check required colors
      REQUIRED_COLORS.each do |key|
        if colors.key?(key)
          validate_color_value("#{prefix_str}#{key}", colors[key], errors)
        else
          errors << "Missing required color: '#{prefix_str}#{key}'"
        end
      end

      # Validate optional colors if present
      OPTIONAL_COLORS.each do |key|
        validate_color_value("#{prefix_str}#{key}", colors[key], errors) if colors.key?(key)
      end

      # Warn about unknown color keys (but don't error)
      known_keys = REQUIRED_COLORS + OPTIONAL_COLORS + LEGACY_KEY_MAPPINGS.keys
      unknown_keys = colors.keys - known_keys
      unknown_keys.each do |key|
        # Still validate the format
        validate_color_value("#{prefix_str}#{key}", colors[key], errors)
      end
    end

    def normalize_color_set(colors, warnings, prefix = nil)
      return unless colors.is_a?(Hash)

      prefix_str = prefix ? " in #{prefix}" : ""

      LEGACY_KEY_MAPPINGS.each do |old_key, new_key|
        if colors.key?(old_key) && !colors.key?(new_key)
          colors[new_key] = colors.delete(old_key)
          warnings << "Migrated legacy key '#{old_key}' to '#{new_key}'#{prefix_str}"
        elsif colors.key?(old_key)
          colors.delete(old_key)
          warnings << "Removed duplicate legacy key '#{old_key}' (#{new_key} already exists)#{prefix_str}"
        end
      end
    end

    def validate_color_value(key, value, errors)
      return if value.nil?

      unless valid_hex_color?(value)
        errors << "Invalid hex color for '#{key}': '#{value}' (expected format: #RRGGBB or #RGB)"
      end
    end

    def validate_preview_colors(palette, errors, warnings)
      preview = palette["preview_colors"]
      return unless preview # Optional field

      unless preview.is_a?(Array)
        return errors << "preview_colors must be an array"
      end

      if preview.length < 3
        warnings << "preview_colors should have at least 3 colors for good visualization"
      elsif preview.length > 5
        warnings << "preview_colors should have at most 5 colors"
      end

      preview.each_with_index do |color, index|
        unless valid_hex_color?(color)
          errors << "Invalid preview color at index #{index}: '#{color}'"
        end
      end
    end
  end
end
