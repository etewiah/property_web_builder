# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_plans
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  billing_interval :string           default("month"), not null
#  description      :text
#  display_name     :string           not null
#  features         :jsonb            not null
#  name             :string           not null
#  position         :integer          default(0), not null
#  price_cents      :integer          default(0), not null
#  price_currency   :string           default("USD"), not null
#  property_limit   :integer
#  public           :boolean          default(TRUE), not null
#  slug             :string           not null
#  trial_days       :integer          default(14), not null
#  user_limit       :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_pwb_plans_on_active_and_position  (active,position)
#  index_pwb_plans_on_slug                 (slug) UNIQUE
#
FactoryBot.define do
  factory :pwb_plan, class: 'Pwb::Plan' do
    sequence(:name) { |n| "plan_#{n}" }
    sequence(:slug) { |n| "plan-#{n}" }
    sequence(:display_name) { |n| "Plan #{n}" }
    description { "A test plan description" }
    price_cents { 2900 }
    price_currency { "USD" }
    billing_interval { "month" }
    trial_days { 14 }
    property_limit { 25 }
    user_limit { 5 }
    active { true }
    public { true }
    position { 1 }
    features { ["basic_themes"] }

    trait :free do
      name { "free" }
      slug { "free" }
      display_name { "Free" }
      price_cents { 0 }
      property_limit { 5 }
      user_limit { 1 }
      trial_days { 0 }
      features { [] }
    end

    trait :starter do
      name { "starter" }
      slug { "starter" }
      display_name { "Starter" }
      price_cents { 2900 }
      property_limit { 25 }
      user_limit { 3 }
      features { ["basic_themes"] }
    end

    trait :professional do
      name { "professional" }
      slug { "professional" }
      display_name { "Professional" }
      price_cents { 7900 }
      property_limit { 100 }
      user_limit { 10 }
      features { ["basic_themes", "premium_themes", "analytics", "custom_domain"] }
    end

    trait :enterprise do
      name { "enterprise" }
      slug { "enterprise" }
      display_name { "Enterprise" }
      price_cents { 19900 }
      property_limit { nil }
      user_limit { nil }
      features { ["basic_themes", "premium_themes", "analytics", "custom_domain", "api_access", "white_label", "priority_support", "dedicated_support"] }
    end

    trait :yearly do
      billing_interval { "year" }
      price_cents { 29000 }
    end

    trait :inactive do
      active { false }
    end

    trait :private do
      public { false }
    end

    trait :no_trial do
      trial_days { 0 }
    end

    trait :unlimited_properties do
      property_limit { nil }
    end

    trait :unlimited_users do
      user_limit { nil }
    end
  end
end
