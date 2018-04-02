require 'rails_helper'

module Pwb
  RSpec.describe "PropCreator" do
    # include ActionDispatch::TestProcess

    let(:scraper_listing_json ) do
      scraper_listing_input = File.read(fixture_path + "/to_import/scraper-listing-1.json")
      JSON.parse(scraper_listing_input)
    end

    let(:scraper_listing_without_latlng_json ) do
      scraper_listing_without_latlng_input = File.read(fixture_path + "/to_import/scraper-listing-without-latlng.json")
      JSON.parse(scraper_listing_without_latlng_input)
    end

    it "creates prop correctly based on input json" do
      creator_params = {
        max_photos_to_process: 1,
        locales: ["fr","it","nl"]
      }

      prop_creator = Pwb::PropCreator.new(scraper_listing_json[0], creator_params)
      prop = prop_creator.create_from_json

      expect(prop.title_fr).to eq(prop.title)
      expect(prop.prop_photos.count).to eq(creator_params[:max_photos_to_process])
      expect(prop.count_bathrooms).to eq(1)
      expect(prop.latitude).to eq(40.4016513)
      expect(prop.street_address).to eq("stubbed street address")
      expect(I18n.t("features.CeramicFloor", locale: :nl)).to eq("Ceramic Floor")
      # allow(PropCreator).to_receive(:add_meal_to_order)
      # expect(prop).to receive(:update_attributes).with(status: "served", customer_id: 123)
      # expect { PropCreator.new(csv_file).import_csv }.to change { Prop.count }.by 4
    end


    it "geocodes where latlng missing" do
      creator_params = {
        max_photos_to_process: 1,
        locales: ["fr","it","nl"]
      }

      prop_creator = Pwb::PropCreator.new(scraper_listing_without_latlng_json[0], creator_params)
      prop = prop_creator.create_from_json

      expect(prop.latitude).to eq(40.7143528)
      # latitude above is set by geocoder stub here:
      # pwb/config/initializers/geocoder.rb
    end
  end
end
