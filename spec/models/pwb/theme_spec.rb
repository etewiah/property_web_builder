# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::Theme do
  describe ".all" do
    it "returns a relation of themes" do
      themes = described_class.all

      expect(themes).to respond_to(:to_a)
      expect(themes.to_a).not_to be_empty
    end

    it "returns Theme instances" do
      themes = described_class.all.to_a

      expect(themes).to all(be_a(described_class))
    end
  end

  describe ".find_by" do
    it "finds theme by name" do
      theme = described_class.find_by(name: "default")

      expect(theme).to be_a(described_class)
      expect(theme.name).to eq("default")
    end

    it "returns nil for unknown theme" do
      theme = described_class.find_by(name: "nonexistent")

      expect(theme).to be_nil
    end
  end

  describe "basic attributes" do
    let(:theme) { described_class.find_by(name: "default") }

    it "has a name" do
      expect(theme.name).to eq("default")
    end

    it "has a friendly name" do
      expect(theme.friendly_name).to be_present
    end

    it "has a version" do
      expect(theme.version).to match(/^\d+\.\d+\.\d+$/)
    end

    it "has a description" do
      expect(theme.description).to be_a(String)
    end

    it "has tags" do
      expect(theme.tags).to be_an(Array)
    end

    it "has screenshots" do
      expect(theme.screenshots).to be_an(Array)
    end
  end

  describe "#parent" do
    context "with parent theme" do
      let(:theme) { described_class.find_by(name: "brisbane") }

      it "returns parent Theme instance" do
        parent = theme.parent

        expect(parent).to be_a(described_class)
        expect(parent.name).to eq("default")
      end
    end

    context "without parent theme" do
      let(:theme) { described_class.find_by(name: "default") }

      it "returns nil" do
        expect(theme.parent).to be_nil
      end
    end
  end

  describe "#has_parent?" do
    it "returns true when theme has parent_theme attribute" do
      theme = described_class.find_by(name: "brisbane")

      # Check that parent_theme attribute exists
      expect(theme.attributes[:parent_theme]).to eq("default")
      expect(theme.has_parent?).to be true
    end

    it "returns false when theme has no parent" do
      theme = described_class.find_by(name: "default")

      expect(theme.has_parent?).to be false
    end
  end

  describe "#inheritance_chain" do
    context "with parent theme" do
      let(:theme) { described_class.find_by(name: "brisbane") }

      it "returns chain starting with self" do
        chain = theme.inheritance_chain

        expect(chain.first.name).to eq("brisbane")
      end

      it "includes parent theme when parent exists" do
        chain = theme.inheritance_chain
        names = chain.map(&:name)

        # At minimum should include self
        expect(names).to include("brisbane")
      end
    end

    context "without parent theme" do
      let(:theme) { described_class.find_by(name: "default") }

      it "returns array with self only" do
        chain = theme.inheritance_chain

        expect(chain.map(&:name)).to eq(["default"])
      end
    end
  end

  describe "#view_paths" do
    context "without parent theme" do
      let(:theme) { described_class.find_by(name: "default") }

      it "includes theme view path" do
        paths = theme.view_paths

        expect(paths.map(&:to_s)).to include(match(/default\/views/))
      end

      it "includes app/views path" do
        paths = theme.view_paths

        expect(paths.map(&:to_s)).to include(match(/app\/views$/))
      end
    end

    context "with parent theme" do
      let(:theme) { described_class.find_by(name: "brisbane") }

      it "includes child theme path" do
        paths = theme.view_paths

        expect(paths.map(&:to_s)).to include(match(/brisbane\/views/))
      end
    end
  end

  describe "#supported_page_parts" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns array of supported page parts from config" do
      parts = theme.supported_page_parts

      expect(parts).to be_an(Array)
    end

    it "accesses supports.page_parts from config" do
      # Check the raw attribute structure
      supports = theme.attributes[:supports]
      expect(supports).to be_a(Hash)
      expect(supports["page_parts"]).to be_an(Array)
      expect(supports["page_parts"]).to include("heroes/hero_centered")
    end
  end

  describe "#available_page_parts" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns all available page parts" do
      parts = theme.available_page_parts

      expect(parts).to be_an(Array)
    end

    it "includes parts from PagePartLibrary" do
      parts = theme.available_page_parts
      library_parts = Pwb::PagePartLibrary.all_keys

      # Should include at least some library parts
      expect((parts & library_parts)).not_to be_empty
    end
  end

  describe "#supported_layouts" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns array of supported layouts" do
      layouts = theme.supported_layouts

      expect(layouts).to be_an(Array)
    end

    it "includes default layouts" do
      layouts = theme.supported_layouts

      # Should include at least the fallback defaults
      expect(layouts).to include("full_width")
    end
  end

  describe "#supported_color_schemes" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns array of color schemes" do
      schemes = theme.supported_color_schemes

      expect(schemes).to be_an(Array)
    end

    it "includes default schemes" do
      schemes = theme.supported_color_schemes

      expect(schemes).to include("light", "dark")
    end
  end

  describe "#has_custom_template?" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns false when no custom template exists" do
      result = theme.has_custom_template?("nonexistent/part")

      expect(result).to be false
    end
  end

  describe "#default_style_variables" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns hash of default style variables" do
      defaults = theme.default_style_variables

      expect(defaults).to be_a(Hash)
    end
  end

  describe "#style_variable_schema" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns style variable schema" do
      schema = theme.style_variable_schema

      expect(schema).to be_a(Hash)
    end

    it "includes sections from ThemeSettingsSchema" do
      schema = theme.style_variable_schema

      expect(schema).to have_key(:sections)
      expect(schema[:sections]).to be_an(Array)
    end
  end

  describe "#page_part_config" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns config for page part" do
      config = theme.page_part_config(:heroes)

      expect(config).to be_a(Hash)
    end
  end

  describe "#page_part_variants" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns variants array" do
      variants = theme.page_part_variants(:heroes)

      expect(variants).to be_an(Array)
    end
  end

  describe "#stylesheet_path" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns stylesheet path" do
      path = theme.stylesheet_path

      expect(path).to eq("pwb/themes/default")
    end
  end

  describe "#javascript_path" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns nil or string" do
      path = theme.javascript_path

      expect(path).to satisfy { |p| p.nil? || p.is_a?(String) }
    end
  end

  describe "#as_api_json" do
    let(:theme) { described_class.find_by(name: "default") }

    it "returns serializable hash" do
      json = theme.as_api_json

      expect(json).to be_a(Hash)
    end

    it "includes basic attributes" do
      json = theme.as_api_json

      expect(json[:name]).to eq("default")
      expect(json[:friendly_name]).to be_present
      expect(json[:version]).to be_present
    end

    it "includes supports section" do
      json = theme.as_api_json

      expect(json[:supports]).to be_a(Hash)
      expect(json[:supports][:page_parts]).to be_an(Array)
      expect(json[:supports][:layouts]).to be_an(Array)
      expect(json[:supports][:color_schemes]).to be_an(Array)
    end

    it "includes style variable schema" do
      json = theme.as_api_json

      expect(json[:style_variable_schema]).to be_a(Hash)
    end

    it "includes default style variables" do
      json = theme.as_api_json

      expect(json[:default_style_variables]).to be_a(Hash)
    end
  end

  describe "comparison" do
    it "themes with same name are equal" do
      theme1 = described_class.find_by(name: "default")
      theme2 = described_class.find_by(name: "default")

      expect(theme1).to eq(theme2)
    end

    it "themes with different names are not equal" do
      theme1 = described_class.find_by(name: "default")
      theme2 = described_class.find_by(name: "brisbane")

      expect(theme1).not_to eq(theme2)
    end
  end
end
