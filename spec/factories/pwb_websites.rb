FactoryBot.define do
  factory :pwb_website, class: 'Pwb::Website' do
    sequence(:subdomain) { |n| "tenant#{n}" }
    company_display_name { 'Test Company' }
    theme_name { 'default' }
    default_currency { 'EUR' }
    default_client_locale { 'en-UK' }
    default_area_unit { 'sqmt' }
    supported_locales { ['en-UK'] }

    # Transient attribute to control agency creation
    transient do
      skip_agency { false }
    end

    # Trait for creating a website without an agency (for testing guards)
    trait :without_agency do
      transient do
        skip_agency { true }
      end
    end

    after(:create) do |website, evaluator|
      # Create an agency for the website if not already created
      # Skip if using :without_agency trait
      next if evaluator.skip_agency

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
