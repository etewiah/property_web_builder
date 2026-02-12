# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_game_listings
# Database name: primary
#
#  id              :uuid             not null, primary key
#  display_title   :string
#  extra_data      :jsonb            not null
#  sort_order      :integer          default(0), not null
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  realty_asset_id :uuid             not null
#  realty_game_id  :uuid             not null
#
# Indexes
#
#  index_pwb_game_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_game_listings_on_realty_game_id   (realty_game_id)
#  index_pwb_game_listings_unique_game_asset   (realty_game_id,realty_asset_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#  fk_rails_...  (realty_game_id => pwb_realty_games.id)
#
module Pwb
  class GameListing < ApplicationRecord
    self.table_name = 'pwb_game_listings'

    belongs_to :realty_game
    belongs_to :realty_asset
    has_many :game_estimates, dependent: :destroy

    validates :realty_asset_id, uniqueness: { scope: :realty_game_id }

    scope :visible, -> { where(visible: true) }
    scope :ordered, -> { order(sort_order: :asc, created_at: :asc) }

    delegate :website, to: :realty_game

    def actual_price_cents
      realty_asset.active_sale_listing&.price_sale_current_cents ||
        realty_asset.rental_listings.active.first&.price_rental_monthly_current_cents ||
        0
    end

    def actual_price_currency
      realty_asset.active_sale_listing&.price_sale_current_currency ||
        realty_asset.rental_listings.active.first&.price_rental_monthly_current_currency ||
        realty_game.default_currency
    end
  end
end
