FactoryBot.define do
  factory :pwb_link, class: 'Pwb::Link' do
    trait :top_nav do
      placement { :top_nav }
    end
  end
end
