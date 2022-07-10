require 'rails_helper'

module Pwb
  RSpec.describe 'Prop API' do
    # let(:prop_for_long_term_rent) { FactoryBot.create(:pwb_prop, :long_term_rent,
    #                                                    price_rental_monthly_current_cents: 100000) }
    # let(:prop_for_sale) { FactoryBot.create(:pwb_prop, :sale,
    #                                          price_sale_current_cents: 10000000) }

    # it 'sends prop details' do
    #   get "/api/v1/properties/#{prop_for_long_term_rent.id}"

    #   # test for the 200 status-code
    #   expect(response).to be_success
    #   expect(response_body_as_json['data']['id']).to eq(prop_for_long_term_rent.id.to_s)

    #   expect(response.body).to be_jsonapi_response_for('properties')

    # end

    before(:all) do
      @prop_for_long_term_rent = FactoryBot.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100_000,
        reference: "ref_pfltr"
      )
      @prop_for_sale = FactoryBot.create(
        :pwb_prop,
        :sale,
        price_sale_current_cents: 10_000_000,
        reference: "ref_pf"
      )
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    end

    context 'with signed in admin user' do
      before do
        sign_in @admin_user
      end
      it 'creates property correctly' do

        post "/api/v1/properties/bulk_create", params: {
          propertiesJSON: [
            {"area_unit":"sqft","reference":"71450225","count_bedrooms":1,"count_bathrooms":0,"count_toilets":0,"count_garages":0,
             "plot_area":0,"constructed_area":0,"title":"1 bedroom flat to rent in Carlyle Road, Birmingham, B16, B16",
             "description":"GLENWOOD PROPERTY SERVICES are proud to present this double bedroom",
             "locale_code":"en","for_rent_short_term":false,"for_rent_long_term":true,"for_sale":false,"currency":"GBP","street_number":nil,
             "street_name":nil,"street_address":"Carlyle Road, Birmingham, B16","postal_code":"B16 9BH","province":nil,"city":nil,
             "region":nil,"country":"UK","latitude":52.4745271399802,"longitude":-1.93576729748747,"features":[],
             "property_photos":[{"url":"http://media.rightmove.co.uk/dir/147k/146672/71450225/146672_F4_Carl_rd_IMG_00_0000.JPG"}],
             "price_rental_monthly_current":600,"price_sale_current":0}
          ]
        }
        expect(response).to be_success


        expect(response_body_as_json["new_props"][0]["title"]).to eq("1 bedroom flat to rent in Carlyle Road, Birmingham, B16, B16")


        # expect(response.body).to have_json_path("feature_key")
      end


      it 'updates features correctly' do

        post "/api/v1/properties/update_extras", params: {
          id: "#{@prop_for_long_term_rent.id}",
          extras: {aireAcondicionado: true}
        }
        expect(response).to be_success
        expect(@prop_for_long_term_rent.features.find_by(feature_key: "aireAcondicionado")).to be_present
        expect(@prop_for_long_term_rent.features.count).to eq(1)
        expect(response_body_as_json[0]["feature_key"]).to eq("aireAcondicionado")
        # expect(response.body).to have_json_path("feature_key")
      end

      it 'sends agency details' do
        # request.env['CONTENT_TYPE'] = 'application/vnd.api+json'
        request_headers = {
          "Accept" => "application/vnd.api+json"
          # "Content-Type" => "application/vnd.api+json"
        }

        get "/api/v1/properties/#{@prop_for_long_term_rent.id}", headers: request_headers

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
