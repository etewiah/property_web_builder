# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::TrialReminderJob, type: :job do
  include ActiveJob::TestHelper

  let(:plan) { create(:pwb_plan, display_name: 'Professional') }
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
        allow(mock_service).to receive(:update_trial_ending)
      end

      context 'with trial ending in 3 days' do
        let!(:website) { create(:pwb_website, provisioning_state: 'live') }
        let!(:owner) { create(:pwb_user, website: website, metadata: { 'zoho_lead_id' => 'lead_3' }) }
        let!(:membership) { create(:pwb_user_membership, user: owner, website: website, role: 'owner', active: true) }
        let!(:subscription) do
          # Set trial_ends_at to middle of the target day
          target_date = Date.current + 3.days
          create(:pwb_subscription,
                 website: website,
                 plan: plan,
                 status: 'trialing',
                 trial_ends_at: target_date.beginning_of_day + 12.hours)
        end

        it 'finds subscriptions ending in 3 days' do
          # Verify the subscription is findable by the job's query
          target_date = Date.current + 3.days
          found = Pwb::Subscription.trialing
                                   .where(trial_ends_at: target_date.beginning_of_day..target_date.end_of_day)

          expect(found.count).to eq(1)
        end

        it 'website has owner accessible' do
          # Force reload to simulate what happens in the job
          found_sub = Pwb::Subscription.find(subscription.id)
          expect(found_sub.website.owner).to eq(owner)
        end

        it 'calls update_trial_ending with correct days parameter' do
          # If owner is found, it will call update_trial_ending with days=3
          # Allow any user but verify the days parameter
          allow(mock_service).to receive(:update_trial_ending)
          described_class.perform_now

          # Verify the method was called with days=3
          expect(mock_service).to have_received(:update_trial_ending).with(anything, 3)
        end
      end

      context 'when subscription has no owner' do
        let(:website) { create(:pwb_website) }
        let!(:subscription) do
          target_date = Date.current + 3.days
          create(:pwb_subscription,
                 website: website,
                 plan: plan,
                 status: 'trialing',
                 trial_ends_at: target_date.to_time + 12.hours)
        end

        it 'skips the subscription' do
          expect(mock_service).not_to receive(:update_trial_ending)

          described_class.perform_now
        end
      end

      context 'when Zoho API fails' do
        let(:website) { create(:pwb_website) }
        let(:owner) { create(:pwb_user, website: website, metadata: { 'zoho_lead_id' => 'lead_123' }) }
        let!(:membership) { create(:pwb_user_membership, user: owner, website: website, role: 'owner', active: true) }
        let!(:subscription) do
          target_date = Date.current + 3.days
          create(:pwb_subscription,
                 website: website,
                 plan: plan,
                 status: 'trialing',
                 trial_ends_at: target_date.to_time + 12.hours)
        end

        before do
          allow(mock_service).to receive(:update_trial_ending)
            .and_raise(Pwb::Zoho::ApiError.new('API Error'))
        end

        it 'does not raise an exception' do
          # The job should catch and log the error, not raise
          expect { described_class.perform_now }.not_to raise_error
        end
      end

      context 'when no trials are ending' do
        it 'completes without errors' do
          expect { described_class.perform_now }.not_to raise_error
        end
      end
    end

    context 'when Zoho is not enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'returns early without processing' do
        expect(mock_service).not_to receive(:update_trial_ending)

        described_class.perform_now
      end
    end
  end

  describe 'REMINDER_DAYS constant' do
    it 'includes expected days' do
      expect(described_class::REMINDER_DAYS).to contain_exactly(3, 2, 1, 0)
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued without arguments' do
      expect do
        described_class.perform_later
      end.to have_enqueued_job(described_class)
    end

    it 'uses the zoho_sync queue' do
      expect do
        described_class.perform_later
      end.to have_enqueued_job.on_queue('zoho_sync')
    end
  end
end
