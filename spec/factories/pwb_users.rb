# == Schema Information
#
# Table name: pwb_users
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
#
FactoryBot.define do
  factory :pwb_user, class: 'Pwb::User' do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }

    # Associate with a website (required as of multi-tenant authentication)
    association :website, factory: :pwb_website

    trait :admin do
      admin { true }

      # Also create admin membership for the website
      after(:create) do |user|
        Pwb::UserMembership.find_or_create_by!(user: user, website: user.website) do |m|
          m.role = 'admin'
          m.active = true
        end
      end
    end

    trait :with_membership do
      transient do
        membership_role { 'member' }
        membership_active { true }
      end

      after(:create) do |user, evaluator|
        Pwb::UserMembership.find_or_create_by!(user: user, website: user.website) do |m|
          m.role = evaluator.membership_role
          m.active = evaluator.membership_active
        end
      end
    end
  end
end
