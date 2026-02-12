# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class ResultsController < BaseController
        before_action :find_game!

        # GET /api_public/v1/hpg/games/:slug/results/:session_id
        def show
          expires_in 1.minute, public: true

          session = @game.game_sessions.find(params[:session_id])
          render json: Pwb::Hpg::ResultBoardSerializer.call(session, @game)
        end
      end
    end
  end
end
