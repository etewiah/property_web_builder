require 'rails_helper'

module Pwb
  RSpec.describe 'Agency API' do
    # FactoryGirl.create_list(:message, 10)
    before(:all) do
      @agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin:true)
    end

    context 'with signed in admin user' do
      it 'sends agency details' do
        sign_in @admin_user
        get '/api/v1/agency'

        # test for the 200 status-code
        expect(response).to be_success
        expect(response_body_as_json['agency']['company_name']).to eq(@agency.company_name)
        # expect(response.status).to eq(201)
        # expect(response.headers['Location']).to match(/\/rental_units\/\d$/)
      end
    end

    context 'without signed in user' do
      it 'redirects to sign_in page' do
        sign_out @admin_user
        get '/api/v1/agency'

        expect(response.status).to eq(302)
      end
    end

    describe "PUT /api/v1/tenant" do
      it "updates agency" do
        sign_in @admin_user

        agency_params = {
          "supported_languages": ["fr","es"]
        }.to_json

        request_headers = {
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }


        #  ActionDispatch::IntegrationTest HTTP request methods will accept only
        # the following keyword arguments in future Rails versions:
        # params, headers, env, xhr, as

        # put '/profile',
        #   params: { id: 1 },
        #   headers: { 'X-Extra-Header' => '123' },
        #   env: { 'action_dispatch.custom' => 'custom' },
        #   xhr: true,
        #   as: :json

        put "/api/v1/tenant", params: agency_params, headers: request_headers
        expect(response.status).to eq 200 # successful
        @agency.reload
        expect(@agency.supported_locales).to eq ["fr","es"]
      end
    end



    after(:all) do
      @agency.destroy
      @admin_user.destroy
    end

  end

end
