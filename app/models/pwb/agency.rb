# frozen_string_literal: true

module Pwb
  # Agency represents the real estate agency information for a website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Agency for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
# == Schema Information
#
# Table name: pwb_agencies
# Database name: primary
#
#  id                              :integer          not null, primary key
#  analytics_id_type               :integer
#  available_currencies            :text             default([]), is an Array
#  available_locales               :text             default([]), is an Array
#  company_id_type                 :integer
#  company_name                    :string
#  default_admin_locale            :string
#  default_client_locale           :string
#  default_currency                :string
#  details                         :json
#  display_name                    :string
#  email_for_general_contact_form  :string
#  email_for_property_contact_form :string
#  email_primary                   :string
#  flags                           :integer          default(0), not null
#  phone_number_mobile             :string
#  phone_number_other              :string
#  phone_number_primary            :string
#  raw_css                         :text
#  site_configuration              :json
#  skype                           :string
#  social_media                    :json
#  supported_currencies            :text             default([]), is an Array
#  supported_locales               :text             default([]), is an Array
#  theme_name                      :string
#  url                             :string
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  analytics_id                    :string
#  company_id                      :string
#  payment_plan_id                 :integer
#  primary_address_id              :integer
#  secondary_address_id            :integer
#  site_template_id                :integer
#  website_id                      :integer
#
# Indexes
#
#  index_pwb_agencies_on_website_id  (website_id)
#
  class Agency < ApplicationRecord
    self.table_name = 'pwb_agencies'

    belongs_to :website, class_name: 'Pwb::Website', optional: true
    belongs_to :primary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'primary_address_id'
    belongs_to :secondary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'secondary_address_id'

    def as_json(options = nil)
      super({
        only: %w[
          display_name company_name
          phone_number_primary phone_number_mobile phone_number_other
          email_primary email_for_property_contact_form email_for_general_contact_form
        ]
      }.merge(options || {}))
    end

    delegate :street_number, :street_address, :city, :postal_code,
             to: :primary_address, allow_nil: true

    def show_contact_map
      primary_address.present?
    end
  end
end
