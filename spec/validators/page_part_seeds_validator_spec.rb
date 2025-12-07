# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Page Part YAML Seeds Validation" do
  let(:yml_seeds_path) { Rails.root.join("db", "yml_seeds", "page_parts") }
  let(:page_part_files) { Dir.glob(yml_seeds_path.join("*.yml")) }

  describe "seed files existence" do
    it "has page part seed files" do
      expect(page_part_files).not_to be_empty,
        "No page part YAML files found in #{yml_seeds_path}"
    end
  end

  describe "each page part seed file" do
    page_part_files_for_testing = Dir.glob(
      Rails.root.join("db", "yml_seeds", "page_parts", "*.yml")
    ).reject { |f| File.basename(f).start_with?("ABOUT") }

    page_part_files_for_testing.each do |file|
      filename = File.basename(file)

      context "#{filename}" do
        let(:file_content) { YAML.load_file(file) }

        it "is valid YAML" do
          expect { YAML.load_file(file) }.not_to raise_error
        end

        it "contains an array of page part definitions" do
          expect(file_content).to be_an(Array),
            "#{filename} should contain an array of page part definitions"
        end

        it "has required fields for each entry" do
          file_content.each_with_index do |entry, index|
            expect(entry).to have_key("page_slug"),
              "Entry #{index} in #{filename} missing 'page_slug'"
            expect(entry).to have_key("page_part_key"),
              "Entry #{index} in #{filename} missing 'page_part_key'"
          end
        end

        it "has a template field for non-rails parts" do
          file_content.each_with_index do |entry, index|
            # Skip rails parts as they don't need templates
            next if entry["is_rails_part"]

            # Skip parts that reference external templates via theme_name
            next if entry["theme_name"].present?

            expect(entry).to have_key("template"),
              "Entry #{index} (#{entry['page_part_key']}) in #{filename} missing 'template'. " \
              "Non-rails page parts must have a Liquid template defined."

            expect(entry["template"]).to be_present,
              "Entry #{index} (#{entry['page_part_key']}) in #{filename} has empty 'template'"
          end
        end

        it "has valid editor_setup when show_in_editor is true" do
          file_content.each_with_index do |entry, index|
            next unless entry["show_in_editor"]

            expect(entry).to have_key("editor_setup"),
              "Entry #{index} in #{filename} has show_in_editor=true but no editor_setup"

            editor_setup = entry["editor_setup"]
            expect(editor_setup).to have_key("editorBlocks"),
              "Entry #{index} in #{filename} editor_setup missing 'editorBlocks'"
          end
        end

        it "has consistent page_slug and filename" do
          file_content.each do |entry|
            page_slug = entry["page_slug"]
            page_part_key = entry["page_part_key"]

            # filename format: page_slug__page_part_key.yml (with / replaced by _)
            expected_prefix = "#{page_slug}__#{page_part_key.gsub('/', '_')}"
            actual_prefix = filename.sub('.yml', '')

            expect(actual_prefix).to eq(expected_prefix),
              "Filename #{filename} doesn't match page_slug/page_part_key pattern. " \
              "Expected: #{expected_prefix}.yml"
          end
        end
      end
    end
  end

  describe "template content validation" do
    page_part_files_for_testing = Dir.glob(
      Rails.root.join("db", "yml_seeds", "page_parts", "*.yml")
    ).reject { |f| File.basename(f).start_with?("ABOUT") }

    page_part_files_for_testing.each do |file|
      filename = File.basename(file)

      context "#{filename} template" do
        let(:file_content) { YAML.load_file(file) }

        it "has valid Liquid syntax" do
          file_content.each_with_index do |entry, index|
            next unless entry["template"].present?

            expect {
              Liquid::Template.parse(entry["template"])
            }.not_to raise_error,
              "Entry #{index} (#{entry['page_part_key']}) in #{filename} has invalid Liquid syntax"
          end
        end

        it "references only defined editor block labels" do
          file_content.each_with_index do |entry, index|
            next unless entry["template"].present? && entry.dig("editor_setup", "editorBlocks")

            # Extract all labels from editorBlocks
            defined_labels = entry["editor_setup"]["editorBlocks"].flatten.map { |b| b["label"] }.compact

            # Extract page_part["label"] references from template
            template = entry["template"]
            referenced_labels = template.scan(/page_part\["(\w+)"\]/).flatten.uniq

            referenced_labels.each do |label|
              expect(defined_labels).to include(label),
                "Template in #{filename} references '#{label}' but it's not defined in editorBlocks. " \
                "Defined labels: #{defined_labels.join(', ')}"
            end
          end
        end
      end
    end
  end
end
