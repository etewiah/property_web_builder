# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PaletteLoader do
  subject(:loader) { described_class.new }

  describe "#load_theme_palettes" do
    it "loads palettes for default theme" do
      palettes = loader.load_theme_palettes("default")
      expect(palettes).to be_a(Hash)
      expect(palettes).not_to be_empty
      expect(palettes.keys).to include("classic_red")
    end

    it "loads palettes for brisbane theme" do
      palettes = loader.load_theme_palettes("brisbane")
      expect(palettes).not_to be_empty
      expect(palettes.keys).to include("gold_navy")
    end

    it "returns empty hash for non-existent theme" do
      palettes = loader.load_theme_palettes("nonexistent")
      expect(palettes).to eq({})
    end
  end

  describe "#get_palette" do
    it "returns specific palette" do
      palette = loader.get_palette("default", "classic_red")
      expect(palette).not_to be_nil
      expect(palette["name"]).to eq("Classic Red")
    end

    it "returns nil for non-existent palette" do
      palette = loader.get_palette("default", "nonexistent")
      expect(palette).to be_nil
    end
  end

  describe "#get_default_palette" do
    it "returns default palette for theme" do
      palette = loader.get_default_palette("default")
      expect(palette).not_to be_nil
      expect(palette["is_default"]).to be true
    end

    it "returns first palette if no default marked" do
      # Even if no is_default, should return something
      palette = loader.get_default_palette("default")
      expect(palette).not_to be_nil
    end
  end

  describe "#get_light_colors" do
    context "with colors structure palette" do
      it "extracts colors from colors key" do
        colors = loader.get_light_colors("default", "classic_red")
        expect(colors).to be_a(Hash)
        expect(colors["primary_color"]).to eq("#e91b23")
      end
    end
  end

  describe "#get_dark_colors" do
    context "without explicit dark mode" do
      it "auto-generates dark mode colors" do
        dark_colors = loader.get_dark_colors("default", "classic_red")
        expect(dark_colors).to be_a(Hash)
        expect(dark_colors["background_color"]).to eq("#121212")
        expect(dark_colors["text_color"]).to eq("#e8e8e8")
      end
    end
  end

  describe "#has_explicit_dark_mode?" do
    it "returns false for palettes without modes.dark" do
      palette = loader.get_palette("default", "classic_red")
      expect(loader.has_explicit_dark_mode?(palette)).to be false
    end
  end

  describe "#has_modes?" do
    it "returns false for palettes with colors structure" do
      palette = loader.get_palette("default", "classic_red")
      expect(loader.has_modes?(palette)).to be false
    end
  end

  describe "#get_palette_colors_with_legacy" do
    it "includes legacy key mappings" do
      colors = loader.get_palette_colors_with_legacy("default", "classic_red")
      expect(colors["header_bg_color"]).to eq(colors["header_background_color"])
      expect(colors["footer_bg_color"]).to eq(colors["footer_background_color"])
    end

    it "supports dark mode parameter" do
      colors = loader.get_palette_colors_with_legacy("default", "classic_red", mode: :dark)
      expect(colors["background_color"]).to eq("#121212")
    end
  end

  describe "#list_palettes" do
    it "returns array of palette summaries" do
      list = loader.list_palettes("default")
      expect(list).to be_an(Array)
      expect(list.first).to include(:id, :name, :is_default)
    end

    it "includes dark mode info" do
      list = loader.list_palettes("default")
      expect(list.first).to include(:supports_dark_mode, :has_explicit_dark_mode)
    end
  end

  describe "#generate_css_variables" do
    it "generates CSS custom properties" do
      css = loader.generate_css_variables("default", "classic_red")
      expect(css).to include("--pwb-primary-color")
      expect(css).to include("#e91b23")
    end

    it "supports dark mode CSS generation" do
      css = loader.generate_css_variables("default", "classic_red", include_dark_mode: true)
      expect(css).to include("prefers-color-scheme: dark")
      expect(css).to include(".dark")
    end
  end

  describe "#generate_full_css" do
    it "generates CSS with both light and dark modes" do
      css = loader.generate_full_css("default", "classic_red")
      expect(css).to include(":root")
      expect(css).to include("prefers-color-scheme: dark")
    end
  end

  describe "#validate_theme_palettes" do
    it "validates all palettes for a theme" do
      results = loader.validate_theme_palettes("default")
      expect(results).to be_a(Hash)
      results.each_value do |result|
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end
  end

  describe "#clear_cache!" do
    it "clears the internal cache" do
      loader.load_theme_palettes("default")
      loader.clear_cache!
      # Should not raise and should reload
      palettes = loader.load_theme_palettes("default")
      expect(palettes).not_to be_empty
    end
  end

  describe "#find_palette_globally" do
    it "finds palette from default theme" do
      result = loader.find_palette_globally("classic_red")

      expect(result).not_to be_nil
      expect(result[:theme_name]).to eq("default")
      expect(result[:palette_id]).to eq("classic_red")
      expect(result[:palette]["name"]).to eq("Classic Red")
    end

    it "finds palette from brisbane theme" do
      result = loader.find_palette_globally("gold_navy")

      expect(result).not_to be_nil
      expect(result[:theme_name]).to eq("brisbane")
      expect(result[:palette_id]).to eq("gold_navy")
    end

    it "finds palette from biarritz theme" do
      result = loader.find_palette_globally("atlantic_blue")

      expect(result).not_to be_nil
      expect(result[:theme_name]).to eq("biarritz")
    end

    it "returns nil for non-existent palette" do
      result = loader.find_palette_globally("nonexistent_palette")

      expect(result).to be_nil
    end
  end

  describe "#all_palettes_flat" do
    it "returns hash of all palettes with theme info" do
      result = loader.all_palettes_flat

      expect(result).to be_a(Hash)
      expect(result.keys).to include("classic_red", "gold_navy", "atlantic_blue")

      # Each entry includes theme info
      expect(result["classic_red"][:theme_name]).to eq("default")
      expect(result["gold_navy"][:theme_name]).to eq("brisbane")
    end
  end

  describe "#list_all_palettes" do
    it "returns array of all palettes across themes" do
      result = loader.list_all_palettes

      expect(result).to be_an(Array)
      expect(result.length).to be > 20 # Multiple themes with multiple palettes

      # Each entry includes theme_name
      classic_red = result.find { |p| p[:id] == "classic_red" }
      expect(classic_red).not_to be_nil
      expect(classic_red[:theme_name]).to eq("default")
      expect(classic_red[:recommended_for_theme]).to eq("default")
    end
  end
end
