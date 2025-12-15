# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SubscriptionService do
    let(:service) { SubscriptionService.new }
    let(:plan) { Plan.create!(name: 'starter', slug: 'starter', display_name: 'Starter', trial_days: 14, property_limit: 25) }
    let(:website) { FactoryBot.create(:pwb_website) }

    describe '#create_trial' do
      it 'creates a trialing subscription' do
        result = service.create_trial(website: website, plan: plan)

        expect(result[:success]).to be true
        expect(result[:subscription]).to be_trialing
        expect(result[:subscription].plan).to eq(plan)
        expect(result[:subscription].trial_ends_at).to be_within(1.minute).of(14.days.from_now)
      end

      it 'uses default plan when not specified' do
        # Ensure our starter plan is the default (first active ordered)
        plan.update!(position: 0)

        result = service.create_trial(website: website)

        expect(result[:success]).to be true
        expect(result[:subscription].plan).to eq(plan) # starter is default
      end

      it 'allows custom trial duration' do
        result = service.create_trial(website: website, plan: plan, trial_days: 30)

        expect(result[:success]).to be true
        expect(result[:subscription].trial_ends_at).to be_within(1.minute).of(30.days.from_now)
      end

      it 'fails if website already has active subscription' do
        service.create_trial(website: website, plan: plan)

        result = service.create_trial(website: website, plan: plan)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Website already has an active subscription')
      end

      it 'creates trial_started event' do
        result = service.create_trial(website: website, plan: plan)

        event = result[:subscription].events.last
        expect(event.event_type).to eq('trial_started')
        expect(event.metadata['plan_slug']).to eq('starter')
      end
    end

    describe '#activate' do
      let!(:subscription) { service.create_trial(website: website, plan: plan)[:subscription] }

      it 'activates a trialing subscription' do
        result = service.activate(subscription: subscription)

        expect(result[:success]).to be true
        expect(subscription.reload).to be_active
      end

      it 'stores external payment provider info' do
        result = service.activate(
          subscription: subscription,
          external_id: 'sub_123',
          external_provider: 'stripe',
          external_customer_id: 'cus_456'
        )

        expect(result[:success]).to be true
        subscription.reload
        expect(subscription.external_id).to eq('sub_123')
        expect(subscription.external_provider).to eq('stripe')
        expect(subscription.external_customer_id).to eq('cus_456')
      end

      it 'fails for already active subscription' do
        subscription.activate!

        result = service.activate(subscription: subscription)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Subscription is already active')
      end
    end

    describe '#cancel' do
      let!(:subscription) do
        sub = service.create_trial(website: website, plan: plan)[:subscription]
        sub.activate!
        sub
      end

      it 'cancels at period end by default' do
        result = service.cancel(subscription: subscription)

        expect(result[:success]).to be true
        expect(subscription.reload.cancel_at_period_end).to be true
        expect(subscription).to be_active # Still active until period end
      end

      it 'cancels immediately when requested' do
        result = service.cancel(subscription: subscription, at_period_end: false)

        expect(result[:success]).to be true
        expect(subscription.reload).to be_canceled
        expect(subscription.canceled_at).to be_present
      end

      it 'fails for already canceled subscription' do
        subscription.cancel!

        result = service.cancel(subscription: subscription)

        expect(result[:success]).to be false
      end
    end

    describe '#change_plan' do
      let(:pro_plan) { Plan.create!(name: 'pro', slug: 'pro', display_name: 'Pro', property_limit: 100) }
      let!(:subscription) { service.create_trial(website: website, plan: plan)[:subscription] }

      it 'changes the plan' do
        result = service.change_plan(subscription: subscription, new_plan: pro_plan)

        expect(result[:success]).to be true
        expect(subscription.reload.plan).to eq(pro_plan)
        expect(result[:old_plan]).to eq(plan)
        expect(result[:new_plan]).to eq(pro_plan)
      end

      it 'fails when changing to same plan' do
        result = service.change_plan(subscription: subscription, new_plan: plan)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('New plan is the same as current plan')
      end

      it 'fails downgrade when exceeding new limit' do
        # Create properties exceeding the new plan limit
        small_plan = Plan.create!(name: 'small', slug: 'small', display_name: 'Small', property_limit: 2)
        3.times { FactoryBot.create(:pwb_realty_asset, website: website) }

        result = service.change_plan(subscription: subscription, new_plan: small_plan)

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('Cannot downgrade')
      end

      it 'creates plan_changed event' do
        result = service.change_plan(subscription: subscription, new_plan: pro_plan)

        event = subscription.events.find_by(event_type: 'plan_changed')
        expect(event).to be_present
        expect(event.metadata['old_plan_slug']).to eq('starter')
        expect(event.metadata['new_plan_slug']).to eq('pro')
      end
    end

    describe '#expire_ended_trials' do
      it 'expires trials that have ended' do
        # Create expired trial
        expired_sub = service.create_trial(website: website, plan: plan)[:subscription]
        expired_sub.update!(trial_ends_at: 1.day.ago)

        # Create active trial
        website2 = FactoryBot.create(:pwb_website)
        active_sub = service.create_trial(website: website2, plan: plan)[:subscription]

        result = service.expire_ended_trials

        expect(result[:expired_count]).to eq(1)
        expect(expired_sub.reload).to be_expired
        expect(active_sub.reload).to be_trialing
      end
    end

    describe '#status_for' do
      it 'returns status summary for website with subscription' do
        service.create_trial(website: website, plan: plan)

        status = service.status_for(website)

        expect(status[:status]).to eq('trialing')
        expect(status[:has_subscription]).to be true
        expect(status[:plan_name]).to eq('Starter')
        expect(status[:in_good_standing]).to be true
        expect(status[:trial_days_remaining]).to eq(14)
        expect(status[:property_limit]).to eq(25)
      end

      it 'returns none status for website without subscription' do
        status = service.status_for(website)

        expect(status[:status]).to eq('none')
        expect(status[:has_subscription]).to be false
      end
    end
  end
end
