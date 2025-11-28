require 'rails_helper'

module Pwb
  RSpec.feature "Berlin theme page part content", type: :feature, js: false do
    feature 'for contact-us page' do
      let!(:contact_us_page) {
        FactoryBot.create(:page_with_content_html_page_part,
                                                  slug: "contact-us")
      }
      # calling above :page would clash with page object

      let(:content_html_ppm) { Pwb::PagePartManager.new "content_html", contact_us_page }
      let!(:form_and_map_page_part) { Pwb::PagePart.create_from_seed_yml "contact-us__form_and_map.yml"  }
      let(:form_and_map_ppm) { Pwb::PagePartManager.new "form_and_map", contact_us_page }

      let(:prop) { FactoryBot.create(:pwb_prop, :sale) }


      before(:all) do
        @website = FactoryBot.create(:pwb_website)
        @website.theme_name = "berlin"
        @website.save!
      end


      scenario 'correct content html is rendered' do
        page_content_html = content_html_ppm.find_or_create_content
        page_content_html.raw = "Content html raw"
        page_content_html.save!

        # set up form_and_map_page_part (which is a rails_part)
        form_and_map_content = form_and_map_ppm.find_or_create_join_model

        visit('/contact-us')

        expect(page).to have_css(".berlin-theme", count: 1)
        # below from form_and_map_page_part
        expect(page).to have_css(".contact-us-section", count: 1)
        # below from content_html page_part
        expect(page).to have_content 'Content html raw'
      end

    end
  end
end
