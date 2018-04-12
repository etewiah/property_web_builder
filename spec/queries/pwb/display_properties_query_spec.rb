require 'spec_helper'

module Pwb
  RSpec.describe 'DisplayPropertiesQuery' do
    before(:all) do
        @two_bedroom_for_sale = FactoryGirl.create(:pwb_prop, :sale,
                                          reference: "ref2bbed",
                                          count_bedrooms: 2)
        @five_bedroom = FactoryGirl.create(:pwb_prop, :long_term_rent, :short_term_rent,
                                           price_rental_monthly_current_cents: 500_000,
                                           reference: "ref5bbed",
                                           count_bedrooms: 5)
      @prop_for_long_term_rent = FactoryGirl.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100_000,
        reference: "ref_pfltr"
      )
    end

    it 'retrieves properties correctly' do
      for_rent_properties = DisplayPropertiesQuery.new().for_rent
      for_sale_properties = DisplayPropertiesQuery.new().for_sale
      expect(for_rent_properties.count).to eq(2)
      expect(for_sale_properties.count).to eq(1)
    end

    after(:all) do
      @prop_for_long_term_rent.destroy
      @five_bedroom.destroy
      @two_bedroom_for_sale.destroy
    end
  end
end
