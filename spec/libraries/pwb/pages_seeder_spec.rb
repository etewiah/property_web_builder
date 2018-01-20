require 'spec_helper'
require 'pwb/pages_seeder'

module Pwb
  RSpec.describe 'PagesSeeder' do
    before(:all) do
      # I18n::Backend::ActiveRecord::Translation.destroy_all
      Pwb::Seeder.seed!
      Pwb::PagesSeeder.seed_page_parts!
      Pwb::PagesSeeder.seed_page_basics!
      Pwb::PagesSeeder.seed_page_content_translations!
      # Pwb::PagesSeeder.seed_content_translations!
    end
    

    # it 'sets visibility correctly' do
    #   byebug      
    # end



    it 'sets sort order correctly' do
      about_us_page = Pwb::Page.find_by_slug "about-us"
      our_agency_content_key = "our_agency"
      our_agency_content = about_us_page.contents.find_by_page_part_key our_agency_content_key
      our_agency_join_model = our_agency_content.page_contents.find_by_page_id about_us_page.id
      content_html_content_key = "content_html"
      content_html_content = about_us_page.contents.find_by_page_part_key content_html_content_key
      content_html_join_model = content_html_content.page_contents.find_by_page_id about_us_page.id

      expect(our_agency_join_model.sort_order).to eq(2)
      expect(content_html_join_model.sort_order).to eq(1)
    end

    it 'creates our_agency content blocks' do
      about_us_page = Pwb::Page.find_by_slug "about-us"
      html_web_part = about_us_page.page_parts.find_by_page_part_key "content_html"

      expect(html_web_part.block_contents.to_json).to have_json_path("en/blocks")
      expect(html_web_part.block_contents["en"]["blocks"].count).to eq(1)
      expect(about_us_page.page_parts.count).to eq(2)
      # expect(about_us_page.details["fragments"]["our_agency"]["es"]["blocks"].count).to eq(3)
    end

    it 'creates our_agency html content' do
      about_us_page = Pwb::Page.find_by_slug "about-us"
      content_key =   "our_agency"
      about_us_page_content = about_us_page.contents.find_by_page_part_key content_key
      expect(about_us_page_content.raw_en).to include("professional")
      expect(about_us_page_content.content_photos.count).to eq(1)
    end



    it 'creates home html content' do
      home_page = Pwb::Page.find_by_slug "home"
      content_key = "landing_hero"
      home_page_content = home_page.contents.find_by_page_part_key content_key
      expect(home_page_content.raw_en).to include("The best realtor")
      expect(home_page_content.content_photos.count).to eq(1)
      # expect(home_page.details["fragments"]["landing_hero"]["en"]["blocks"].count).to eq(3)
    end
  end
end
