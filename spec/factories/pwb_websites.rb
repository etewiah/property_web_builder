FactoryBot.define do
  factory :pwb_website, class: 'Pwb::Website' do
    sequence(:subdomain) { |n| "tenant#{n}" }
    company_display_name { 'Test Company' }
    theme_name { 'default' }
    default_currency { 'EUR' }
    default_client_locale { 'en-UK' }
    default_area_unit { 'sqmt' }
    supported_locales { ['en-UK'] }
    
    after(:create) do |website|
      # Create an agency for the website if not already created
      # Use build to avoid circular dependency with agency factory
      unless website.agency.present?
        agency = Pwb::Agency.create!(
          company_name: 'Test Company',
          display_name: 'Test Agency',
          website: website
        )
        website.update(agency: agency)
      end
    end
  end
end
