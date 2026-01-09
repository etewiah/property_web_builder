# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::SyncNewSignupJob, type: :job do
  include ActiveJob::TestHelper

  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website, onboarding_state: 'lead', metadata: {}) }
  let(:mock_client) { instance_double(Pwb::Zoho::Client) }
  let(:mock_service) { instance_double(Pwb::Zoho::LeadSyncService) }

  before do
    allow(Pwb::Zoho::Client).to receive(:instance).and_return(mock_client)
    allow(Pwb::Zoho::LeadSyncService).to receive(:new).and_return(mock_service)
  end

  describe '#perform' do
    context 'when Zoho is enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
        allow(mock_service).to receive(:create_lead_from_signup).and_return('lead_123')
      end

      it 'calls the lead sync service' do
        expect(mock_service).to receive(:create_lead_from_signup)
          .with(user, request_info: { ip: '192.168.1.1' })

        described_class.perform_now(user.id, { 'ip' => '192.168.1.1' })
      end

      it 'symbolizes request info keys' do
        expect(mock_service).to receive(:create_lead_from_signup)
          .with(user, request_info: { ip: '1.2.3.4', utm_source: 'google' })

        described_class.perform_now(user.id, { 'ip' => '1.2.3.4', 'utm_source' => 'google' })
      end
    end

    context 'when Zoho is not enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'does not call the sync service' do
        expect(mock_service).not_to receive(:create_lead_from_signup)

        described_class.perform_now(user.id, {})
      end
    end

    context 'when user is not found' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'returns early without error' do
        expect(mock_service).not_to receive(:create_lead_from_signup)

        # Should not raise
        expect { described_class.perform_now(999_999, {}) }.not_to raise_error
      end
    end

    context 'when user already has Zoho lead ID' do
      let(:synced_user) { create(:pwb_user, website: website, metadata: { 'zoho_lead_id' => 'existing_lead' }) }

      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'skips sync' do
        expect(mock_service).not_to receive(:create_lead_from_signup)

        described_class.perform_now(synced_user.id, {})
      end
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued' do
      expect do
        described_class.perform_later(user.id, { 'ip' => '1.2.3.4' })
      end.to have_enqueued_job(described_class).with(user.id, { 'ip' => '1.2.3.4' })
    end
  end
end
