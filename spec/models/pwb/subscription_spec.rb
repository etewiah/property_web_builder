# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Subscription do
    let(:plan) { Plan.create!(name: 'test', slug: 'test', display_name: 'Test', property_limit: 10, features: %w[analytics]) }
    let(:website) { FactoryBot.create(:pwb_website) }

    describe 'associations' do
      it 'belongs to website' do
        subscription = Subscription.new(website: website, plan: plan)
        expect(subscription.website).to eq(website)
      end

      it 'belongs to plan' do
        subscription = Subscription.new(website: website, plan: plan)
        expect(subscription.plan).to eq(plan)
      end
    end

    describe 'validations' do
      it 'validates website_id uniqueness' do
        Subscription.create!(website: website, plan: plan)
        duplicate = Subscription.new(website: website, plan: plan)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:website_id]).to be_present
      end
    end

    describe 'AASM states' do
      let(:subscription) { Subscription.create!(website: website, plan: plan, status: 'trialing', trial_ends_at: 14.days.from_now) }

      describe '#activate' do
        it 'transitions from trialing to active' do
          expect(subscription).to be_trialing
          subscription.activate!
          expect(subscription).to be_active
        end

        it 'creates an event' do
          expect { subscription.activate! }.to change { subscription.events.count }.by(1)
          expect(subscription.events.last.event_type).to eq('activated')
        end
      end

      describe '#cancel' do
        before { subscription.activate! }

        it 'transitions from active to canceled' do
          expect(subscription).to be_active
          subscription.cancel!
          expect(subscription).to be_canceled
        end

        it 'sets canceled_at' do
          subscription.cancel!
          expect(subscription.canceled_at).to be_present
        end
      end

      describe '#expire_trial' do
        it 'transitions from trialing to expired when trial ended' do
          subscription.update!(trial_ends_at: 1.day.ago)
          expect(subscription.may_expire_trial?).to be true
          subscription.expire_trial!
          expect(subscription).to be_expired
        end

        it 'does not expire if trial has not ended' do
          subscription.update!(trial_ends_at: 1.day.from_now)
          expect(subscription.may_expire_trial?).to be false
        end
      end
    end

    describe '#in_good_standing?' do
      it 'returns true for trialing' do
        subscription = Subscription.new(status: 'trialing')
        expect(subscription.in_good_standing?).to be true
      end

      it 'returns true for active' do
        subscription = Subscription.new(status: 'active')
        expect(subscription.in_good_standing?).to be true
      end

      it 'returns false for past_due' do
        subscription = Subscription.new(status: 'past_due')
        expect(subscription.in_good_standing?).to be false
      end

      it 'returns false for canceled' do
        subscription = Subscription.new(status: 'canceled')
        expect(subscription.in_good_standing?).to be false
      end
    end

    describe '#allows_access?' do
      it 'returns true for trialing, active, and past_due' do
        %w[trialing active past_due].each do |status|
          subscription = Subscription.new(status: status)
          expect(subscription.allows_access?).to be true
        end
      end

      it 'returns false for canceled and expired' do
        %w[canceled expired].each do |status|
          subscription = Subscription.new(status: status)
          expect(subscription.allows_access?).to be false
        end
      end
    end

    describe '#trial_days_remaining' do
      let(:subscription) { Subscription.create!(website: website, plan: plan, status: 'trialing') }

      it 'returns days remaining when trialing' do
        subscription.update!(trial_ends_at: 5.days.from_now)
        expect(subscription.trial_days_remaining).to eq(5)
      end

      it 'returns 0 when trial has ended' do
        subscription.update!(trial_ends_at: 1.day.ago)
        expect(subscription.trial_days_remaining).to eq(0)
      end

      it 'returns nil when not trialing' do
        subscription.activate!
        expect(subscription.trial_days_remaining).to be_nil
      end
    end

    describe '#within_property_limit?' do
      let(:limited_plan) { Plan.create!(name: 'limited', slug: 'limited', display_name: 'Limited', property_limit: 5) }
      let(:unlimited_plan) { Plan.create!(name: 'unlimited', slug: 'unlimited', display_name: 'Unlimited', property_limit: nil) }

      it 'returns true when within limit' do
        subscription = Subscription.new(plan: limited_plan)
        expect(subscription.within_property_limit?(3)).to be true
        expect(subscription.within_property_limit?(5)).to be true
      end

      it 'returns false when exceeding limit' do
        subscription = Subscription.new(plan: limited_plan)
        expect(subscription.within_property_limit?(6)).to be false
      end

      it 'always returns true for unlimited plans' do
        subscription = Subscription.new(plan: unlimited_plan)
        expect(subscription.within_property_limit?(1000)).to be true
      end
    end

    describe '#has_feature?' do
      let(:subscription) { Subscription.create!(website: website, plan: plan) }

      it 'delegates to plan' do
        expect(subscription.has_feature?(:analytics)).to be true
        expect(subscription.has_feature?(:custom_domain)).to be false
      end
    end

    describe '#change_plan' do
      let(:subscription) { Subscription.create!(website: website, plan: plan) }
      let(:new_plan) { Plan.create!(name: 'pro', slug: 'pro', display_name: 'Pro', property_limit: 100) }

      it 'changes the plan' do
        expect(subscription.change_plan(new_plan)).to be true
        expect(subscription.reload.plan).to eq(new_plan)
      end

      it 'creates a plan_changed event' do
        expect { subscription.change_plan(new_plan) }.to change { subscription.events.count }.by(1)
        expect(subscription.events.last.event_type).to eq('plan_changed')
      end

      it 'returns false when changing to same plan' do
        expect(subscription.change_plan(plan)).to be false
      end
    end
  end
end
