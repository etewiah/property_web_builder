# frozen_string_literal: true

module Pwb
  # Loads and manages theme color palettes from separate JSON files
  # Supports both single color set (colors) and multi-mode (modes.light/dark) palettes
  #
  # Usage:
  #   loader = Pwb::PaletteLoader.new
  #   palettes = loader.load_theme_palettes("brisbane")
  #   # => { "gold_navy" => {...}, "rose_gold" => {...}, ... }
  #
  #   palette = loader.get_palette("brisbane", "gold_navy")
  #   default_palette = loader.get_default_palette("brisbane")
  #
  #   # Get colors for specific mode
  #   light = loader.get_light_colors("brisbane", "gold_navy")
  #   dark = loader.get_dark_colors("brisbane", "gold_navy")  # auto-generated if not explicit
  #
  class PaletteLoader
    attr_reader :themes_path

    def initialize(themes_path: nil)
      @themes_path = themes_path || Rails.root.join("app/themes")
      @cache = {}
      @validator = PaletteValidator.new
    end

    # Load all palettes for a theme
    # @param theme_name [String] The theme name (e.g., "brisbane")
    # @return [Hash] Hash of palette_id => palette_data
    def load_theme_palettes(theme_name)
      return @cache[theme_name] if @cache[theme_name]

      palettes_dir = File.join(@themes_path, theme_name, "palettes")
      return fallback_to_config(theme_name) unless Dir.exist?(palettes_dir)

      palettes = {}
      Dir.glob(File.join(palettes_dir, "*.json")).each do |file|
        palette_data = JSON.parse(File.read(file))
        result = @validator.validate(palette_data)

        if result.valid?
          palettes[palette_data["id"]] = result.normalized_palette
        else
          Rails.logger.warn("Invalid palette #{file}: #{result.errors.join(', ')}")
        end
      end

      # Fallback to config.json if no palettes found
      return fallback_to_config(theme_name) if palettes.empty?

      @cache[theme_name] = palettes
      palettes
    end

    # Get a specific palette for a theme
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @return [Hash, nil] The palette data or nil
    def get_palette(theme_name, palette_id)
      palettes = load_theme_palettes(theme_name)
      palettes[palette_id]
    end

    # Get the default palette for a theme
    # @param theme_name [String] The theme name
    # @return [Hash, nil] The default palette or first available
    def get_default_palette(theme_name)
      palettes = load_theme_palettes(theme_name)
      default = palettes.values.find { |p| p["is_default"] }
      default || palettes.values.first
    end

    # Get light mode colors from a palette
    # Works with both `colors` and `modes.light` structures
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @return [Hash] Light mode colors
    def get_light_colors(theme_name, palette_id)
      palette = get_palette(theme_name, palette_id)
      extract_light_colors(palette)
    end

    # Get dark mode colors from a palette
    # Returns explicit dark mode if available, otherwise auto-generates
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @return [Hash] Dark mode colors
    def get_dark_colors(theme_name, palette_id)
      palette = get_palette(theme_name, palette_id)
      return {} unless palette

      # Check for explicit dark mode
      if has_explicit_dark_mode?(palette)
        return palette.dig("modes", "dark").dup
      end

      # Auto-generate dark mode from light colors
      light_colors = extract_light_colors(palette)
      ColorUtils.generate_dark_mode_colors(light_colors)
    end

    # Check if a palette has explicit dark mode colors
    # @param palette [Hash] The palette data
    # @return [Boolean]
    def has_explicit_dark_mode?(palette)
      return false unless palette

      palette.dig("modes", "dark").is_a?(Hash)
    end

    # Check if a palette uses the modes structure
    # @param palette [Hash] The palette data
    # @return [Boolean]
    def has_modes?(palette)
      return false unless palette

      palette["modes"].is_a?(Hash) && palette.dig("modes", "light").is_a?(Hash)
    end

    # Get palette colors with legacy key mappings for backward compatibility
    # Returns light mode colors by default
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @param mode [Symbol] :light or :dark (default: :light)
    # @return [Hash] Colors hash with both new and legacy keys
    def get_palette_colors_with_legacy(theme_name, palette_id, mode: :light)
      colors = mode == :dark ? get_dark_colors(theme_name, palette_id) : get_light_colors(theme_name, palette_id)
      return {} unless colors

      colors = colors.dup

      # Add legacy key mappings for backward compatibility
      colors["header_bg_color"] ||= colors["header_background_color"]
      colors["footer_bg_color"] ||= colors["footer_background_color"]
      colors["footer_main_text_color"] ||= colors["footer_text_color"]

      colors
    end

    # List all available palettes for a theme
    # @param theme_name [String] The theme name
    # @return [Array<Hash>] Array of palette summaries
    def list_palettes(theme_name)
      palettes = load_theme_palettes(theme_name)
      palettes.map do |id, data|
        {
          id: id,
          name: data["name"],
          description: data["description"],
          preview_colors: data["preview_colors"],
          is_default: data["is_default"] || false,
          supports_dark_mode: data["supports_dark_mode"] || false,
          has_explicit_dark_mode: has_explicit_dark_mode?(data)
        }
      end
    end

    # Generate CSS custom properties for a palette
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @param include_dark_mode [Boolean] Whether to include dark mode CSS
    # @return [String] CSS custom properties
    def generate_css_variables(theme_name, palette_id = nil, include_dark_mode: false)
      palette = palette_id ? get_palette(theme_name, palette_id) : get_default_palette(theme_name)
      return "" unless palette

      if include_dark_mode
        light_colors = extract_light_colors(palette)
        dark_colors = has_explicit_dark_mode?(palette) ? palette.dig("modes", "dark") : nil
        ColorUtils.generate_dual_mode_css_variables(light_colors, dark_colors)
      else
        ColorUtils.generate_palette_css_variables(palette)
      end
    end

    # Generate full CSS with both light and dark mode support
    # @param theme_name [String] The theme name
    # @param palette_id [String] The palette identifier
    # @return [String] Complete CSS with :root, dark mode media query, and .dark class
    def generate_full_css(theme_name, palette_id = nil)
      generate_css_variables(theme_name, palette_id, include_dark_mode: true)
    end

    # Clear cached palettes
    def clear_cache!
      @cache = {}
    end

    # Validate all palettes for a theme
    # @param theme_name [String] The theme name
    # @return [Hash] Validation results
    def validate_theme_palettes(theme_name)
      palettes_dir = File.join(@themes_path, theme_name, "palettes")
      return { error: "Palettes directory not found" } unless Dir.exist?(palettes_dir)

      results = {}
      Dir.glob(File.join(palettes_dir, "*.json")).each do |file|
        palette_data = JSON.parse(File.read(file))
        result = @validator.validate(palette_data)
        results[File.basename(file)] = {
          valid: result.valid?,
          errors: result.errors,
          warnings: result.warnings
        }
      end
      results
    end

    # Get all themes with their palettes
    # @return [Hash] theme_name => palettes hash
    def all_themes_palettes
      themes = {}
      Dir.glob(File.join(@themes_path, "*/palettes")).each do |palettes_dir|
        theme_name = File.basename(File.dirname(palettes_dir))
        themes[theme_name] = load_theme_palettes(theme_name)
      end
      themes
    end

    private

    # Extract light mode colors from a palette
    # Handles both `colors` and `modes.light` structures
    # @param palette [Hash] The palette data
    # @return [Hash] Light mode colors or empty hash
    def extract_light_colors(palette)
      return {} unless palette

      if palette["modes"].is_a?(Hash) && palette.dig("modes", "light").is_a?(Hash)
        palette.dig("modes", "light").dup
      elsif palette["colors"].is_a?(Hash)
        palette["colors"].dup
      else
        {}
      end
    end

    # Fallback to loading from config.json for backward compatibility
    def fallback_to_config(theme_name)
      config_path = File.join(@themes_path, "config.json")
      return {} unless File.exist?(config_path)

      themes = JSON.parse(File.read(config_path))
      theme = themes.find { |t| t["name"] == theme_name }
      return {} unless theme && theme["palettes"]

      # Normalize the palettes from config.json
      palettes = {}
      theme["palettes"].each do |id, data|
        result = @validator.validate(data)
        palettes[id] = result.normalized_palette
      end

      @cache[theme_name] = palettes
      palettes
    end
  end
end
