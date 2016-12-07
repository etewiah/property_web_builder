require 'rails_helper'

module Pwb
  RSpec.describe 'Agency API' do
    it 'sends agency details' do
      # FactoryGirl.create_list(:message, 10)
      agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')

      get '/api/v1/agency'

      # response_body_as_json = JSON.parse(response.body)

      # test for the 200 status-code
      expect(response).to be_success

      expect(response_body_as_json['agency']['company_name']).to eq(agency.company_name)
    end
  end

end
