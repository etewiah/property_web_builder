require 'rails_helper'

module Pwb
  RSpec.describe "ImportProperties" do
    # include ActionDispatch::TestProcess

    let(:bulk_create_json ) do
      bulk_create_input = File.read(fixture_path + "/params/bulk_create.json")
       JSON.parse(bulk_create_input)
    end

    # let(:csv_file) do
    #   fixture_file_upload(
    #     "/to_import/pwb-properties.csv",
    #     'text/csv'
    #   )
    #   # above uses below config setting
    #   #   config.fixture_path = "#{Pwb::Engine.root}/spec/fixtures"
    # end

    it "imports a valid csv file" do
      prop_creator = Pwb::PropCreator.new(bulk_create_json[0])
      prop = prop_creator.create
      expect(prop.count_bathrooms).to eq(2.5)
      # allow(ImportProperties).to_receive(:add_meal_to_order)
      # expect(prop).to receive(:update_attributes).with(status: "served", customer_id: 123)
      # expect { ImportProperties.new(csv_file).import_csv }.to change { Prop.count }.by 4
      # parsed_properties = ImportProperties.new(csv_file).import_csv
      # expect(parsed_properties[0]).to include("title_en")
      # expect(parsed_properties.count).to eq(4)
    end
  end
end
