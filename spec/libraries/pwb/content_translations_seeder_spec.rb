require 'spec_helper'
require 'pwb/content_translations_seeder'

module Pwb
  RSpec.describe 'ContentTranslationsSeeder' do
    before(:all) do
      # I18n::Backend::ActiveRecord::Translation.destroy_all
      # Pwb::Seeder.seed!
      Pwb::ContentTranslationsSeeder.seed_content_translations!
    end

    it 'creates our_agency content blocks' do
      about_us_page = Pwb::Page.find_by_slug "about-us"
      expect(about_us_page.details["fragments"]["our_agency"]["en"]["blocks"].count).to eq(3)
      expect(about_us_page.details["fragments"]["our_agency"]["es"]["blocks"].count).to eq(3)
    end

    it 'creates our_agency html content' do
      about_us_page = Pwb::Page.find_by_slug "about-us"
      about_us_page_content = about_us_page.contents.find_by_key "our_agency"
      expect(about_us_page_content.raw_en).to include("professional")
    end

 
    # it 'creates i18n translations' do
    #   es_translations = I18n::Backend::ActiveRecord::Translation.where(locale: "es")
    #   en_translations = I18n::Backend::ActiveRecord::Translation.where(locale: "en")
    #   expect(es_translations.count).to eq(en_translations.count)
    #   expect(es_translations.count).to be > 0
    # end

    # it 'creates a landing page hero entry' do
    #   expect(Pwb::Content.find_by_key('landingCarousel1')).to be_present
    # end

    # it 'creates an about_us entry' do
    #   expect(Pwb::Content.find_by_key('aboutUs')).to be_present
    # end

    # it 'creates 3 content-area-cols' do
    #   expect(Pwb::Content.where(tag: 'content-area-cols').count).to eq(3)
    # end

    # it 'creates 4 prop entries' do
    #   expect(Pwb::Prop.count).to eq(4)
    # end
  end
end
