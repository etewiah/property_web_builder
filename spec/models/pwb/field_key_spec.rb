require 'rails_helper'

module Pwb
  RSpec.describe FieldKey, type: :model do
    before(:each) do
      @fk1 = FactoryGirl.create(
        :pwb_field_key,
        global_key: "propertyStates.nuevo",
        tag: "property-states",
        visible: "true"
      )
    end

    describe 'get_options_by_tag' do
      it 'should return ' do
        ps_opts = FieldKey.get_options_by_tag "property-states"
        # byebug
        expect(ps_opts.count).to eq(1)
      end
    end

    # it "should only return properties with correct number of bedrooms" do
    #   expect(Prop.count_bedrooms(3)).to eq([@five_bedroom])
    #   # Prop.count_bedrooms(3).should == [@five_bedroom]
    # end
  end

  # it 'is valid with uppercase country code' do
  #   field_key = Pwb::FieldKey.new(
  #     country_code: 'AT',
  #     field_key_code: 'de',
  #     name: 'Österreich',
  #     frontpage_name: 'Start',
  #     page_layout: 'index',
  #     site: build(:alchemy_site)
  #   )
  #   expect(field_key).to be_valid
  # end

  # it "should return a label for code" do
  #   expect(field_key.label(:code)).to eq('kl')
  # end

  # describe '.table_name' do
  #   it "should return table name" do
  #     tk = FieldKey.get_options_by_tag "property-types"
  #     byebug
  #     expect(FieldKey.table_name).to eq('pwb_field_keys')
  #   end
  # end
end
