require "rails_helper"

module Pwb
  RSpec.describe PagePart, type: :model do
    include FactoryBot::Syntax::Methods
    # Use "brisbane" as it's a valid theme (bristol doesn't exist)
    let(:website) { create(:pwb_website, theme_name: "brisbane") }
    let(:page_part) { create(:pwb_page_part, page_part_key: "landing_hero", website: website) }

    before do
      # Clear cache before each test to avoid stale data
      Rails.cache.clear
    end

    after do
      # Clean up any test files created
      FileUtils.rm_rf(Rails.root.join("app/themes/brisbane/page_parts"))
      FileUtils.rm_f(Rails.root.join("app/views/pwb/page_parts/landing_hero.liquid"))
    end

    describe "#template_content" do
      context "when database template exists" do
        before do
          page_part.update(template: "<div>Database Override</div>")
        end

        it "prefers database template over files" do
          expect(page_part.template_content).to eq("<div>Database Override</div>")
        end
      end

      context "when theme-specific file exists" do
        before do
          page_part.update(template: nil)
          theme_dir = Rails.root.join("app/themes/brisbane/page_parts")
          FileUtils.mkdir_p(theme_dir)
          File.write(theme_dir.join("landing_hero.liquid"), "<div>Brisbane Theme</div>")
        end

        it "uses theme-specific template" do
          expect(page_part.template_content).to eq("<div>Brisbane Theme</div>")
        end
      end

      context "when only default file exists" do
        before do
          page_part.update(template: nil)
          default_dir = Rails.root.join("app/views/pwb/page_parts")
          FileUtils.mkdir_p(default_dir)
          File.write(default_dir.join("landing_hero.liquid"), "<div>Default Template</div>")
        end

        it "falls back to default template" do
          expect(page_part.template_content).to eq("<div>Default Template</div>")
        end
      end

      context "when no template exists" do
        before do
          page_part.update(template: nil)
        end

        it "returns empty string" do
          expect(page_part.template_content).to eq("")
        end
      end
    end

    describe "caching" do
      before do
        # Create a theme-specific file for testing
        theme_dir = Rails.root.join("app/themes/brisbane/page_parts")
        FileUtils.mkdir_p(theme_dir)
        File.write(theme_dir.join("landing_hero.liquid"), "<div>Cached Content</div>")
      end

      it "caches template content" do
        # First call should read from file
        expect(File).to receive(:read).once.and_call_original

        # Call twice - should only read file once due to caching
        2.times { page_part.template_content }
      end

      it "clears cache when page part is updated" do
        # Prime the cache
        initial_content = page_part.template_content
        expect(initial_content).to eq("<div>Cached Content</div>")

        # Update with database template
        page_part.update(template: "<div>New Content</div>")

        # Should return new content, not cached
        expect(page_part.template_content).to eq("<div>New Content</div>")
      end

      it "clears cache when page part is destroyed" do
        cache_key = "page_part/#{page_part.id}/#{page_part.page_part_key}/brisbane/template"

        # Prime the cache
        page_part.template_content

        # Verify cache exists
        expect(Rails.cache.exist?(cache_key)).to be true

        # Destroy the page part
        page_part.destroy

        # Cache should be cleared
        expect(Rails.cache.exist?(cache_key)).to be false
      end
    end

    describe "template priority" do
      let!(:default_file) do
        default_dir = Rails.root.join("app/views/pwb/page_parts")
        FileUtils.mkdir_p(default_dir)
        File.write(default_dir.join("landing_hero.liquid"), "<div>Default</div>")
      end

      let!(:theme_file) do
        theme_dir = Rails.root.join("app/themes/brisbane/page_parts")
        FileUtils.mkdir_p(theme_dir)
        File.write(theme_dir.join("landing_hero.liquid"), "<div>Brisbane</div>")
      end

      it "database overrides theme file" do
        page_part.update(template: "<div>Database</div>")
        expect(page_part.template_content).to eq("<div>Database</div>")
      end

      it "theme file overrides default file" do
        page_part.update(template: nil)
        expect(page_part.template_content).to eq("<div>Brisbane</div>")
      end

      it "uses default when theme file doesn't exist" do
        FileUtils.rm_f(Rails.root.join("app/themes/brisbane/page_parts/landing_hero.liquid"))
        page_part.update(template: nil)
        expect(page_part.template_content).to eq("<div>Default</div>")
      end
    end
  end
end

