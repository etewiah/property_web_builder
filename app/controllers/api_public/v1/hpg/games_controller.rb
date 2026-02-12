# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class GamesController < BaseController
        before_action :find_game!, only: :show

        # GET /api_public/v1/hpg/games
        def index
          expires_in 1.hour, public: true

          games = current_website.realty_games.visible_on_landing.currently_available
          data = games.map { |g| Pwb::Hpg::GameSerializer.call(g) }

          render json: { data: data, meta: { total: data.size } }
        end

        # GET /api_public/v1/hpg/games/:slug
        def show
          render json: Pwb::Hpg::GameSummarySerializer.call(@game)
        end
      end
    end
  end
end
