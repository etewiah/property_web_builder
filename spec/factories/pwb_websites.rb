FactoryBot.define do
  factory :pwb_website, class: 'Pwb::Website' do
    initialize_with { Pwb::Website.unique_instance }
  end
end
