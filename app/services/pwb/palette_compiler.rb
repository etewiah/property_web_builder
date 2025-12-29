# frozen_string_literal: true

module Pwb
  # Compiles palette colors into static CSS for production performance
  #
  # When a website is in "compiled" mode, this service generates CSS with
  # actual hex values baked in (instead of CSS variables), which provides:
  # - No runtime variable resolution overhead
  # - Smaller CSS output (no variable declarations)
  # - Better CDN cacheability
  #
  # Usage:
  #   compiler = Pwb::PaletteCompiler.new(website)
  #   css = compiler.compile
  #   website.update!(compiled_palette_css: css, palette_mode: "compiled")
  #
  class PaletteCompiler
    attr_reader :website, :style_vars

    # Shade percentages for generating color variants
    # Maps shade step to mixing percentage (for color-mix equivalent)
    SHADE_CONFIG = {
      50 => { mix_with: :white, percent: 10 },
      100 => { mix_with: :white, percent: 20 },
      200 => { mix_with: :white, percent: 35 },
      300 => { mix_with: :white, percent: 50 },
      400 => { mix_with: :white, percent: 70 },
      500 => { mix_with: :base, percent: 100 },
      600 => { mix_with: :black, percent: 85 },
      700 => { mix_with: :black, percent: 70 },
      800 => { mix_with: :black, percent: 55 },
      900 => { mix_with: :black, percent: 40 }
    }.freeze

    def initialize(website)
      @website = website
      @style_vars = website.style_variables || {}
    end

    # Generate compiled CSS with actual color values
    # @return [String] CSS string
    def compile
      css_lines = []
      css_lines << header_comment
      css_lines << ""
      css_lines << ":root {"
      css_lines << compile_css_variables
      css_lines << "}"
      css_lines << ""
      css_lines << compile_semantic_utilities
      css_lines.join("\n")
    end

    # Generate only the CSS variables portion
    # @return [String] CSS variables
    def compile_css_variables
      vars = []

      # Primary color and shades
      primary = style_vars["primary_color"] || "#3b82f6"
      vars << "  --pwb-primary-color: #{primary};"
      vars << "  --primary-color: #{primary};"
      SHADE_CONFIG.each do |step, config|
        shade = generate_shade(primary, config)
        vars << "  --pwb-primary-#{step}: #{shade};"
      end

      # Secondary color and shades
      secondary = style_vars["secondary_color"] || "#64748b"
      vars << "  --pwb-secondary-color: #{secondary};"
      vars << "  --secondary-color: #{secondary};"
      SHADE_CONFIG.each do |step, config|
        shade = generate_shade(secondary, config)
        vars << "  --pwb-secondary-#{step}: #{shade};"
      end

      # Accent color and shades
      accent = style_vars["accent_color"] || "#f59e0b"
      vars << "  --pwb-accent-color: #{accent};"
      vars << "  --accent-color: #{accent};"
      SHADE_CONFIG.each do |step, config|
        shade = generate_shade(accent, config)
        vars << "  --pwb-accent-#{step}: #{shade};"
      end

      # Additional palette colors
      additional_colors.each do |key, fallback|
        value = style_vars[key] || fallback
        css_key = key.gsub("_", "-")
        vars << "  --pwb-#{css_key}: #{value};"
        vars << "  --#{css_key}: #{value};"
      end

      vars.join("\n")
    end

    # Generate semantic utility classes with baked-in colors
    # @return [String] CSS utility classes
    def compile_semantic_utilities
      primary = style_vars["primary_color"] || "#3b82f6"
      secondary = style_vars["secondary_color"] || "#64748b"
      accent = style_vars["accent_color"] || "#f59e0b"

      css = []

      # Primary backgrounds
      css << "/* Primary color utilities - backgrounds */"
      css << ".bg-pwb-primary { background-color: #{primary}; }"
      SHADE_CONFIG.each do |step, config|
        shade = generate_shade(primary, config)
        css << ".bg-pwb-primary-#{step} { background-color: #{shade}; }"
      end

      # Primary text
      css << ""
      css << "/* Primary color utilities - text */"
      css << ".text-pwb-primary { color: #{primary}; }"
      [600, 700, 800, 900].each do |step|
        shade = generate_shade(primary, SHADE_CONFIG[step])
        css << ".text-pwb-primary-#{step} { color: #{shade}; }"
      end

      # Primary borders
      css << ""
      css << "/* Primary color utilities - borders */"
      css << ".border-pwb-primary { border-color: #{primary}; }"
      [200, 300].each do |step|
        shade = generate_shade(primary, SHADE_CONFIG[step])
        css << ".border-pwb-primary-#{step} { border-color: #{shade}; }"
      end

      # Primary ring
      css << ".ring-pwb-primary { --tw-ring-color: #{primary}; }"

      # Secondary backgrounds
      css << ""
      css << "/* Secondary color utilities - backgrounds */"
      css << ".bg-pwb-secondary { background-color: #{secondary}; }"
      [50, 100, 500, 600, 700].each do |step|
        shade = generate_shade(secondary, SHADE_CONFIG[step])
        css << ".bg-pwb-secondary-#{step} { background-color: #{shade}; }"
      end

      # Secondary text
      css << ""
      css << "/* Secondary color utilities - text */"
      css << ".text-pwb-secondary { color: #{secondary}; }"
      [600, 700].each do |step|
        shade = generate_shade(secondary, SHADE_CONFIG[step])
        css << ".text-pwb-secondary-#{step} { color: #{shade}; }"
      end

      # Secondary borders
      css << ".border-pwb-secondary { border-color: #{secondary}; }"

      # Accent backgrounds
      css << ""
      css << "/* Accent color utilities - backgrounds */"
      css << ".bg-pwb-accent { background-color: #{accent}; }"
      [500, 600].each do |step|
        shade = generate_shade(accent, SHADE_CONFIG[step])
        css << ".bg-pwb-accent-#{step} { background-color: #{shade}; }"
      end

      # Accent text
      css << ".text-pwb-accent { color: #{accent}; }"
      css << ".text-pwb-accent-600 { color: #{generate_shade(accent, SHADE_CONFIG[600])}; }"

      # Accent borders
      css << ".border-pwb-accent { border-color: #{accent}; }"

      # Hover variants - primary
      css << ""
      css << "/* Hover variants for primary colors */"
      css << ".hover\\:bg-pwb-primary:hover { background-color: #{primary}; }"
      [600, 700, 800].each do |step|
        shade = generate_shade(primary, SHADE_CONFIG[step])
        css << ".hover\\:bg-pwb-primary-#{step}:hover { background-color: #{shade}; }"
      end
      css << ".hover\\:text-pwb-primary:hover { color: #{primary}; }"
      [600, 700].each do |step|
        shade = generate_shade(primary, SHADE_CONFIG[step])
        css << ".hover\\:text-pwb-primary-#{step}:hover { color: #{shade}; }"
      end
      css << ".hover\\:border-pwb-primary:hover { border-color: #{primary}; }"

      # Hover variants - secondary
      css << ""
      css << "/* Hover variants for secondary colors */"
      css << ".hover\\:bg-pwb-secondary:hover { background-color: #{secondary}; }"
      [600, 700].each do |step|
        shade = generate_shade(secondary, SHADE_CONFIG[step])
        css << ".hover\\:bg-pwb-secondary-#{step}:hover { background-color: #{shade}; }"
      end
      css << ".hover\\:text-pwb-secondary:hover { color: #{secondary}; }"

      # Focus variants
      css << ""
      css << "/* Focus variants */"
      css << ".focus\\:ring-pwb-primary:focus { --tw-ring-color: #{primary}; }"
      css << ".focus\\:border-pwb-primary:focus { border-color: #{primary}; }"
      css << ".focus\\:outline-pwb-primary:focus { outline-color: #{primary}; }"

      # Active variants
      css << ""
      css << "/* Active variants */"
      css << ".active\\:bg-pwb-primary-800:active { background-color: #{generate_shade(primary, SHADE_CONFIG[800])}; }"

      # Gradient utilities
      css << ""
      css << "/* Gradient utilities with palette colors */"
      css << ".from-pwb-primary { --tw-gradient-from: #{primary}; }"
      css << ".to-pwb-primary { --tw-gradient-to: #{primary}; }"
      css << ".from-pwb-primary-600 { --tw-gradient-from: #{generate_shade(primary, SHADE_CONFIG[600])}; }"
      css << ".to-pwb-primary-700 { --tw-gradient-to: #{generate_shade(primary, SHADE_CONFIG[700])}; }"
      css << ".from-pwb-secondary { --tw-gradient-from: #{secondary}; }"
      css << ".to-pwb-secondary { --tw-gradient-to: #{secondary}; }"

      # Button components
      css << ""
      css << "/* Button component classes using palette colors */"
      css << compile_button_classes(primary, secondary)

      # Link styles
      css << ""
      css << "/* Link styles using palette colors */"
      css << compile_link_classes(primary)

      # Badge styles
      css << ""
      css << "/* Badge/tag styles using palette colors */"
      css << compile_badge_classes(primary, secondary)

      css.join("\n")
    end

    private

    def header_comment
      <<~COMMENT.strip
        /* ==========================================================================
           Compiled Palette CSS for #{website.subdomain || 'website'}
           Generated: #{Time.current.iso8601}
           Palette: #{website.selected_palette || 'default'}
           Theme: #{website.theme_name || 'default'}

           This CSS contains pre-computed color values for maximum performance.
           To update colors, switch to dynamic mode, make changes, then recompile.
           ========================================================================== */
      COMMENT
    end

    def generate_shade(base_hex, config)
      return base_hex if config[:mix_with] == :base

      case config[:mix_with]
      when :white
        ColorUtils.lighten(base_hex, 100 - config[:percent])
      when :black
        ColorUtils.darken(base_hex, 100 - config[:percent])
      else
        base_hex
      end
    end

    def additional_colors
      {
        "background_color" => "#ffffff",
        "text_color" => "#1e293b",
        "header_background_color" => "#ffffff",
        "header_text_color" => "#1e293b",
        "footer_background_color" => "#1e293b",
        "footer_text_color" => "#f8fafc",
        "card_background_color" => "#ffffff",
        "border_color" => "#e2e8f0",
        "link_color" => "#3b82f6",
        "success_color" => "#22c55e",
        "warning_color" => "#f59e0b",
        "error_color" => "#ef4444"
      }
    end

    def compile_button_classes(primary, secondary)
      primary_700 = generate_shade(primary, SHADE_CONFIG[700])
      secondary_700 = generate_shade(secondary, SHADE_CONFIG[700])

      <<~CSS.strip
        .btn-pwb-primary {
          background-color: #{primary};
          color: white;
          padding: 0.5rem 1rem;
          border-radius: 0.375rem;
          font-weight: 500;
          transition: background-color 0.2s;
        }
        .btn-pwb-primary:hover {
          background-color: #{primary_700};
        }
        .btn-pwb-primary:focus {
          outline: 2px solid #{primary};
          outline-offset: 2px;
        }

        .btn-pwb-secondary {
          background-color: #{secondary};
          color: white;
          padding: 0.5rem 1rem;
          border-radius: 0.375rem;
          font-weight: 500;
          transition: background-color 0.2s;
        }
        .btn-pwb-secondary:hover {
          background-color: #{secondary_700};
        }

        .btn-pwb-outline {
          background-color: transparent;
          color: #{primary};
          border: 2px solid #{primary};
          padding: 0.5rem 1rem;
          border-radius: 0.375rem;
          font-weight: 500;
          transition: all 0.2s;
        }
        .btn-pwb-outline:hover {
          background-color: #{primary};
          color: white;
        }
      CSS
    end

    def compile_link_classes(primary)
      primary_700 = generate_shade(primary, SHADE_CONFIG[700])

      <<~CSS.strip
        .link-pwb-primary {
          color: #{primary};
          text-decoration: none;
          transition: color 0.2s;
        }
        .link-pwb-primary:hover {
          color: #{primary_700};
          text-decoration: underline;
        }
      CSS
    end

    def compile_badge_classes(primary, secondary)
      primary_100 = generate_shade(primary, SHADE_CONFIG[100])
      primary_800 = generate_shade(primary, SHADE_CONFIG[800])
      secondary_100 = generate_shade(secondary, SHADE_CONFIG[100])
      secondary_800 = generate_shade(secondary, SHADE_CONFIG[800])

      <<~CSS.strip
        .badge-pwb-primary {
          background-color: #{primary_100};
          color: #{primary_800};
          padding: 0.25rem 0.75rem;
          border-radius: 9999px;
          font-size: 0.875rem;
          font-weight: 500;
        }

        .badge-pwb-secondary {
          background-color: #{secondary_100};
          color: #{secondary_800};
          padding: 0.25rem 0.75rem;
          border-radius: 9999px;
          font-size: 0.875rem;
          font-weight: 500;
        }
      CSS
    end
  end
end
