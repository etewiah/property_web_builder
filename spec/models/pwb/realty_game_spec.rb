# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_realty_games
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  bg_image_url             :string
#  default_country          :string
#  default_currency         :string           default("EUR"), not null
#  description              :text
#  end_at                   :datetime
#  estimates_count          :integer          default(0), not null
#  hidden_from_landing_page :boolean          default(FALSE), not null
#  sessions_count           :integer          default(0), not null
#  slug                     :string           not null
#  start_at                 :datetime
#  title                    :string           not null
#  validation_rules         :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_realty_games_on_website_id             (website_id)
#  index_pwb_realty_games_on_website_id_and_active  (website_id,active)
#  index_pwb_realty_games_on_website_id_and_slug    (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Pwb::RealtyGame, type: :model do
  let!(:website) { create(:pwb_website) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      game = build(:pwb_realty_game, website: website)
      expect(game).to be_valid
    end

    it 'requires slug' do
      game = build(:pwb_realty_game, website: website, slug: nil)
      expect(game).not_to be_valid
      expect(game.errors[:slug]).to include("can't be blank")
    end

    it 'requires title' do
      game = build(:pwb_realty_game, website: website, title: nil)
      expect(game).not_to be_valid
      expect(game.errors[:title]).to include("can't be blank")
    end

    it 'requires default_currency' do
      game = build(:pwb_realty_game, website: website, default_currency: nil)
      expect(game).not_to be_valid
    end

    it 'requires unique slug per website' do
      create(:pwb_realty_game, website: website, slug: 'london')
      duplicate = build(:pwb_realty_game, website: website, slug: 'london')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'allows same slug on different websites' do
      other_website = create(:pwb_website)
      create(:pwb_realty_game, website: website, slug: 'london')
      game = build(:pwb_realty_game, website: other_website, slug: 'london')
      expect(game).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to website' do
      game = create(:pwb_realty_game, website: website)
      expect(game.website).to eq(website)
    end

    it 'has many game_listings' do
      game = create(:pwb_realty_game, website: website)
      asset = create(:pwb_realty_asset, website: website)
      listing = create(:pwb_game_listing, realty_game: game, realty_asset: asset)
      expect(game.game_listings).to include(listing)
    end

    it 'has many game_sessions' do
      game = create(:pwb_realty_game, website: website)
      session = create(:pwb_game_session, realty_game: game, website: website)
      expect(game.game_sessions).to include(session)
    end

    it 'destroys dependent game_listings' do
      game = create(:pwb_realty_game, website: website)
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset)

      expect { game.destroy }.to change(Pwb::GameListing, :count).by(-1)
    end
  end

  describe 'scopes' do
    it '.active returns only active games' do
      active = create(:pwb_realty_game, website: website, active: true)
      create(:pwb_realty_game, :inactive, website: website)

      expect(described_class.active).to contain_exactly(active)
    end

    it '.visible_on_landing excludes hidden games' do
      visible = create(:pwb_realty_game, website: website, active: true, hidden_from_landing_page: false)
      create(:pwb_realty_game, :hidden, website: website)
      create(:pwb_realty_game, :inactive, website: website)

      expect(described_class.visible_on_landing).to contain_exactly(visible)
    end

    it '.currently_available filters by date range' do
      available = create(:pwb_realty_game, website: website, active: true,
                         start_at: 1.day.ago, end_at: 1.day.from_now)
      not_started = create(:pwb_realty_game, website: website, active: true,
                           start_at: 1.day.from_now, end_at: 1.month.from_now)
      ended = create(:pwb_realty_game, website: website, active: true,
                     start_at: 1.month.ago, end_at: 1.day.ago)
      no_dates = create(:pwb_realty_game, website: website, active: true,
                        start_at: nil, end_at: nil)

      result = described_class.currently_available
      expect(result).to include(available, no_dates)
      expect(result).not_to include(not_started, ended)
    end
  end

  describe '#listings_count' do
    it 'returns count of visible game listings' do
      game = create(:pwb_realty_game, website: website)
      asset1 = create(:pwb_realty_asset, website: website)
      asset2 = create(:pwb_realty_asset, website: website)
      asset3 = create(:pwb_realty_asset, website: website)

      create(:pwb_game_listing, realty_game: game, realty_asset: asset1, visible: true)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset2, visible: true)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset3, visible: false)

      expect(game.listings_count).to eq(2)
    end
  end
end
