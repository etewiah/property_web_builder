# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of RealtyAsset.
  # Inherits all functionality from Pwb::RealtyAsset but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::RealtyAsset for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_realty_assets
#
#  id                 :uuid             not null, primary key
#  city               :string
#  constructed_area   :float            default(0.0)
#  count_bathrooms    :float            default(0.0)
#  count_bedrooms     :integer          default(0)
#  count_garages      :integer          default(0)
#  count_toilets      :integer          default(0)
#  country            :string
#  description        :text
#  energy_performance :float
#  energy_rating      :integer
#  latitude           :float
#  longitude          :float
#  plot_area          :float            default(0.0)
#  postal_code        :string
#  prop_origin_key    :string
#  prop_photos_count  :integer          default(0), not null
#  prop_state_key     :string
#  prop_type_key      :string
#  reference          :string
#  region             :string
#  slug               :string
#  street_address     :string
#  street_name        :string
#  street_number      :string
#  title              :string
#  translations       :jsonb            not null
#  year_construction  :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :integer
#
# Indexes
#
#  index_pwb_realty_assets_on_prop_photos_count             (prop_photos_count)
#  index_pwb_realty_assets_on_prop_state_key                (prop_state_key)
#  index_pwb_realty_assets_on_prop_type_key                 (prop_type_key)
#  index_pwb_realty_assets_on_slug                          (slug) UNIQUE
#  index_pwb_realty_assets_on_translations                  (translations) USING gin
#  index_pwb_realty_assets_on_website_id                    (website_id)
#  index_pwb_realty_assets_on_website_id_and_prop_type_key  (website_id,prop_type_key)
#
  class RealtyAsset < Pwb::RealtyAsset
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
