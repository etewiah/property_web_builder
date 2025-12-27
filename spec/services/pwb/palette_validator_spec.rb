# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PaletteValidator do
  subject(:validator) { described_class.new }

  let(:valid_palette) do
    {
      "id" => "test_palette",
      "name" => "Test Palette",
      "colors" => {
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
    }
  end

  describe "#validate" do
    context "with a valid palette using colors structure" do
      it "returns valid result" do
        result = validator.validate(valid_palette)
        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "with a valid palette using modes structure" do
      let(:modes_palette) do
        {
          "id" => "modes_palette",
          "name" => "Modes Palette",
          "modes" => {
            "light" => valid_palette["colors"],
            "dark" => {
              "primary_color" => "#f3111a",
              "secondary_color" => "#688cb1",
              "accent_color" => "#2c9ae3",
              "background_color" => "#121212",
              "text_color" => "#e8e8e8",
              "header_background_color" => "#1a1a1a",
              "header_text_color" => "#e8e8e8",
              "footer_background_color" => "#0d0d0d",
              "footer_text_color" => "#e8e8e8"
            }
          }
        }
      end

      it "returns valid result" do
        result = validator.validate(modes_palette)
        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "with missing required keys" do
      it "reports missing id" do
        palette = valid_palette.except("id")
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors).to include("Missing required key: 'id'")
      end

      it "reports missing name" do
        palette = valid_palette.except("name")
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors).to include("Missing required key: 'name'")
      end
    end

    context "with missing color structure" do
      it "reports missing colors or modes" do
        palette = valid_palette.except("colors")
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors).to include("Palette must have either 'colors' or 'modes.light'")
      end
    end

    context "with both colors and modes" do
      it "reports error for having both" do
        palette = valid_palette.merge(
          "modes" => { "light" => valid_palette["colors"] }
        )
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors).to include("Palette cannot have both 'colors' and 'modes' - use one or the other")
      end
    end

    context "with invalid id format" do
      it "reports invalid snake_case format" do
        palette = valid_palette.merge("id" => "InvalidFormat")
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors.first).to include("Invalid id format")
      end
    end

    context "with invalid hex color" do
      it "reports invalid color format" do
        palette = valid_palette.deep_dup
        palette["colors"]["primary_color"] = "not-a-color"
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors.first).to include("Invalid hex color")
      end
    end

    context "with missing required colors" do
      it "reports missing required color" do
        palette = valid_palette.deep_dup
        palette["colors"].delete("primary_color")
        result = validator.validate(palette)
        expect(result.valid?).to be false
        expect(result.errors).to include("Missing required color: 'primary_color'")
      end
    end

    context "with legacy key normalization" do
      it "migrates legacy keys and adds warning" do
        palette = valid_palette.deep_dup
        palette["colors"]["footer_main_text_color"] = "#ffffff"
        palette["colors"].delete("footer_text_color")

        result = validator.validate(palette)
        expect(result.valid?).to be true
        expect(result.warnings.first).to include("Migrated legacy key 'footer_main_text_color'")
        expect(result.normalized_palette.dig("colors", "footer_text_color")).to eq("#ffffff")
      end
    end
  end

  describe "#valid_hex_color?" do
    it "validates 6-digit hex colors" do
      expect(validator.valid_hex_color?("#FF5733")).to be true
      expect(validator.valid_hex_color?("#ffffff")).to be true
    end

    it "validates 3-digit hex colors" do
      expect(validator.valid_hex_color?("#FFF")).to be true
      expect(validator.valid_hex_color?("#abc")).to be true
    end

    it "rejects invalid formats" do
      expect(validator.valid_hex_color?("red")).to be false
      expect(validator.valid_hex_color?("#GGGGGG")).to be false
      expect(validator.valid_hex_color?("ffffff")).to be false
      expect(validator.valid_hex_color?(nil)).to be false
    end
  end

  describe "#has_modes?" do
    it "returns true for palettes with modes structure" do
      palette = {
        "modes" => {
          "light" => valid_palette["colors"]
        }
      }
      expect(validator.has_modes?(palette)).to be true
    end

    it "returns false for palettes with colors structure" do
      expect(validator.has_modes?(valid_palette)).to be false
    end
  end

  describe "#has_dark_mode?" do
    it "returns true when dark mode is present" do
      palette = {
        "modes" => {
          "light" => valid_palette["colors"],
          "dark" => valid_palette["colors"]
        }
      }
      expect(validator.has_dark_mode?(palette)).to be true
    end

    it "returns false when only light mode is present" do
      palette = {
        "modes" => {
          "light" => valid_palette["colors"]
        }
      }
      expect(validator.has_dark_mode?(palette)).to be false
    end
  end
end
