require 'spec_helper'
require 'pwb/importer'

module Pwb
  RSpec.describe 'Importer' do
    # before(:all) do
    #   I18n::Backend::ActiveRecord::Translation.destroy_all
    #   Pwb::Seeder.seed!
    # end

    # it 'creates i18n translations' do
    #   es_translations = I18n::Backend::ActiveRecord::Translation.where(locale: "es")
    #   en_translations = I18n::Backend::ActiveRecord::Translation.where(locale: "en")
    #   expect(es_translations.count).to eq(en_translations.count)
    #   expect(es_translations.count).to be > 0
    # end



    it 'imports properties using demo config correctly' do
      VCR.use_cassette('importer/rerenting') do
        Pwb::Importer.import!
        expect(Prop.last.count_bathrooms).to eq(2)
        # web_scraper = PropertyWebScraper::Scraper.new('rerenting')
        # listing = PropertyWebScraper::Listing.where(import_url: import_url).first_or_create
        # retrieved_property = web_scraper.retrieve_and_save listing, 1

        # expect(retrieved_property.for_sale).to eq(true)
        # expect(retrieved_property.image_urls.count).to eq(38)
        # expect(retrieved_property.year_construction).to eq(1998)
        # expect(retrieved_property.latitude).to eq(33.1470154308066)
        # expect(retrieved_property.longitude).to eq(-96.7932415858605)
        # expect(retrieved_property.currency).to eq("USD")
        # expect(retrieved_property.price_string).to eq("$280,000")
        # expect(retrieved_property.title).to eq("10080 Queens Road Frisco, TX 75035 — MLS# 13729013")

      end
    end

  end
end
