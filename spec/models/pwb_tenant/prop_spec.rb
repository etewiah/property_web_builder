# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_props
# Database name: primary
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
require 'rails_helper'

module PwbTenant
  RSpec.describe Prop, type: :model do
    # PwbTenant::Prop is a scoped model that inherits from Pwb::Prop
    # It provides multi-tenant isolation by filtering by current website

    let!(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a-prop') }
    let!(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b-prop') }

    let!(:prop_a) do
      ActsAsTenant.with_tenant(website_a) do
        FactoryBot.create(:pwb_prop, :sale, website: website_a)
      end
    end
    let!(:prop_b) do
      ActsAsTenant.with_tenant(website_b) do
        FactoryBot.create(:pwb_prop, :sale, website: website_b)
      end
    end

    before do
      Pwb::Current.reset
      # Simulate request context
      allow(Pwb::Current).to receive(:website).and_return(website_a)
      ActsAsTenant.current_tenant = website_a
    end

    after do
      ActsAsTenant.current_tenant = nil
    end

    describe 'default scope' do
      it 'only returns props for current website' do
        ids = described_class.all.map(&:id)
        expect(ids).to include(prop_a.id)
        expect(ids).not_to include(prop_b.id)
      end

      it 'finds prop belonging to current website' do
        found_prop = described_class.find(prop_a.id)
        expect(found_prop.id).to eq(prop_a.id)
        expect(found_prop).to be_a(PwbTenant::Prop)
      end

      it 'raises RecordNotFound for prop belonging to other website' do
        expect do
          described_class.find(prop_b.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'inheritance' do
      it 'inherits methods from Pwb::Prop' do
        prop = described_class.find(prop_a.id)
        expect(prop).to respond_to(:url_friendly_title)
        expect(prop).to be_a(Pwb::Prop)
      end
    end
  end
end
