# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ThemeSettingsSchema do
  describe "SCHEMA" do
    it "defines expected sections" do
      expect(described_class::SCHEMA.keys).to include(
        :colors, :typography, :layout, :header, :footer, :buttons, :appearance
      )
    end

    it "has required metadata for each section" do
      described_class::SCHEMA.each do |key, section|
        expect(section).to have_key(:label), "Section #{key} missing :label"
        expect(section).to have_key(:fields), "Section #{key} missing :fields"
      end
    end

    it "has icon for each section" do
      described_class::SCHEMA.each do |key, section|
        expect(section).to have_key(:icon), "Section #{key} missing :icon"
      end
    end
  end

  describe "colors section" do
    let(:colors) { described_class::SCHEMA[:colors] }
    let(:fields) { colors[:fields] }

    it "includes primary color field" do
      expect(fields).to have_key(:primary_color)
      expect(fields[:primary_color][:type]).to eq(:color)
      expect(fields[:primary_color][:default]).to be_present
    end

    it "includes secondary color field" do
      expect(fields).to have_key(:secondary_color)
      expect(fields[:secondary_color][:type]).to eq(:color)
    end

    it "includes accent color field" do
      expect(fields).to have_key(:accent_color)
      expect(fields[:accent_color][:type]).to eq(:color)
    end

    it "includes text color fields" do
      expect(fields).to have_key(:text_primary)
      expect(fields).to have_key(:text_secondary)
    end

    it "has valid hex color defaults" do
      color_fields = fields.select { |_, v| v[:type] == :color }

      color_fields.each do |key, field|
        expect(field[:default]).to match(/^#[0-9A-Fa-f]{6}$/),
          "#{key} has invalid color default: #{field[:default]}"
      end
    end
  end

  describe "typography section" do
    let(:typography) { described_class::SCHEMA[:typography] }
    let(:fields) { typography[:fields] }

    it "includes font_primary field" do
      expect(fields).to have_key(:font_primary)
      expect(fields[:font_primary][:type]).to eq(:font_select)
    end

    it "includes font_secondary field" do
      expect(fields).to have_key(:font_secondary)
      expect(fields[:font_secondary][:type]).to eq(:font_select)
    end

    it "provides font options as hashes with value and label" do
      expect(fields[:font_primary][:options]).to be_an(Array)
      expect(fields[:font_primary][:options].first).to have_key(:value)
      expect(fields[:font_primary][:options].first).to have_key(:label)
    end

    it "includes font size field as range type" do
      expect(fields).to have_key(:font_size_base)
      expect(fields[:font_size_base][:type]).to eq(:range)
    end

    it "has min/max/step for range fields" do
      range_field = fields[:font_size_base]
      expect(range_field[:min]).to be_present
      expect(range_field[:max]).to be_present
      expect(range_field[:step]).to be_present
    end
  end

  describe "layout section" do
    let(:layout) { described_class::SCHEMA[:layout] }
    let(:fields) { layout[:fields] }

    it "includes container max width field" do
      expect(fields).to have_key(:container_max_width)
      expect(fields[:container_max_width][:type]).to eq(:select)
    end

    it "includes container padding field" do
      expect(fields).to have_key(:container_padding)
      expect(fields[:container_padding][:type]).to eq(:range)
    end
  end

  describe "header section" do
    let(:header) { described_class::SCHEMA[:header] }
    let(:fields) { header[:fields] }

    it "includes header style field" do
      expect(fields).to have_key(:header_style)
      expect(fields[:header_style][:type]).to eq(:select)
    end

    it "includes header background color" do
      expect(fields).to have_key(:header_bg_color)
      expect(fields[:header_bg_color][:type]).to eq(:color)
    end

    it "includes header text color" do
      expect(fields).to have_key(:header_text_color)
      expect(fields[:header_text_color][:type]).to eq(:color)
    end
  end

  describe "footer section" do
    let(:footer) { described_class::SCHEMA[:footer] }
    let(:fields) { footer[:fields] }

    it "includes footer background color" do
      expect(fields).to have_key(:footer_bg_color)
      expect(fields[:footer_bg_color][:type]).to eq(:color)
    end

    it "includes footer text color" do
      expect(fields).to have_key(:footer_main_text_color)
      expect(fields[:footer_main_text_color][:type]).to eq(:color)
    end

    it "includes footer link color" do
      expect(fields).to have_key(:footer_link_color)
      expect(fields[:footer_link_color][:type]).to eq(:color)
    end
  end

  describe "buttons section" do
    let(:buttons) { described_class::SCHEMA[:buttons] }
    let(:fields) { buttons[:fields] }

    it "includes button style field" do
      expect(fields).to have_key(:button_style)
      expect(fields[:button_style][:type]).to eq(:select)
    end

    it "includes button radius field" do
      expect(fields).to have_key(:button_radius)
      expect(fields[:button_radius][:type]).to eq(:select)
    end
  end

  describe "appearance section" do
    let(:appearance) { described_class::SCHEMA[:appearance] }
    let(:fields) { appearance[:fields] }

    it "includes border radius field" do
      expect(fields).to have_key(:border_radius)
      expect(fields[:border_radius][:type]).to eq(:range)
    end

    it "includes shadow intensity field" do
      expect(fields).to have_key(:shadow_intensity)
      expect(fields[:shadow_intensity][:type]).to eq(:select)
    end

    it "includes color scheme field" do
      expect(fields).to have_key(:color_scheme)
      expect(fields[:color_scheme][:type]).to eq(:select)
    end
  end

  describe "field type validation" do
    let(:valid_types) { %i[color font_select select range size toggle text textarea] }

    it "uses only valid field types" do
      described_class::SCHEMA.each do |section_key, section|
        section[:fields].each do |field_key, field|
          expect(valid_types).to include(field[:type]),
            "#{section_key}.#{field_key} has invalid type: #{field[:type]}"
        end
      end
    end
  end

  describe "select fields" do
    it "all select fields have options" do
      described_class::SCHEMA.each do |section_key, section|
        section[:fields].each do |field_key, field|
          next unless %i[select font_select].include?(field[:type])

          expect(field[:options]).to be_present,
            "#{section_key}.#{field_key} is a select but has no options"
          expect(field[:options]).to be_an(Array)
        end
      end
    end

    it "select options have value and label" do
      described_class::SCHEMA.each do |section_key, section|
        section[:fields].each do |field_key, field|
          next unless %i[select font_select].include?(field[:type])

          field[:options].each do |option|
            expect(option).to have_key(:value),
              "#{section_key}.#{field_key} option missing :value"
            expect(option).to have_key(:label),
              "#{section_key}.#{field_key} option missing :label"
          end
        end
      end
    end
  end

  describe "defaults" do
    it "all fields have defaults" do
      described_class::SCHEMA.each do |section_key, section|
        section[:fields].each do |field_key, field|
          expect(field).to have_key(:default),
            "#{section_key}.#{field_key} has no default value"
        end
      end
    end
  end

  describe "labels" do
    it "all fields have labels" do
      described_class::SCHEMA.each do |section_key, section|
        section[:fields].each do |field_key, field|
          expect(field).to have_key(:label),
            "#{section_key}.#{field_key} has no label"
          expect(field[:label]).to be_present
        end
      end
    end
  end

  describe ".sections" do
    it "returns all section keys" do
      expect(described_class.sections).to eq(described_class::SCHEMA.keys)
    end
  end

  describe ".section" do
    it "returns section by name" do
      section = described_class.section(:colors)
      expect(section[:label]).to eq("Colors")
    end

    it "returns nil for unknown section" do
      expect(described_class.section(:unknown)).to be_nil
    end
  end

  describe ".field" do
    it "returns field by section and name" do
      field = described_class.field(:colors, :primary_color)
      expect(field[:type]).to eq(:color)
    end

    it "returns nil for unknown field" do
      expect(described_class.field(:colors, :unknown)).to be_nil
    end
  end

  describe ".all_fields" do
    it "returns flattened list of all fields" do
      fields = described_class.all_fields

      expect(fields).to be_an(Array)
      expect(fields.first).to have_key(:name)
      expect(fields.first).to have_key(:section)
    end
  end

  describe ".defaults" do
    it "returns hash of default values" do
      defaults = described_class.defaults

      expect(defaults).to be_a(Hash)
      expect(defaults["primary_color"]).to eq("#e91b23")
    end
  end

  describe ".to_json_schema" do
    it "returns structured JSON schema" do
      schema = described_class.to_json_schema

      expect(schema).to have_key(:sections)
      expect(schema[:sections]).to be_an(Array)
    end

    it "includes section metadata" do
      schema = described_class.to_json_schema
      colors_section = schema[:sections].find { |s| s[:name] == :colors }

      expect(colors_section[:label]).to eq("Colors")
      expect(colors_section[:icon]).to eq("palette")
    end

    it "includes fields within sections" do
      schema = described_class.to_json_schema
      colors_section = schema[:sections].find { |s| s[:name] == :colors }

      expect(colors_section[:fields]).to be_an(Array)
      expect(colors_section[:fields].first).to have_key(:name)
    end
  end

  describe ".validate" do
    it "returns empty array for valid values" do
      errors = described_class.validate({
        "primary_color" => "#ff0000",
        "secondary_color" => "#00ff00"
      })

      expect(errors).to be_empty
    end

    it "returns error for invalid color format" do
      errors = described_class.validate({ "primary_color" => "red" })

      expect(errors).to include(match(/primary_color.*Invalid color format/))
    end

    it "returns error for range value below minimum" do
      errors = described_class.validate({ "font_size_base" => "10px" })

      expect(errors).to include(match(/font_size_base.*below minimum/))
    end

    it "returns error for range value above maximum" do
      errors = described_class.validate({ "font_size_base" => "30px" })

      expect(errors).to include(match(/font_size_base.*above maximum/))
    end

    it "returns error for invalid select option" do
      errors = described_class.validate({ "button_style" => "invalid" })

      expect(errors).to include(match(/button_style.*Invalid option/))
    end
  end
end
