require 'rails_helper'


module Pwb
  RSpec.describe "ImportMapper" do
    # include ActionDispatch::TestProcess

    let(:property_mris) do
      JSON.parse( File.read(fixture_path + "/mls/property_mris.json") )
    end

    let(:property_interealty) do
      JSON.parse( File.read(fixture_path + "/mls/property_interealty.json") )
    end

    it "maps mris data correctly" do
      mapped_property = ImportMapper.new("mls_mris").map_property(property_mris)
      expect(mapped_property).to include("reference" => property_mris["ListingKey"])
    end

    it "maps interealty data correctly" do
      mapped_property = ImportMapper.new("mls_interealty").map_property(property_interealty)
      expect(mapped_property).to include("reference" => property_interealty["ListingID"])
    end
  end
end
