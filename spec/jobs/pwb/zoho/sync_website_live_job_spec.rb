# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::SyncWebsiteLiveJob, type: :job do
  include ActiveJob::TestHelper

  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, website: website, metadata: { 'zoho_lead_id' => 'lead_123' }) }
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
        allow(mock_service).to receive(:update_lead_website_live)
      end

      it 'calls the lead sync service with user and website' do
        expect(mock_service).to receive(:update_lead_website_live)
          .with(user, website)

        described_class.perform_now(user.id, website.id)
      end
    end

    context 'when Zoho is not enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'does not call the sync service' do
        expect(mock_service).not_to receive(:update_lead_website_live)

        described_class.perform_now(user.id, website.id)
      end
    end

    context 'when user is not found' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/User .* or website .* not found/)
        expect(mock_service).not_to receive(:update_lead_website_live)

        described_class.perform_now(999_999, website.id)
      end
    end

    context 'when website is not found' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/User .* or website .* not found/)
        expect(mock_service).not_to receive(:update_lead_website_live)

        described_class.perform_now(user.id, 999_999)
      end
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued with user ID and website ID' do
      expect do
        described_class.perform_later(user.id, website.id)
      end.to have_enqueued_job(described_class).with(user.id, website.id)
    end

    it 'uses the zoho_sync queue' do
      expect do
        described_class.perform_later(user.id, website.id)
      end.to have_enqueued_job.on_queue('zoho_sync')
    end
  end
end
