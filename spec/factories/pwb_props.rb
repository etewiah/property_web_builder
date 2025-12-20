# == Schema Information
#
# Table name: pwb_props
#
#  id                                            :integer          not null, primary key
#  active_from                                   :datetime
#  archived                                      :boolean          default(FALSE)
#  area_unit                                     :integer          default("sqmt")
#  available_to_rent_from                        :datetime
#  available_to_rent_till                        :datetime
#  city                                          :string
#  commission_cents                              :integer          default(0), not null
#  commission_currency                           :string           default("EUR"), not null
#  constructed_area                              :float            default(0.0), not null
#  count_bathrooms                               :float            default(0.0), not null
#  count_bedrooms                                :integer          default(0), not null
#  count_garages                                 :integer          default(0), not null
#  count_toilets                                 :integer          default(0), not null
#  country                                       :string
#  currency                                      :string
#  deleted_at                                    :datetime
#  energy_performance                            :float
#  energy_rating                                 :integer
#  flags                                         :integer          default(0), not null
#  for_rent_long_term                            :boolean          default(FALSE)
#  for_rent_short_term                           :boolean          default(FALSE)
#  for_sale                                      :boolean          default(FALSE)
#  furnished                                     :boolean          default(FALSE)
#  hide_map                                      :boolean          default(FALSE)
#  highlighted                                   :boolean          default(FALSE)
#  latitude                                      :float
#  longitude                                     :float
#  meta_description                              :text
#  obscure_map                                   :boolean          default(FALSE)
#  plot_area                                     :float            default(0.0), not null
#  portals_enabled                               :boolean          default(FALSE)
#  postal_code                                   :string
#  price_rental_monthly_current_cents            :integer          default(0), not null
#  price_rental_monthly_current_currency         :string           default("EUR"), not null
#  price_rental_monthly_for_search_cents         :integer          default(0), not null
#  price_rental_monthly_for_search_currency      :string           default("EUR"), not null
#  price_rental_monthly_high_season_cents        :integer          default(0), not null
#  price_rental_monthly_high_season_currency     :string           default("EUR"), not null
#  price_rental_monthly_low_season_cents         :integer          default(0), not null
#  price_rental_monthly_low_season_currency      :string           default("EUR"), not null
#  price_rental_monthly_original_cents           :integer          default(0), not null
#  price_rental_monthly_original_currency        :string           default("EUR"), not null
#  price_rental_monthly_standard_season_cents    :integer          default(0), not null
#  price_rental_monthly_standard_season_currency :string           default("EUR"), not null
#  price_sale_current_cents                      :bigint           default(0), not null
#  price_sale_current_currency                   :string           default("EUR"), not null
#  price_sale_original_cents                     :bigint           default(0), not null
#  price_sale_original_currency                  :string           default("EUR"), not null
#  prop_origin_key                               :string           default(""), not null
#  prop_state_key                                :string           default(""), not null
#  prop_type_key                                 :string           default(""), not null
#  province                                      :string
#  reference                                     :string
#  region                                        :string
#  reserved                                      :boolean          default(FALSE)
#  seo_title                                     :string
#  service_charge_yearly_cents                   :integer          default(0), not null
#  service_charge_yearly_currency                :string           default("EUR"), not null
#  sold                                          :boolean          default(FALSE)
#  street_address                                :string
#  street_name                                   :string
#  street_number                                 :string
#  translations                                  :jsonb            not null
#  visible                                       :boolean          default(FALSE)
#  year_construction                             :integer          default(0), not null
#  created_at                                    :datetime         not null
#  updated_at                                    :datetime         not null
#  website_id                                    :integer
#
# Indexes
#
#  index_pwb_props_on_archived                            (archived)
#  index_pwb_props_on_flags                               (flags)
#  index_pwb_props_on_for_rent_long_term                  (for_rent_long_term)
#  index_pwb_props_on_for_rent_short_term                 (for_rent_short_term)
#  index_pwb_props_on_for_sale                            (for_sale)
#  index_pwb_props_on_highlighted                         (highlighted)
#  index_pwb_props_on_latitude_and_longitude              (latitude,longitude)
#  index_pwb_props_on_price_rental_monthly_current_cents  (price_rental_monthly_current_cents)
#  index_pwb_props_on_price_sale_current_cents            (price_sale_current_cents)
#  index_pwb_props_on_reference                           (reference)
#  index_pwb_props_on_translations                        (translations) USING gin
#  index_pwb_props_on_visible                             (visible)
#  index_pwb_props_on_website_id                          (website_id)
#
FactoryBot.define do
  factory :pwb_prop, class: 'PwbTenant::Prop' do
    title_en { "A property for " }
    currency { "USD" }
    association :website, factory: :pwb_website
    trait :sale do
      for_sale { true }
      visible { true }
    end
    trait :long_term_rent do
      for_rent_long_term { true }
      visible { true }
    end
    trait :short_term_rent do
      for_rent_short_term { true }
      visible { true }
    end
  end
end
