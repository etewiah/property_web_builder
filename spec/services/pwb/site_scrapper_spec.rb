require 'rails_helper'

module Pwb
  RSpec.describe "SiteScrapper" do
    it "scrapes property correctly" do
      VCR.use_cassette("listing_re_renting") do
        # just a proof of concept at this stage
        target_url = "http://re-renting.com/en/properties/for-rent/1/acogedor-piso-en-anton-martin"
         # "http://public.olr.com/details.aspx?id=1658517"


        retrieved_properties = SiteScrapper.new(target_url).retrieve_from_webpage
        expect(retrieved_properties.length).to eq(1)
      end
    end
  end
end
