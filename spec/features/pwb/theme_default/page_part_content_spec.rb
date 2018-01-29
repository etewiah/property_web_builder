require 'rails_helper'

module Pwb
  RSpec.feature "Default theme page part content", type: :feature, js: false do
    feature 'for contact-us page' do
      let!(:contact_us_page) {
        FactoryGirl.create(:page_with_content_html_page_part,
                           slug: "contact-us")
      }
      # calling above :page would clash with page object
      let(:content_html_ppm) { Pwb::PagePartManager.new "content_html", contact_us_page }
      let!(:form_and_map_page_part) { Pwb::PagePart.create_from_seed_yml "contact-us__form_and_map.yml"  }
      let(:form_and_map_ppm) { Pwb::PagePartManager.new "form_and_map", contact_us_page }

      let!(:footer_content_page_part) { Pwb::PagePart.create_from_seed_yml "website__footer_content_html.yml"  }
      let(:footer_content_ppm) { Pwb::PagePartManager.new "footer_content_html", Pwb::Website.unique_instance}

      let(:prop) { FactoryGirl.create(:pwb_prop, :sale) }

      scenario 'correct content html is rendered' do
        # TODO: move all of the setting up below into
        # a helper or factory
        page_content_html = content_html_ppm.find_or_create_content
        page_content_html.raw = "Content html raw"
        page_content_html.save!

        footer_content_html = footer_content_ppm.find_or_create_content

        # TODO - use get_seed_content here
        # seed_content = footer_content_ppm.get_seed_content

        footer_content_html.raw = "We are registered with the national association "
        footer_content_html.save!

        # set up form_and_map_page_part (which is a rails_part)
        form_and_map_ppm.find_or_create_join_model
        visit('/contact-us')

        expect(page).to have_css(".default-theme", count: 1)
        # below from form_and_map_page_part
        expect(page).to have_css(".contact-us-section", count: 1)
        # below from content_html page_part
        expect(page).to have_content 'Content html raw'

        expect(page).to have_content 'We are registered with the national association'
      end
    end
  end
end
