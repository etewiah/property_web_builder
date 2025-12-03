require 'rails_helper'

module Pwb
  RSpec.describe "Theme Rendering", type: :feature do
    let!(:website) { FactoryBot.create(:pwb_website) }
    let!(:home_page) { FactoryBot.create(:pwb_page, slug: "home", website: website) }

    # Define the new semantic templates
    let(:landing_hero_template) do
      <<~HTML
        <div class="hero-section">
          <div class="hero-bg-wrapper">
            <div class="hero-bg-placeholder"></div>
          </div>
          <div class="hero-content-wrapper">
            <h1 class="hero-title">
              {{ page_part["landing_title_a"]["content"] }}
            </h1>
          </div>
        </div>
      HTML
    end

    let(:about_us_services_template) do
      <<~HTML
        <div class="services-section-wrapper">
          <div class="services-container">
            <div class="service-card">
              <h4>Find your home</h4>
            </div>
          </div>
        </div>
      HTML
    end

    before do
      # Create PageParts with the new semantic templates
      hero_editor_setup = {
        "editorBlocks" => [
          [
            { "label" => "landing_title_a", "isSingleLineText" => "true" },
            { "label" => "landing_content_a", "isHtml" => "true" }
          ]
        ]
      }

      hero_part = FactoryBot.create(:pwb_page_part,
        page_part_key: "landing_hero",
        page_slug: "home",
        template: landing_hero_template,
        editor_setup: hero_editor_setup,
        website: website
      )

      services_editor_setup = {
        "editorBlocks" => [
          [
            { "label" => "icon_a", "isIcon" => "true" },
            { "label" => "title_a", "isSingleLineText" => "true" },
            { "label" => "content_a", "isMultipleLineText" => "true" }
          ]
        ]
      }

      services_part = FactoryBot.create(:pwb_page_part,
        page_part_key: "about_us_services",
        page_slug: "home",
        template: about_us_services_template,
        editor_setup: services_editor_setup,
        website: website
      )

      # Seed content for the hero part
      hero_content_seed = {
        "landing_title_a" => "Welcome to Springfield",
        "landing_content_a" => "The best realtor in town"
      }

      # Use PagePartManager to set up the content
      hero_manager = Pwb::PagePartManager.new("landing_hero", home_page)
      hero_manager.seed_container_block_content("en", hero_content_seed)

      # Also setup services part
      services_manager = Pwb::PagePartManager.new("about_us_services", home_page)
      services_manager.seed_container_block_content("en", {})

      # Ensure the page parts are associated with the page
      # (The manager might do this, but let's be sure)
      unless home_page.page_parts.include?(hero_part)
        home_page.page_parts << hero_part
      end
      unless home_page.page_parts.include?(services_part)
        home_page.page_parts << services_part
      end

      # Ensure content is visible
      home_page.page_contents.update_all(visible_on_page: true)
    end

    scenario 'Home page renders with semantic CSS classes' do
      visit('/')

      # Check for Hero Section
      expect(page).to have_css('.hero-section')
      expect(page).to have_css('.hero-title', text: 'Welcome to Springfield')
      expect(page).to have_css('.hero-bg-wrapper')

      # Check for Services Section
      expect(page).to have_css('.services-section-wrapper')
      expect(page).to have_css('.services-container')
    end
  end
end
