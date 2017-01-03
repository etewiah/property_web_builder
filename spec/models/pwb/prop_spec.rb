require 'rails_helper'

module Pwb
  RSpec.describe Prop, type: :model do
    let(:prop) { FactoryGirl.create(:pwb_prop) }

    it 'has a valid factory' do
      expect(prop).to be_valid
    end

    context 'scopes' do
      before(:all) do
        # @first = FactoryGirl.create(:pwb_prop, created_at: 1.day.ago)
        @two_bedroom  = FactoryGirl.create(:pwb_prop,
                                           reference: "ref2bbed",
                                           count_bedrooms: 2)
        @five_bedroom  = FactoryGirl.create(:pwb_prop, :long_term_rent, :short_term_rent,
                                            price_rental_monthly_current_cents: 100000,
                                            reference: "ref5bbed",
                                            count_bedrooms: 5)
      end

      it 'should have correct rental price' do
        expect(@five_bedroom.rental_price.to_i).to eq(1000)
      end

      it "should only return properties with correct number of bedrooms" do
        expect(Prop.count_bedrooms(3)).to eq([@five_bedroom])
        # Prop.count_bedrooms(3).should == [@five_bedroom]
      end

      # before(:each) calls will get cleaned after
      # Would normally have to take care of before(:all)
      # calls manually but now using databasecleaner in spec_helper to do that
      # after(:all) do
      #   @two_bedroom.destroy
      #   @five_bedroom.destroy
      # end

    end

  end
end
