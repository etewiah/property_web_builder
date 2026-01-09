# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformNtfyService do
  around do |example|
    # Backup original ENV values
    original_env = ENV.to_h.dup
    
    # Set test ENV values
    ENV['PLATFORM_NTFY_ENABLED'] = 'false'
    ENV['PLATFORM_NTFY_SERVER_URL'] = 'https://ntfy.sh'
    ENV['PLATFORM_NTFY_TOPIC_PREFIX'] = 'pwb-platform'
    ENV['PLATFORM_NTFY_NOTIFY_SIGNUPS'] = 'true'
    ENV['PLATFORM_NTFY_NOTIFY_PROVISIONING'] = 'true'
    ENV['PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS'] = 'true'
    ENV['PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH'] = 'true'
    ENV['PLATFORM_DOMAIN'] = 'propertywebbuilder.com'
    ENV['TENANT_ADMIN_DOMAIN'] = 'admin.propertywebbuilder.com'
    
    # Run example
    example.run
    
    # Restore original ENV
    ENV.replace(original_env)
  end

  describe '.enabled?' do
    context 'when PLATFORM_NTFY_ENABLED is true' do
      it 'returns true' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'true'
        expect(described_class.enabled?).to be true
      end
    end

    context 'when PLATFORM_NTFY_ENABLED is false' do
      it 'returns false' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'false'
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe '.test_configuration' do
    context 'when ntfy is disabled' do
      it 'returns failure message' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'false'
        result = described_class.test_configuration
        expect(result[:success]).to be false
        expect(result[:message]).to include('not enabled')
      end
    end

    context 'when ntfy is enabled but topic prefix is missing' do
      it 'returns failure message' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'true'
        ENV['PLATFORM_NTFY_TOPIC_PREFIX'] = ''
        result = described_class.test_configuration
        expect(result[:success]).to be false
        expect(result[:message]).to include('Topic prefix is required')
      end
    end
  end

  describe '.notify_user_signup' do
    let(:user) { create(:pwb_user, email: 'test@example.com') }

    context 'when signups notifications are disabled' do
      it 'does not send notification' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'false'
        expect(described_class).not_to receive(:perform_request)
        described_class.notify_user_signup(user, reserved_subdomain: 'test')
      end
    end

    context 'when signups notifications are enabled' do
      it 'sends notification' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'true'
        allow(described_class).to receive(:perform_request).and_return(true)
        described_class.notify_user_signup(user, reserved_subdomain: 'test')
        expect(described_class).to have_received(:perform_request).once
      end
    end
  end

  describe '.notify_provisioning_complete' do
    let!(:website) { create(:pwb_website, subdomain: 'test-site') }

    context 'when provisioning notifications are enabled' do
      it 'sends notification' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'true'
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

    context 'when subscription notifications are enabled' do
      it 'sends notification' do
        ENV['PLATFORM_NTFY_ENABLED'] = 'true'
        allow(described_class).to receive(:perform_request).and_return(true)
        described_class.notify_subscription_activated(subscription)
        expect(described_class).to have_received(:perform_request).once
      end
    end
  end
end
