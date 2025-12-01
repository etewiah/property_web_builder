require 'rails_helper'

module Pwb
  RSpec.describe FirebaseAuthService do
    let(:token) { 'valid_token' }
    let(:payload) { { 'user_id' => 'firebase_123', 'email' => 'test@example.com' } }
    let!(:default_website) { FactoryBot.create(:pwb_website) }
    
    before do
      allow(FirebaseIdToken::Signature).to receive(:verify).with(token).and_return(payload)
      allow(Pwb::Website).to receive(:first).and_return(default_website)
    end

    describe '#call' do
      context 'when user does not exist' do
        it 'creates a new user and membership' do
          expect {
            described_class.new(token).call
          }.to change(User, :count).by(1)
          .and change(UserMembership, :count).by(1)
          
          user = User.last
          expect(user.email).to eq('test@example.com')
          expect(user.firebase_uid).to eq('firebase_123')
          
          membership = UserMembership.last
          expect(membership.user).to eq(user)
          expect(membership.role).to eq('member')
        end
      end

      context 'when user exists by email' do
        let!(:existing_user) { FactoryBot.create(:pwb_user, email: 'test@example.com') }

        it 'updates the user with firebase_uid' do
          expect {
            described_class.new(token).call
          }.not_to change(User, :count)
          
          existing_user.reload
          expect(existing_user.firebase_uid).to eq('firebase_123')
        end
      end

      context 'when user exists by firebase_uid' do
        let!(:existing_user) { FactoryBot.create(:pwb_user, email: 'test@example.com', firebase_uid: 'firebase_123') }

        it 'returns the existing user' do
          expect {
            described_class.new(token).call
          }.not_to change(User, :count)
          
          expect(described_class.new(token).call).to eq(existing_user)
        end
      end

      context 'when token is invalid' do
        before do
          allow(FirebaseIdToken::Signature).to receive(:verify).with(token).and_return(nil)
        end

        it 'returns nil' do
          expect(described_class.new(token).call).to be_nil
        end
      end
    end
  end
end
