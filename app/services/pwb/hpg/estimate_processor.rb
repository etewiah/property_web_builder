# frozen_string_literal: true

module Pwb
  module Hpg
    # Orchestrates creating a game estimate:
    # 1. Find or create a GameSession
    # 2. Resolve actual price from the game listing
    # 3. Create the GameEstimate (score calculated via callback)
    # 4. Return estimate + session data
    class EstimateProcessor
      def self.call(game:, website:, params:)
        new(game: game, website: website, params: params).call
      end

      def initialize(game:, website:, params:)
        @game = game
        @website = website
        @params = params
      end

      def call
        game_listing = @game.game_listings.find(@params[:game_listing_id])
        session = find_or_create_session!

        # Check for duplicate
        if session.game_estimates.exists?(game_listing_id: game_listing.id)
          return {
            error: { code: 'DUPLICATE_ESTIMATE', message: 'Already submitted an estimate for this listing in this session' },
            status: :conflict
          }
        end

        actual_cents = game_listing.actual_price_cents
        if actual_cents.zero?
          return {
            error: { code: 'NO_PRICE', message: 'No active listing price available for this property' },
            status: :unprocessable_entity
          }
        end

        estimate = session.game_estimates.create!(
          game_listing: game_listing,
          website: @website,
          estimated_price_cents: (@params[:estimated_price].to_f * 100).to_i,
          actual_price_cents: actual_cents,
          currency: @params[:currency] || @game.default_currency,
          property_index: @params[:property_index]
        )

        {
          data: {
            estimate: serialize_estimate(estimate),
            session: serialize_session(session.reload)
          }
        }
      rescue ActiveRecord::RecordNotFound => e
        { error: { code: 'NOT_FOUND', message: e.message }, status: :not_found }
      rescue ActiveRecord::RecordInvalid => e
        { error: { code: 'VALIDATION_FAILED', message: e.message }, status: :unprocessable_entity }
      end

      private

      def find_or_create_session!
        if @params[:session_id].present?
          @game.game_sessions.find(@params[:session_id])
        else
          @game.game_sessions.create!(
            website: @website,
            visitor_token: @params[:visitor_token] || SecureRandom.urlsafe_base64(16),
            guest_name: @params[:guest_name]
          ).tap { |s| @game.increment!(:sessions_count) }
        end
      end

      def serialize_estimate(estimate)
        {
          id: estimate.id,
          estimated_price_cents: estimate.estimated_price_cents,
          actual_price_cents: estimate.actual_price_cents,
          currency: estimate.currency,
          percentage_diff: estimate.percentage_diff,
          score: estimate.score,
          feedback: estimate.estimate_details['feedback'],
          emoji: estimate.estimate_details['emoji'],
          property_index: estimate.property_index
        }
      end

      def serialize_session(session)
        {
          id: session.id,
          total_score: session.total_score,
          estimates_count: session.estimates_count,
          game_listings_count: @game.game_listings.visible.count
        }
      end
    end
  end
end
