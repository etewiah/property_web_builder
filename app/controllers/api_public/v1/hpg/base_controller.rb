# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class BaseController < ApiPublic::V1::BaseController
        private

        # Override: shorter default cache for game data
        def set_api_public_cache_headers
          expires_in 5.minutes, public: true
          response.headers["Vary"] = "X-Website-Slug"
        end

        def disable_cache!
          response.headers["Cache-Control"] = "no-store"
        end

        def find_game!
          @game = current_website.realty_games.find_by!(slug: params[:slug])
        end

        def require_website!
          return if current_website.present?

          render json: {
            error: { code: 'WEBSITE_REQUIRED', message: 'Unable to determine website from request.' }
          }, status: :bad_request
        end
      end
    end
  end
end
