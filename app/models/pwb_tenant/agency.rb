# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Agency.
  # Inherits all functionality from Pwb::Agency but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Agency for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_agencies
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
  #
  class Agency < Pwb::Agency
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
