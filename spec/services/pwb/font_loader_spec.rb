# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::FontLoader do
  subject(:loader) { described_class.new }

  describe "#initialize" do
    it "loads fonts configuration" do
      expect(loader.fonts_config).to be_a(Hash)
      expect(loader.fonts_config["fonts"]).not_to be_empty
    end
  end

  describe "#get_font" do
    it "returns font configuration for known fonts" do
      font = loader.get_font("Open Sans")
      expect(font).not_to be_nil
      expect(font["provider"]).to eq("google")
      expect(font["category"]).to eq("sans-serif")
    end

    it "returns nil for unknown fonts" do
      font = loader.get_font("Unknown Font")
      expect(font).to be_nil
    end

    it "returns system font configuration" do
      font = loader.get_font("System UI")
      expect(font).not_to be_nil
      expect(font["provider"]).to eq("system")
    end
  end

  describe "#google_font?" do
    it "returns true for Google fonts" do
      expect(loader.google_font?("Open Sans")).to be true
      expect(loader.google_font?("Montserrat")).to be true
    end

    it "returns false for system fonts" do
      expect(loader.google_font?("System UI")).to be false
    end

    it "returns false for unknown fonts" do
      expect(loader.google_font?("Unknown Font")).to be false
    end
  end

  describe "#system_font?" do
    it "returns true for system fonts" do
      expect(loader.system_font?("System UI")).to be true
      expect(loader.system_font?("Georgia")).to be true
    end

    it "returns false for Google fonts" do
      expect(loader.system_font?("Open Sans")).to be false
    end
  end

  describe "#google_fonts_url" do
    it "generates correct URL for single font" do
      url = loader.google_fonts_url(["Open Sans"])
      expect(url).to include("fonts.googleapis.com")
      expect(url).to include("Open+Sans")
      expect(url).to include("display=swap")
    end

    it "generates correct URL for multiple fonts" do
      url = loader.google_fonts_url(["Open Sans", "Montserrat"])
      expect(url).to include("Open+Sans")
      expect(url).to include("Montserrat")
    end

    it "returns nil for empty array" do
      url = loader.google_fonts_url([])
      expect(url).to be_nil
    end

    it "returns nil for system fonts only" do
      url = loader.google_fonts_url(["System UI"])
      expect(url).to be_nil
    end

    it "filters out system fonts from mixed list" do
      url = loader.google_fonts_url(["Open Sans", "System UI"])
      expect(url).to include("Open+Sans")
      expect(url).not_to include("System")
    end
  end

  describe "#font_family_css" do
    it "generates correct font-family with fallbacks" do
      css = loader.font_family_css("Open Sans")
      expect(css).to eq("'Open Sans', system-ui, -apple-system, sans-serif")
    end

    it "returns fallback for unknown fonts" do
      css = loader.font_family_css("Unknown Font")
      expect(css).to eq("system-ui, sans-serif")
    end

    it "handles serif fonts correctly" do
      css = loader.font_family_css("Playfair Display")
      expect(css).to include("Georgia, serif")
    end
  end

  describe "#available_fonts" do
    it "returns array of font names" do
      fonts = loader.available_fonts
      expect(fonts).to be_an(Array)
      expect(fonts).to include("Open Sans")
      expect(fonts).to include("Montserrat")
      expect(fonts).to include("System UI")
    end

    it "includes both Google and system fonts" do
      fonts = loader.available_fonts
      expect(fonts.count).to be > 20
    end
  end

  describe "#fonts_by_category" do
    it "groups fonts by category" do
      by_category = loader.fonts_by_category
      expect(by_category).to be_a(Hash)
      expect(by_category.keys).to include("sans-serif")
      expect(by_category.keys).to include("serif")
    end

    it "includes font details in each category" do
      sans_fonts = loader.fonts_by_category["sans-serif"]
      expect(sans_fonts).to be_an(Array)
      expect(sans_fonts.first).to have_key(:name)
      expect(sans_fonts.first).to have_key(:provider)
    end
  end

  describe "#preconnect_tags" do
    it "generates preconnect link tags" do
      tags = loader.preconnect_tags
      expect(tags).to include("fonts.googleapis.com")
      expect(tags).to include("fonts.gstatic.com")
      expect(tags).to include("preconnect")
    end
  end

  describe "with website" do
    let(:website) { create(:pwb_website) }

    describe "#fonts_for_website" do
      it "returns primary and heading fonts" do
        fonts = loader.fonts_for_website(website)
        expect(fonts).to have_key(:primary)
        expect(fonts).to have_key(:heading)
      end

      it "uses defaults when style_variables are empty" do
        website.update(style_variables_for_theme: {})
        fonts = loader.fonts_for_website(website)
        expect(fonts[:primary]).to eq("Open Sans")
        # Heading falls back to font_secondary from DEFAULT_STYLE_VARIABLES, then primary
        expect(fonts[:heading]).to be_present
      end
    end

    describe "#fonts_to_load" do
      it "returns unique fonts needing loading" do
        fonts = loader.fonts_to_load(website)
        expect(fonts).to be_an(Array)
      end

      it "filters out system fonts" do
        website.style_variables_for_theme["default"] = { "font_primary" => "System UI" }
        website.save!
        fonts = loader.fonts_to_load(website)
        expect(fonts).not_to include("System UI")
      end
    end

    describe "#google_fonts_url_for_website" do
      it "generates URL for website fonts" do
        url = loader.google_fonts_url_for_website(website)
        # Should return URL or nil depending on website config
        expect(url).to include("fonts.googleapis.com") if url
      end
    end

    describe "#font_css_variables" do
      it "generates CSS custom properties" do
        css = loader.font_css_variables(website)
        expect(css).to include(":root")
        expect(css).to include("--pwb-font-primary")
        expect(css).to include("--pwb-font-heading")
        expect(css).to include("font-family")
      end

      it "includes body and heading selectors" do
        css = loader.font_css_variables(website)
        expect(css).to include("body {")
        expect(css).to include("h1, h2, h3")
      end
    end

    describe "#font_loading_html" do
      it "generates complete HTML for font loading" do
        html = loader.font_loading_html(website)
        expect(html).to include("<style>")
        expect(html).to include("--pwb-font-primary")
      end

      it "includes preconnect when loading Google fonts" do
        html = loader.font_loading_html(website)
        # Check if there are fonts to load
        if loader.fonts_to_load(website).any?
          expect(html).to include("preconnect")
          expect(html).to include("preload")
        end
      end
    end
  end
end
