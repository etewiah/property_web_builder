# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteSubscribable, type: :model do
  let(:website) { create(:pwb_website) }
  let(:plan) { create(:pwb_plan, :starter, property_limit: 10) }
  let(:subscription) { create(:pwb_subscription, website: website, plan: plan) }

  describe '#plan' do
    it 'returns nil when no subscription exists' do
      expect(website.plan).to be_nil
    end

    it 'returns the plan from subscription' do
      subscription
      expect(website.plan).to eq(plan)
    end
  end

  describe '#has_active_subscription?' do
    it 'returns false when no subscription exists' do
      expect(website.has_active_subscription?).to be false
    end

    it 'returns true when subscription is in good standing' do
      subscription
      allow(subscription).to receive(:in_good_standing?).and_return(true)
      website.reload
      expect(website.has_active_subscription?).to be true
    end
  end

  describe '#in_trial?' do
    it 'returns false when no subscription exists' do
      expect(website.in_trial?).to be false
    end

    it 'returns true when subscription is trialing' do
      subscription.update!(status: 'trialing')
      website.reload
      expect(website.in_trial?).to be true
    end
  end

  describe '#trial_days_remaining' do
    it 'returns nil when no subscription exists' do
      expect(website.trial_days_remaining).to be_nil
    end

    it 'delegates to subscription' do
      subscription
      allow(subscription).to receive(:trial_days_remaining).and_return(7)
      website.reload
      expect(website.trial_days_remaining).to eq(7)
    end
  end

  describe '#has_feature?' do
    it 'returns false when no subscription exists' do
      expect(website.has_feature?(:premium_themes)).to be false
    end

    it 'delegates to subscription' do
      subscription
      allow(subscription).to receive(:has_feature?).with(:premium_themes).and_return(true)
      website.reload
      expect(website.has_feature?(:premium_themes)).to be true
    end
  end

  describe '#can_add_property?' do
    it 'returns true when no subscription exists (legacy behavior)' do
      expect(website.can_add_property?).to be true
    end

    it 'checks property limit with subscription' do
      subscription
      allow(subscription).to receive(:within_property_limit?).with(1).and_return(true)
      website.reload
      expect(website.can_add_property?).to be true
    end
  end

  describe '#remaining_properties' do
    it 'returns nil when no subscription exists' do
      expect(website.remaining_properties).to be_nil
    end

    it 'delegates to subscription' do
      subscription
      allow(subscription).to receive(:remaining_properties).and_return(5)
      website.reload
      expect(website.remaining_properties).to eq(5)
    end
  end

  describe '#property_limit' do
    it 'returns nil when no subscription exists' do
      expect(website.property_limit).to be_nil
    end

    it 'returns plan property limit' do
      subscription
      website.reload
      expect(website.property_limit).to eq(10)
    end
  end
end
