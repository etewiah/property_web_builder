# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_market_report, class: 'Pwb::MarketReport' do
    association :website, factory: :pwb_website
    report_type { 'cma' }
    title { 'CMA Report for 123 Main St' }
    status { 'draft' }

    trait :with_subject_property do
      association :subject_property, factory: :pwb_realty_asset
    end

    trait :with_user do
      association :user, factory: :pwb_user
    end

    trait :with_location do
      city { 'Test City' }
      region { 'Test Region' }
      postal_code { '12345' }
      latitude { 40.4168 }
      longitude { -3.7038 }
      radius_km { 2.0 }
    end

    trait :generating do
      status { 'generating' }
    end

    trait :completed do
      status { 'completed' }
      generated_at { Time.current }
      suggested_price_low_cents { 350_000_00 }
      suggested_price_high_cents { 400_000_00 }
      suggested_price_currency { 'USD' }

      market_statistics do
        {
          average_price: 375_000,
          median_price: 370_000,
          price_per_sqft: 250,
          days_on_market: 45,
          comparable_count: 5
        }
      end

      ai_insights do
        {
          executive_summary: 'This property is competitively priced for the area.',
          market_position: 'Above average condition with typical features for the neighborhood.',
          pricing_rationale: 'Based on 5 comparable sales within 2 km in the last 6 months.',
          strengths: ['Updated kitchen', 'Good location', 'Private backyard'],
          considerations: ['Single bathroom', 'Limited parking'],
          recommendation: 'List at $375,000 for a 30-day sale.',
          time_to_sell_estimate: '30-45 days at suggested price'
        }
      end

      comparable_properties do
        [
          {
            id: SecureRandom.uuid,
            address: '125 Main St',
            price_cents: 365_000_00,
            bedrooms: 3,
            bathrooms: 2,
            sqft: 1500,
            similarity_score: 92,
            adjusted_price_cents: 370_000_00
          },
          {
            id: SecureRandom.uuid,
            address: '127 Oak Ave',
            price_cents: 380_000_00,
            bedrooms: 3,
            bathrooms: 2,
            sqft: 1600,
            similarity_score: 88,
            adjusted_price_cents: 375_000_00
          }
        ]
      end
    end

    trait :shared do
      status { 'shared' }
      generated_at { 1.hour.ago }
      shared_at { Time.current }
      share_token { SecureRandom.urlsafe_base64(16) }
      view_count { 5 }
    end

    trait :with_pdf do
      after(:create) do |report|
        report.pdf_file.attach(
          io: StringIO.new('PDF content'),
          filename: report.pdf_filename,
          content_type: 'application/pdf'
        )
      end
    end

    trait :with_branding do
      branding do
        {
          agent_name: 'John Smith',
          agent_phone: '+1 555-0123',
          agent_email: 'john@example.com',
          company_name: 'Premier Realty',
          company_logo_url: 'https://example.com/logo.png'
        }
      end
    end

    trait :market_report_type do
      report_type { 'market_report' }
      title { 'Market Report for Downtown Area' }
    end
  end
end
