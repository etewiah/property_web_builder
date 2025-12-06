FactoryBot.define do
  factory :pwb_message, class: 'PwbTenant::Message' do
    website { Pwb::Website.first || association(:pwb_website) }
  end
end
