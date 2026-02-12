# frozen_string_literal: true

module Pwb
  module Hpg
    # Serializes a RealtyGame for the games list endpoint
    class GameSerializer
      def self.call(game)
        {
          slug: game.slug,
          title: game.title,
          description: game.description,
          bg_image_url: game.bg_image_url,
          default_currency: game.default_currency,
          default_country: game.default_country,
          listings_count: game.listings_count,
          sessions_count: game.sessions_count,
          estimates_count: game.estimates_count,
          active: game.active,
          hidden_from_landing_page: game.hidden_from_landing_page,
          start_at: game.start_at&.iso8601,
          end_at: game.end_at&.iso8601,
          validation_rules: game.validation_rules
        }
      end
    end
  end
end
