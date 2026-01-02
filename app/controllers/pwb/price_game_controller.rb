# frozen_string_literal: true

module Pwb
  # Controller for the "Guess the Price" game
  # Handles game page display, guess submission, and share tracking
  class PriceGameController < ApplicationController
    before_action :set_listing
    before_action :check_game_enabled
    before_action :set_visitor_token
    skip_before_action :verify_authenticity_token, only: %i[guess track_share]

    # GET /g/:token
    def show
      @listing.increment_game_views!

      @property = load_property_details
      @existing_guess = @listing.visitor_guess(@visitor_token)
      @leaderboard = @listing.game_leaderboard(limit: 10)
      @listing_type = @listing.game_listing_type

      # SEO
      @page_title = I18n.t("price_game.title", property: @listing.title)
    end

    # POST /g/:token/guess
    def guess
      # Check if already guessed
      existing = @listing.visitor_guess(@visitor_token)
      if existing.present?
        return render json: {
          error: I18n.t("price_game.already_guessed"),
          guess: serialize_guess(existing)
        }, status: :unprocessable_entity
      end

      # Validate guess amount
      guessed_cents = parse_price_to_cents(params[:guessed_price], params[:currency])
      if guessed_cents.nil? || guessed_cents <= 0
        return render json: {
          error: I18n.t("price_game.invalid_guess")
        }, status: :unprocessable_entity
      end

      # Create the guess
      @guess = Pwb::PriceGuess.new(
        listing: @listing,
        website: current_website,
        visitor_token: @visitor_token,
        guessed_price_cents: guessed_cents,
        guessed_price_currency: params[:currency] || @listing.game_price_currency
      )

      if @guess.save
        render json: {
          success: true,
          guess: serialize_guess(@guess),
          leaderboard: serialize_leaderboard(@listing.game_leaderboard)
        }
      else
        render json: {
          error: @guess.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    end

    # POST /g/:token/share
    def track_share
      @listing.increment_game_shares!
      render json: { success: true, shares: @listing.game_shares_count }
    end

    private

    def set_listing
      # Try SaleListing first, then RentalListing
      @listing = Pwb::SaleListing.find_by(game_token: params[:token]) ||
                 Pwb::RentalListing.find_by(game_token: params[:token])

      unless @listing
        render_not_found
      end
    end

    def check_game_enabled
      return if @listing&.game_enabled?

      render_not_found
    end

    def render_not_found
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
    end

    def set_visitor_token
      # Get or generate visitor token from cookie
      @visitor_token = if cookies[:price_game_visitor].present?
                         cookies[:price_game_visitor]
                       else
                         token = SecureRandom.urlsafe_base64(16)
                         cookies[:price_game_visitor] = {
                           value: token,
                           expires: 1.year.from_now,
                           httponly: true
                         }
                         token
                       end
    end

    def load_property_details
      # Load property details through realty_asset
      realty_asset = @listing.realty_asset
      return nil unless realty_asset

      OpenStruct.new(
        title: @listing.title,
        description: @listing.description,
        bedrooms: realty_asset.count_bedrooms,
        bathrooms: realty_asset.count_bathrooms,
        built_area: realty_asset.constructed_area,
        plot_area: realty_asset.plot_area,
        city: realty_asset.city,
        region: realty_asset.region,
        street_address: realty_asset.street_address,
        year_built: realty_asset.year_construction,
        features: realty_asset.features&.pluck(:feature_key) || [],
        photos: realty_asset.prop_photos&.order(:sort_order) || [],
        latitude: realty_asset.latitude,
        longitude: realty_asset.longitude,
        reference: @listing.reference || realty_asset.reference
      )
    end

    def parse_price_to_cents(price_input, currency = nil)
      return nil if price_input.blank?

      # Handle various input formats
      # Remove currency symbols, spaces, and convert comma decimals
      cleaned = price_input.to_s.gsub(/[^\d.,]/, "")

      # Handle European format (1.234,56) vs US format (1,234.56)
      if cleaned.include?(",") && cleaned.include?(".")
        # Determine format by position of last separator
        if cleaned.rindex(",") > cleaned.rindex(".")
          # European: 1.234,56 -> 1234.56
          cleaned = cleaned.tr(".", "").tr(",", ".")
        else
          # US: 1,234.56 -> 1234.56
          cleaned = cleaned.delete(",")
        end
      elsif cleaned.include?(",") && !cleaned.include?(".")
        # Could be European decimal (123,45) or thousand separator (1,234)
        # If comma is followed by exactly 2 digits at end, treat as decimal
        if cleaned.match?(/,\d{2}$/)
          cleaned = cleaned.tr(",", ".")
        else
          cleaned = cleaned.delete(",")
        end
      end

      amount = cleaned.to_f
      (amount * 100).round
    rescue StandardError
      nil
    end

    def serialize_guess(guess)
      {
        id: guess.id,
        guessed_price: guess.formatted_guessed_price,
        guessed_price_cents: guess.guessed_price_cents,
        actual_price: guess.formatted_actual_price,
        actual_price_cents: guess.actual_price_cents,
        score: guess.score,
        percentage_diff: guess.percentage_diff,
        feedback: guess.feedback_message,
        emoji: guess.emoji,
        created_at: guess.created_at.iso8601
      }
    end

    def serialize_leaderboard(guesses)
      guesses.map.with_index do |guess, index|
        {
          rank: index + 1,
          score: guess.score,
          percentage_diff: guess.percentage_diff&.abs&.round(1),
          created_at: guess.created_at.iso8601
        }
      end
    end
  end
end
