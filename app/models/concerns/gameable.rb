# frozen_string_literal: true

# Gameable concern adds "Guess the Price" game functionality to listings.
# Include in SaleListing and RentalListing models.
#
# Required columns on including model:
#   - game_token: string (unique)
#   - game_enabled: boolean (default: false)
#   - game_views_count: integer (default: 0)
#   - game_shares_count: integer (default: 0)
#
module Gameable
  extend ActiveSupport::Concern

  included do
    has_many :price_guesses, as: :listing, class_name: "Pwb::PriceGuess", dependent: :destroy

    scope :game_enabled, -> { where(game_enabled: true) }

    before_create :generate_game_token
  end

  # Generate a unique, unguessable game token
  def generate_game_token
    return if game_token.present?

    loop do
      self.game_token = SecureRandom.urlsafe_base64(16) # 22 chars, URL-safe
      break unless self.class.exists?(game_token: game_token)
    end
  end

  # Enable the game for this listing
  def enable_game!
    generate_game_token if game_token.blank?
    update!(game_enabled: true)
  end

  # Disable the game for this listing
  def disable_game!
    update!(game_enabled: false)
  end

  # Full URL for sharing the game
  def game_url(host: nil)
    return nil unless game_enabled? && game_token.present?

    host ||= website&.primary_host || "localhost:3000"
    Rails.application.routes.url_helpers.price_game_url(game_token, host: host)
  end

  # Relative path for the game
  def game_path
    return nil unless game_enabled? && game_token.present?

    Rails.application.routes.url_helpers.price_game_path(game_token)
  end

  # Increment view counter (called when game page is viewed)
  def increment_game_views!
    increment!(:game_views_count)
  end

  # Increment share counter (called when share button is clicked)
  def increment_game_shares!
    increment!(:game_shares_count)
  end

  # Get leaderboard for this listing
  def game_leaderboard(limit: 10)
    price_guesses.leaderboard(limit)
  end

  # Check if a visitor has already guessed
  def visitor_has_guessed?(visitor_token)
    price_guesses.exists?(visitor_token: visitor_token)
  end

  # Get a visitor's guess
  def visitor_guess(visitor_token)
    price_guesses.find_by(visitor_token: visitor_token)
  end

  # Total number of guesses
  def game_guesses_count
    price_guesses.count
  end

  # Average score for this listing
  def average_game_score
    price_guesses.average(:score)&.round(1) || 0
  end

  # The price to guess (override in subclasses if needed)
  def game_price_cents
    raise NotImplementedError, "Subclass must implement #game_price_cents"
  end

  def game_price_currency
    raise NotImplementedError, "Subclass must implement #game_price_currency"
  end

  # Game analytics summary
  def game_analytics
    {
      views: game_views_count,
      shares: game_shares_count,
      guesses: game_guesses_count,
      average_score: average_game_score,
      enabled: game_enabled?
    }
  end
end
