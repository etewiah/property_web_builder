FactoryGirl.define do
  factory :pwb_agency, class: 'Pwb::Agency' do
    initialize_with { Pwb::Agency.unique_instance }
    trait :theme_default do
      theme_name "default"
    end
    trait :theme_berlin do
      theme_name "berlin"
      # visible true
    end
  end
end
