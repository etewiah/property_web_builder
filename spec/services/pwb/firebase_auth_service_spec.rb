require 'rails_helper'

module Pwb
  RSpec.describe FirebaseAuthService do
    let(:token) { 'valid_token' }
    let(:payload) { { 'sub' => 'firebase_123', 'user_id' => 'firebase_123', 'email' => 'test@example.com' } }
    let!(:default_website) { FactoryBot.create(:pwb_website) }

    before do
      # Mock the FirebaseTokenVerifier to return our test payload
      verifier_instance = instance_double(FirebaseTokenVerifier)
      allow(FirebaseTokenVerifier).to receive(:new).with(token).and_return(verifier_instance)
      allow(verifier_instance).to receive(:verify!).and_return(payload)
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

      context 'when token verification fails' do
        before do
          verifier_instance = instance_double(FirebaseTokenVerifier)
          allow(FirebaseTokenVerifier).to receive(:new).with(token).and_return(verifier_instance)
          allow(verifier_instance).to receive(:verify!).and_raise(
            FirebaseTokenVerifier::InvalidTokenError.new('Invalid token')
          )
        end

        it 'returns nil' do
          expect(described_class.new(token).call).to be_nil
        end
      end

      context 'when certificate error occurs and retry succeeds' do
        it 'returns user after certificate refresh' do
          verifier_instance = instance_double(FirebaseTokenVerifier)
          call_count = 0
          allow(FirebaseTokenVerifier).to receive(:new).with(token).and_return(verifier_instance)
          allow(verifier_instance).to receive(:verify!) do
            call_count += 1
            if call_count == 1
              raise FirebaseTokenVerifier::CertificateError.new('No certificates')
            else
              payload
            end
          end
          allow(FirebaseTokenVerifier).to receive(:fetch_certificates!)

          expect {
            described_class.new(token).call
          }.to change(User, :count).by(1)
        end
      end

      context 'when website is locked_pending_registration' do
        let(:owner_email) { 'owner@example.com' }
        let(:verification_token) { 'valid-verification-token-abc123' }
        let!(:locked_website) do
          FactoryBot.create(:pwb_website,
            provisioning_state: 'locked_pending_registration',
            owner_email: owner_email,
            email_verification_token: verification_token
          )
        end

        context 'and signup email matches owner email with valid verification token' do
          let(:payload) { { 'sub' => 'firebase_owner', 'user_id' => 'firebase_owner', 'email' => owner_email } }

          it 'creates user with admin role' do
            expect {
              described_class.new(token, website: locked_website, verification_token: verification_token).call
            }.to change(User, :count).by(1)
            .and change(UserMembership, :count).by(1)

            user = User.last
            expect(user.email).to eq(owner_email)

            membership = UserMembership.last
            expect(membership.role).to eq('admin')
          end

          it 'transitions website to live state' do
            described_class.new(token, website: locked_website, verification_token: verification_token).call

            locked_website.reload
            expect(locked_website.live?).to be true
          end
        end

        context 'and signup email matches but verification token is missing' do
          let(:payload) { { 'sub' => 'firebase_owner', 'user_id' => 'firebase_owner', 'email' => owner_email } }

          it 'raises an error' do
            expect {
              described_class.new(token, website: locked_website).call
            }.to raise_error(StandardError, /Invalid or missing verification token/)
          end

          it 'does not create a user' do
            expect {
              begin
                described_class.new(token, website: locked_website).call
              rescue StandardError
                # Expected error
              end
            }.not_to change(User, :count)
          end
        end

        context 'and signup email matches but verification token is invalid' do
          let(:payload) { { 'sub' => 'firebase_owner', 'user_id' => 'firebase_owner', 'email' => owner_email } }

          it 'raises an error' do
            expect {
              described_class.new(token, website: locked_website, verification_token: 'wrong-token').call
            }.to raise_error(StandardError, /Invalid or missing verification token/)
          end

          it 'does not create a user' do
            expect {
              begin
                described_class.new(token, website: locked_website, verification_token: 'wrong-token').call
              rescue StandardError
                # Expected error
              end
            }.not_to change(User, :count)
          end
        end

        context 'and signup email does not match owner email' do
          let(:payload) { { 'sub' => 'firebase_other', 'user_id' => 'firebase_other', 'email' => 'other@example.com' } }

          it 'raises an error about owner email (checked before token)' do
            expect {
              described_class.new(token, website: locked_website, verification_token: verification_token).call
            }.to raise_error(StandardError, /Only the verified owner email/)
          end

          it 'does not create a user' do
            expect {
              begin
                described_class.new(token, website: locked_website, verification_token: verification_token).call
              rescue StandardError
                # Expected error
              end
            }.not_to change(User, :count)
          end

          it 'does not transition website state' do
            begin
              described_class.new(token, website: locked_website, verification_token: verification_token).call
            rescue StandardError
              # Expected error
            end

            locked_website.reload
            expect(locked_website.locked_pending_registration?).to be true
          end
        end

        context 'and signup email matches owner email with different case' do
          let(:payload) { { 'sub' => 'firebase_owner', 'user_id' => 'firebase_owner', 'email' => 'OWNER@EXAMPLE.COM' } }

          it 'creates user with admin role (case insensitive)' do
            expect {
              described_class.new(token, website: locked_website, verification_token: verification_token).call
            }.to change(User, :count).by(1)

            membership = UserMembership.last
            expect(membership.role).to eq('admin')
          end
        end

        context 'and existing owner user logs in (bypassed signup flow)' do
          let(:payload) { { 'sub' => 'firebase_owner', 'user_id' => 'firebase_owner', 'email' => owner_email } }
          let!(:existing_owner) do
            FactoryBot.create(:pwb_user,
              email: owner_email,
              firebase_uid: 'firebase_owner'
            )
          end

          it 'transitions website to live state' do
            expect {
              described_class.new(token, website: locked_website).call
            }.not_to change(User, :count)

            locked_website.reload
            expect(locked_website.live?).to be true
          end

          it 'grants admin role if not already admin' do
            described_class.new(token, website: locked_website).call

            expect(existing_owner.admin_for?(locked_website)).to be true
          end

          it 'returns the existing user' do
            result = described_class.new(token, website: locked_website).call
            expect(result).to eq(existing_owner)
          end
        end
      end
    end
  end
end
