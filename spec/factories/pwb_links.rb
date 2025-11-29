FactoryBot.define do
  factory :pwb_link, class: 'Pwb::Link' do
    association :website, factory: :pwb_website
    trait :top_nav do
      placement { :top_nav }
    end
  end
end
