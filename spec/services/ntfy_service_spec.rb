# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NtfyService do
  let(:website) { FactoryBot.create(:pwb_website) }

  before do
    website.update!(
      ntfy_enabled: true,
      ntfy_server_url: 'https://ntfy.sh',
      ntfy_topic_prefix: 'test-prefix',
      ntfy_notify_inquiries: true,
      ntfy_notify_listings: true,
      ntfy_notify_users: true,
      ntfy_notify_security: true
    )
  end

  describe '.publish' do
    context 'when ntfy is enabled' do
      it 'sends a notification to the ntfy server' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .with(body: 'Test message')
          .to_return(status: 200)

        result = described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test message',
          title: 'Test Title'
        )

        expect(result).to be true
        expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-admin')
          .with(
            body: 'Test message',
            headers: { 'Title' => 'Test Title' }
          )
      end

      it 'includes proper headers for title, priority, and tags' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .to_return(status: 200)

        described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test',
          title: 'My Title',
          priority: NtfyService::PRIORITY_HIGH,
          tags: ['warning', 'bell']
        )

        expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-admin')
          .with(
            headers: {
              'Title' => 'My Title',
              'Priority' => '4',
              'Tags' => 'warning,bell'
            }
          )
      end

      it 'includes click URL when provided' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .to_return(status: 200)

        described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test',
          click_url: 'https://example.com/view'
        )

        expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-admin')
          .with(headers: { 'Click' => 'https://example.com/view' })
      end

      it 'includes authorization header when access token is set' do
        website.update!(ntfy_access_token: 'tk_secret123')

        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .to_return(status: 200)

        described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test'
        )

        expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-admin')
          .with(headers: { 'Authorization' => 'Bearer tk_secret123' })
      end
    end

    context 'when ntfy is disabled' do
      before { website.update!(ntfy_enabled: false) }

      it 'does not send a notification' do
        result = described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test message'
        )

        expect(result).to be false
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end

    context 'when message is blank' do
      it 'does not send a notification' do
        result = described_class.publish(
          website: website,
          channel: 'admin',
          message: ''
        )

        expect(result).to be false
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end

    context 'when server returns an error' do
      it 'returns false and logs the error' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .to_return(status: 500, body: 'Internal Server Error')

        expect(Rails.logger).to receive(:error).with(/Failed to send notification/)

        result = described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test'
        )

        expect(result).to be false
      end
    end

    context 'when network error occurs' do
      it 'returns false and logs the error' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-admin')
          .to_raise(Errno::ECONNREFUSED)

        expect(Rails.logger).to receive(:error).with(/Error sending notification/)

        result = described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test'
        )

        expect(result).to be false
      end
    end

    context 'with custom server URL' do
      before { website.update!(ntfy_server_url: 'https://custom.ntfy.example.com') }

      it 'sends to the custom server' do
        stub_request(:post, 'https://custom.ntfy.example.com/test-prefix-admin')
          .to_return(status: 200)

        described_class.publish(
          website: website,
          channel: 'admin',
          message: 'Test'
        )

        expect(WebMock).to have_requested(:post, 'https://custom.ntfy.example.com/test-prefix-admin')
      end
    end
  end

  describe '.notify_inquiry' do
    let(:contact) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_contact,
          first_name: 'John',
          primary_email: 'john@example.com',
          primary_phone_number: '+1234567890',
          website: website
        )
      end
    end
    let(:message) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_message,
          title: 'Property Inquiry',
          content: 'I am interested in this property.',
          contact: contact,
          website: website
        )
      end
    end

    it 'sends an inquiry notification' do
      stub_request(:post, 'https://ntfy.sh/test-prefix-inquiries')
        .to_return(status: 200)

      described_class.notify_inquiry(website, message)

      expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-inquiries')
        .with(headers: { 'Title' => 'New Inquiry: Property Inquiry' })
    end

    context 'when inquiries notifications are disabled' do
      before { website.update!(ntfy_notify_inquiries: false) }

      it 'does not send a notification' do
        described_class.notify_inquiry(website, message)
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end
  end

  describe '.notify_security_event' do
    it 'sends a security notification for login_failed events' do
      stub_request(:post, 'https://ntfy.sh/test-prefix-security')
        .to_return(status: 200)

      described_class.notify_security_event(website, 'login_failed', {
        email: 'attacker@example.com',
        ip: '192.168.1.100'
      })

      expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-security')
        .with(
          headers: {
            'Title' => 'Failed Login Attempt',
            'Priority' => '4'
          }
        )
    end

    it 'sends an urgent notification for account_locked events' do
      stub_request(:post, 'https://ntfy.sh/test-prefix-security')
        .to_return(status: 200)

      described_class.notify_security_event(website, 'account_locked', {
        email: 'locked@example.com'
      })

      expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-security')
        .with(
          headers: {
            'Title' => 'Account Locked',
            'Priority' => '5'
          }
        )
    end

    context 'when security notifications are disabled' do
      before { website.update!(ntfy_notify_security: false) }

      it 'does not send a notification' do
        described_class.notify_security_event(website, 'login_failed', {})
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end
  end

  describe '.notify_user_event' do
    let(:user) { FactoryBot.create(:pwb_user, email: 'newuser@example.com') }

    it 'sends a notification for user registration' do
      stub_request(:post, 'https://ntfy.sh/test-prefix-users')
        .to_return(status: 200)

      described_class.notify_user_event(website, user, :registered)

      expect(WebMock).to have_requested(:post, 'https://ntfy.sh/test-prefix-users')
        .with(headers: { 'Title' => 'New User Registration' })
    end

    context 'when user notifications are disabled' do
      before { website.update!(ntfy_notify_users: false) }

      it 'does not send a notification' do
        described_class.notify_user_event(website, user, :registered)
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end
  end

  describe '.test_configuration' do
    context 'when configuration is valid' do
      it 'sends a test notification and returns success' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-test')
          .to_return(status: 200)

        result = described_class.test_configuration(website)

        expect(result[:success]).to be true
        expect(result[:message]).to include('successfully')
      end
    end

    context 'when ntfy is not enabled' do
      before { website.update!(ntfy_enabled: false) }

      it 'returns an error without sending' do
        result = described_class.test_configuration(website)

        expect(result[:success]).to be false
        expect(result[:message]).to include('not enabled')
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end

    context 'when topic prefix is missing' do
      before { website.update!(ntfy_topic_prefix: nil) }

      it 'returns an error without sending' do
        result = described_class.test_configuration(website)

        expect(result[:success]).to be false
        expect(result[:message]).to include('prefix')
        expect(WebMock).not_to have_requested(:post, /ntfy/)
      end
    end

    context 'when notification fails' do
      it 'returns failure' do
        stub_request(:post, 'https://ntfy.sh/test-prefix-test')
          .to_return(status: 500)

        result = described_class.test_configuration(website)

        expect(result[:success]).to be false
        expect(result[:message]).to include('Failed')
      end
    end
  end
end
