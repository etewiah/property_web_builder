# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_realty_games
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  bg_image_url             :string
#  default_country          :string
#  default_currency         :string           default("EUR"), not null
#  description              :text
#  end_at                   :datetime
#  estimates_count          :integer          default(0), not null
#  hidden_from_landing_page :boolean          default(FALSE), not null
#  sessions_count           :integer          default(0), not null
#  slug                     :string           not null
#  start_at                 :datetime
#  title                    :string           not null
#  validation_rules         :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_realty_games_on_website_id             (website_id)
#  index_pwb_realty_games_on_website_id_and_active  (website_id,active)
#  index_pwb_realty_games_on_website_id_and_slug    (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class RealtyGame < ApplicationRecord
    self.table_name = 'pwb_realty_games'

    belongs_to :website
    has_many :game_listings, dependent: :destroy
    has_many :realty_assets, through: :game_listings
    has_many :game_sessions, dependent: :destroy

    validates :slug, presence: true, uniqueness: { scope: :website_id }
    validates :title, presence: true
    validates :default_currency, presence: true

    scope :active, -> { where(active: true) }
    scope :visible_on_landing, -> { active.where(hidden_from_landing_page: false) }
    scope :currently_available, -> {
      active
        .where('pwb_realty_games.start_at IS NULL OR pwb_realty_games.start_at <= ?', Time.current)
        .where('pwb_realty_games.end_at IS NULL OR pwb_realty_games.end_at >= ?', Time.current)
    }

    def listings_count
      game_listings.visible.count
    end
  end
end
