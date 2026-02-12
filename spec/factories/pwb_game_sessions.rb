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
FactoryBot.define do
  factory :pwb_game_session, class: 'Pwb::GameSession' do
    association :realty_game, factory: :pwb_realty_game
    association :website, factory: :pwb_website
    visitor_token { SecureRandom.urlsafe_base64(16) }
    guest_name { 'Test Player' }
    total_score { 0 }
  end
end
