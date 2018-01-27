require 'rails_helper'

module Pwb
  RSpec.describe Page, type: :model do
    let(:page) { FactoryGirl.create(:pwb_page) }
    # below will not be available in context block
    # let(:about_us_page) { FactoryGirl.create(:about_us_page_with_page_part)}

    it 'has a valid factory' do
      expect(page).to be_valid
    end

    # below to be replaced with page_part_manager
    # it 'sets fragment visibility correctly' do

    # end

    # context 'with correct fragment_block' do
    #   before(:all) do
    #     @about_us_page = FactoryGirl.create(:about_us_page_with_page_part)

    #     @fragment_block = {
    #       "blocks": {
    #         "main_content": {
    #           "content": "<p>Hola.</p>"
    #         }
    #       }
    #     }
    #     @page_part_key = "content_html"
    #   end

    #   it 'sets page_part block contents correctly' do
    #     # for the "content_html" page part
    #     # if I pass in a locale key and a blocks json element to the right method on the page
    #     # (the below method is called by admin page via API that passes in correctly
    #     # formated fragment_block)
    #     byebug
    #     @about_us_page.update_page_part_content  @page_part_key, "en", @fragment_block
    #     about_us__content_html__page_part  = @about_us_page.page_parts.find_by_page_part_key @page_part_key


    #     # the corresponding page_part will have that json element correctly set
    #     expect(about_us__content_html__page_part.block_contents.to_json).to have_json_path("en/blocks")
    #   end

    #   it 'builds page content correctly' do
    #     about_us__content_html__page_part  = @about_us_page.page_parts.find_by_page_part_key @page_part_key
    #     about_us__content_html__page_part.template = '<div>{{ page_part["main_content"]["content"] %> }}</div>'
    #     about_us__content_html__page_part.save!
    #     @about_us_page.update_page_part_content  @page_part_key, "en", @fragment_block

    #     expect(@about_us_page.page_contents.first.page_part_key).to eq(@page_part_key)
    #     expect(@about_us_page.contents.first.raw_en).to eq("<div><p>Hola.</p></div>")
    #   end

    #   # @about_us_page not available in context below
    #   # context 'www' do
    #   #   # and when I rebuild the page content
    #   #   @about_us_page.rebuild_page_content @page_part_key, "en"
    #   # end

    # end
  end
end
