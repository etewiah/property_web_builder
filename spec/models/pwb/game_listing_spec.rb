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
require 'rails_helper'

RSpec.describe Pwb::GameListing, type: :model do
  let!(:website) { create(:pwb_website) }
  let!(:game) { create(:pwb_realty_game, website: website) }
  let!(:asset) { create(:pwb_realty_asset, website: website) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      listing = build(:pwb_game_listing, realty_game: game, realty_asset: asset)
      expect(listing).to be_valid
    end

    it 'requires unique realty_asset per game' do
      create(:pwb_game_listing, realty_game: game, realty_asset: asset)
      duplicate = build(:pwb_game_listing, realty_game: game, realty_asset: asset)
      expect(duplicate).not_to be_valid
    end

    it 'allows same asset in different games' do
      other_game = create(:pwb_realty_game, website: website)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset)
      listing = build(:pwb_game_listing, realty_game: other_game, realty_asset: asset)
      expect(listing).to be_valid
    end
  end

  describe 'scopes' do
    it '.visible returns only visible listings' do
      visible = create(:pwb_game_listing, realty_game: game, realty_asset: asset, visible: true)
      asset2 = create(:pwb_realty_asset, website: website)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset2, visible: false)

      expect(described_class.visible).to contain_exactly(visible)
    end

    it '.ordered sorts by sort_order then created_at' do
      asset2 = create(:pwb_realty_asset, website: website)
      asset3 = create(:pwb_realty_asset, website: website)

      second = create(:pwb_game_listing, realty_game: game, realty_asset: asset, sort_order: 2)
      first = create(:pwb_game_listing, realty_game: game, realty_asset: asset2, sort_order: 1)
      third = create(:pwb_game_listing, realty_game: game, realty_asset: asset3, sort_order: 3)

      expect(described_class.ordered).to eq([first, second, third])
    end
  end

  describe '#actual_price_cents' do
    it 'returns price from active sale listing' do
      sale_listing = create(:pwb_sale_listing, realty_asset: asset, price_sale_current_cents: 500_000_00)
      game_listing = create(:pwb_game_listing, realty_game: game, realty_asset: asset)

      expect(game_listing.actual_price_cents).to eq(500_000_00)
    end

    it 'returns 0 when no active listing exists' do
      game_listing = create(:pwb_game_listing, realty_game: game, realty_asset: asset)

      expect(game_listing.actual_price_cents).to eq(0)
    end
  end

  describe '#website' do
    it 'delegates to realty_game' do
      game_listing = create(:pwb_game_listing, realty_game: game, realty_asset: asset)
      expect(game_listing.website).to eq(website)
    end
  end
end
