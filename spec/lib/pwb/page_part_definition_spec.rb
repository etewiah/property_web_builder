# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::PagePartDefinition do
  before do
    # Create a test template
    template_dir = Rails.root.join("app/views/pwb/page_parts")
    FileUtils.mkdir_p(template_dir)
    File.write(template_dir.join("test_part.liquid"), "<h1>{{ title }}</h1><p>{{ description }}</p>")
  end

  after do
    Pwb::PagePartRegistry.clear!
    FileUtils.rm_f(Rails.root.join("app/views/pwb/page_parts/test_part.liquid"))
  end

  describe ".define" do
    it "creates a definition with fields" do
      definition = Pwb::PagePartDefinition.define :test_part do
        field :title, type: :single_line_text
        field :description, type: :html
      end

      expect(definition.key).to eq(:test_part)
      expect(definition.fields.length).to eq(2)
      expect(definition.fields[0][:name]).to eq(:title)
      expect(definition.fields[0][:type]).to eq(:single_line_text)
    end

    it "registers definition in the registry" do
      Pwb::PagePartDefinition.define :test_part do
        field :title, type: :single_line_text
      end

      expect(Pwb::PagePartRegistry.find(:test_part)).not_to be_nil
    end

    it "auto-generates labels from field names" do
      definition = Pwb::PagePartDefinition.define :test_part do
        field :landing_title, type: :single_line_text
      end

      expect(definition.fields[0][:label]).to eq("Landing title")
    end

    it "accepts custom labels" do
      definition = Pwb::PagePartDefinition.define :test_part do
        field :landing_title, type: :single_line_text, label: "Hero Title"
      end

      expect(definition.fields[0][:label]).to eq("Hero Title")
    end
  end

  describe "#validate_template!" do
    it "does not warn when fields exist in template" do
      expect(Rails.logger).not_to receive(:warn)

      Pwb::PagePartDefinition.define :test_part do
        field :title, type: :single_line_text
        field :description, type: :html
      end
    end

    it "warns about missing fields" do
      expect(Rails.logger).to receive(:warn).with(/Field 'missing_field' not found/)

      Pwb::PagePartDefinition.define :test_part do
        field :missing_field, type: :single_line_text
      end
    end

    it "skips validation if template file doesn't exist" do
      FileUtils.rm_f(Rails.root.join("app/views/pwb/page_parts/test_part.liquid"))

      expect {
        Pwb::PagePartDefinition.define :test_part do
          field :any_field, type: :single_line_text
        end
      }.not_to raise_error
    end
  end

  describe "#to_editor_config" do
    it "exports definition as editor configuration" do
      definition = Pwb::PagePartDefinition.define :test_part do
        field :title, type: :single_line_text, label: "Title"
        field :content, type: :html, label: "Content"
      end

      config = definition.to_editor_config

      expect(config[:key]).to eq(:test_part)
      expect(config[:fields].length).to eq(2)
      expect(config[:fields][0][:name]).to eq(:title)
      expect(config[:fields][0][:type]).to eq(:single_line_text)
      expect(config[:fields][0][:label]).to eq("Title")
    end
  end
end
