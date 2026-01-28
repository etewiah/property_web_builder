# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PagePartLibrary do
  describe "CATEGORIES" do
    it "defines expected categories" do
      expect(described_class::CATEGORIES.keys).to include(
        :heroes, :features, :testimonials, :cta, :stats,
        :teams, :galleries, :pricing, :faqs, :content, :contact, :layout
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
      total_parts = grouped.values.sum(&:size)

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
      definition = described_class.definition(:'heroes/hero_centered')

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

      expect(path.to_s).to include("heroes/hero_centered.liquid") if path
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

      modern.each_value do |config|
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

      legacy.each_value do |config|
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

  describe "field definitions format" do
    context "modern hash-based fields" do
      let(:hero_centered) { described_class.definition("heroes/hero_centered") }
      let(:cta_banner) { described_class.definition("cta/cta_banner") }
      let(:faq_accordion) { described_class.definition("faqs/faq_accordion") }
      let(:content_html) { described_class.definition("content_html") }

      it "heroes/hero_centered uses hash-based field definitions" do
        expect(hero_centered[:fields]).to be_a(Hash)
      end

      it "heroes/hero_centered has explicit field types" do
        expect(hero_centered[:fields][:title][:type]).to eq(:text)
        expect(hero_centered[:fields][:subtitle][:type]).to eq(:textarea)
        expect(hero_centered[:fields][:background_image][:type]).to eq(:image)
        expect(hero_centered[:fields][:cta_link][:type]).to eq(:url)
      end

      it "heroes/hero_centered has field metadata" do
        title_field = hero_centered[:fields][:title]

        expect(title_field[:label]).to eq("Main Title")
        expect(title_field[:hint]).to be_present
        expect(title_field[:required]).to be true
        expect(title_field[:max_length]).to eq(80)
        expect(title_field[:group]).to eq(:titles)
      end

      it "heroes/hero_centered has content guidance" do
        title_field = hero_centered[:fields][:title]

        expect(title_field[:content_guidance]).to be_present
        expect(title_field[:content_guidance][:recommended_length]).to be_present
        expect(title_field[:content_guidance][:seo_tip]).to be_present
      end

      it "heroes/hero_centered has field groups" do
        expect(hero_centered[:field_groups]).to be_a(Hash)
        expect(hero_centered[:field_groups][:titles]).to be_present
        expect(hero_centered[:field_groups][:cta]).to be_present
        expect(hero_centered[:field_groups][:media]).to be_present
      end

      it "heroes/hero_centered field groups have order" do
        expect(hero_centered[:field_groups][:titles][:order]).to eq(1)
        expect(hero_centered[:field_groups][:cta][:order]).to eq(2)
        expect(hero_centered[:field_groups][:media][:order]).to eq(3)
      end

      it "heroes/hero_centered has paired fields" do
        expect(hero_centered[:fields][:cta_text][:paired_with]).to eq(:cta_link)
        expect(hero_centered[:fields][:cta_link][:paired_with]).to eq(:cta_text)
      end

      it "cta/cta_banner has select fields with choices" do
        button_style = cta_banner[:fields][:button_style]

        expect(button_style[:type]).to eq(:select)
        expect(button_style[:choices]).to be_an(Array)
        expect(button_style[:choices].first).to have_key(:value)
        expect(button_style[:choices].first).to have_key(:label)
        expect(button_style[:default]).to eq("primary")
      end

      it "faqs/faq_accordion has faq_array with item_schema" do
        faq_items = faq_accordion[:fields][:faq_items]

        expect(faq_items[:type]).to eq(:faq_array)
        expect(faq_items[:item_schema]).to be_a(Hash)
        expect(faq_items[:item_schema][:question]).to be_present
        expect(faq_items[:item_schema][:answer]).to be_present
        expect(faq_items[:min_items]).to eq(1)
        expect(faq_items[:max_items]).to eq(20)
      end

      it "faqs/faq_accordion item_schema has nested field definitions" do
        question_schema = faq_accordion[:fields][:faq_items][:item_schema][:question]

        expect(question_schema[:type]).to eq(:text)
        expect(question_schema[:label]).to eq("Question")
        expect(question_schema[:required]).to be true
      end

      it "content_html has html type field" do
        content_field = content_html[:fields][:content_html]

        expect(content_field[:type]).to eq(:html)
        expect(content_field[:required]).to be true
        expect(content_field[:content_guidance]).to be_present
      end
    end

    context "legacy array-based fields" do
      let(:hero_split) { described_class.definition("heroes/hero_split") }
      let(:our_agency) { described_class.definition("our_agency") }

      it "heroes/hero_split uses array-based field definitions" do
        expect(hero_split[:fields]).to be_an(Array)
      end

      it "heroes/hero_split has expected fields" do
        expect(hero_split[:fields]).to include(
          "title", "subtitle", "image", "cta_link"
        )
      end

      it "our_agency uses array-based field definitions" do
        expect(our_agency[:fields]).to be_an(Array)
      end
    end

    context "mixed format support" do
      it "supports both hash and array field formats" do
        # Hash-based (modern)
        hero_centered = described_class.definition("heroes/hero_centered")
        expect(hero_centered[:fields]).to be_a(Hash)

        # Array-based (legacy)
        hero_split = described_class.definition("heroes/hero_split")
        expect(hero_split[:fields]).to be_an(Array)
      end

      it "all definitions have fields key" do
        described_class::DEFINITIONS.each do |key, definition|
          expect(definition).to have_key(:fields),
            "Definition #{key} missing :fields"
        end
      end

      it "fields are either Hash or Array" do
        described_class::DEFINITIONS.each do |key, definition|
          fields = definition[:fields]
          expect(fields.is_a?(Hash) || fields.is_a?(Array)).to be(true),
            "Definition #{key} :fields should be Hash or Array, got #{fields.class}"
        end
      end
    end
  end

  describe "container page parts" do
    describe "DEFINITIONS for containers" do
      it "includes layout container page parts" do
        expect(described_class::DEFINITIONS.keys).to include(
          "layout_two_column_equal",
          "layout_two_column_wide_narrow",
          "layout_sidebar_left",
          "layout_sidebar_right",
          "layout_three_column_equal"
        )
      end

      it "container definitions have is_container flag" do
        container_keys = %w[
          layout_two_column_equal
          layout_two_column_wide_narrow
          layout_sidebar_left
          layout_sidebar_right
          layout_three_column_equal
        ]

        container_keys.each do |key|
          definition = described_class.definition(key)
          expect(definition[:is_container]).to be(true),
            "Container #{key} missing is_container: true"
        end
      end

      it "container definitions have slots" do
        container_keys = %w[
          layout_two_column_equal
          layout_two_column_wide_narrow
          layout_sidebar_left
          layout_sidebar_right
          layout_three_column_equal
        ]

        container_keys.each do |key|
          definition = described_class.definition(key)
          expect(definition[:slots]).to be_a(Hash),
            "Container #{key} missing :slots"
          expect(definition[:slots]).not_to be_empty,
            "Container #{key} has empty :slots"
        end
      end

      it "two column containers have left and right slots" do
        %w[layout_two_column_equal layout_two_column_wide_narrow].each do |key|
          definition = described_class.definition(key)
          expect(definition[:slots].keys).to contain_exactly(:left, :right),
            "Container #{key} should have left and right slots"
        end
      end

      it "sidebar containers have main and sidebar slots" do
        %w[layout_sidebar_left layout_sidebar_right].each do |key|
          definition = described_class.definition(key)
          expect(definition[:slots].keys).to contain_exactly(:main, :sidebar),
            "Container #{key} should have main and sidebar slots"
        end
      end

      it "three column container has left, center, and right slots" do
        definition = described_class.definition("layout_three_column_equal")
        expect(definition[:slots].keys).to contain_exactly(:left, :center, :right)
      end

      it "slots have required metadata" do
        described_class.container_parts.each do |key, definition|
          definition[:slots].each do |slot_name, slot_config|
            expect(slot_config).to have_key(:label),
              "Container #{key} slot #{slot_name} missing :label"
            expect(slot_config).to have_key(:description),
              "Container #{key} slot #{slot_name} missing :description"
          end
        end
      end
    end

    describe ".container_parts" do
      it "returns only container page parts" do
        containers = described_class.container_parts

        expect(containers).to be_a(Hash)
        containers.each_value do |config|
          expect(config[:is_container]).to be(true)
        end
      end

      it "includes all layout containers" do
        containers = described_class.container_parts

        expect(containers.keys).to include(
          "layout_two_column_equal",
          "layout_sidebar_left"
        )
      end

      it "does not include non-container page parts" do
        containers = described_class.container_parts

        expect(containers.keys).not_to include("heroes/hero_centered")
        expect(containers.keys).not_to include("cta/cta_banner")
      end
    end

    describe ".container?" do
      it "returns true for container page parts" do
        expect(described_class.container?("layout_two_column_equal")).to be true
        expect(described_class.container?("layout_sidebar_right")).to be true
      end

      it "returns false for non-container page parts" do
        expect(described_class.container?("heroes/hero_centered")).to be false
        expect(described_class.container?("cta/cta_banner")).to be false
        expect(described_class.container?("our_agency")).to be false
      end

      it "returns false for unknown page parts" do
        expect(described_class.container?("nonexistent")).to be false
      end
    end

    describe ".slots_for" do
      it "returns slots for container page parts" do
        slots = described_class.slots_for("layout_two_column_equal")

        expect(slots).to be_a(Hash)
        expect(slots.keys).to contain_exactly(:left, :right)
      end

      it "returns nil for non-container page parts" do
        expect(described_class.slots_for("heroes/hero_centered")).to be_nil
      end

      it "returns nil for unknown page parts" do
        expect(described_class.slots_for("nonexistent")).to be_nil
      end
    end

    describe ".slot_names" do
      it "returns slot names as strings for container page parts" do
        names = described_class.slot_names("layout_three_column_equal")

        expect(names).to contain_exactly("left", "center", "right")
      end

      it "returns empty array for non-container page parts" do
        expect(described_class.slot_names("heroes/hero_centered")).to eq([])
      end

      it "returns empty array for unknown page parts" do
        expect(described_class.slot_names("nonexistent")).to eq([])
      end
    end

    describe ".to_json_schema with containers" do
      it "includes is_container flag in schema" do
        schema = described_class.to_json_schema
        layout_category = schema[:categories].find { |c| c[:key] == :layout }

        expect(layout_category).not_to be_nil

        layout_category[:parts].each do |part|
          expect(part[:is_container]).to be(true)
        end
      end

      it "includes slots in schema for container page parts" do
        schema = described_class.to_json_schema
        layout_category = schema[:categories].find { |c| c[:key] == :layout }
        two_col = layout_category[:parts].find { |p| p[:key] == "layout_two_column_equal" }

        expect(two_col[:slots]).to be_present
        expect(two_col[:slots].keys).to contain_exactly(:left, :right)
      end
    end
  end

  describe "contact form page parts" do
    it "includes modern contact form definitions" do
      expect(described_class::DEFINITIONS.keys).to include(
        "contact_general_enquiry",
        "contact_location_map"
      )
    end

    it "contact forms use URL-safe naming (no slashes)" do
      contact_keys = described_class.for_category(:contact).keys

      contact_keys.each do |key|
        next if key == "form_and_map" # Legacy key

        expect(key).not_to include("/"),
          "Contact form key '#{key}' should not contain slashes for URL safety"
      end
    end

    it "contact_general_enquiry has expected fields" do
      definition = described_class.definition("contact_general_enquiry")

      expect(definition[:fields]).to be_a(Hash)
      expect(definition[:fields].keys).to include(
        :section_title, :section_subtitle, :show_phone_field,
        :show_subject_field, :submit_button_text, :success_message
      )
    end

    it "contact_location_map has map configuration fields" do
      definition = described_class.definition("contact_location_map")

      expect(definition[:fields].keys).to include(
        :map_latitude, :map_longitude, :map_zoom, :marker_title
      )
    end
  end
end
