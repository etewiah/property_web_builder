require 'rails_helper'

module Pwb
  RSpec.describe 'Prop API' do
    # let(:prop_for_long_term_rent) { FactoryGirl.create(:pwb_prop, :long_term_rent,
    #                                                    price_rental_monthly_current_cents: 100000) }
    # let(:prop_for_sale) { FactoryGirl.create(:pwb_prop, :sale,
    #                                          price_sale_current_cents: 10000000) }

    # it 'sends prop details' do
    #   get "/api/v1/properties/#{prop_for_long_term_rent.id}"

    #   # test for the 200 status-code
    #   expect(response).to be_success
    #   expect(response_body_as_json['data']['id']).to eq(prop_for_long_term_rent.id.to_s)

    #   expect(response.body).to be_jsonapi_response_for('properties')

    # end

    before(:all) do
      @prop_for_long_term_rent = FactoryGirl.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100_000,
        reference: "ref_pfltr"
      )
      @prop_for_sale = FactoryGirl.create(
        :pwb_prop,
        :sale,
        price_sale_current_cents: 10_000_000,
        reference: "ref_pf"
      )
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    end

    context 'with signed in admin user' do
      it 'sends agency details' do
        sign_in @admin_user

        get "/api/v1/properties/#{@prop_for_long_term_rent.id}"

        expect(response).to be_success
        expect(response_body_as_json['data']['id']).to eq(@prop_for_long_term_rent.id.to_s)

        expect(response.body).to be_jsonapi_response_for('properties')
      end
    end

    context 'without signed in admin user' do
      it 'redirects to sign_in page' do
        sign_out @admin_user

        get "/api/v1/properties/#{@prop_for_long_term_rent.id}"
        expect(response.status).to eq(302)
      end
    end

    after(:all) do
      @prop_for_sale.destroy
      @prop_for_long_term_rent.destroy
      @admin_user.destroy
    end
  end
end
