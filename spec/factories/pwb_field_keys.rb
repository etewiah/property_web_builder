FactoryBot.define do
  factory :pwb_field_key, class: 'PwbTenant::FieldKey' do
    website { Pwb::Website.first || association(:pwb_website) }
    sequence(:global_key) { |n| "test.key.#{n}" }
    tag { 'test_tag' }
  end
end
