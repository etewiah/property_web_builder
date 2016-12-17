require 'rails_helper'

module Pwb
  RSpec.describe Api::V1::AgencyController, type: :controller do
    routes { Pwb::Engine.routes }


    context 'without signing in' do
      before(:each) do
        sign_in_stub nil
      end
      it "should not have a current_user" do
        expect(subject.current_user).to eq(nil)
      end

    end

    context 'with non_admin user' do
      login_non_admin_user

      it "should have a current_user" do
        expect(subject.current_user).to_not eq(nil)
      end

      describe 'GET #show' do
        it 'returns unauthorized status' do
          get :show, params: {}

          expect(response.status).to eq(422)
        end
      end
    end

    context 'with admin user' do
      login_admin_user

      it "should have a current_user" do
        expect(subject.current_user).to_not eq(nil)
      end

      describe 'GET #show' do
        let!(:agency)    { FactoryGirl.create(:pwb_agency) }

        it 'returns correct agency' do
          get :show, params: {}
          # , format: :json

          expect(response.status).to eq(200)
          expect(response.content_type).to eq('application/json')

          result = JSON.parse(response.body)

          expect(result).to have_key('agency')
          expect(result['agency']['id']).to eq(agency.id)

        end
      end
    end

  end
end
