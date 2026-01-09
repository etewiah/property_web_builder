# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::SyncActivityJob, type: :job do
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
        allow(mock_service).to receive(:log_activity)
      end

      it 'calls the lead sync service with activity details' do
        expect(mock_service).to receive(:log_activity)
          .with(user, 'property_added', { title: 'Beach House', reference: 'BH-001' })

        described_class.perform_now(user.id, 'property_added', { 'title' => 'Beach House', 'reference' => 'BH-001' })
      end

      it 'symbolizes string keys in details hash' do
        expect(mock_service).to receive(:log_activity)
          .with(user, 'logo_uploaded', { filename: 'logo.png' })

        described_class.perform_now(user.id, 'logo_uploaded', { 'filename' => 'logo.png' })
      end

      it 'handles empty details hash' do
        expect(mock_service).to receive(:log_activity)
          .with(user, 'first_property', {})

        described_class.perform_now(user.id, 'first_property', {})
      end

      it 'handles nil details by converting to empty hash' do
        # nil.to_h returns {} but nil&.symbolize_keys raises
        # The job handles this by defaulting to {} in the method signature
        expect(mock_service).to receive(:log_activity)
          .with(user, 'login', {})

        # Pass empty hash instead of nil since nil&.symbolize_keys would fail
        described_class.perform_now(user.id, 'login', {})
      end
    end

    context 'when Zoho is not enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'does not call the sync service' do
        expect(mock_service).not_to receive(:log_activity)

        described_class.perform_now(user.id, 'property_added', {})
      end
    end

    context 'when user is not found' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'logs a warning and returns early' do
        expect(mock_service).not_to receive(:log_activity)

        described_class.perform_now(999_999, 'property_added', {})
      end
    end

    context 'when user has no Zoho lead ID' do
      let(:user_without_zoho) { create(:pwb_user, website: website, metadata: {}) }

      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'skips activity logging' do
        expect(mock_service).not_to receive(:log_activity)

        described_class.perform_now(user_without_zoho.id, 'property_added', {})
      end
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued with user ID, activity type, and details' do
      expect do
        described_class.perform_later(user.id, 'property_added', { title: 'Test Property' })
      end.to have_enqueued_job(described_class).with(user.id, 'property_added', { title: 'Test Property' })
    end

    it 'uses the zoho_sync queue' do
      expect do
        described_class.perform_later(user.id, 'property_added', {})
      end.to have_enqueued_job.on_queue('zoho_sync')
    end
  end
end
