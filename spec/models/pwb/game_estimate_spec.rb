# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_game_estimates
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  actual_price_cents    :bigint           not null
#  currency              :string           default("EUR"), not null
#  estimate_details      :jsonb            not null
#  estimated_price_cents :bigint           not null
#  percentage_diff       :decimal(8, 2)
#  property_index        :integer
#  score                 :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  game_listing_id       :uuid             not null
#  game_session_id       :uuid             not null
#  website_id            :bigint           not null
#
# Indexes
#
#  index_pwb_game_estimates_on_game_listing_id      (game_listing_id)
#  index_pwb_game_estimates_on_game_session_id      (game_session_id)
#  index_pwb_game_estimates_on_website_id           (website_id)
#  index_pwb_game_estimates_unique_session_listing  (game_session_id,game_listing_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_listing_id => pwb_game_listings.id)
#  fk_rails_...  (game_session_id => pwb_game_sessions.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

RSpec.describe Pwb::GameEstimate, type: :model do
  let!(:website) { create(:pwb_website) }
  let!(:game) { create(:pwb_realty_game, website: website) }
  let!(:asset) { create(:pwb_realty_asset, website: website) }
  let!(:game_listing) { create(:pwb_game_listing, realty_game: game, realty_asset: asset) }
  let!(:session) { create(:pwb_game_session, realty_game: game, website: website) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      estimate = build(:pwb_game_estimate,
                       game_session: session, game_listing: game_listing, website: website)
      expect(estimate).to be_valid
    end

    it 'requires estimated_price_cents > 0' do
      estimate = build(:pwb_game_estimate,
                       game_session: session, game_listing: game_listing, website: website,
                       estimated_price_cents: 0)
      expect(estimate).not_to be_valid
    end

    it 'requires actual_price_cents > 0' do
      estimate = build(:pwb_game_estimate,
                       game_session: session, game_listing: game_listing, website: website,
                       actual_price_cents: 0)
      expect(estimate).not_to be_valid
    end

    it 'enforces one estimate per listing per session' do
      create(:pwb_game_estimate,
             game_session: session, game_listing: game_listing, website: website)

      duplicate = build(:pwb_game_estimate,
                        game_session: session, game_listing: game_listing, website: website)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:game_listing_id]).to include('already has an estimate in this session')
    end

    it 'allows same listing in different sessions' do
      create(:pwb_game_estimate,
             game_session: session, game_listing: game_listing, website: website)

      other_session = create(:pwb_game_session, realty_game: game, website: website)
      estimate = build(:pwb_game_estimate,
                       game_session: other_session, game_listing: game_listing, website: website)
      expect(estimate).to be_valid
    end
  end

  describe 'score calculation' do
    it 'calculates score using ScoreCalculator on create' do
      estimate = create(:pwb_game_estimate,
                        game_session: session, game_listing: game_listing, website: website,
                        estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00)

      expect(estimate.score).to eq(100)
      expect(estimate.percentage_diff).to eq(0.0)
    end

    it 'calculates percentage diff correctly' do
      estimate = create(:pwb_game_estimate,
                        game_session: session, game_listing: game_listing, website: website,
                        estimated_price_cents: 330_000_00, actual_price_cents: 300_000_00)

      expect(estimate.percentage_diff).to eq(10.0)
      expect(estimate.score).to eq(90) # 5-10% bracket
    end

    it 'stores estimate details from ScoreCalculator' do
      estimate = create(:pwb_game_estimate,
                        game_session: session, game_listing: game_listing, website: website,
                        estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00)

      expect(estimate.estimate_details).to include('score' => 100)
      expect(estimate.estimate_details).to have_key('feedback')
      expect(estimate.estimate_details).to have_key('emoji')
    end
  end

  describe 'callbacks' do
    it 'updates session total_score after create' do
      expect {
        create(:pwb_game_estimate,
               game_session: session, game_listing: game_listing, website: website,
               estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00)
      }.to change { session.reload.total_score }

      expect(session.total_score).to eq(100)
    end

    it 'increments game estimates_count after create' do
      expect {
        create(:pwb_game_estimate,
               game_session: session, game_listing: game_listing, website: website,
               estimated_price_cents: 300_000_00, actual_price_cents: 300_000_00)
      }.to change { game.reload.estimates_count }.by(1)
    end
  end
end
