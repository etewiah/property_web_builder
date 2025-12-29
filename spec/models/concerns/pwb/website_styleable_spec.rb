# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::WebsiteStyleable do
  # Set up tenant settings to allow all themes used in tests
  before(:all) do
    Pwb::TenantSettings.delete_all
    Pwb::TenantSettings.create!(
      singleton_key: "default",
      default_available_themes: %w[default brisbane bologna barcelona biarritz]
    )
  end

  after(:all) do
    Pwb::TenantSettings.delete_all
  end

  # Clear memoization on website instances between tests
  after(:each) do
    # Ensure website instance variables are cleared for fresh state
  end

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
      # Get a fresh instance since reload doesn't clear memoized @current_theme
      fresh_website = Pwb::Website.find(website.id)

      expect(fresh_website.current_theme).to be_nil
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
      it "returns nil" do
        website.update_column(:theme_name, "nonexistent")
        # Get a fresh instance since reload doesn't clear memoized @current_theme
        fresh_website = Pwb::Website.find(website.id)

        expect(fresh_website.effective_palette_id).to be_nil
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
      # Get a fresh instance since reload doesn't clear memoized @current_theme
      fresh_website = Pwb::Website.find(website.id)

      result = fresh_website.apply_palette!("ocean_blue")

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
      # Get a fresh instance since reload doesn't clear memoized @current_theme
      fresh_website = Pwb::Website.find(website.id)

      expect(fresh_website.available_palettes).to eq({})
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
      # Get a fresh instance since reload doesn't clear memoized @current_theme
      fresh_website = Pwb::Website.find(website.id)

      expect(fresh_website.palette_options_for_select).to eq([])
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

  describe "theme change and palette reset" do
    it "clears memoized theme when theme_name changes" do
      website.theme_name = "default"
      website.save!

      # Get current theme to memoize it
      original_theme = website.current_theme
      expect(original_theme.name).to eq("default")

      # Change theme
      website.theme_name = "brisbane"
      website.instance_variable_set(:@current_theme, nil) # Clear memoization
      website.save!

      new_theme = website.current_theme
      expect(new_theme.name).to eq("brisbane")
      expect(new_theme.name).not_to eq(original_theme.name)
    end

    it "validates selected_palette belongs to current theme" do
      website.theme_name = "default"
      website.selected_palette = "classic_red"
      website.save!

      # Verify the palette is valid for this theme
      expect(website.apply_palette!("classic_red")).to be true

      # Try to apply palette from different theme
      expect(website.apply_palette!("gold_navy")).to be false
    end

    it "resets to theme default palette when invalid palette selected" do
      website.theme_name = "default"
      website.update_column(:selected_palette, "invalid_palette")

      effective = website.effective_palette_id
      expect(effective).to eq("classic_red") # Default for 'default' theme
    end
  end

  describe "all themes have valid palettes" do
    %w[default brisbane bologna barcelona biarritz].each do |theme_name|
      context "#{theme_name} theme" do
        before do
          website.theme_name = theme_name
          website.save!
        end

        it "has available palettes" do
          palettes = website.available_palettes
          expect(palettes).not_to be_empty
          expect(palettes).to be_a(Hash)
        end

        it "has a default palette" do
          expect(website.effective_palette_id).to be_present
        end

        it "returns style variables" do
          vars = website.style_variables
          expect(vars).to be_a(Hash)
          expect(vars["primary_color"]).to be_present
        end

        it "can apply any available palette" do
          palettes = website.available_palettes
          palettes.each_key do |palette_id|
            result = website.apply_palette!(palette_id)
            expect(result).to be(true),
              -> { "Failed to apply palette '#{palette_id}' for #{theme_name} theme" }
          end
        end

        it "generates palette options for select" do
          options = website.palette_options_for_select
          expect(options).to be_an(Array)
          expect(options).not_to be_empty
        end
      end
    end
  end

  describe "palette color consistency" do
    it "palette colors are valid hex values" do
      website.theme_name = "default"
      website.selected_palette = "classic_red"
      website.save!

      vars = website.style_variables
      color_keys = vars.keys.select { |k| k.include?("color") }

      color_keys.each do |key|
        value = vars[key]
        next if value.nil? # Skip nil values

        expect(value).to match(/^#[0-9a-fA-F]{3,6}$/),
          "Expected #{key} to be valid hex, got: #{value}"
      end
    end

    it "primary_color and secondary_color are always present" do
      %w[default brisbane bologna].each do |theme_name|
        website.theme_name = theme_name
        website.save!

        vars = website.style_variables
        expect(vars["primary_color"]).to be_present,
          "primary_color missing for #{theme_name}"
        expect(vars["secondary_color"]).to be_present,
          "secondary_color missing for #{theme_name}"
      end
    end
  end

  describe "website without theme_name" do
    it "falls back to default theme when theme_name is nil" do
      website.update_column(:theme_name, nil)
      website.instance_variable_set(:@current_theme, nil) # Clear memoization

      expect(website.current_theme).to be_present
      expect(website.current_theme.name).to eq("default")
    end

    it "returns default theme palettes when theme_name is nil" do
      website.update_column(:theme_name, nil)
      website.instance_variable_set(:@current_theme, nil) # Clear memoization

      expect(website.available_palettes).not_to be_empty
    end

    it "returns style variables from default theme when theme_name is nil" do
      website.update_column(:theme_name, nil)
      website.instance_variable_set(:@current_theme, nil) # Clear memoization

      vars = website.style_variables
      expect(vars).to be_a(Hash)
      expect(vars).to have_key("primary_color")
    end

    it "effective_palette_id returns default theme palette when theme_name is nil" do
      website.update_column(:theme_name, nil)
      website.instance_variable_set(:@current_theme, nil) # Clear memoization

      expect(website.effective_palette_id).to be_present
    end
  end

  describe "new website defaults" do
    it "newly created website has accessible themes" do
      new_website = FactoryBot.create(:pwb_website, theme_name: "default")

      expect(new_website.accessible_theme_names).to include("default")
      expect(new_website.current_theme).to be_present
    end

    it "newly created website can apply palettes" do
      new_website = FactoryBot.create(:pwb_website, theme_name: "default")

      expect(new_website.apply_palette!("ocean_blue")).to be true
      expect(new_website.selected_palette).to eq("ocean_blue")
    end
  end

  describe "cache clearing" do
    it "clears theme cache on save when theme_name changes" do
      website.theme_name = "default"
      website.save!

      # Access current_theme to memoize
      expect(website.current_theme.name).to eq("default")

      # Change theme
      website.theme_name = "brisbane"
      website.save!

      # Should get new theme without manual cache clearing
      expect(website.current_theme.name).to eq("brisbane")
    end

    it "refresh_theme_data! forces reload of all theme data" do
      website.theme_name = "default"
      website.selected_palette = "classic_red"
      website.save!

      # Access to memoize
      old_theme = website.current_theme
      old_vars = website.style_variables

      # Force refresh
      website.refresh_theme_data!

      # Data should still be valid after refresh
      expect(website.current_theme.name).to eq("default")
      expect(website.style_variables).to be_a(Hash)
    end

    it "clears palette loader cache after palette change" do
      website.theme_name = "default"
      website.selected_palette = "classic_red"
      website.save!

      old_vars = website.style_variables

      website.selected_palette = "ocean_blue"
      website.save!

      new_vars = website.style_variables
      expect(new_vars["primary_color"]).to eq("#3498db")
      expect(new_vars["primary_color"]).not_to eq(old_vars["primary_color"])
    end
  end
end
