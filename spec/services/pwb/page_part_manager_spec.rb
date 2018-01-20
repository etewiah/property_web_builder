require 'rails_helper'

module Pwb
  RSpec.describe "PagePartManager" do
    let!(:current_website) { Website.unique_instance || FactoryGirl.create(:pwb_website) }
    let(:page_part_key) {"footer_content_html"}
    let(:page_part_manager) {Pwb::PagePartManager.new page_part_key, current_website}
    let!(:page_part) {    FactoryGirl.create(:pwb_page_part, :footer_content_html_for_website)}




    it "creates content for website correctly" do
      # current_website = Pwb::Website.last
      # page_part_key = "footer_content_html"
      # page_part_manager = Pwb::PagePartManager.new page_part_key, current_website
      page_fragment_content = page_part_manager.find_or_create_content
      page_fragment_content_2 = page_part_manager.find_or_create_content

      expect(page_fragment_content).to eq(page_fragment_content_2)
      expect( page_fragment_content.page_contents).to eq(current_website.page_contents)
      # expect(current_website.page_parts.count).to eq(1)
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
end
