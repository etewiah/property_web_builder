# frozen_string_literal: true

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
require 'rails_helper'

module Pwb
  RSpec.describe Agency, type: :model do
    let(:website) { FactoryBot.create(:pwb_website, subdomain: 'agency-test') }

    before(:each) do
      Pwb::Current.reset
    end

    let(:agency) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_agency, website: website)
      end
    end

    it 'has a valid factory' do
      expect(agency).to be_valid
    end
  end
end
