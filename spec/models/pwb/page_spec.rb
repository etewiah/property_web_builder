require 'rails_helper'


module Pwb
  RSpec.describe Page, type: :model do
    let(:page) { FactoryGirl.create(:pwb_page) }
    # let(:about_us_page) { FactoryGirl.create(:pwb_page, :about_us)}
    let(:about_us_page) { FactoryGirl.create(:about_us_page)}

    it 'has a valid factory' do
      expect(page).to be_valid
    end




    it 'sets page_page block contents correctly' do
      page_part_key = "content_html"
      about_us_page.set_page_part_block_contents  page_part_key, "en", {"blocks": {}}
      about_us__content_html__page_part  = about_us_page.page_parts.find_by_page_part_key page_part_key


      # expect(about_us_page.details.to_json).to have_json_path("fragments")
      expect(about_us__content_html__page_part.block_contents.to_json).to have_json_path("en/blocks")
    end

  end
end
