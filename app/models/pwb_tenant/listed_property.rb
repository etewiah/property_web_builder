# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of ListedProperty.
  # Inherits all functionality from Pwb::ListedProperty but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::ListedProperty for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_properties
# Database name: primary
#
#  id                                     :uuid             primary key
#  city                                   :string
#  commission_cents                       :bigint
#  commission_currency                    :string
#  constructed_area                       :float
#  count_bathrooms                        :float
#  count_bedrooms                         :integer
#  count_garages                          :integer
#  count_toilets                          :integer
#  country                                :string
#  currency                               :string
#  energy_performance                     :float
#  energy_rating                          :integer
#  for_rent                               :boolean
#  for_rent_long_term                     :boolean
#  for_rent_short_term                    :boolean
#  for_sale                               :boolean
#  furnished                              :boolean
#  highlighted                            :boolean
#  latitude                               :float
#  longitude                              :float
#  plot_area                              :float
#  postal_code                            :string
#  price_rental_monthly_current_cents     :bigint
#  price_rental_monthly_current_currency  :string
#  price_rental_monthly_for_search_cents  :bigint
#  price_rental_monthly_high_season_cents :bigint
#  price_rental_monthly_low_season_cents  :bigint
#  price_sale_current_cents               :bigint
#  price_sale_current_currency            :string
#  prop_origin_key                        :string
#  prop_state_key                         :string
#  prop_type_key                          :string
#  reference                              :string
#  region                                 :string
#  rental_furnished                       :boolean
#  rental_highlighted                     :boolean
#  rental_reserved                        :boolean
#  reserved                               :boolean
#  sale_furnished                         :boolean
#  sale_highlighted                       :boolean
#  sale_reserved                          :boolean
#  slug                                   :string
#  street_address                         :string
#  street_name                            :string
#  street_number                          :string
#  visible                                :boolean
#  year_construction                      :integer
#  created_at                             :datetime
#  updated_at                             :datetime
#  rental_listing_id                      :uuid
#  sale_listing_id                        :uuid
#  website_id                             :integer
#
# Indexes
#
#  index_pwb_properties_on_bathrooms           (count_bathrooms)
#  index_pwb_properties_on_bedrooms            (count_bedrooms)
#  index_pwb_properties_on_for_rent            (for_rent)
#  index_pwb_properties_on_for_sale            (for_sale)
#  index_pwb_properties_on_highlighted         (highlighted)
#  index_pwb_properties_on_id                  (id) UNIQUE
#  index_pwb_properties_on_lat_lng             (latitude,longitude)
#  index_pwb_properties_on_price_rental_cents  (price_rental_monthly_current_cents)
#  index_pwb_properties_on_price_sale_cents    (price_sale_current_cents)
#  index_pwb_properties_on_prop_type           (prop_type_key)
#  index_pwb_properties_on_reference           (reference)
#  index_pwb_properties_on_slug                (slug)
#  index_pwb_properties_on_visible             (visible)
#  index_pwb_properties_on_website_id          (website_id)
#
  class ListedProperty < Pwb::ListedProperty
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
