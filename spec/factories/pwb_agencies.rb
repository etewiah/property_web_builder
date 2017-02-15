FactoryGirl.define do
  factory :pwb_agency, class: 'Pwb::Agency' do
    initialize_with { Pwb::Agency.unique_instance() }
  end
end
