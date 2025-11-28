FactoryBot.define do
  factory :pwb_website, class: 'Pwb::Website' do
    sequence(:subdomain) { |n| "tenant#{n}" }
    theme_name { 'default' }
    default_currency { 'EUR' }
    default_client_locale { 'en-UK' }
    default_area_unit { 'sqmt' }
    supported_locales { ['en-UK'] }
  end
end
