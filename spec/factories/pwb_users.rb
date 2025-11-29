FactoryBot.define do
  factory :pwb_user, class: 'Pwb::User' do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    
    # Associate with a website (required as of multi-tenant authentication)
    association :website, factory: :pwb_website
    
    trait :admin do
      admin { true }
    end
  end
end
