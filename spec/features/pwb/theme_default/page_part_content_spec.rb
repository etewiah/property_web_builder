require 'rails_helper'

module Pwb
  RSpec.describe "Default theme page part content", type: :feature, js: false do
    context 'for contact-us page' do
      let!(:contact_us_page) { FactoryGirl.create(:page_with_content_html_page_part,
                                                  slug: "contact-us") }
      # calling above :page would clash with page object

      let(:prop) { FactoryGirl.create(:pwb_prop, :sale) }

      scenario 'when general contact form is filled' do
        page_content_html = contact_us_page.contents.find_by_page_part_key "content_html"
        page_content_html.raw = "Content html raw"
        page_content_html.save!

        visit('/contact-us')

        expect(page).to have_content 'Content html raw'
      end
    end
  end
end
