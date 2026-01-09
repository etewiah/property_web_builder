# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformNtfyService do
  # Helper to stub credentials
  def stub_credentials(config = {})
    allow(Rails.application.credentials).to receive(:dig).with(:platform_ntfy, :topic).and_return(config[:topic])
    allow(Rails.application.credentials).to receive(:dig).with(:platform_ntfy, :server_url).and_return(config[:server_url])
    allow(Rails.application.credentials).to receive(:dig).with(:platform_ntfy, :access_token).and_return(config[:access_token])
  end

  describe '.enabled?' do
    context 'when topic is configured' do
      it 'returns true' do
        stub_credentials(topic: 'test-topic')
        expect(described_class.enabled?).to be true
      end
    end

    context 'when topic is not configured' do
      it 'returns false' do
        stub_credentials(topic: nil)
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe '.test_configuration' do
    context 'when ntfy is not configured' do
      it 'returns failure message' do
        stub_credentials(topic: nil)
        result = described_class.test_configuration
        expect(result[:success]).to be false
        expect(result[:message]).to include('not configured')
      end
    end

    context 'when ntfy is configured' do
      it 'sends test notification' do
        stub_credentials(topic: 'test-topic')
        allow(described_class).to receive(:perform_request).and_return(true)
        
        result = described_class.test_configuration
        expect(result[:success]).to be true
        expect(result[:message]).to include('Test notification sent')
      end
    end
  end

  describe '.notify_user_signup' do
    let(:user) { create(:pwb_user, email: 'test@example.com') }

    context 'when notifications are enabled' do
      it 'sends notification' do
        stub_credentials(topic: 'test-topic')
        allow(described_class).to receive(:perform_request).and_return(true)
        described_class.notify_user_signup(user, reserved_subdomain: 'test')
        expect(described_class).to have_received(:perform_request).once
      end
    end

    context 'when notifications are disabled' do
      it 'does not send notification' do
        stub_credentials(topic: nil)
        expect(described_class).not_to receive(:perform_request)
        described_class.notify_user_signup(user, reserved_subdomain: 'test')
      end
    end
  end

  describe '.notify_provisioning_complete' do
    let!(:website) { create(:pwb_website, subdomain: 'test-site') }

    context 'when notifications are enabled' do
      it 'sends notification' do
        stub_credentials(topic: 'test-topic')
        allow(described_class).to receive(:perform_request).and_return(true)
        described_class.notify_provisioning_complete(website)
        expect(described_class).to have_received(:perform_request).once
      end
    end
  end

  describe '.notify_subscription_activated' do
    let(:website) { create(:pwb_website) }
    let(:plan) { create(:pwb_plan, name: 'Professional', price_cents: 4900) }
    let(:subscription) { create(:pwb_subscription, website: website, plan: plan, status: 'active') }

    context 'when notifications are enabled' do
      it 'sends notification' do
        stub_credentials(topic: 'test-topic')
        allow(described_class).to receive(:perform_request).and_return(true)
        described_class.notify_subscription_activated(subscription)
        expect(described_class).to have_received(:perform_request).once
      end
    end
  end
end
