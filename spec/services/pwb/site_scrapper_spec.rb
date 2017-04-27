require 'rails_helper'

module Pwb
  RSpec.describe "SiteScrapper" do

    it "scrapes property correctly" do
      VCR.use_cassette("listing_olr") do
        # just a proof of concept at this stage
        target_url = "http://public.olr.com/details.aspx?id=1658517"

        retrieved_properties = SiteScrapper.new(target_url).retrieve()
        expect(retrieved_properties.length).to eq(1)
      end
    end

  end
end
