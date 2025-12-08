# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NtfyNotificationJob, type: :job do
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

  describe '#perform' do
    context 'when website has ntfy disabled' do
      before { website.update!(ntfy_enabled: false) }

      it 'does not send any notification' do
        expect(NtfyService).not_to receive(:notify_inquiry)

        described_class.new.perform(website.id, :inquiry, 123)
      end
    end

    context 'when website is not found' do
      it 'discards the job without error' do
        expect {
          described_class.new.perform(999999, :inquiry, 123)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'inquiry notifications' do
      let(:contact) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_contact, website: website)
        end
      end
      let(:message) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_message, website: website, contact: contact)
        end
      end

      it 'calls NtfyService.notify_inquiry' do
        stub_request(:post, /ntfy/).to_return(status: 200)

        # The job loads Message via Pwb::Message which may differ from factory class
        expect(NtfyService).to receive(:notify_inquiry) do |ws, msg|
          expect(ws.id).to eq(website.id)
          expect(msg.id).to eq(message.id)
        end

        described_class.new.perform(website.id, :inquiry, message.id)
      end

      it 'raises error when message not found' do
        expect {
          described_class.new.perform(website.id, :inquiry, 999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'security notifications' do
      it 'calls NtfyService.notify_security_event with symbolized details' do
        stub_request(:post, /ntfy/).to_return(status: 200)

        expect(NtfyService).to receive(:notify_security_event).with(
          website,
          'login_failed',
          { email: 'test@example.com', ip: '127.0.0.1' }
        )

        described_class.new.perform(
          website.id,
          :security,
          nil,
          nil,
          'login_failed',
          { 'email' => 'test@example.com', 'ip' => '127.0.0.1' }
        )
      end

      it 'handles nil details gracefully' do
        stub_request(:post, /ntfy/).to_return(status: 200)

        expect(NtfyService).to receive(:notify_security_event).with(
          website,
          'account_locked',
          {}
        )

        described_class.new.perform(website.id, :security, nil, nil, 'account_locked', nil)
      end
    end

    describe 'user event notifications' do
      let(:user) { FactoryBot.create(:pwb_user) }

      it 'calls NtfyService.notify_user_event' do
        stub_request(:post, /ntfy/).to_return(status: 200)

        expect(NtfyService).to receive(:notify_user_event).with(
          website,
          user,
          :registered
        )

        described_class.new.perform(website.id, :user_event, user.id, nil, :registered)
      end
    end

    describe 'admin notifications' do
      it 'calls NtfyService.notify_admin with details' do
        stub_request(:post, /ntfy/).to_return(status: 200)

        expect(NtfyService).to receive(:notify_admin).with(
          website,
          'Custom Title',
          'Custom message body',
          { priority: 4 }
        )

        described_class.new.perform(
          website.id,
          :admin,
          nil,
          nil,
          'Custom Title',
          { 'message' => 'Custom message body', 'priority' => 4 }
        )
      end
    end

    describe 'unknown notification type' do
      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Unknown notification type: unknown_type/)

        described_class.new.perform(website.id, :unknown_type)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued in the notifications queue' do
      expect(described_class.new.queue_name).to eq('notifications')
    end
  end
end
