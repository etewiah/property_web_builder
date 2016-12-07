require 'rails_helper'

module Pwb
  RSpec.describe 'Prop API' do

    let(:prop_for_long_term_rent) { FactoryGirl.create(:pwb_prop, :available_for_long_term_rent,
                                                       price_rental_monthly_current_cents: 100000) }
    let(:prop_for_sale) { FactoryGirl.create(:pwb_prop, :available_for_sale,
                                             price_sale_current_cents: 10000000) }

    it 'sends prop details' do
      get "/api/v1/properties/#{prop_for_long_term_rent.id}"

      # test for the 200 status-code
      expect(response).to be_success
      expect(response_body_as_json['data']['id']).to eq(prop_for_long_term_rent.id.to_s)
      
      expect(response.body).to be_jsonapi_response_for('properties')

    end
  end

end
