# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::SyncSubscriptionJob, type: :job do
  include ActiveJob::TestHelper

  let(:plan) { create(:pwb_plan, display_name: 'Professional') }
  let(:website) { create(:pwb_website) }
  let(:subscription) { create(:pwb_subscription, website: website, plan: plan) }
  let(:owner) { create(:pwb_user, website: website, metadata: { 'zoho_lead_id' => 'lead_123' }) }
  let(:mock_client) { instance_double(Pwb::Zoho::Client) }
  let(:mock_service) { instance_double(Pwb::Zoho::LeadSyncService) }

  before do
    # Set up owner membership
    create(:pwb_user_membership, user: owner, website: website, role: 'owner', active: true)

    allow(Pwb::Zoho::Client).to receive(:instance).and_return(mock_client)
    allow(Pwb::Zoho::LeadSyncService).to receive(:new).and_return(mock_service)
  end

  describe '#perform' do
    context 'when Zoho is enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      describe 'with created event' do
        it 'updates lead with plan selection' do
          expect(mock_service).to receive(:update_lead_plan_selected)
            .with(owner, subscription)

          described_class.perform_now(subscription.id, 'created')
        end
      end

      describe 'with plan_changed event' do
        it 'updates lead with new plan' do
          expect(mock_service).to receive(:update_lead_plan_selected)
            .with(owner, subscription)

          described_class.perform_now(subscription.id, 'plan_changed')
        end
      end

      describe 'with activated event' do
        it 'converts lead to customer' do
          expect(mock_service).to receive(:convert_lead_to_customer)
            .with(owner, subscription)

          described_class.perform_now(subscription.id, 'activated')
        end
      end

      describe 'with canceled event' do
        it 'marks lead as lost with cancellation reason' do
          expect(mock_service).to receive(:mark_lead_lost)
            .with(owner, 'User Canceled')

          described_class.perform_now(subscription.id, 'canceled')
        end
      end

      describe 'with expired event' do
        it 'marks lead as lost with expiration reason' do
          expect(mock_service).to receive(:mark_lead_lost)
            .with(owner, 'Trial Expired')

          described_class.perform_now(subscription.id, 'expired')
        end
      end

      describe 'with invalid event' do
        it 'does nothing' do
          expect(mock_service).not_to receive(:update_lead_plan_selected)
          expect(mock_service).not_to receive(:convert_lead_to_customer)
          expect(mock_service).not_to receive(:mark_lead_lost)

          described_class.perform_now(subscription.id, 'invalid_event')
        end
      end
    end

    context 'when Zoho is not enabled' do
      before do
        allow(mock_client).to receive(:configured?).and_return(false)
      end

      it 'does not call the sync service' do
        expect(mock_service).not_to receive(:update_lead_plan_selected)

        described_class.perform_now(subscription.id, 'created')
      end
    end

    context 'when subscription is not found' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
      end

      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/Subscription .* not found/)

        described_class.perform_now(999_999, 'created')
      end
    end

    context 'when website has no owner' do
      before do
        allow(mock_client).to receive(:configured?).and_return(true)
        # Remove owner membership
        website.user_memberships.destroy_all
      end

      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/No owner found/)

        described_class.perform_now(subscription.id, 'created')
      end
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued with subscription ID and event' do
      expect do
        described_class.perform_later(subscription.id, 'activated')
      end.to have_enqueued_job(described_class).with(subscription.id, 'activated')
    end

    it 'uses the zoho_sync queue' do
      expect do
        described_class.perform_later(subscription.id, 'activated')
      end.to have_enqueued_job.on_queue('zoho_sync')
    end
  end

  describe 'VALID_EVENTS constant' do
    it 'includes all expected events' do
      expect(described_class::VALID_EVENTS).to contain_exactly(
        'created', 'plan_changed', 'activated', 'canceled', 'expired'
      )
    end
  end
end
