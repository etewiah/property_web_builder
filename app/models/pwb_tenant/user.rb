# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of User.
  # Inherits all functionality from Pwb::User but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::User for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_users
# Database name: primary
#
#  id                                 :integer          not null, primary key
#  admin                              :boolean          default(FALSE)
#  authentication_token               :string
#  confirmation_sent_at               :datetime
#  confirmation_token                 :string
#  confirmed_at                       :datetime
#  current_sign_in_at                 :datetime
#  current_sign_in_ip                 :string
#  default_admin_locale               :string
#  default_client_locale              :string
#  default_currency                   :string
#  email                              :string           default(""), not null
#  encrypted_password                 :string           default(""), not null
#  failed_attempts                    :integer          default(0), not null
#  firebase_uid                       :string
#  first_names                        :string
#  last_names                         :string
#  last_sign_in_at                    :datetime
#  last_sign_in_ip                    :string
#  locked_at                          :datetime
#  metadata                           :jsonb            not null
#  onboarding_completed_at            :datetime
#  onboarding_started_at              :datetime
#  onboarding_state                   :string           default("active"), not null
#  onboarding_step                    :integer          default(0)
#  phone_number_primary               :string
#  remember_created_at                :datetime
#  reset_password_sent_at             :datetime
#  reset_password_token               :string
#  sign_in_count                      :integer          default(0), not null
#  signup_token                       :string
#  signup_token_expires_at            :datetime
#  site_admin_onboarding_completed_at :datetime
#  skype                              :string
#  unconfirmed_email                  :string
#  unlock_token                       :string
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  website_id                         :integer
#
# Indexes
#
#  index_pwb_users_on_confirmation_token                  (confirmation_token) UNIQUE
#  index_pwb_users_on_email                               (email) UNIQUE
#  index_pwb_users_on_firebase_uid                        (firebase_uid) UNIQUE
#  index_pwb_users_on_onboarding_state                    (onboarding_state)
#  index_pwb_users_on_reset_password_token                (reset_password_token) UNIQUE
#  index_pwb_users_on_signup_token                        (signup_token) UNIQUE
#  index_pwb_users_on_site_admin_onboarding_completed_at  (site_admin_onboarding_completed_at)
#  index_pwb_users_on_unlock_token                        (unlock_token) UNIQUE
#  index_pwb_users_on_website_id                          (website_id)
#  index_pwb_users_on_zoho_lead_id                        (((metadata ->> 'zoho_lead_id'::text))) WHERE ((metadata ->> 'zoho_lead_id'::text) IS NOT NULL)
#
  class User < Pwb::User
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
