# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_game_sessions
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  guest_name         :string
#  performance_rating :string
#  total_score        :integer          default(0), not null
#  user_uuid          :string
#  visitor_token      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  realty_game_id     :uuid             not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_game_sessions_on_game_and_visitor   (realty_game_id,visitor_token)
#  index_pwb_game_sessions_on_realty_game_id     (realty_game_id)
#  index_pwb_game_sessions_on_website_and_score  (website_id,total_score)
#  index_pwb_game_sessions_on_website_id         (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (realty_game_id => pwb_realty_games.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Pwb::GameSession, type: :model do
  let!(:website) { create(:pwb_website) }
  let!(:game) { create(:pwb_realty_game, website: website) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      session = build(:pwb_game_session, realty_game: game, website: website)
      expect(session).to be_valid
    end

    it 'requires visitor_token' do
      session = build(:pwb_game_session, realty_game: game, website: website, visitor_token: nil)
      expect(session).not_to be_valid
      expect(session.errors[:visitor_token]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to realty_game' do
      session = create(:pwb_game_session, realty_game: game, website: website)
      expect(session.realty_game).to eq(game)
    end

    it 'belongs to website' do
      session = create(:pwb_game_session, realty_game: game, website: website)
      expect(session.website).to eq(website)
    end

    it 'has many game_estimates' do
      session = create(:pwb_game_session, realty_game: game, website: website)
      expect(session.game_estimates).to eq([])
    end
  end

  describe '#recalculate_total_score!' do
    it 'sums scores from all estimates' do
      session = create(:pwb_game_session, realty_game: game, website: website)
      asset1 = create(:pwb_realty_asset, website: website)
      asset2 = create(:pwb_realty_asset, website: website)
      gl1 = create(:pwb_game_listing, realty_game: game, realty_asset: asset1)
      gl2 = create(:pwb_game_listing, realty_game: game, realty_asset: asset2)

      create(:pwb_game_estimate,
             game_session: session, game_listing: gl1, website: website,
             estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00,
             score: 100)
      create(:pwb_game_estimate,
             game_session: session, game_listing: gl2, website: website,
             estimated_price_cents: 200_000_00, actual_price_cents: 300_000_00,
             score: 50)

      session.recalculate_total_score!
      expect(session.reload.total_score).to eq(150)
    end
  end

  describe '.for_leaderboard' do
    it 'orders by total_score desc, created_at asc' do
      low = create(:pwb_game_session, realty_game: game, website: website, total_score: 50)
      high = create(:pwb_game_session, realty_game: game, website: website, total_score: 200)
      mid = create(:pwb_game_session, realty_game: game, website: website, total_score: 100)

      expect(described_class.for_leaderboard).to eq([high, mid, low])
    end
  end

  describe '#compute_performance_rating' do
    it 'returns expert for 90%+ ratio' do
      session = create(:pwb_game_session, realty_game: game, website: website, total_score: 0)
      asset = create(:pwb_realty_asset, website: website)
      gl = create(:pwb_game_listing, realty_game: game, realty_asset: asset)
      create(:pwb_game_estimate,
             game_session: session, game_listing: gl, website: website,
             estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00,
             score: 100)
      session.update!(total_score: 100)

      expect(session.compute_performance_rating).to eq('expert')
      expect(session.reload.performance_rating).to eq('expert')
    end
  end
end
