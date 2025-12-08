FactoryBot.define do
  factory :pwb_rental_listing, class: 'Pwb::RentalListing' do
    association :realty_asset, factory: :pwb_realty_asset

    sequence(:reference) { |n| "RENT-#{n}" }
    visible { false }
    highlighted { false }
    archived { false }
    reserved { false }
    furnished { false }
    for_rent_short_term { false }
    for_rent_long_term { false }
    active { true }  # Required for materialized view JOIN

    price_rental_monthly_current_cents { 1_200_00 } # 1,200 EUR/month
    price_rental_monthly_current_currency { 'EUR' }
    price_rental_monthly_low_season_cents { 0 }
    price_rental_monthly_high_season_cents { 0 }

    trait :visible do
      visible { true }
    end

    trait :highlighted do
      highlighted { true }
      visible { true }
    end

    trait :archived do
      archived { true }
    end

    trait :reserved do
      reserved { true }
      visible { true }
    end

    trait :furnished do
      furnished { true }
    end

    trait :long_term do
      for_rent_long_term { true }
    end

    trait :short_term do
      for_rent_short_term { true }
      price_rental_monthly_low_season_cents { 800_00 }
      price_rental_monthly_current_cents { 1_500_00 }
      price_rental_monthly_high_season_cents { 2_500_00 }
    end

    trait :vacation do
      for_rent_short_term { true }
      furnished { true }
      price_rental_monthly_low_season_cents { 1_000_00 }
      price_rental_monthly_current_cents { 2_000_00 }
      price_rental_monthly_high_season_cents { 3_500_00 }
    end

    trait :luxury do
      price_rental_monthly_current_cents { 5_000_00 } # 5,000 EUR/month
      for_rent_long_term { true }
    end

    trait :budget do
      price_rental_monthly_current_cents { 600_00 } # 600 EUR/month
      for_rent_long_term { true }
    end

    trait :with_translations do
      after(:create) do |listing|
        listing.title_en = 'Test Rental Property'
        listing.description_en = 'A beautiful rental property'
        listing.title_es = 'Propiedad de Alquiler de Prueba'
        listing.description_es = 'Una hermosa propiedad de alquiler'
        listing.save!
      end
    end
  end
end
