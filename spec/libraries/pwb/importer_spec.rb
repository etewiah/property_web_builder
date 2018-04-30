require 'spec_helper'
require 'pwb/importer'

module Pwb
  RSpec.describe 'Importer' do

    # it 'imports properties using custom scraper correctly' do
    #   VCR.use_cassette('importer/laventa') do
    #     # Pwb::Importer.import!
    #     import_host_data = { slug: 'laventa', scraper_name: 'pwb1', host: 'laventa.com' }
    #     existing_props = []
    #     new_props = []
    #     import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
    #     import_url = "http://www.laventa-mallorca.com/en/properties/for-rent/38/shop-botique-s-arenal-2-line"
    #     creator_params = {
    #       max_photos_to_process: 1,
    #       locales: ["fr","it","nl"]
    #     }

    #     listing = Pwb::Importer.retrieve_listing_for_url import_url, import_host
    #     expect(listing.count_bathrooms).to eq(1)
    #     expect(listing.title).to eq("Shop/Botique S´Arenal 2. Line")
    #     # expect(listing.count_bathrooms).to eq(1)
    #     # expect(listing.count_bathrooms).to eq(1)
    #   end
    # end

    it 'imports properties using demo config correctly' do
      VCR.use_cassette('importer/rerenting') do
        # Pwb::Importer.import!
        import_host_data = { slug: 're-renting', scraper_name: 'inmo1', host: 're-renting.com' }
        existing_props = []
        new_props = []
        import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
        import_url = "http://re-renting.com/en/properties/for-rent/1/acogedor-piso-en-anton-martin"
        creator_params = {
          max_photos_to_process: 1,
          locales: ["fr","it","nl"]
        }

        # Pwb::Importer.import_single_page import_url, import_host, existing_props, new_props, creator_params
        listing = Pwb::Importer.retrieve_listing_for_url import_url, import_host

        expect(listing.count_bathrooms).to eq(2)
      end
    end


    # it 'imports properties using demo config correctly' do
    #   VCR.use_cassette('importer/rerenting') do
    #     # Pwb::Importer.import!
    #     import_host_data = { slug: 're-renting', scraper_name: 'inmo1', host: 're-renting.com' }
    #     existing_props = []
    #     new_props = []
    #     import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
    #     url = "http://re-renting.com/en/properties/for-rent/1/acogedor-piso-en-anton-martin"
    #     creator_params = {
    #       max_photos_to_process: 1,
    #       locales: ["fr","it","nl"]
    #     }

    #     Pwb::Importer.import_single_page url, import_host, existing_props, new_props, creator_params
    #     expect(Prop.last.count_bathrooms).to eq(2)
    #   end
    # end

  end
end
