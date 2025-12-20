# == Schema Information
#
# Table name: pwb_sale_listings
#
#  id                          :uuid             not null, primary key
#  active                      :boolean          default(FALSE), not null
#  archived                    :boolean          default(FALSE)
#  commission_cents            :bigint           default(0)
#  commission_currency         :string           default("EUR")
#  furnished                   :boolean          default(FALSE)
#  highlighted                 :boolean          default(FALSE)
#  noindex                     :boolean          default(FALSE), not null
#  price_sale_current_cents    :bigint           default(0)
#  price_sale_current_currency :string           default("EUR")
#  reference                   :string
#  reserved                    :boolean          default(FALSE)
#  translations                :jsonb            not null
#  visible                     :boolean          default(FALSE)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  realty_asset_id             :uuid
#
# Indexes
#
#  index_pwb_sale_listings_on_noindex          (noindex)
#  index_pwb_sale_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_sale_listings_on_translations     (translations) USING gin
#  index_pwb_sale_listings_unique_active       (realty_asset_id,active) UNIQUE WHERE (active = true)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
FactoryBot.define do
  factory :pwb_sale_listing, class: 'Pwb::SaleListing' do
    association :realty_asset, factory: :pwb_realty_asset

    sequence(:reference) { |n| "SALE-#{n}" }
    visible { false }
    highlighted { false }
    archived { false }
    reserved { false }
    furnished { false }
    active { true }  # Required for materialized view JOIN

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
      active { false }  # Archived listings should not be active
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

    trait :with_translations do
      after(:create) do |listing|
        listing.title_en = 'Test Property Title'
        listing.description_en = 'A beautiful test property'
        listing.title_es = 'Titulo de Propiedad de Prueba'
        listing.description_es = 'Una hermosa propiedad de prueba'
        listing.save!
      end
    end
  end
end
