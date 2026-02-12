# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class LeaderboardsController < BaseController
        # GET /api_public/v1/hpg/leaderboards
        def index
          expires_in 1.minute, public: true

          sessions = current_website.game_sessions.for_leaderboard
          sessions = filter_by_game(sessions)
          sessions = filter_by_period(sessions)

          limit = [(params[:limit] || 20).to_i, 100].min
          data = sessions.limit(limit).includes(:realty_game).map do |s|
            {
              rank: nil, # computed below
              guest_name: s.guest_name,
              total_score: s.total_score,
              estimates_count: s.estimates_count,
              game_slug: s.realty_game.slug,
              game_title: s.realty_game.title,
              created_at: s.created_at.iso8601
            }
          end

          data.each_with_index { |entry, i| entry[:rank] = i + 1 }

          render json: {
            data: data,
            meta: {
              total: sessions.count,
              period: params[:period] || 'all_time',
              game_slug: params[:game_slug]
            }
          }
        end

        private

        def filter_by_game(sessions)
          return sessions if params[:game_slug].blank?

          sessions.joins(:realty_game)
                  .where(pwb_realty_games: { slug: params[:game_slug] })
        end

        def filter_by_period(sessions)
          case params[:period]
          when 'daily'   then sessions.where('pwb_game_sessions.created_at >= ?', 1.day.ago)
          when 'weekly'  then sessions.where('pwb_game_sessions.created_at >= ?', 1.week.ago)
          when 'monthly' then sessions.where('pwb_game_sessions.created_at >= ?', 1.month.ago)
          else sessions
          end
        end
      end
    end
  end
end
