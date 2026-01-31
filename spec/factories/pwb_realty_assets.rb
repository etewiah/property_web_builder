# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_realty_assets
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  city               :string
#  constructed_area   :float            default(0.0)
#  count_bathrooms    :float            default(0.0)
#  count_bedrooms     :integer          default(0)
#  count_garages      :integer          default(0)
#  count_toilets      :integer          default(0)
#  country            :string
#  description        :text
#  energy_performance :float
#  energy_rating      :integer
#  latitude           :float
#  longitude          :float
#  plot_area          :float            default(0.0)
#  postal_code        :string
#  prop_origin_key    :string
#  prop_photos_count  :integer          default(0), not null
#  prop_state_key     :string
#  prop_type_key      :string
#  reference          :string
#  region             :string
#  slug               :string
#  street_address     :string
#  street_name        :string
#  street_number      :string
#  title              :string
#  translations       :jsonb            not null
#  year_construction  :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :integer
#
# Indexes
#
#  index_pwb_realty_assets_on_prop_photos_count             (prop_photos_count)
#  index_pwb_realty_assets_on_prop_state_key                (prop_state_key)
#  index_pwb_realty_assets_on_prop_type_key                 (prop_type_key)
#  index_pwb_realty_assets_on_slug                          (slug) UNIQUE
#  index_pwb_realty_assets_on_translations                  (translations) USING gin
#  index_pwb_realty_assets_on_website_id                    (website_id)
#  index_pwb_realty_assets_on_website_id_and_prop_type_key  (website_id,prop_type_key)
#
FactoryBot.define do
  factory :pwb_realty_asset, class: 'Pwb::RealtyAsset', aliases: [:realty_asset] do
    sequence(:reference) { |n| "ASSET-#{n}" }
    association :website, factory: :pwb_website

    count_bedrooms { 2 }
    count_bathrooms { 1 }
    count_toilets { 1 }
    count_garages { 0 }
    constructed_area { 80.0 }
    plot_area { 0.0 }
    year_construction { 2000 }

    street_address { '123 Test Street' }
    city { 'Test City' }
    postal_code { '12345' }
    country { 'Spain' }

    prop_type_key { 'apartment' }
    prop_state_key { 'good' }

    trait :with_location do
      latitude { 40.4168 }
      longitude { -3.7038 }
    end

    trait :luxury do
      count_bedrooms { 5 }
      count_bathrooms { 3 }
      count_garages { 2 }
      constructed_area { 300.0 }
      plot_area { 500.0 }
      prop_type_key { 'villa' }
    end

    trait :with_sale_listing do
      after(:create) do |asset|
        create(:pwb_sale_listing, :visible, realty_asset: asset)
      end
    end

    trait :with_rental_listing do
      after(:create) do |asset|
        create(:pwb_rental_listing, :visible, :long_term, realty_asset: asset)
      end
    end

    trait :with_short_term_rental do
      after(:create) do |asset|
        create(:pwb_rental_listing, :visible, :short_term, realty_asset: asset)
      end
    end

    trait :with_photos do
      after(:create) do |asset|
        create_list(:pwb_prop_photo, 2, realty_asset_id: asset.id)
      end
    end

    trait :with_features do
      after(:create) do |asset|
        create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'pool')
        create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'garden')
      end
    end

    trait :with_translations do
      # Creates a sale listing with translations
      # Translations now belong to listings, not the asset itself
      after(:create) do |asset|
        create(:pwb_sale_listing, :visible, :with_translations, realty_asset: asset)
      end
    end
  end
end
