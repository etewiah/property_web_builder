FactoryGirl.define do
  factory :pwb_prop, class: 'Pwb::Prop' do
    title_en 'A property for '
    trait :available_for_sale do
      for_sale true
      visible true
    end    
    trait :available_for_long_term_rent do
      for_rent_long_term true
      visible true
    end    
  end
end
