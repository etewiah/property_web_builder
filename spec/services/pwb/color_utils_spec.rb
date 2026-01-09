# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ColorUtils do
  describe ".hex_to_rgb" do
    it "converts 6-digit hex to RGB" do
      expect(described_class.hex_to_rgb("#FF5733")).to eq([255, 87, 51])
      expect(described_class.hex_to_rgb("#000000")).to eq([0, 0, 0])
      expect(described_class.hex_to_rgb("#FFFFFF")).to eq([255, 255, 255])
    end

    it "converts 3-digit hex to RGB" do
      expect(described_class.hex_to_rgb("#FFF")).to eq([255, 255, 255])
      expect(described_class.hex_to_rgb("#000")).to eq([0, 0, 0])
    end

    it "handles lowercase hex" do
      expect(described_class.hex_to_rgb("#ff5733")).to eq([255, 87, 51])
    end
  end

  describe ".rgb_to_hex" do
    it "converts RGB to hex" do
      expect(described_class.rgb_to_hex(255, 87, 51)).to eq("#ff5733")
      expect(described_class.rgb_to_hex(0, 0, 0)).to eq("#000000")
      expect(described_class.rgb_to_hex(255, 255, 255)).to eq("#ffffff")
    end
  end

  describe ".rgb_to_hsl" do
    it "converts RGB to HSL" do
      h, s, l = described_class.rgb_to_hsl(255, 0, 0)
      expect(h).to be_within(1).of(0)
      expect(s).to be_within(1).of(100) # 0-100 scale
      expect(l).to be_within(1).of(50)  # 0-100 scale
    end

    it "handles white" do
      _, _, l = described_class.rgb_to_hsl(255, 255, 255)
      expect(l).to be_within(1).of(100)
    end

    it "handles black" do
      _, _, l = described_class.rgb_to_hsl(0, 0, 0)
      expect(l).to be_within(1).of(0)
    end
  end

  describe ".hsl_to_rgb" do
    it "converts HSL to RGB" do
      # Using 0-100 scale for saturation and lightness
      expect(described_class.hsl_to_rgb(0, 100, 50)).to eq([255, 0, 0])
      expect(described_class.hsl_to_rgb(120, 100, 50)).to eq([0, 255, 0])
      expect(described_class.hsl_to_rgb(240, 100, 50)).to eq([0, 0, 255])
    end

    it "handles grayscale" do
      expect(described_class.hsl_to_rgb(0, 0, 100)).to eq([255, 255, 255])
      expect(described_class.hsl_to_rgb(0, 0, 0)).to eq([0, 0, 0])
    end
  end

  describe ".lighten" do
    it "lightens a color" do
      original = described_class.hex_to_rgb("#333333")
      result_hex = described_class.lighten("#333333", 20)
      result = described_class.hex_to_rgb(result_hex)
      # Lighter means higher RGB values on average
      expect(result.sum).to be > original.sum
    end
  end

  describe ".darken" do
    it "darkens a color" do
      original = described_class.hex_to_rgb("#CCCCCC")
      result_hex = described_class.darken("#CCCCCC", 20)
      result = described_class.hex_to_rgb(result_hex)
      # Darker means lower RGB values on average
      expect(result.sum).to be < original.sum
    end
  end

  describe ".contrast_ratio" do
    it "calculates WCAG contrast ratio" do
      ratio = described_class.contrast_ratio("#000000", "#FFFFFF")
      expect(ratio).to be_within(0.1).of(21.0)
    end

    it "returns 1 for same color" do
      ratio = described_class.contrast_ratio("#333333", "#333333")
      expect(ratio).to eq(1.0)
    end
  end

  describe ".wcag_aa_compliant?" do
    it "returns true for high contrast" do
      expect(described_class.wcag_aa_compliant?("#000000", "#FFFFFF")).to be true
    end

    it "returns false for low contrast" do
      expect(described_class.wcag_aa_compliant?("#777777", "#888888")).to be false
    end
  end

  describe ".generate_shade_scale" do
    it "generates Tailwind-style shade scale" do
      shades = described_class.generate_shade_scale("#3498db")
      expect(shades.keys).to include(50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950)
    end

    it "has lighter shades for lower numbers" do
      shades = described_class.generate_shade_scale("#3498db")
      # Lighter shades have higher RGB sum
      sum_50 = described_class.hex_to_rgb(shades[50]).sum
      sum_900 = described_class.hex_to_rgb(shades[900]).sum
      expect(sum_50).to be > sum_900
    end
  end

  describe ".generate_dark_mode_colors" do
    let(:light_colors) do
      {
        "primary_color" => "#e91b23",
        "secondary_color" => "#2c3e50",
        "accent_color" => "#3498db",
        "background_color" => "#ffffff",
        "text_color" => "#333333",
        "header_background_color" => "#ffffff",
        "header_text_color" => "#333333",
        "footer_background_color" => "#2c3e50",
        "footer_text_color" => "#ffffff"
      }
    end

    it "generates dark mode colors" do
      dark = described_class.generate_dark_mode_colors(light_colors)
      expect(dark).to be_a(Hash)
      expect(dark["background_color"]).to eq("#121212")
      expect(dark["text_color"]).to eq("#e8e8e8")
    end

    it "preserves all keys from light colors" do
      dark = described_class.generate_dark_mode_colors(light_colors)
      light_colors.each_key do |key|
        expect(dark).to have_key(key)
      end
    end

    it "adjusts primary/accent colors for visibility" do
      dark = described_class.generate_dark_mode_colors(light_colors)
      # Dark mode primary should be slightly adjusted for dark backgrounds
      expect(dark["primary_color"]).not_to eq(light_colors["primary_color"])
    end
  end

  describe ".generate_dual_mode_css_variables" do
    let(:light_colors) do
      {
        "primary_color" => "#e91b23",
        "background_color" => "#ffffff"
      }
    end

    it "generates CSS with light mode root" do
      css = described_class.generate_dual_mode_css_variables(light_colors)
      expect(css).to include(":root {")
      expect(css).to include("--pwb-primary-color: #e91b23")
    end

    it "generates CSS with dark mode media query" do
      css = described_class.generate_dual_mode_css_variables(light_colors)
      expect(css).to include("@media (prefers-color-scheme: dark)")
    end

    it "generates CSS with .dark class" do
      css = described_class.generate_dual_mode_css_variables(light_colors)
      expect(css).to include(".dark {")
    end

    it "uses provided dark colors if given" do
      dark_colors = { "primary_color" => "#custom1", "background_color" => "#custom2" }
      css = described_class.generate_dual_mode_css_variables(light_colors, dark_colors)
      expect(css).to include("--pwb-primary-color: #custom1")
    end
  end

  describe ".generate_palette_css_variables" do
    let(:palette) do
      {
        "colors" => {
          "primary_color" => "#e91b23",
          "secondary_color" => "#2c3e50"
        }
      }
    end

    it "generates CSS variables from palette colors" do
      css = described_class.generate_palette_css_variables(palette)
      expect(css).to include("--pwb-primary-color: #e91b23")
      expect(css).to include("--pwb-secondary-color: #2c3e50")
    end

    it "generates shade scales for primary/secondary/accent" do
      css = described_class.generate_palette_css_variables(palette)
      expect(css).to include("--pwb-primary-50:")
      expect(css).to include("--pwb-primary-500:")
      expect(css).to include("--pwb-primary-900:")
    end
  end
end
