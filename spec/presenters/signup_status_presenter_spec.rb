# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignupStatusPresenter do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website) }
  let(:signup_token) { 'test-token-123' }

  subject(:presenter) { described_class.new(user: user, signup_token: signup_token) }

  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  describe '#to_h' do
    context 'when user has a website' do
      before do
        create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true)
      end

      it 'returns provisioning status' do
        result = presenter.to_h

        expect(result[:stage]).to eq('provisioning')
        expect(result[:signup_token]).to eq(signup_token)
        expect(result[:email]).to eq(user.email)
        expect(result[:subdomain]).to eq(website.subdomain)
        expect(result[:provisioning_status]).to eq(website.provisioning_state)
        expect(result[:progress]).to eq(website.provisioning_progress)
        expect(result[:message]).to eq(website.provisioning_status_message)
      end

      context 'when website is live' do
        before do
          website.update!(provisioning_state: 'live')
        end

        it 'includes website URLs' do
          result = presenter.to_h

          expect(result[:complete]).to be true
          expect(result[:website_url]).to be_present
          expect(result[:admin_url]).to include('/site_admin')
        end
      end

      context 'when website is locked' do
        before do
          website.update!(provisioning_state: 'locked_pending_email_verification')
        end

        it 'includes locked state information' do
          result = presenter.to_h

          expect(result[:locked]).to be true
          expect(result[:locked_mode]).to eq(:pending_email_verification)
          expect(result[:email_verified]).to be false
          expect(result[:registration_url]).to include('/pwb_sign_up')
        end
      end
    end

    context 'when user has reserved subdomain but no website' do
      let(:user_without_website) { create(:pwb_user) }
      let(:presenter) { described_class.new(user: user_without_website, signup_token: signup_token) }

      before do
        create(:pwb_subdomain, :reserved, reserved_by_email: user_without_website.email)
      end

      it 'returns subdomain reserved status' do
        result = presenter.to_h

        expect(result[:stage]).to eq('subdomain_reserved')
        expect(result[:signup_token]).to eq(signup_token)
        expect(result[:email]).to eq(user_without_website.email)
        expect(result[:progress]).to eq(10)
        expect(result[:next_step]).to eq('configure')
        expect(result[:complete]).to be false
      end
    end

    context 'when user has only email (no website, no subdomain)' do
      let(:user_email_only) { create(:pwb_user) }
      let(:presenter) { described_class.new(user: user_email_only, signup_token: signup_token) }

      it 'returns email captured status' do
        result = presenter.to_h

        expect(result[:stage]).to eq('email_captured')
        expect(result[:signup_token]).to eq(signup_token)
        expect(result[:email]).to eq(user_email_only.email)
        expect(result[:subdomain]).to be_nil
        expect(result[:progress]).to eq(5)
        expect(result[:next_step]).to eq('configure')
        expect(result[:complete]).to be false
      end
    end
  end
end
