# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PagePartLibrary do
  describe "CATEGORIES" do
    it "defines expected categories" do
      expect(described_class::CATEGORIES.keys).to include(
        :heroes, :features, :testimonials, :cta, :stats,
        :teams, :galleries, :pricing, :faqs, :content, :contact
      )
    end

    it "has required fields for each category" do
      described_class::CATEGORIES.each do |key, category|
        expect(category).to have_key(:label), "Category #{key} missing :label"
        expect(category).to have_key(:description), "Category #{key} missing :description"
        expect(category).to have_key(:icon), "Category #{key} missing :icon"
      end
    end
  end

  describe "DEFINITIONS" do
    it "includes hero page parts" do
      expect(described_class::DEFINITIONS.keys).to include(
        "heroes/hero_centered",
        "heroes/hero_split",
        "heroes/hero_search"
      )
    end

    it "includes feature page parts" do
      expect(described_class::DEFINITIONS.keys).to include(
        "features/feature_grid_3col",
        "features/feature_cards_icons"
      )
    end

    it "includes testimonial page parts" do
      expect(described_class::DEFINITIONS.keys).to include(
        "testimonials/testimonial_carousel",
        "testimonials/testimonial_grid"
      )
    end

    it "includes CTA page parts" do
      expect(described_class::DEFINITIONS.keys).to include(
        "cta/cta_banner",
        "cta/cta_split_image"
      )
    end

    it "has required fields for each definition" do
      described_class::DEFINITIONS.each do |key, definition|
        expect(definition).to have_key(:category), "Definition #{key} missing :category"
        expect(definition).to have_key(:label), "Definition #{key} missing :label"
        expect(definition).to have_key(:description), "Definition #{key} missing :description"
        expect(definition).to have_key(:fields), "Definition #{key} missing :fields"
      end
    end

    it "references valid categories" do
      valid_categories = described_class::CATEGORIES.keys

      described_class::DEFINITIONS.each do |key, definition|
        expect(valid_categories).to include(definition[:category]),
          "Definition #{key} references invalid category: #{definition[:category]}"
      end
    end
  end

  describe ".all_keys" do
    it "returns all page part keys" do
      keys = described_class.all_keys

      expect(keys).to be_an(Array)
      expect(keys).to include("heroes/hero_centered")
      expect(keys).to include("features/feature_grid_3col")
    end

    it "returns keys from DEFINITIONS" do
      expect(described_class.all_keys).to eq(described_class::DEFINITIONS.keys)
    end
  end

  describe ".by_category" do
    it "groups page parts by category" do
      grouped = described_class.by_category

      expect(grouped).to be_a(Hash)
      expect(grouped.keys).to all(be_a(Symbol))
    end

    it "includes all definitions in grouped result" do
      grouped = described_class.by_category
      total_parts = grouped.values.sum { |parts| parts.size }

      expect(total_parts).to eq(described_class::DEFINITIONS.size)
    end
  end

  describe ".for_category" do
    it "returns page parts for a specific category" do
      heroes = described_class.for_category(:heroes)

      expect(heroes).to be_a(Hash)
      expect(heroes.keys).to all(start_with("heroes/"))
    end

    it "returns empty hash for unknown category" do
      result = described_class.for_category(:nonexistent)

      expect(result).to eq({})
    end

    it "works with string category" do
      heroes = described_class.for_category("heroes")

      expect(heroes).not_to be_empty
    end
  end

  describe ".definition" do
    it "returns definition for existing key" do
      definition = described_class.definition("heroes/hero_centered")

      expect(definition).to be_a(Hash)
      expect(definition[:category]).to eq(:heroes)
      expect(definition[:label]).to eq("Centered Hero")
    end

    it "returns nil for unknown key" do
      expect(described_class.definition("nonexistent")).to be_nil
    end

    it "works with symbol key" do
      definition = described_class.definition(:"heroes/hero_centered")

      expect(definition).not_to be_nil
    end
  end

  describe ".exists?" do
    it "returns true for defined page parts" do
      expect(described_class.exists?("heroes/hero_centered")).to be true
    end

    it "returns false for undefined page parts" do
      expect(described_class.exists?("nonexistent/part")).to be false
    end

    it "returns true if template file exists" do
      allow(described_class).to receive(:template_exists?).with("custom/part").and_return(true)

      expect(described_class.exists?("custom/part")).to be true
    end
  end

  describe ".template_exists?" do
    it "returns true when template file exists" do
      allow(described_class).to receive(:template_path).and_return(Pathname.new("/path/to/template.liquid"))

      expect(described_class.template_exists?("heroes/hero_centered")).to be true
    end

    it "returns false when template file does not exist" do
      allow(described_class).to receive(:template_path).and_return(nil)

      expect(described_class.template_exists?("nonexistent")).to be false
    end
  end

  describe ".template_path" do
    it "returns path for categorized page parts" do
      path = described_class.template_path("heroes/hero_centered")

      if path
        expect(path.to_s).to include("heroes/hero_centered.liquid")
      end
    end

    it "returns nil for nonexistent template" do
      path = described_class.template_path("nonexistent/template")

      expect(path).to be_nil
    end
  end

  describe ".categories" do
    it "returns all categories" do
      expect(described_class.categories).to eq(described_class::CATEGORIES)
    end
  end

  describe ".category_info" do
    it "returns info for existing category" do
      info = described_class.category_info(:heroes)

      expect(info[:label]).to eq("Hero Sections")
      expect(info[:description]).to be_present
      expect(info[:icon]).to eq("hero")
    end

    it "returns nil for unknown category" do
      expect(described_class.category_info(:nonexistent)).to be_nil
    end

    it "works with string category" do
      info = described_class.category_info("heroes")

      expect(info).not_to be_nil
    end
  end

  describe ".modern_parts" do
    it "excludes legacy page parts" do
      modern = described_class.modern_parts

      modern.each do |_key, config|
        expect(config[:legacy]).to be_falsey
      end
    end

    it "includes non-legacy page parts" do
      modern = described_class.modern_parts

      expect(modern.keys).to include("heroes/hero_centered")
    end
  end

  describe ".legacy_parts" do
    it "includes only legacy page parts" do
      legacy = described_class.legacy_parts

      legacy.each do |_key, config|
        expect(config[:legacy]).to be true
      end
    end

    it "includes known legacy parts" do
      legacy = described_class.legacy_parts

      expect(legacy.keys).to include("our_agency")
      expect(legacy.keys).to include("content_html")
    end
  end

  describe ".to_json_schema" do
    it "returns structured schema" do
      schema = described_class.to_json_schema

      expect(schema).to have_key(:categories)
      expect(schema[:categories]).to be_an(Array)
    end

    it "includes category metadata" do
      schema = described_class.to_json_schema
      heroes_category = schema[:categories].find { |c| c[:key] == :heroes }

      expect(heroes_category).not_to be_nil
      expect(heroes_category[:label]).to eq("Hero Sections")
      expect(heroes_category[:description]).to be_present
      expect(heroes_category[:icon]).to eq("hero")
    end

    it "includes parts within categories" do
      schema = described_class.to_json_schema
      heroes_category = schema[:categories].find { |c| c[:key] == :heroes }

      expect(heroes_category[:parts]).to be_an(Array)
      expect(heroes_category[:parts].first).to have_key(:key)
      expect(heroes_category[:parts].first).to have_key(:label)
      expect(heroes_category[:parts].first).to have_key(:fields)
    end

    it "marks legacy parts correctly" do
      schema = described_class.to_json_schema
      content_category = schema[:categories].find { |c| c[:key] == :content }
      legacy_part = content_category[:parts].find { |p| p[:key] == "our_agency" }

      expect(legacy_part[:legacy]).to be true
    end
  end
end
