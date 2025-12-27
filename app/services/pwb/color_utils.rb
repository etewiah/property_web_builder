# frozen_string_literal: true

module Pwb
  # Utility class for color manipulation and variant generation
  #
  # Usage:
  #   ColorUtils.lighten("#3498db", 20)    # => "#68b2e5"
  #   ColorUtils.darken("#3498db", 20)     # => "#217dbb"
  #   ColorUtils.generate_shade_scale("#3498db")
  #   # => { 50: "#eaf4fc", 100: "#c8e2f5", ..., 900: "#0d2a3d" }
  #
  class ColorUtils
    # Tailwind-style shade scale steps
    SHADE_STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].freeze

    # Default lightness values for each shade step (as percentages from base)
    # 500 is considered the base color
    SHADE_LIGHTNESS = {
      50 => 95,
      100 => 90,
      200 => 80,
      300 => 70,
      400 => 60,
      500 => 50,  # Base
      600 => 40,
      700 => 30,
      800 => 20,
      900 => 10,
      950 => 5
    }.freeze

    class << self
      # Parse a hex color to RGB components
      # @param hex [String] Hex color (e.g., "#3498db" or "#fff")
      # @return [Array<Integer>] RGB values [r, g, b]
      def hex_to_rgb(hex)
        hex = hex.delete("#")

        # Handle 3-digit hex
        if hex.length == 3
          hex = hex.chars.map { |c| c * 2 }.join
        end

        [
          hex[0..1].to_i(16),
          hex[2..3].to_i(16),
          hex[4..5].to_i(16)
        ]
      end

      # Convert RGB to hex color
      # @param r [Integer] Red (0-255)
      # @param g [Integer] Green (0-255)
      # @param b [Integer] Blue (0-255)
      # @return [String] Hex color (e.g., "#3498db")
      def rgb_to_hex(r, g, b)
        "#%02x%02x%02x" % [r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)]
      end

      # Convert RGB to HSL
      # @param r [Integer] Red (0-255)
      # @param g [Integer] Green (0-255)
      # @param b [Integer] Blue (0-255)
      # @return [Array<Float>] HSL values [h, s, l] (h: 0-360, s: 0-100, l: 0-100)
      def rgb_to_hsl(r, g, b)
        r /= 255.0
        g /= 255.0
        b /= 255.0

        max = [r, g, b].max
        min = [r, g, b].min
        l = (max + min) / 2.0

        if max == min
          h = s = 0.0
        else
          d = max - min
          s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)

          h = case max
              when r then ((g - b) / d + (g < b ? 6 : 0)) / 6.0
              when g then ((b - r) / d + 2) / 6.0
              when b then ((r - g) / d + 4) / 6.0
              end
        end

        [h * 360, s * 100, l * 100]
      end

      # Convert HSL to RGB
      # @param h [Float] Hue (0-360)
      # @param s [Float] Saturation (0-100)
      # @param l [Float] Lightness (0-100)
      # @return [Array<Integer>] RGB values [r, g, b]
      def hsl_to_rgb(h, s, l)
        h /= 360.0
        s /= 100.0
        l /= 100.0

        if s == 0
          r = g = b = l
        else
          q = l < 0.5 ? l * (1 + s) : l + s - l * s
          p = 2 * l - q
          r = hue_to_rgb(p, q, h + 1/3.0)
          g = hue_to_rgb(p, q, h)
          b = hue_to_rgb(p, q, h - 1/3.0)
        end

        [(r * 255).round, (g * 255).round, (b * 255).round]
      end

      # Lighten a color by a percentage
      # @param hex [String] Hex color
      # @param amount [Integer] Percentage to lighten (0-100)
      # @return [String] Lightened hex color
      def lighten(hex, amount)
        r, g, b = hex_to_rgb(hex)
        h, s, l = rgb_to_hsl(r, g, b)
        l = [l + amount, 100].min
        r, g, b = hsl_to_rgb(h, s, l)
        rgb_to_hex(r, g, b)
      end

      # Darken a color by a percentage
      # @param hex [String] Hex color
      # @param amount [Integer] Percentage to darken (0-100)
      # @return [String] Darkened hex color
      def darken(hex, amount)
        r, g, b = hex_to_rgb(hex)
        h, s, l = rgb_to_hsl(r, g, b)
        l = [l - amount, 0].max
        r, g, b = hsl_to_rgb(h, s, l)
        rgb_to_hex(r, g, b)
      end

      # Adjust saturation of a color
      # @param hex [String] Hex color
      # @param amount [Integer] Percentage to adjust (-100 to 100)
      # @return [String] Adjusted hex color
      def saturate(hex, amount)
        r, g, b = hex_to_rgb(hex)
        h, s, l = rgb_to_hsl(r, g, b)
        s = (s + amount).clamp(0, 100)
        r, g, b = hsl_to_rgb(h, s, l)
        rgb_to_hex(r, g, b)
      end

      # Generate a full Tailwind-style shade scale from a base color
      # @param base_hex [String] Base hex color (will be used as 500)
      # @return [Hash] Hash of step => hex color
      def generate_shade_scale(base_hex)
        r, g, b = hex_to_rgb(base_hex)
        h, s, base_l = rgb_to_hsl(r, g, b)

        SHADE_STEPS.each_with_object({}) do |step, scale|
          target_l = SHADE_LIGHTNESS[step]
          new_r, new_g, new_b = hsl_to_rgb(h, s, target_l)
          scale[step] = rgb_to_hex(new_r, new_g, new_b)
        end
      end

      # Generate CSS custom properties for a color with all shades
      # @param name [String] Color name (e.g., "primary")
      # @param base_hex [String] Base hex color
      # @return [String] CSS custom properties
      def generate_css_variables(name, base_hex)
        shades = generate_shade_scale(base_hex)
        css = shades.map { |step, hex| "--pwb-#{name}-#{step}: #{hex};" }
        css.unshift("--pwb-#{name}: #{base_hex};")
        css.join("\n  ")
      end

      # Generate all CSS variables for a palette
      # @param palette [Hash] Palette colors hash
      # @return [String] All CSS custom properties
      def generate_palette_css_variables(palette)
        css_lines = []

        palette["colors"].each do |key, hex|
          # Add base variable
          css_name = key.gsub("_", "-")
          css_lines << "--pwb-#{css_name}: #{hex};"

          # Generate shades for main colors only
          if key.match?(/^(primary|secondary|accent)_color$/)
            color_name = key.gsub("_color", "")
            generate_shade_scale(hex).each do |step, shade_hex|
              css_lines << "--pwb-#{color_name}-#{step}: #{shade_hex};"
            end
          end
        end

        css_lines.join("\n  ")
      end

      # Calculate relative luminance for contrast checking
      # @param hex [String] Hex color
      # @return [Float] Relative luminance (0-1)
      def relative_luminance(hex)
        r, g, b = hex_to_rgb(hex).map do |c|
          c = c / 255.0
          c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
        end
        0.2126 * r + 0.7152 * g + 0.0722 * b
      end

      # Calculate contrast ratio between two colors
      # @param hex1 [String] First hex color
      # @param hex2 [String] Second hex color
      # @return [Float] Contrast ratio (1-21)
      def contrast_ratio(hex1, hex2)
        l1 = relative_luminance(hex1)
        l2 = relative_luminance(hex2)
        lighter = [l1, l2].max
        darker = [l1, l2].min
        (lighter + 0.05) / (darker + 0.05)
      end

      # Check if text on background meets WCAG AA contrast
      # @param text_hex [String] Text color
      # @param bg_hex [String] Background color
      # @param large_text [Boolean] Whether text is large (14pt bold or 18pt+)
      # @return [Boolean]
      def wcag_aa_compliant?(text_hex, bg_hex, large_text: false)
        ratio = contrast_ratio(text_hex, bg_hex)
        large_text ? ratio >= 3.0 : ratio >= 4.5
      end

      # Suggest a readable text color for a given background
      # @param bg_hex [String] Background color
      # @return [String] Suggested text color (#ffffff or #000000)
      def suggest_text_color(bg_hex)
        luminance = relative_luminance(bg_hex)
        luminance > 0.179 ? "#000000" : "#ffffff"
      end

      # ===== Dark Mode Generation =====

      # Default dark mode background colors
      DARK_MODE_DEFAULTS = {
        background_color: "#121212",
        surface_color: "#1e1e1e",
        surface_alt_color: "#2d2d2d",
        card_background_color: "#1e1e1e",
        header_background_color: "#1a1a1a",
        footer_background_color: "#0d0d0d",
        input_background_color: "#2d2d2d",
        border_color: "#3d3d3d"
      }.freeze

      # Generate dark mode colors from light mode colors
      # @param light_colors [Hash] Light mode color hash
      # @return [Hash] Generated dark mode colors
      def generate_dark_mode_colors(light_colors)
        dark_colors = {}

        light_colors.each do |key, value|
          dark_colors[key] = transform_color_for_dark_mode(key, value, light_colors)
        end

        dark_colors
      end

      # Transform a single color for dark mode
      # @param key [String] The color key
      # @param value [String] The hex color value
      # @param all_colors [Hash] All light mode colors for context
      # @return [String] Dark mode hex color
      def transform_color_for_dark_mode(key, value, all_colors = {})
        return value unless valid_hex?(value)

        case key.to_s
        # Background colors - use dark defaults or invert
        when "background_color"
          DARK_MODE_DEFAULTS[:background_color]
        when "surface_color"
          DARK_MODE_DEFAULTS[:surface_color]
        when "surface_alt_color"
          DARK_MODE_DEFAULTS[:surface_alt_color]
        when "card_background_color"
          DARK_MODE_DEFAULTS[:card_background_color]
        when "header_background_color"
          DARK_MODE_DEFAULTS[:header_background_color]
        when "footer_background_color"
          DARK_MODE_DEFAULTS[:footer_background_color]
        when "input_background_color"
          DARK_MODE_DEFAULTS[:input_background_color]
        when "border_color", "input_border_color"
          DARK_MODE_DEFAULTS[:border_color]

        # Text colors - invert to light
        when "text_color"
          "#e8e8e8"
        when "header_text_color", "footer_text_color", "card_text_color"
          "#e8e8e8"
        when "muted_text_color"
          "#a0a0a0"

        # Primary/Secondary/Accent - adjust for dark backgrounds
        when "primary_color", "secondary_color", "accent_color", "link_color"
          adjust_for_dark_background(value)

        # Button colors - adjust for visibility
        when "button_primary_background"
          adjust_for_dark_background(all_colors["primary_color"] || value)
        when "button_primary_text"
          suggest_text_color(adjust_for_dark_background(all_colors["primary_color"] || "#3498db"))
        when "button_secondary_background"
          "#3d3d3d"
        when "button_secondary_text"
          "#e8e8e8"

        # Status colors - adjust saturation for dark mode
        when "success_color"
          "#4ade80" # Brighter green for dark mode
        when "warning_color"
          "#fbbf24" # Brighter yellow for dark mode
        when "error_color"
          "#f87171" # Brighter red for dark mode

        # Link hover - lighten the link color
        when "link_hover_color"
          link_color = all_colors["link_color"] || all_colors["primary_color"] || value
          lighten(adjust_for_dark_background(link_color), 15)

        # Focus colors - use accent or adjust
        when "input_focus_color"
          adjust_for_dark_background(all_colors["accent_color"] || all_colors["primary_color"] || value)

        # Light color (used for subtle backgrounds) - make it dark
        when "light_color"
          "#1e1e1e"

        # Action color - same as primary adjustment
        when "action_color"
          adjust_for_dark_background(all_colors["primary_color"] || value)

        # Default - pass through or adjust based on luminance
        else
          luminance = relative_luminance(value)
          if luminance > 0.5
            # Light color - darken for dark mode
            darken(value, 60)
          elsif luminance < 0.2
            # Very dark color - lighten for dark mode
            lighten(value, 40)
          else
            # Mid-range - adjust slightly for dark background visibility
            adjust_for_dark_background(value)
          end
        end
      end

      # Adjust a color to be visible on dark backgrounds
      # @param hex [String] Hex color
      # @return [String] Adjusted color
      def adjust_for_dark_background(hex)
        return hex unless valid_hex?(hex)

        r, g, b = hex_to_rgb(hex)
        h, s, l = rgb_to_hsl(r, g, b)

        # Ensure minimum lightness for visibility on dark backgrounds
        # But don't go too light (max ~70%) to preserve color character
        if l < 45
          l = 55
        elsif l > 70
          l = 65
        end

        # Slightly boost saturation for vibrancy on dark backgrounds
        s = [s * 1.1, 100].min if s > 20

        new_r, new_g, new_b = hsl_to_rgb(h, s, l)
        rgb_to_hex(new_r, new_g, new_b)
      end

      # Check if a string is a valid hex color
      # @param value [String] Value to check
      # @return [Boolean]
      def valid_hex?(value)
        value.is_a?(String) && value.match?(/\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/)
      end

      # Generate CSS custom properties for both light and dark modes
      # @param light_colors [Hash] Light mode colors
      # @param dark_colors [Hash, nil] Dark mode colors (auto-generated if nil)
      # @return [String] CSS with light and dark mode variables
      def generate_dual_mode_css_variables(light_colors, dark_colors = nil)
        dark_colors ||= generate_dark_mode_colors(light_colors)

        css_lines = []
        css_lines << "/* Light mode (default) */"
        css_lines << ":root {"

        light_colors.each do |key, hex|
          css_name = key.gsub("_", "-")
          css_lines << "  --pwb-#{css_name}: #{hex};"

          # Generate shades for main colors
          if key.match?(/^(primary|secondary|accent)_color$/)
            color_name = key.gsub("_color", "")
            generate_shade_scale(hex).each do |step, shade_hex|
              css_lines << "  --pwb-#{color_name}-#{step}: #{shade_hex};"
            end
          end
        end

        css_lines << "}"
        css_lines << ""
        css_lines << "/* Dark mode */"
        css_lines << "@media (prefers-color-scheme: dark) {"
        css_lines << "  :root {"

        dark_colors.each do |key, hex|
          css_name = key.gsub("_", "-")
          css_lines << "    --pwb-#{css_name}: #{hex};"

          # Generate shades for main colors in dark mode
          if key.match?(/^(primary|secondary|accent)_color$/)
            color_name = key.gsub("_color", "")
            generate_shade_scale(hex).each do |step, shade_hex|
              css_lines << "    --pwb-#{color_name}-#{step}: #{shade_hex};"
            end
          end
        end

        css_lines << "  }"
        css_lines << "}"
        css_lines << ""
        css_lines << "/* Dark mode class override */"
        css_lines << ".dark {"

        dark_colors.each do |key, hex|
          css_name = key.gsub("_", "-")
          css_lines << "  --pwb-#{css_name}: #{hex};"

          if key.match?(/^(primary|secondary|accent)_color$/)
            color_name = key.gsub("_color", "")
            generate_shade_scale(hex).each do |step, shade_hex|
              css_lines << "  --pwb-#{color_name}-#{step}: #{shade_hex};"
            end
          end
        end

        css_lines << "}"

        css_lines.join("\n")
      end

      private

      def hue_to_rgb(p, q, t)
        t += 1 if t < 0
        t -= 1 if t > 1

        if t < 1/6.0
          p + (q - p) * 6 * t
        elsif t < 1/2.0
          q
        elsif t < 2/3.0
          p + (q - p) * (2/3.0 - t) * 6
        else
          p
        end
      end
    end
  end
end
