# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::BaseJob, type: :job do
  # BaseJob is an abstract class. Test the concrete implementations that inherit from it.

  describe '.queue_name' do
    it 'uses the zoho_sync queue' do
      expect(described_class.queue_name).to eq('zoho_sync')
    end
  end

  describe 'helper methods' do
    let(:mock_client) { instance_double(Pwb::Zoho::Client) }

    # Create a concrete test job to test the private methods
    let(:test_job) do
      job = described_class.new
      allow(Pwb::Zoho::Client).to receive(:instance).and_return(mock_client)
      job
    end

    describe '#zoho_enabled?' do
      context 'when Zoho is configured' do
        before do
          allow(mock_client).to receive(:configured?).and_return(true)
        end

        it 'returns true' do
          expect(test_job.send(:zoho_enabled?)).to be true
        end
      end

      context 'when Zoho is not configured' do
        before do
          allow(mock_client).to receive(:configured?).and_return(false)
        end

        it 'returns false' do
          expect(test_job.send(:zoho_enabled?)).to be false
        end
      end
    end

    describe '#lead_sync_service' do
      it 'returns a LeadSyncService instance' do
        allow(mock_client).to receive(:configured?).and_return(true)
        expect(test_job.send(:lead_sync_service)).to be_a(Pwb::Zoho::LeadSyncService)
      end
    end
  end
end
