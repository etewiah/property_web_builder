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
      it 'sends agency details' do
        sign_out @admin_user
        get '/api/v1/agency'

        # byebug
        expect(response.status).to eq(422)
      end
    end

    after(:all) do
      @agency.destroy
      @admin_user.destroy
    end

  end

end
