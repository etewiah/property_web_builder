# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Plan do
    describe 'validations' do
      it 'validates presence of required fields' do
        plan = Plan.new
        expect(plan).not_to be_valid
        expect(plan.errors[:name]).to be_present
        expect(plan.errors[:slug]).to be_present
        expect(plan.errors[:display_name]).to be_present
      end

      it 'validates slug format' do
        plan = Plan.new(name: 'Test', slug: 'Invalid Slug!', display_name: 'Test Plan')
        expect(plan).not_to be_valid
        expect(plan.errors[:slug]).to be_present
      end

      it 'validates slug uniqueness' do
        Plan.create!(name: 'test1', slug: 'test-slug', display_name: 'Test 1')
        plan2 = Plan.new(name: 'test2', slug: 'test-slug', display_name: 'Test 2')
        expect(plan2).not_to be_valid
        expect(plan2.errors[:slug]).to include('has already been taken')
      end

      it 'validates billing_interval inclusion' do
        plan = Plan.new(
          name: 'test', slug: 'test', display_name: 'Test',
          billing_interval: 'invalid'
        )
        expect(plan).not_to be_valid
        expect(plan.errors[:billing_interval]).to be_present
      end
    end

    describe 'scopes' do
      before do
        Plan.delete_all
        @active_plan = Plan.create!(name: 'active', slug: 'active', display_name: 'Active', active: true, public: true, position: 1)
        @inactive_plan = Plan.create!(name: 'inactive', slug: 'inactive', display_name: 'Inactive', active: false, public: true, position: 2)
        @private_plan = Plan.create!(name: 'private', slug: 'private', display_name: 'Private', active: true, public: false, position: 3)
      end

      it 'active scope returns only active plans' do
        expect(Plan.active).to include(@active_plan, @private_plan)
        expect(Plan.active).not_to include(@inactive_plan)
      end

      it 'public_plans scope returns only public plans' do
        expect(Plan.public_plans).to include(@active_plan, @inactive_plan)
        expect(Plan.public_plans).not_to include(@private_plan)
      end

      it 'for_display returns active public plans ordered by position' do
        plans = Plan.for_display
        expect(plans).to eq([@active_plan])
      end
    end

    describe '#has_feature?' do
      let(:plan) { Plan.new(features: %w[analytics custom_domain]) }

      it 'returns true for included features' do
        expect(plan.has_feature?(:analytics)).to be true
        expect(plan.has_feature?('custom_domain')).to be true
      end

      it 'returns false for excluded features' do
        expect(plan.has_feature?(:api_access)).to be false
      end
    end

    describe '#unlimited_properties?' do
      it 'returns true when property_limit is nil' do
        plan = Plan.new(property_limit: nil)
        expect(plan.unlimited_properties?).to be true
      end

      it 'returns false when property_limit is set' do
        plan = Plan.new(property_limit: 25)
        expect(plan.unlimited_properties?).to be false
      end
    end

    describe '#formatted_price' do
      it 'returns Free for zero price' do
        plan = Plan.new(price_cents: 0)
        expect(plan.formatted_price).to eq('Free')
      end

      it 'formats monthly USD price correctly' do
        plan = Plan.new(price_cents: 2900, price_currency: 'USD', billing_interval: 'month')
        expect(plan.formatted_price).to eq('$29/month')
      end

      it 'formats yearly EUR price correctly' do
        plan = Plan.new(price_cents: 29000, price_currency: 'EUR', billing_interval: 'year')
        expect(plan.formatted_price).to eq('€290/year')
      end
    end

    describe '.default_plan' do
      before do
        Plan.delete_all
      end

      it 'returns the starter plan if it exists' do
        starter = Plan.create!(name: 'starter', slug: 'starter', display_name: 'Starter')
        Plan.create!(name: 'pro', slug: 'pro', display_name: 'Pro', position: 0)

        expect(Plan.default_plan).to eq(starter)
      end

      it 'returns first active plan if no starter' do
        pro = Plan.create!(name: 'pro', slug: 'pro', display_name: 'Pro', position: 1)
        enterprise = Plan.create!(name: 'enterprise', slug: 'enterprise', display_name: 'Enterprise', position: 2)

        expect(Plan.default_plan).to eq(pro)
      end
    end
  end
end
