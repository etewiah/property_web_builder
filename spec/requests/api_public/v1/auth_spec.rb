require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Auth', type: :request do
  describe 'POST /api_public/v1/auth/firebase' do
    let(:token) { 'valid_token' }
    let(:user) { FactoryBot.create(:pwb_user, email: 'test@example.com', firebase_uid: 'firebase_123') }

    before do
      allow_any_instance_of(Pwb::FirebaseAuthService).to receive(:call).and_return(user)
    end

    context 'with valid token' do
      it 'returns success and user info' do
        post '/api_public/v1/auth/firebase', params: { token: token }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['user']['email']).to eq(user.email)
        expect(json['user']['firebase_uid']).to eq(user.firebase_uid)
      end
    end

    context 'with invalid token' do
      before do
        allow_any_instance_of(Pwb::FirebaseAuthService).to receive(:call).and_return(nil)
      end

      it 'returns unauthorized' do
        post '/api_public/v1/auth/firebase', params: { token: 'invalid' }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'missing token' do
      it 'returns bad request' do
        post '/api_public/v1/auth/firebase'
        
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
