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
module Pwb
  class GameEstimate < ApplicationRecord
    self.table_name = 'pwb_game_estimates'

    belongs_to :game_session
    belongs_to :game_listing
    belongs_to :website

    validates :estimated_price_cents, presence: true, numericality: { greater_than: 0 }
    validates :actual_price_cents, presence: true, numericality: { greater_than: 0 }
    validates :game_listing_id, uniqueness: { scope: :game_session_id,
                                               message: 'already has an estimate in this session' }

    before_validation :calculate_score, on: :create
    after_create :update_session_score!
    after_create :increment_game_counter

    private

    def calculate_score
      return unless estimated_price_cents.present? && actual_price_cents.present?

      calculator = Pwb::PriceGame::ScoreCalculator.new(
        guessed_cents: estimated_price_cents,
        actual_cents: actual_price_cents
      )
      self.score = calculator.score
      self.percentage_diff = calculator.percentage_diff
      self.estimate_details = calculator.result
    end

    def update_session_score!
      game_session.recalculate_total_score!
    end

    def increment_game_counter
      game_listing.realty_game.increment!(:estimates_count)
    end
  end
end
