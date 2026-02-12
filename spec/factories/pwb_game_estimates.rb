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
FactoryBot.define do
  factory :pwb_game_estimate, class: 'Pwb::GameEstimate' do
    association :game_session, factory: :pwb_game_session
    association :game_listing, factory: :pwb_game_listing
    association :website, factory: :pwb_website
    estimated_price_cents { 280_000_00 }
    actual_price_cents { 300_000_00 }
    currency { 'EUR' }
    property_index { 0 }

    # Skip callbacks for factory — score is set manually
    before(:create) do |estimate|
      if estimate.score.zero? && estimate.estimated_price_cents.present? && estimate.actual_price_cents.present?
        calculator = Pwb::PriceGame::ScoreCalculator.new(
          guessed_cents: estimate.estimated_price_cents,
          actual_cents: estimate.actual_price_cents
        )
        estimate.score = calculator.score
        estimate.percentage_diff = calculator.percentage_diff
        estimate.estimate_details = calculator.result
      end
    end
  end
end
