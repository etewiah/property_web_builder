require 'rails_helper'

module Pwb
  RSpec.describe "Theme Rendering", type: :feature do
    let!(:website) { FactoryBot.create(:pwb_website) }
    let!(:home_page) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page, slug: "home", website: website)
      end
    end

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

    let(:our_agency_template) do
      <<~HTML
        <section class="our-agency-section">
          <div class="agency-container">
            <div class="agency-content-wrapper">
              <h3 class="agency-title">
                <span>{{ page_part["title_a"]["content"] }}</span>
              </h3>
            </div>
          </div>
        </section>
      HTML
    end

    before do
      ActsAsTenant.with_tenant(website) do
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

    scenario 'About Us page renders with semantic CSS classes' do
      ActsAsTenant.with_tenant(website) do
        about_us_page = FactoryBot.create(:pwb_page, slug: "about-us", website: website)

        agency_editor_setup = {
          "editorBlocks" => [
            [
              { "label" => "title_a", "isSingleLineText" => "true" },
              { "label" => "content_a", "isMultipleLineText" => "true" },
              { "label" => "our_agency_img", "isImage" => "true" }
            ]
          ]
        }

        agency_part = FactoryBot.create(:pwb_page_part,
          page_part_key: "our_agency",
          page_slug: "about-us",
          template: our_agency_template,
          editor_setup: agency_editor_setup,
          website: website
        )

        agency_content_seed = {
          "title_a" => "Our Agency Story",
          "content_a" => "We started in 1990..."
        }

        agency_manager = Pwb::PagePartManager.new("our_agency", about_us_page)
        agency_manager.seed_container_block_content("en", agency_content_seed)

        unless about_us_page.page_parts.include?(agency_part)
          about_us_page.page_parts << agency_part
        end
        about_us_page.page_contents.update_all(visible_on_page: true)
      end

      visit('/about-us')

      expect(page).to have_css('.our-agency-section')
      expect(page).to have_css('.agency-container')
      expect(page).to have_css('.agency-title', text: 'Our Agency Story')
    end
  end
end

