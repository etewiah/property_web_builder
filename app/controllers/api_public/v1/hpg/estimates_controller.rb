# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class EstimatesController < BaseController
        before_action :find_game!

        # POST /api_public/v1/hpg/games/:slug/estimates
        def create
          disable_cache!

          result = Pwb::Hpg::EstimateProcessor.call(
            game: @game,
            website: current_website,
            params: estimate_params
          )

          if result[:error]
            render json: { error: result[:error] }, status: result[:status]
          else
            render json: result[:data], status: :created
          end
        end

        private

        def estimate_params
          params.require(:price_estimate).permit(
            :game_listing_id, :estimated_price, :currency,
            :visitor_token, :guest_name, :property_index, :session_id
          )
        end
      end
    end
  end
end
