FactoryBot.define do
  factory :pwb_contact, class: 'PwbTenant::Contact' do
    website { Pwb::Website.first || association(:pwb_website) }
  end
end
