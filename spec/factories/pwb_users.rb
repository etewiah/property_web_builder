FactoryBot.define do
  factory :pwb_user, class: 'Pwb::User' do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    
    trait :admin do
      admin { true }
    end
  end
end
