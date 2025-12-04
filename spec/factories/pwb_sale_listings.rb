FactoryBot.define do
  factory :pwb_sale_listing, class: 'Pwb::SaleListing' do
    association :realty_asset, factory: :pwb_realty_asset

    sequence(:reference) { |n| "SALE-#{n}" }
    visible { false }
    highlighted { false }
    archived { false }
    reserved { false }
    furnished { false }

    price_sale_current_cents { 250_000_00 } # 250,000 EUR
    price_sale_current_currency { 'EUR' }
    commission_cents { 7_500_00 } # 7,500 EUR (3%)
    commission_currency { 'EUR' }

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

    trait :luxury do
      price_sale_current_cents { 1_500_000_00 } # 1.5M EUR
      commission_cents { 45_000_00 } # 45,000 EUR (3%)
    end

    trait :budget do
      price_sale_current_cents { 100_000_00 } # 100,000 EUR
      commission_cents { 3_000_00 }
    end
  end
end
