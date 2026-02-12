# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_game_listings
# Database name: primary
#
#  id              :uuid             not null, primary key
#  display_title   :string
#  extra_data      :jsonb            not null
#  sort_order      :integer          default(0), not null
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  realty_asset_id :uuid             not null
#  realty_game_id  :uuid             not null
#
# Indexes
#
#  index_pwb_game_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_game_listings_on_realty_game_id   (realty_game_id)
#  index_pwb_game_listings_unique_game_asset   (realty_game_id,realty_asset_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#  fk_rails_...  (realty_game_id => pwb_realty_games.id)
#
FactoryBot.define do
  factory :pwb_game_listing, class: 'Pwb::GameListing' do
    association :realty_game, factory: :pwb_realty_game
    association :realty_asset, factory: :pwb_realty_asset
    visible { true }
    sort_order { 0 }

    trait :hidden do
      visible { false }
    end

    trait :with_sale_listing do
      after(:create) do |game_listing|
        create(:pwb_sale_listing, :visible,
               realty_asset: game_listing.realty_asset,
               price_sale_current_cents: 300_000_00)
      end
    end
  end
end
