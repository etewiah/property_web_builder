# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_subscription_events
# Database name: primary
#
#  id              :bigint           not null, primary key
#  event_type      :string           not null
#  metadata        :jsonb            not null
#  created_at      :datetime         not null
#  subscription_id :bigint           not null
#
# Indexes
#
#  idx_on_subscription_id_created_at_3fabb76699      (subscription_id,created_at)
#  index_pwb_subscription_events_on_event_type       (event_type)
#  index_pwb_subscription_events_on_subscription_id  (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (subscription_id => pwb_subscriptions.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe SubscriptionEvent, type: :model do
    let(:website) { create(:pwb_website) }
    let(:subscription) { create(:pwb_subscription, website: website) }

    describe 'associations' do
      it { is_expected.to belong_to(:subscription) }
    end

    describe 'validations' do
      subject { build(:pwb_subscription_event, subscription: subscription) }

      it { is_expected.to validate_presence_of(:event_type) }
    end

    describe 'scopes' do
      let!(:recent_event) { create(:pwb_subscription_event, subscription: subscription, created_at: 1.hour.ago) }
      let!(:old_event) { create(:pwb_subscription_event, subscription: subscription, created_at: 1.week.ago) }
      let!(:activated_event) { create(:pwb_subscription_event, :activated, subscription: subscription) }
      let!(:trial_started_event) { create(:pwb_subscription_event, :trial_started, subscription: subscription) }

      describe '.recent' do
        it 'orders by created_at desc' do
          result = SubscriptionEvent.recent
          expect(result.first.created_at).to be >= result.last.created_at
        end
      end

      describe '.by_type' do
        it 'filters by event_type' do
          expect(SubscriptionEvent.by_type('activated')).to include(activated_event)
          expect(SubscriptionEvent.by_type('activated')).not_to include(trial_started_event)
        end
      end
    end

    describe 'EVENT_TYPES constant' do
      it 'includes expected event types' do
        expected_types = %w[
          trial_started
          activated
          trial_expired
          past_due
          canceled
          expired
          reactivated
          plan_changed
          payment_received
          payment_failed
        ]

        expect(SubscriptionEvent::EVENT_TYPES).to match_array(expected_types)
      end

      it 'is frozen' do
        expect(SubscriptionEvent::EVENT_TYPES).to be_frozen
      end
    end

    describe '#plan' do
      context 'when metadata contains plan_id' do
        let(:plan) { create(:pwb_plan) }
        let(:event) do
          create(:pwb_subscription_event,
            subscription: subscription,
            metadata: { 'plan_id' => plan.id }
          )
        end

        it 'returns the plan' do
          expect(event.plan).to eq(plan)
        end
      end

      context 'when metadata does not contain plan_id' do
        let(:event) do
          create(:pwb_subscription_event,
            subscription: subscription,
            metadata: {}
          )
        end

        it 'returns nil' do
          expect(event.plan).to be_nil
        end
      end

      context 'when plan_id refers to non-existent plan' do
        let(:event) do
          create(:pwb_subscription_event,
            subscription: subscription,
            metadata: { 'plan_id' => 999999 }
          )
        end

        it 'returns nil' do
          expect(event.plan).to be_nil
        end
      end
    end

    describe 'metadata' do
      it 'stores arbitrary JSON data' do
        event = create(:pwb_subscription_event,
          subscription: subscription,
          metadata: {
            'plan_id' => 123,
            'amount_cents' => 9900,
            'currency' => 'USD',
            'custom_field' => 'custom_value'
          }
        )

        expect(event.metadata['plan_id']).to eq(123)
        expect(event.metadata['amount_cents']).to eq(9900)
        expect(event.metadata['currency']).to eq('USD')
        expect(event.metadata['custom_field']).to eq('custom_value')
      end
    end

    describe 'factory traits' do
      it 'creates trial_started event' do
        event = create(:pwb_subscription_event, :trial_started, subscription: subscription)
        expect(event.event_type).to eq('trial_started')
      end

      it 'creates activated event' do
        event = create(:pwb_subscription_event, :activated, subscription: subscription)
        expect(event.event_type).to eq('activated')
      end

      it 'creates canceled event' do
        event = create(:pwb_subscription_event, :canceled, subscription: subscription)
        expect(event.event_type).to eq('canceled')
      end
    end
  end
end
