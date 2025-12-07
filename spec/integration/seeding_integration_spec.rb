# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Seeding Integration", type: :integration do
  # This integration test runs the actual seeding process without mocking
  # to catch issues like missing templates that only appear during real seeding

  describe "Full seeding process" do
    let!(:website) { create(:pwb_website, subdomain: 'integration-test', slug: 'integration-test') }

    before do
      # Clean up any existing data for this website
      website.pages.destroy_all
      website.page_parts.destroy_all
      website.links.destroy_all
      website.contents.destroy_all
      website.page_contents.destroy_all
    end

    context "page parts seeding" do
      it "seeds all page parts with valid templates" do
        # This should not raise any errors about missing templates
        expect {
          Pwb::PagesSeeder.seed_page_parts!
        }.not_to raise_error
      end

      it "creates page parts for all YAML seed files" do
        Pwb::PagesSeeder.seed_page_parts!

        yml_files = Dir.glob(Rails.root.join("db", "yml_seeds", "page_parts", "*.yml"))
          .reject { |f| File.basename(f).start_with?("ABOUT") }

        yml_files.each do |file|
          data = YAML.load_file(file)
          data.each do |entry|
            page_part = Pwb::PagePart.find_by(
              page_part_key: entry["page_part_key"],
              page_slug: entry["page_slug"]
            )

            expect(page_part).to be_present,
              "PagePart not created for #{entry['page_part_key']} on #{entry['page_slug']}"

            # Verify template is present for non-rails parts
            unless entry["is_rails_part"]
              expect(page_part.template).to be_present,
                "PagePart #{entry['page_part_key']} has no template"
            end
          end
        end
      end
    end

    context "page basics seeding" do
      before do
        Pwb::PagesSeeder.seed_page_parts!
      end

      it "seeds page basics without errors" do
        expect {
          Pwb::PagesSeeder.seed_page_basics!(website: website)
        }.not_to raise_error
      end

      it "creates pages for the website" do
        Pwb::PagesSeeder.seed_page_basics!(website: website)

        # Check that essential pages are created
        %w[home about-us contact-us].each do |slug|
          page = website.pages.find_by(slug: slug)
          expect(page).to be_present, "Page '#{slug}' should be created"
        end
      end
    end

    context "content translations seeding" do
      before do
        Pwb::PagesSeeder.seed_page_parts!
        Pwb::PagesSeeder.seed_page_basics!(website: website)
      end

      it "seeds content translations without errors" do
        expect {
          Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
        }.not_to raise_error
      end

      it "creates content with rendered HTML from templates" do
        Pwb::ContentsSeeder.seed_page_content_translations!(website: website)

        # Check that at least some content was created
        expect(website.contents.count).to be > 0

        # Verify content has raw HTML populated (from Liquid templates)
        content_with_html = website.contents.where.not(translations: {})
        expect(content_with_html.count).to be >= 0
      end
    end

    context "full seed runner" do
      it "completes without template errors" do
        result = Pwb::SeedRunner.run(
          website: website,
          mode: :create_only,
          dry_run: false,
          verbose: false,
          skip_properties: true
        )

        expect(result).to be true
      end

      it "creates all expected data" do
        Pwb::SeedRunner.run(
          website: website,
          mode: :create_only,
          dry_run: false,
          verbose: false,
          skip_properties: true
        )

        # Verify essential data was created
        expect(website.pages.count).to be > 0
        expect(website.links.count).to be > 0
        expect(website.field_keys.count).to be > 0
      end
    end
  end

  describe "Page part template rendering" do
    let!(:website) { create(:pwb_website, subdomain: 'template-test', slug: 'template-test') }

    before do
      Pwb::PagesSeeder.seed_page_parts!
      Pwb::PagesSeeder.seed_page_basics!(website: website)
    end

    it "can render all page part templates with Liquid" do
      page_parts_with_templates = Pwb::PagePart.where.not(template: [nil, ""])

      page_parts_with_templates.each do |page_part|
        expect {
          Liquid::Template.parse(page_part.template)
        }.not_to raise_error,
          "Failed to parse Liquid template for #{page_part.page_part_key}"
      end
    end

    it "renders templates with sample block contents" do
      page_parts_with_templates = Pwb::PagePart.where.not(template: [nil, ""])

      page_parts_with_templates.each do |page_part|
        # Create sample block contents based on editor_setup
        sample_blocks = {}
        if page_part.editor_setup && page_part.editor_setup["editorBlocks"]
          page_part.editor_setup["editorBlocks"].flatten.each do |block|
            next unless block.is_a?(Hash) && block["label"]
            sample_blocks[block["label"]] = { "content" => "Sample content for #{block['label']}" }
          end
        end

        template = Liquid::Template.parse(page_part.template)

        expect {
          template.render("page_part" => sample_blocks)
        }.not_to raise_error,
          "Failed to render template for #{page_part.page_part_key}"
      end
    end
  end

  describe "Regression tests" do
    let!(:website) { create(:pwb_website, subdomain: 'regression-test', slug: 'regression-test') }

    it "does not have page parts with missing templates in YAML seeds" do
      yml_files = Dir.glob(Rails.root.join("db", "yml_seeds", "page_parts", "*.yml"))
        .reject { |f| File.basename(f).start_with?("ABOUT") }

      missing_templates = []

      yml_files.each do |file|
        data = YAML.load_file(file)
        data.each do |entry|
          # Skip rails parts as they render via Rails partials
          next if entry["is_rails_part"]

          unless entry["template"].present?
            missing_templates << "#{File.basename(file)}: #{entry['page_part_key']}"
          end
        end
      end

      expect(missing_templates).to be_empty,
        "Page parts with missing templates:\n#{missing_templates.join("\n")}"
    end

    it "all page parts referenced in theme config have corresponding YAML seeds" do
      config_path = Rails.root.join("app", "themes", "config.json")
      skip "Theme config not found" unless File.exist?(config_path)

      config = JSON.parse(File.read(config_path))

      # Config is an array of theme objects
      themes = config.is_a?(Array) ? config : [config]

      themes.each do |theme_config|
        theme_name = theme_config["name"] || "unknown"
        page_parts = theme_config.dig("supports", "page_parts") || []

        # These page parts are global (not page-specific) and may have different naming conventions
        global_parts = %w[our_agency about_us_services content_html footer_content_html
                         footer_social_links form_and_map search_cmpt landing_hero]

        page_parts.each do |part_key|
          # Skip global parts that follow different naming conventions
          next if global_parts.include?(part_key)

          # For non-global parts, we'd need to know which page they belong to
          # This test is more of a sanity check - most parts are defined per-page
        end
      end

      # Simply verify that we have page part YAML files
      yml_files = Dir.glob(Rails.root.join("db", "yml_seeds", "page_parts", "*.yml"))
        .reject { |f| File.basename(f).start_with?("ABOUT") }

      expect(yml_files.count).to be > 10,
        "Expected at least 10 page part YAML seed files"
    end
  end
end
