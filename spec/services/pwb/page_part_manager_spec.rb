require 'rails_helper'

module Pwb
  RSpec.describe "PagePartManager" do
    context 'for website' do
      let!(:current_website) { Website.unique_instance || FactoryBot.create(:pwb_website) }
      let(:page_part_key) { "footer_content_html" }
      let(:page_part_manager) { Pwb::PagePartManager.new page_part_key, current_website }
      let!(:page_part) { FactoryBot.create(:pwb_page_part, :footer_content_html_for_website) }

      it "creates content for website correctly" do
        # current_website = Pwb::Website.last
        # page_part_key = "footer_content_html"
        # page_part_manager = Pwb::PagePartManager.new page_part_key, current_website
        content_for_container = page_part_manager.find_or_create_content
        content_for_container_2 = page_part_manager.find_or_create_content

        expect(content_for_container).to eq(content_for_container_2)
        # expect( content_for_container.page_contents).to eq(current_website.page_contents)
        expect(current_website.contents).to include(content_for_container)
      end
      it 'seeds website content correctly' do
        locale = "en"
        seed_content = {
          "main_content" => "<p>We are proud to be registered with the national association of realtors.</p>"
        }
        # below would fail:
        #         "main_content":"<p>We are proud to be registered with the national association of realtors.</p>"

        result = page_part_manager.seed_container_block_content locale, seed_content

        expect(current_website.contents.find_by_page_part_key(page_part_key).raw).to include("We are proud to be registered with")
      end
    end
    context 'for pages' do
      let!(:contact_us_page) {
        FactoryBot.create(:page_with_content_html_page_part,
                           slug: "contact-us")
      }

      let(:page_part_key) { "content_html" }
      let(:page_part_manager) { Pwb::PagePartManager.new page_part_key, contact_us_page }
      # let!(:page_part) { FactoryBot.create(:pwb_page_part, :footer_content_html_for_website) }

      it "creates content for page correctly" do
        content_for_container = page_part_manager.find_or_create_content
        content_for_container_2 = page_part_manager.find_or_create_content


        expect(content_for_container).to eq(content_for_container_2)
        expect(contact_us_page.contents).to include(content_for_container)
      end

      it 'seeds page content correctly' do
        locale = "en"
        en_seed_content = {
          "main_content" => "<p>We are proud to be registered with the national association of realtors.</p>"
        }
        result_en = page_part_manager.seed_container_block_content locale, en_seed_content

        locale = "es"
        es_seed_content = {
          "main_content" => "<p>Estamos orgulloso.</p>"
        }
        result_es = page_part_manager.seed_container_block_content locale, es_seed_content


        expect(contact_us_page.contents.find_by_page_part_key(page_part_key).raw).to include("We are proud to be registered with")
        expect(contact_us_page.contents.find_by_page_part_key(page_part_key).raw_es).to include("Estamos orgulloso")
      end
    end
  end
end
