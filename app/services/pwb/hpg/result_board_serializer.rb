# frozen_string_literal: true

module Pwb
  module Hpg
    # Serializes a GameSession into a result board response
    class ResultBoardSerializer
      def self.call(session, game)
        new(session, game).call
      end

      def initialize(session, game)
        @session = session
        @game = game
      end

      def call
        estimates = @session.game_estimates
                            .includes(game_listing: { realty_asset: :prop_photos })
                            .order(:property_index, :created_at)

        {
          session: serialize_session,
          estimates: estimates.map { |e| serialize_estimate(e) },
          ranking: compute_ranking,
          game: {
            slug: @game.slug,
            title: @game.title,
            listings_count: @game.game_listings.visible.count
          }
        }
      end

      private

      def serialize_session
        @session.compute_performance_rating if @session.performance_rating.nil? && @session.game_estimates.any?

        {
          id: @session.id,
          guest_name: @session.guest_name,
          total_score: @session.total_score,
          performance_rating: @session.performance_rating,
          estimates_count: @session.estimates_count,
          created_at: @session.created_at.iso8601
        }
      end

      def serialize_estimate(estimate)
        asset = estimate.game_listing.realty_asset
        photo = asset.prop_photos.first

        {
          property_index: estimate.property_index,
          game_listing_id: estimate.game_listing_id,
          estimated_price_cents: estimate.estimated_price_cents,
          actual_price_cents: estimate.actual_price_cents,
          currency: estimate.currency,
          percentage_diff: estimate.percentage_diff,
          score: estimate.score,
          feedback: estimate.estimate_details['feedback'],
          emoji: estimate.estimate_details['emoji'],
          property: {
            display_title: estimate.game_listing.display_title || asset.title,
            city: asset.city,
            photo_url: photo&.image_url
          }
        }
      end

      def compute_ranking
        higher_scores = @game.game_sessions
                             .where('total_score > ?', @session.total_score)
                             .count
        total_players = @game.game_sessions.count

        position = higher_scores + 1
        percentile = total_players > 1 ? ((total_players - position).to_f / (total_players - 1) * 100).round(1) : 100.0

        {
          position: position,
          total_players: total_players,
          percentile: percentile
        }
      end
    end
  end
end
