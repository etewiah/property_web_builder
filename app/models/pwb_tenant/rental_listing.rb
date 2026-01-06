# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of RentalListing.
  # Inherits all functionality from Pwb::RentalListing but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::RentalListing for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_rental_listings
# Database name: primary
#
#  id                                     :uuid             not null, primary key
#  active                                 :boolean          default(FALSE), not null
#  archived                               :boolean          default(FALSE)
#  for_rent_long_term                     :boolean          default(FALSE)
#  for_rent_short_term                    :boolean          default(FALSE)
#  furnished                              :boolean          default(FALSE)
#  game_enabled                           :boolean          default(FALSE)
#  game_shares_count                      :integer          default(0)
#  game_token                             :string
#  game_views_count                       :integer          default(0)
#  highlighted                            :boolean          default(FALSE)
#  noindex                                :boolean          default(FALSE), not null
#  price_rental_monthly_current_cents     :bigint           default(0)
#  price_rental_monthly_current_currency  :string           default("EUR")
#  price_rental_monthly_high_season_cents :bigint           default(0)
#  price_rental_monthly_low_season_cents  :bigint           default(0)
#  reference                              :string
#  reserved                               :boolean          default(FALSE)
#  translations                           :jsonb            not null
#  visible                                :boolean          default(FALSE)
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  realty_asset_id                        :uuid
#
# Indexes
#
#  index_pwb_rental_listings_on_game_token       (game_token) UNIQUE WHERE (game_token IS NOT NULL)
#  index_pwb_rental_listings_on_noindex          (noindex)
#  index_pwb_rental_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_rental_listings_on_translations     (translations) USING gin
#  index_pwb_rental_listings_unique_active       (realty_asset_id,active) UNIQUE WHERE (active = true)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
  class RentalListing < Pwb::RentalListing
    include RequiresTenant
    acts_as_tenant :website, through: :realty_asset, class_name: 'Pwb::Website'
  end
end
