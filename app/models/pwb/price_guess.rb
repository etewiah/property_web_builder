# frozen_string_literal: true

module Pwb
  # PriceGuess represents a visitor's guess in the "Guess the Price" game.
  # Polymorphic: can belong to either SaleListing or RentalListing.
  #
# == Schema Information
#
# Table name: pwb_price_guesses
#
#  id                     :uuid             not null, primary key
#  actual_price_cents     :bigint           not null
#  actual_price_currency  :string           default("EUR")
#  guessed_price_cents    :bigint           not null
#  guessed_price_currency :string           default("EUR")
#  listing_type           :string           not null
#  percentage_diff        :decimal(8, 2)
#  score                  :integer          default(0)
#  visitor_token          :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  listing_id             :uuid             not null
#  website_id             :bigint           not null
#
# Indexes
#
#  index_price_guesses_on_listing_and_score    (listing_type,listing_id,score)
#  index_price_guesses_on_listing_and_visitor  (listing_type,listing_id,visitor_token) UNIQUE
#  index_pwb_price_guesses_on_listing          (listing_type,listing_id)
#  index_pwb_price_guesses_on_website_id       (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  class PriceGuess < ApplicationRecord
    self.table_name = "pwb_price_guesses"

    belongs_to :listing, polymorphic: true
    belongs_to :website, class_name: "Pwb::Website"

    monetize :guessed_price_cents, with_model_currency: :guessed_price_currency
    monetize :actual_price_cents, with_model_currency: :actual_price_currency

    validates :visitor_token, presence: true
    validates :guessed_price_cents, presence: true, numericality: { greater_than: 0 }
    validates :visitor_token, uniqueness: { scope: %i[listing_type listing_id],
                                            message: "has already guessed for this listing" }

    before_validation :set_actual_price, on: :create
    before_validation :calculate_score, on: :create

    # Scopes for leaderboard
    scope :for_listing, ->(listing) { where(listing: listing) }
    scope :top_scores, -> { order(score: :desc, created_at: :asc) }
    scope :leaderboard, ->(limit = 10) { top_scores.limit(limit) }

    def formatted_guessed_price
      guessed_price.format(no_cents: true)
    end

    def formatted_actual_price
      actual_price.format(no_cents: true)
    end

    def feedback
      @feedback ||= Pwb::PriceGame::ScoreCalculator.new(
        guessed_cents: guessed_price_cents,
        actual_cents: actual_price_cents
      )
    end

    def feedback_message
      feedback.feedback_message
    end

    def emoji
      feedback.emoji
    end

    private

    def set_actual_price
      return unless listing.present?

      self.actual_price_cents = listing_price_cents
      self.actual_price_currency = listing_price_currency
    end

    def calculate_score
      return unless guessed_price_cents.present? && actual_price_cents.present?

      calculator = Pwb::PriceGame::ScoreCalculator.new(
        guessed_cents: guessed_price_cents,
        actual_cents: actual_price_cents
      )
      self.score = calculator.score
      self.percentage_diff = calculator.percentage_diff
    end

    def listing_price_cents
      case listing
      when Pwb::SaleListing
        listing.price_sale_current_cents
      when Pwb::RentalListing
        listing.price_rental_monthly_current_cents
      else
        0
      end
    end

    def listing_price_currency
      case listing
      when Pwb::SaleListing
        listing.price_sale_current_currency
      when Pwb::RentalListing
        listing.price_rental_monthly_current_currency
      else
        "EUR"
      end
    end
  end
end
