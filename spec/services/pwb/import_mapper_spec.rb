require 'rails_helper'


module Pwb
  RSpec.describe "ImportMapper" do
    # include ActionDispatch::TestProcess

    let(:example_mls_property) do
      JSON.parse( File.read(fixture_path + "/mls/property_mris.json") )
    end


    it "imports a valid tab seperated file" do
      mapped_property = ImportMapper.new("").map_property(example_mls_property)
      expect(mapped_property).to include("reference" => example_mls_property["ListingKey"])
    end

  end
end
