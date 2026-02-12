# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_game_sessions
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  guest_name         :string
#  performance_rating :string
#  total_score        :integer          default(0), not null
#  user_uuid          :string
#  visitor_token      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  realty_game_id     :uuid             not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_game_sessions_on_game_and_visitor   (realty_game_id,visitor_token)
#  index_pwb_game_sessions_on_realty_game_id     (realty_game_id)
#  index_pwb_game_sessions_on_website_and_score  (website_id,total_score)
#  index_pwb_game_sessions_on_website_id         (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (realty_game_id => pwb_realty_games.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class GameSession < ApplicationRecord
    self.table_name = 'pwb_game_sessions'

    belongs_to :realty_game
    belongs_to :website
    has_many :game_estimates, dependent: :destroy

    validates :visitor_token, presence: true

    scope :for_leaderboard, -> { order(total_score: :desc, created_at: :asc) }

    def recalculate_total_score!
      update!(total_score: game_estimates.sum(:score))
    end

    def estimates_count
      game_estimates.count
    end

    def compute_performance_rating
      return nil if game_estimates.empty?

      possible = game_estimates.count * 100
      ratio = total_score.to_f / possible

      rating = if ratio >= 0.9
                 'expert'
               elsif ratio >= 0.7
                 'advanced'
               elsif ratio >= 0.5
                 'intermediate'
               elsif ratio >= 0.3
                 'beginner'
               else
                 'novice'
               end

      update!(performance_rating: rating)
      rating
    end
  end
end
