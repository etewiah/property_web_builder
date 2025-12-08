FactoryBot.define do
  factory :pwb_link, class: 'PwbTenant::Link' do
    association :website, factory: :pwb_website
    slug { SecureRandom.uuid }

    trait :top_nav do
      placement { :top_nav }
    end

    trait :footer do
      placement { :footer }
    end
  end
end
