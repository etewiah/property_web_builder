# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::CssHelper, type: :helper do
  let(:website) { FactoryBot.create(:pwb_website, theme_name: "default") }

  before do
    # Set up @current_website as the helper expects
    assign(:current_website, website)
  end

  describe "#custom_styles" do
    it "renders CSS partial for given theme" do
      result = helper.custom_styles("default")

      expect(result).to be_a(String)
      expect(result).to include(":root")
    end

    context "with default theme" do
      it "includes primary-color variable" do
        result = helper.custom_styles("default")

        expect(result).to include("--primary-color:")
      end

      it "includes secondary-color variable" do
        result = helper.custom_styles("default")

        expect(result).to include("--secondary-color:")
      end
    end

    context "with brisbane theme" do
      before do
        website.theme_name = "brisbane"
        website.save!
      end

      it "includes brisbane-specific variables" do
        result = helper.custom_styles("brisbane")

        expect(result).to include("--brisbane-gold:")
        expect(result).to include("--brisbane-navy:")
      end

      context "with palette selected" do
        before do
          website.selected_palette = "emerald_luxury"
          website.save!
        end

        it "uses palette colors in CSS" do
          result = helper.custom_styles("brisbane")

          # emerald_luxury primary color is #2d6a4f
          expect(result).to include("#2d6a4f")
        end

        it "includes palette action color" do
          result = helper.custom_styles("brisbane")

          expect(result).to include("--action-color:")
        end
      end

      context "with different palettes" do
        it "gold_navy palette uses gold color" do
          website.selected_palette = "gold_navy"
          website.save!

          result = helper.custom_styles("brisbane")

          expect(result).to include("#c9a962")
        end

        it "rose_gold palette uses rose color" do
          website.selected_palette = "rose_gold"
          website.save!

          result = helper.custom_styles("brisbane")

          expect(result).to include("#b76e79")
        end
      end
    end

    context "with bologna theme" do
      before do
        website.theme_name = "bologna"
        website.save!
      end

      it "includes bologna-specific variables" do
        result = helper.custom_styles("bologna")

        expect(result).to include("--bologna-terra:")
        expect(result).to include("--bologna-olive:")
      end

      context "with terracotta palette" do
        before do
          website.selected_palette = "terracotta_classic"
          website.save!
        end

        it "uses terracotta primary color" do
          result = helper.custom_styles("bologna")

          expect(result).to include("#c45d3e")
        end
      end

      context "with sage_stone palette" do
        before do
          website.selected_palette = "sage_stone"
          website.save!
        end

        it "uses sage green primary color" do
          result = helper.custom_styles("bologna")

          expect(result).to include("#5c6b4d")
        end
      end
    end
  end

  describe "#element_classes" do
    it "returns element classes from website" do
      # This depends on style_variables configuration
      result = helper.element_classes("page_top_strip_color")

      expect(result).to be_a(String)
    end
  end

  describe "CSS variable consistency" do
    # Verify all themes render valid CSS
    %w[default brisbane bologna].each do |theme_name|
      context "#{theme_name} theme" do
        before do
          website.theme_name = theme_name
          website.save!
        end

        it "renders valid CSS without ERB errors" do
          expect { helper.custom_styles(theme_name) }.not_to raise_error
        end

        it "includes :root selector" do
          result = helper.custom_styles(theme_name)

          expect(result).to include(":root")
        end
      end
    end

    # Theme-specific variable checks
    context "brisbane theme" do
      before do
        website.theme_name = "brisbane"
        website.save!
      end

      it "includes footer color variables" do
        result = helper.custom_styles("brisbane")

        expect(result).to include("--footer-bg-color:")
        expect(result).to include("--footer-text-color:")
      end

      it "includes action color variable" do
        result = helper.custom_styles("brisbane")

        expect(result).to include("--action-color:")
      end
    end

    context "bologna theme" do
      before do
        website.theme_name = "bologna"
        website.save!
      end

      it "includes footer color variables" do
        result = helper.custom_styles("bologna")

        expect(result).to include("--footer-bg-color:")
        expect(result).to include("--footer-text-color:")
      end

      it "includes action color variable" do
        result = helper.custom_styles("bologna")

        expect(result).to include("--action-color:")
      end
    end
  end

  describe "palette color propagation" do
    before do
      website.theme_name = "default"
      website.save!
    end

    it "classic_red palette renders correct primary color" do
      website.selected_palette = "classic_red"
      website.save!

      result = helper.custom_styles("default")

      expect(result).to include("#e91b23")
    end

    it "ocean_blue palette renders correct primary color" do
      website.selected_palette = "ocean_blue"
      website.save!

      result = helper.custom_styles("default")

      expect(result).to include("#3498db")
    end

    it "forest_green palette renders correct primary color" do
      website.selected_palette = "forest_green"
      website.save!

      result = helper.custom_styles("default")

      expect(result).to include("#27ae60")
    end

    it "sunset_orange palette renders correct primary color" do
      website.selected_palette = "sunset_orange"
      website.save!

      result = helper.custom_styles("default")

      expect(result).to include("#e67e22")
    end
  end

  describe "style_variables in CSS context" do
    before do
      website.theme_name = "brisbane"
      website.selected_palette = "emerald_luxury"
      website.save!
    end

    it "palette overrides base style variables in CSS output" do
      # Set a different base color
      website.style_variables_for_theme = {
        "default" => { "primary_color" => "#ff0000" }
      }
      website.save!

      result = helper.custom_styles("brisbane")

      # Should use palette color, not base
      expect(result).to include("#2d6a4f")
      expect(result).not_to include("#ff0000")
    end
  end
end
