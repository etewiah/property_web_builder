# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PaletteCompiler do
  let(:website) do
    create(:website,
           subdomain: "test-palette",
           theme_name: "default",
           selected_palette: "ocean_blue")
  end

  let(:style_vars) do
    {
      "primary_color" => "#DC2626",
      "secondary_color" => "#1E40AF",
      "accent_color" => "#F59E0B"
    }
  end

  before do
    allow(website).to receive(:style_variables).and_return(style_vars)
  end

  subject { described_class.new(website) }

  describe "#initialize" do
    it "stores website reference" do
      expect(subject.website).to eq(website)
    end

    it "stores style variables" do
      expect(subject.style_vars).to eq(style_vars)
    end
  end

  describe "#compile" do
    let(:css) { subject.compile }

    it "returns a non-empty string" do
      expect(css).to be_a(String)
      expect(css).not_to be_empty
    end

    it "includes header comment with website info" do
      expect(css).to include("Compiled Palette CSS")
      expect(css).to include("test-palette")
      expect(css).to include("ocean_blue")
    end

    it "includes CSS root variables" do
      expect(css).to include(":root {")
      expect(css).to include("--pwb-primary-color: #DC2626")
      expect(css).to include("--pwb-secondary-color: #1E40AF")
      expect(css).to include("--pwb-accent-color: #F59E0B")
    end

    it "includes shade variables for primary color" do
      expect(css).to include("--pwb-primary-50:")
      expect(css).to include("--pwb-primary-100:")
      expect(css).to include("--pwb-primary-500:")
      expect(css).to include("--pwb-primary-900:")
    end

    it "includes semantic utility classes" do
      expect(css).to include(".bg-pwb-primary {")
      expect(css).to include(".text-pwb-primary {")
      expect(css).to include(".border-pwb-primary {")
    end

    it "includes hover variants" do
      expect(css).to include(".hover\\:bg-pwb-primary:hover {")
      expect(css).to include(".hover\\:text-pwb-primary:hover {")
    end

    it "includes focus variants" do
      expect(css).to include(".focus\\:ring-pwb-primary:focus {")
    end

    it "includes button component classes" do
      expect(css).to include(".btn-pwb-primary {")
      expect(css).to include(".btn-pwb-secondary {")
      expect(css).to include(".btn-pwb-outline {")
    end

    it "includes badge classes" do
      expect(css).to include(".badge-pwb-primary {")
      expect(css).to include(".badge-pwb-secondary {")
    end

    it "uses actual hex colors, not CSS variables" do
      # In compiled mode, colors should be baked in
      expect(css).to include("background-color: #DC2626")
      expect(css).not_to include("var(--pwb-primary-color)")
    end
  end

  describe "#compile_css_variables" do
    let(:css_vars) { subject.compile_css_variables }

    it "generates primary color variable" do
      expect(css_vars).to include("--pwb-primary-color: #DC2626")
    end

    it "generates secondary color variable" do
      expect(css_vars).to include("--pwb-secondary-color: #1E40AF")
    end

    it "generates accent color variable" do
      expect(css_vars).to include("--pwb-accent-color: #F59E0B")
    end

    it "generates all shade steps" do
      [50, 100, 200, 300, 400, 500, 600, 700, 800, 900].each do |step|
        expect(css_vars).to include("--pwb-primary-#{step}:")
      end
    end

    it "generates additional palette color variables" do
      expect(css_vars).to include("--pwb-background-color:")
      expect(css_vars).to include("--pwb-text-color:")
      expect(css_vars).to include("--pwb-link-color:")
    end
  end

  describe "#compile_semantic_utilities" do
    let(:utilities) { subject.compile_semantic_utilities }

    it "generates background utilities for all shades" do
      expect(utilities).to include(".bg-pwb-primary-50 {")
      expect(utilities).to include(".bg-pwb-primary-100 {")
      expect(utilities).to include(".bg-pwb-primary-600 {")
      expect(utilities).to include(".bg-pwb-primary-900 {")
    end

    it "generates text utilities" do
      expect(utilities).to include(".text-pwb-primary {")
      expect(utilities).to include(".text-pwb-primary-700 {")
    end

    it "generates border utilities" do
      expect(utilities).to include(".border-pwb-primary {")
      expect(utilities).to include(".border-pwb-secondary {")
    end

    it "generates gradient utilities" do
      expect(utilities).to include(".from-pwb-primary {")
      expect(utilities).to include(".to-pwb-primary {")
    end
  end

  describe "shade generation" do
    it "generates lighter shades for low numbers" do
      css_vars = subject.compile_css_variables

      # Extract shade 50 (should be very light)
      shade_50_match = css_vars.match(/--pwb-primary-50: (#[a-fA-F0-9]{6})/)
      expect(shade_50_match).not_to be_nil

      shade_50 = shade_50_match[1]
      # Lighter colors have higher RGB values - check it's different from primary
      expect(shade_50.downcase).not_to eq("#dc2626")
    end

    it "generates darker shades for high numbers" do
      css_vars = subject.compile_css_variables

      # Extract shade 900 (should be very dark)
      shade_900_match = css_vars.match(/--pwb-primary-900: (#[a-fA-F0-9]{6})/)
      expect(shade_900_match).not_to be_nil

      shade_900 = shade_900_match[1]
      # Darker colors have lower RGB values - check it's different from primary
      expect(shade_900.downcase).not_to eq("#dc2626")
    end
  end

  describe "with default fallback colors" do
    let(:empty_style_vars) { {} }

    before do
      allow(website).to receive(:style_variables).and_return(empty_style_vars)
    end

    it "uses fallback primary color" do
      css = subject.compile
      expect(css).to include("--pwb-primary-color: #3b82f6")
    end

    it "uses fallback secondary color" do
      css = subject.compile
      expect(css).to include("--pwb-secondary-color: #64748b")
    end

    it "uses fallback accent color" do
      css = subject.compile
      expect(css).to include("--pwb-accent-color: #f59e0b")
    end
  end

  describe "CSS validity" do
    it "generates valid CSS with proper syntax" do
      css = subject.compile

      # Check for balanced braces
      open_braces = css.count("{")
      close_braces = css.count("}")
      expect(open_braces).to eq(close_braces)

      # Check for semicolons after property values
      expect(css).to match(/: #[a-fA-F0-9]+;/)
    end

    it "escapes pseudo-class selectors properly" do
      css = subject.compile

      # Hover, focus, active selectors need escaped colons
      expect(css).to include(".hover\\:bg-pwb-primary:hover")
      expect(css).to include(".focus\\:ring-pwb-primary:focus")
    end
  end
end
