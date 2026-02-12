# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_spp_listings
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  active               :boolean          default(FALSE), not null
#  archived             :boolean          default(FALSE)
#  extra_data           :jsonb
#  highlighted_features :jsonb
#  listing_type         :string           default("sale"), not null
#  live_url             :string
#  noindex              :boolean          default(FALSE), not null
#  photo_ids_ordered    :jsonb
#  price_cents          :bigint           default(0), not null
#  price_currency       :string           default("EUR"), not null
#  published_at         :datetime
#  spp_settings         :jsonb
#  spp_slug             :string
#  template             :string
#  translations         :jsonb            not null
#  visible              :boolean          default(FALSE)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  realty_asset_id      :uuid             not null
#
# Indexes
#
#  index_pwb_spp_listings_on_noindex          (noindex)
#  index_pwb_spp_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_spp_listings_on_spp_slug         (spp_slug)
#  index_pwb_spp_listings_on_translations     (translations) USING gin
#  index_pwb_spp_listings_unique_active       (realty_asset_id,listing_type,active) UNIQUE WHERE (active = true)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
FactoryBot.define do
  factory :pwb_spp_listing, class: 'Pwb::SppListing' do
    association :realty_asset, factory: :pwb_realty_asset

    listing_type { 'sale' }
    active { true }
    visible { false }
    archived { false }

    price_cents { 450_000_00 }
    price_currency { 'EUR' }

    trait :sale do
      listing_type { 'sale' }
    end

    trait :rental do
      listing_type { 'rental' }
      price_cents { 2_500_00 }
    end

    trait :visible do
      visible { true }
    end

    trait :published do
      active { true }
      visible { true }
      published_at { Time.current }
      live_url { 'https://test-property-sale.spp.example.com/' }
    end

    trait :archived do
      archived { true }
      active { false }
    end

    trait :with_curated_photos do
      after(:create) do |listing|
        photos = create_list(:pwb_prop_photo, 3, realty_asset_id: listing.realty_asset_id)
        listing.update!(photo_ids_ordered: [photos[2].id, photos[0].id])
      end
    end

    trait :with_highlighted_features do
      after(:create) do |listing|
        create(:pwb_feature, realty_asset_id: listing.realty_asset_id, feature_key: 'sea_views')
        create(:pwb_feature, realty_asset_id: listing.realty_asset_id, feature_key: 'pool')
        create(:pwb_feature, realty_asset_id: listing.realty_asset_id, feature_key: 'garden')
        listing.update!(highlighted_features: %w[sea_views pool])
      end
    end

    trait :with_translations do
      after(:create) do |listing|
        listing.title_en = 'Your Dream Mediterranean Retreat'
        listing.description_en = 'Imagine waking up to the sound of waves...'
        listing.title_es = 'Tu Refugio Mediterraneo Ideal'
        listing.description_es = 'Imagina despertar con el sonido de las olas...'
        listing.save!
      end
    end

    trait :with_template do
      template { 'luxury' }
      spp_slug { 'test-property' }
    end
  end
end
