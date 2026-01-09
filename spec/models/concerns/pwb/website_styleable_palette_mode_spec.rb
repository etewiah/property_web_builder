# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::WebsiteStyleable, "palette mode support" do
  include ActiveSupport::Testing::TimeHelpers

  let(:website) do
    create(:website,
           subdomain: "palette-test",
           theme_name: "default",
           selected_palette: nil) # Don't use theme palette, use our custom colors
  end

  let(:test_colors) do
    {
      "primary_color" => "#DC2626",
      "secondary_color" => "#1E40AF",
      "accent_color" => "#F59E0B"
    }
  end

  before do
    # Set up style variables directly (bypassing palette system)
    website.style_variables_for_theme["default"] = test_colors
    website.save!
  end

  describe "#palette_dynamic?" do
    it "returns true when palette_mode is 'dynamic'" do
      website.update!(palette_mode: "dynamic")
      expect(website.palette_dynamic?).to be true
    end

    it "returns false when palette_mode is 'compiled'" do
      website.update!(palette_mode: "compiled")
      expect(website.palette_dynamic?).to be false
    end
  end

  describe "#palette_compiled?" do
    it "returns false when palette_mode is 'dynamic'" do
      website.update!(palette_mode: "dynamic")
      expect(website.palette_compiled?).to be false
    end

    it "returns true when palette_mode is 'compiled'" do
      website.update!(palette_mode: "compiled")
      expect(website.palette_compiled?).to be true
    end
  end

  describe "#compile_palette!" do
    before do
      # Stub style_variables to return our test colors
      allow(website).to receive(:style_variables).and_return(test_colors)
    end

    it "sets palette_mode to 'compiled'" do
      expect(website.compile_palette!).to be true
      expect(website.reload.palette_mode).to eq("compiled")
    end

    it "generates and stores compiled CSS" do
      website.compile_palette!
      expect(website.compiled_palette_css).to be_present
    end

    it "sets palette_compiled_at timestamp" do
      freeze_time do
        website.compile_palette!
        expect(website.palette_compiled_at).to be_within(1.second).of(Time.current)
      end
    end

    it "includes primary color in compiled CSS" do
      website.compile_palette!
      expect(website.compiled_palette_css).to include("#DC2626")
    end

    it "includes utility classes in compiled CSS" do
      website.compile_palette!
      expect(website.compiled_palette_css).to include(".bg-pwb-primary")
      expect(website.compiled_palette_css).to include(".text-pwb-primary")
    end
  end

  describe "#unpin_palette!" do
    before do
      allow(website).to receive(:style_variables).and_return(test_colors)
      website.compile_palette!
    end

    it "sets palette_mode to 'dynamic'" do
      expect(website.unpin_palette!).to be true
      expect(website.reload.palette_mode).to eq("dynamic")
    end

    it "clears compiled_palette_css" do
      website.unpin_palette!
      expect(website.compiled_palette_css).to be_nil
    end

    it "clears palette_compiled_at" do
      website.unpin_palette!
      expect(website.palette_compiled_at).to be_nil
    end
  end

  describe "#palette_stale?" do
    context "in dynamic mode" do
      it "returns false" do
        website.update!(palette_mode: "dynamic")
        expect(website.palette_stale?).to be false
      end
    end

    context "in compiled mode" do
      before do
        allow(website).to receive(:style_variables).and_return(test_colors)
        website.compile_palette!
      end

      it "returns false when recently compiled" do
        # After compiling, reload to get fresh timestamps
        website.reload
        expect(website.palette_stale?).to be false
      end

      it "returns true when compiled_palette_css is blank" do
        website.update_column(:compiled_palette_css, nil)
        expect(website.palette_stale?).to be true
      end

      it "returns true when palette_compiled_at is blank" do
        website.update_column(:palette_compiled_at, nil)
        expect(website.palette_stale?).to be true
      end

      it "returns true when updated after compilation" do
        website.compile_palette!
        travel 1.minute
        website.touch
        expect(website.palette_stale?).to be true
      end
    end
  end

  describe "#palette_css" do
    context "in dynamic mode" do
      it "returns dynamic CSS with variables" do
        website.update!(palette_mode: "dynamic")
        css = website.palette_css

        expect(css).to include(":root {")
        expect(css).to include("--pwb-primary-color:")
        expect(css).to include("color-mix")
      end
    end

    context "in compiled mode" do
      before do
        allow(website).to receive(:style_variables).and_return(test_colors)
        website.compile_palette!
      end

      it "returns compiled static CSS" do
        css = website.palette_css

        expect(css).to include(".bg-pwb-primary")
        expect(css).to include("#DC2626")
        expect(css).not_to include("var(--pwb-primary-color)")
      end
    end

    context "in compiled mode with missing CSS" do
      before do
        website.update!(palette_mode: "compiled", compiled_palette_css: nil)
      end

      it "falls back to dynamic CSS" do
        css = website.palette_css

        expect(css).to include(":root {")
        expect(css).to include("color-mix")
      end
    end
  end

  describe "#generate_dynamic_palette_css" do
    before do
      allow(website).to receive(:style_variables).and_return(test_colors)
    end

    let(:css) { website.generate_dynamic_palette_css }

    it "generates CSS with :root selector" do
      expect(css).to include(":root {")
    end

    it "includes primary color variable" do
      expect(css).to include("--pwb-primary-color: #DC2626")
    end

    it "includes secondary color variable" do
      expect(css).to include("--pwb-secondary-color: #1E40AF")
    end

    it "includes accent color variable" do
      expect(css).to include("--pwb-accent-color: #F59E0B")
    end

    it "includes shade variables using color-mix" do
      expect(css).to include("--pwb-primary-50: color-mix")
      expect(css).to include("--pwb-primary-600: color-mix")
    end

    it "generates proper light shade mix percentages" do
      expect(css).to include("--pwb-primary-100: color-mix(in srgb, #DC2626 20%, white)")
    end

    it "generates proper dark shade mix percentages" do
      expect(css).to include("--pwb-primary-700: color-mix(in srgb, #DC2626 70%, black)")
    end
  end

  describe "validation" do
    it "allows valid palette_mode values" do
      %w[dynamic compiled].each do |mode|
        website.palette_mode = mode
        expect(website).to be_valid
      end
    end

    it "rejects invalid palette_mode values" do
      website.palette_mode = "invalid"
      expect(website).not_to be_valid
      expect(website.errors[:palette_mode]).to be_present
    end
  end

  describe "module class methods" do
    it "provides palette_mode_options for admin UI" do
      options = Pwb::WebsiteStyleable.palette_mode_options

      expect(options).to be_an(Array)
      expect(options.length).to eq(2)
      expect(options.map(&:last)).to include("dynamic", "compiled")
    end
  end
end
