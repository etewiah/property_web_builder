FactoryBot.define do
  factory :pwb_user, class: 'Pwb::User' do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }

    # Associate with a website (required as of multi-tenant authentication)
    association :website, factory: :pwb_website

    trait :admin do
      admin { true }

      # Also create admin membership for the website
      after(:create) do |user|
        Pwb::UserMembership.find_or_create_by!(user: user, website: user.website) do |m|
          m.role = 'admin'
          m.active = true
        end
      end
    end

    trait :with_membership do
      transient do
        membership_role { 'member' }
        membership_active { true }
      end

      after(:create) do |user, evaluator|
        Pwb::UserMembership.find_or_create_by!(user: user, website: user.website) do |m|
          m.role = evaluator.membership_role
          m.active = evaluator.membership_active
        end
      end
    end
  end
end
