# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_user_membership, class: 'Pwb::UserMembership' do
    association :user, factory: :pwb_user
    association :website, factory: :pwb_website
    role { 'member' }
    active { true }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :member do
      role { 'member' }
    end

    trait :viewer do
      role { 'viewer' }
    end

    trait :inactive do
      active { false }
    end
  end
end
