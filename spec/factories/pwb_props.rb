FactoryGirl.define do
  factory :pwb_prop, class: 'Pwb::Prop' do
    title_en 'A property for '
    trait :sale do
      for_sale true
      visible true
    end    
    trait :long_term_rent do
      for_rent_long_term true
      visible true
    end    
    trait :short_term_rent do
      for_rent_short_term true
      visible true
    end    
  end
end
