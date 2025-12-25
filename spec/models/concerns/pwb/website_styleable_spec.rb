# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::WebsiteStyleable do
  # Use a real Website instance to test the concern
  let(:website) { FactoryBot.create(:pwb_website, theme_name: "default") }

  describe "DEFAULT_STYLE_VARIABLES" do
    it "defines default style variables" do
      defaults = Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES

      expect(defaults).to be_a(Hash)
      expect(defaults).to have_key("primary_color")
      expect(defaults).to have_key("secondary_color")
    end

    it "is frozen to prevent modification" do
      expect(Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES).to be_frozen
    end
  end

  describe "#style_variables" do
    context "without palette selected" do
      before do
        website.selected_palette = nil
        website.save!
      end

      it "returns base style variables" do
        vars = website.style_variables

        expect(vars).to be_a(Hash)
      end

      it "falls back to DEFAULT_STYLE_VARIABLES when no custom vars" do
        website.style_variables_for_theme = {}
        website.save!

        vars = website.style_variables
        defaults = Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES

        expect(vars["primary_color"]).to eq(defaults["primary_color"])
      end
    end

    context "with palette selected" do
      before do
        website.theme_name = "default"
        website.selected_palette = "ocean_blue"
        website.save!
      end

      it "merges palette colors into style variables" do
        vars = website.style_variables

        expect(vars["primary_color"]).to eq("#3498db")
        expect(vars["secondary_color"]).to eq("#2c3e50")
      end

      it "palette colors override base variables" do
        # Set custom base variable
        website.style_variables_for_theme = {
          "default" => { "primary_color" => "#ff0000" }
        }
        website.save!

        vars = website.style_variables

        # Palette should override
        expect(vars["primary_color"]).to eq("#3498db")
      end

      it "includes additional palette colors not in base" do
        vars = website.style_variables

        # Ocean blue palette includes these colors
        expect(vars).to have_key("accent_color")
        expect(vars).to have_key("background_color")
      end
    end

    context "with invalid palette" do
      before do
        website.theme_name = "default"
        website.update_column(:selected_palette, "nonexistent_palette")
      end

      it "returns base variables without palette merge" do
        vars = website.style_variables

        expect(vars).to be_a(Hash)
        # Should not have palette-specific overrides
      end
    end

    context "with no theme" do
      before do
        website.update_column(:theme_name, "nonexistent")
        website.selected_palette = "ocean_blue"
      end

      it "returns base variables" do
        vars = website.style_variables

        expect(vars).to be_a(Hash)
      end
    end
  end

  describe "#current_theme" do
    it "returns Theme instance for valid theme_name" do
      website.theme_name = "brisbane"
      website.save!

      theme = website.current_theme

      expect(theme).to be_a(Pwb::Theme)
      expect(theme.name).to eq("brisbane")
    end

    it "returns nil for invalid theme_name" do
      website.update_column(:theme_name, "nonexistent")

      expect(website.current_theme).to be_nil
    end

    it "memoizes the result" do
      website.theme_name = "default"

      theme1 = website.current_theme
      theme2 = website.current_theme

      expect(theme1.object_id).to eq(theme2.object_id)
    end
  end

  describe "#effective_palette_id" do
    context "with valid selected palette" do
      before do
        website.theme_name = "default"
        website.selected_palette = "forest_green"
        website.save!
      end

      it "returns the selected palette" do
        expect(website.effective_palette_id).to eq("forest_green")
      end
    end

    context "with invalid selected palette" do
      before do
        website.theme_name = "default"
        website.update_column(:selected_palette, "invalid")
      end

      it "returns theme default palette" do
        expect(website.effective_palette_id).to eq("classic_red")
      end
    end

    context "without selected palette" do
      before do
        website.theme_name = "brisbane"
        website.selected_palette = nil
        website.save!
      end

      it "returns theme default palette" do
        expect(website.effective_palette_id).to eq("gold_navy")
      end
    end

    context "with no current theme" do
      before do
        website.update_column(:theme_name, "nonexistent")
      end

      it "returns nil" do
        expect(website.effective_palette_id).to be_nil
      end
    end
  end

  describe "#apply_palette!" do
    before do
      website.theme_name = "default"
      website.save!
    end

    it "updates selected_palette for valid palette" do
      expect {
        website.apply_palette!("sunset_orange")
      }.to change { website.reload.selected_palette }.to("sunset_orange")
    end

    it "returns true on success" do
      result = website.apply_palette!("ocean_blue")

      expect(result).to be true
    end

    it "returns false for invalid palette" do
      result = website.apply_palette!("nonexistent")

      expect(result).to be false
    end

    it "does not update for invalid palette" do
      website.update!(selected_palette: "classic_red")

      website.apply_palette!("nonexistent")

      expect(website.reload.selected_palette).to eq("classic_red")
    end

    it "returns false when no theme" do
      website.update_column(:theme_name, "nonexistent")

      result = website.apply_palette!("ocean_blue")

      expect(result).to be false
    end
  end

  describe "#available_palettes" do
    it "returns current theme palettes" do
      website.theme_name = "default"
      website.save!

      palettes = website.available_palettes

      expect(palettes).to be_a(Hash)
      expect(palettes.keys).to include("classic_red", "ocean_blue")
    end

    it "returns empty hash when no theme" do
      website.update_column(:theme_name, "nonexistent")

      expect(website.available_palettes).to eq({})
    end

    it "returns theme-specific palettes" do
      website.theme_name = "bologna"
      website.save!

      palettes = website.available_palettes

      expect(palettes.keys).to include("terracotta_classic", "sage_stone")
      expect(palettes.keys).not_to include("classic_red")
    end
  end

  describe "#palette_options_for_select" do
    before do
      website.theme_name = "default"
      website.save!
    end

    it "returns array of [name, id] pairs" do
      options = website.palette_options_for_select

      expect(options).to be_an(Array)
      options.each do |option|
        expect(option).to be_an(Array)
        expect(option.length).to eq(2)
        expect(option.first).to be_a(String) # name
        expect(option.last).to be_a(String)  # id
      end
    end

    it "returns empty array when no theme" do
      website.update_column(:theme_name, "nonexistent")

      expect(website.palette_options_for_select).to eq([])
    end
  end

  describe "palette color application across themes" do
    shared_examples "applies palette colors correctly" do |theme_name, palette_id, expected_primary|
      context "#{theme_name} theme with #{palette_id} palette" do
        before do
          website.theme_name = theme_name
          website.selected_palette = palette_id
          website.save!
        end

        it "applies #{palette_id} primary color" do
          vars = website.style_variables

          expect(vars["primary_color"]).to eq(expected_primary)
        end

        it "includes all standard palette keys" do
          vars = website.style_variables
          standard_keys = %w[primary_color secondary_color]

          standard_keys.each do |key|
            expect(vars).to have_key(key),
              "Expected style_variables to have key '#{key}' for #{theme_name}/#{palette_id}"
          end
        end
      end
    end

    include_examples "applies palette colors correctly", "default", "classic_red", "#e91b23"
    include_examples "applies palette colors correctly", "default", "ocean_blue", "#3498db"
    include_examples "applies palette colors correctly", "default", "forest_green", "#27ae60"
    include_examples "applies palette colors correctly", "brisbane", "gold_navy", "#c9a962"
    include_examples "applies palette colors correctly", "brisbane", "emerald_luxury", "#2d6a4f"
    include_examples "applies palette colors correctly", "bologna", "terracotta_classic", "#c45d3e"
    include_examples "applies palette colors correctly", "bologna", "sage_stone", "#5c6b4d"
  end

  describe "style_variables edge cases" do
    it "handles nil style_variables_for_theme gracefully" do
      website.style_variables_for_theme = nil
      website.selected_palette = nil
      website.save!

      expect { website.style_variables }.not_to raise_error
      expect(website.style_variables).to be_a(Hash)
    end

    it "handles empty style_variables_for_theme" do
      website.style_variables_for_theme = {}
      website.selected_palette = nil
      website.save!

      vars = website.style_variables

      expect(vars).to eq(Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES)
    end

    it "handles missing 'default' key in style_variables_for_theme" do
      website.style_variables_for_theme = { "other" => { "foo" => "bar" } }
      website.selected_palette = nil
      website.save!

      vars = website.style_variables

      expect(vars).to eq(Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES)
    end
  end
end
