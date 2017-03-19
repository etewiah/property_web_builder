require 'rails_helper'

module Pwb
  RSpec.describe "ImportProperties" do
    include ActionDispatch::TestProcess

    # before :each do
    #   @file = fixture_file_upload('../to_import/pwb-properties.csv', 'text/csv')
    # end

    let(:file) do
      fixture_file_upload(
        "/to_import/pwb-properties.csv",
        'text/csv'
      )
    end


    let(:tsv_file) do
      fixture_file_upload(
        "/to_import/mls-listings-1.tsv",
        'text/csv'
      )
    end

    it "imports a valid tab seperated file" do
      expect { ImportProperties.new(tsv_file).import_mls_tsv }.to change { Prop.count }.by 3
    end


    # it "imports a valid csv file" do
    #   # allow(ImportProperties).to_receive(:add_meal_to_order)
    #   # expect(prop).to receive(:update_attributes).with(status: "served", customer_id: 123)
    #   expect { ImportProperties.new(file).import_csv }.to change { Prop.count }.by 4
    # end

  end
end
