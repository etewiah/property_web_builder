module Pwb
  # User model for authentication and authorization.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::User for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  # Zoho CRM Integration:
  # This model includes ZohoSyncable which automatically syncs new signups
  # to Zoho CRM as Leads. The Zoho lead ID is stored in the metadata JSONB column.
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
  class User < ApplicationRecord
    include AASM
    include ZohoSyncable

    # Include Devise modules for authentication:
    # - :database_authenticatable - email/password authentication
    # - :registerable - user registration
    # - :recoverable - password reset via email
    # - :rememberable - remember me cookie
    # - :trackable - sign in tracking (count, timestamps, IP)
    # - :validatable - email/password validation
    # - :lockable - account lockout after failed attempts
    # - :timeoutable - session timeout after inactivity
    # - :omniauthable - OAuth authentication (Facebook)
    devise :database_authenticatable, :registerable,
      :recoverable, :rememberable, :trackable,
      :validatable, :lockable, :timeoutable,
      :omniauthable, omniauth_providers: [:facebook]

    # Fix for Devise compatibility with Ruby 3.4
    # Ruby 3.4 changed keyword argument handling which breaks Devise's serialize_from_session
    # This override handles both legacy (key only) and new (key, salt) serialization formats
    def self.serialize_from_session(key, salt = nil)
      record = to_adapter.get(key)
      # If salt is provided, verify it matches (new format)
      # If salt is nil, allow authentication (legacy format or test environment)
      if salt.nil?
        record
      else
        record if record && record.authenticatable_salt == salt
      end
    end

    belongs_to :website, optional: true # Made optional for multi-website support
    has_many :authorizations
    has_many :auth_audit_logs, class_name: 'Pwb::AuthAuditLog', dependent: :destroy

    # Multi-website support via memberships
    has_many :user_memberships, dependent: :destroy
    has_many :websites, through: :user_memberships

    # Callbacks for audit logging
    after_create :log_registration
    after_update :log_lockout_events

    # Onboarding state machine for new user signup flow
    aasm column: :onboarding_state do
      state :lead, initial: true          # Just provided email
      state :registered                    # Account created but not verified
      state :email_verified                # Email verified
      state :onboarding                    # Going through signup wizard
      state :active                        # Fully onboarded
      state :churned                       # Abandoned signup

      event :register do
        transitions from: :lead, to: :registered
        after do
          update!(onboarding_started_at: Time.current)
        end
      end

      event :verify_email do
        transitions from: :registered, to: :email_verified
      end

      event :start_onboarding do
        transitions from: [:lead, :email_verified], to: :onboarding
        after do
          update!(onboarding_step: 1, onboarding_started_at: Time.current) if onboarding_started_at.blank?
        end
      end

      event :complete_onboarding do
        transitions from: :onboarding, to: :active
        after do
          update!(onboarding_completed_at: Time.current)
        end
      end

      event :activate do
        # Allow direct activation for existing users or admin-created users
        transitions from: [:lead, :registered, :email_verified, :onboarding], to: :active
        after do
          update!(onboarding_completed_at: Time.current) if onboarding_completed_at.blank?
        end
      end

      event :mark_churned do
        transitions from: [:lead, :registered, :email_verified, :onboarding], to: :churned
      end

      event :reactivate do
        transitions from: :churned, to: :lead
      end
    end

    # Onboarding step titles for progress display
    ONBOARDING_STEPS = {
      1 => 'Verify Email',
      2 => 'Choose Subdomain',
      3 => 'Select Site Type',
      4 => 'Setup Complete'
    }.freeze

    def onboarding_step_title
      ONBOARDING_STEPS[onboarding_step] || 'Getting Started'
    end

    def advance_onboarding_step!
      new_step = (onboarding_step || 0) + 1
      update!(onboarding_step: new_step)
      complete_onboarding! if new_step >= ONBOARDING_STEPS.keys.max
    end

    def onboarding_progress_percentage
      return 100 if active?
      return 0 if onboarding_step.nil? || onboarding_step.zero?
      ((onboarding_step.to_f / ONBOARDING_STEPS.keys.max) * 100).round
    end

    def needs_onboarding?
      %w[lead registered email_verified onboarding].include?(onboarding_state)
    end

    # Returns user's display name (full name or email)
    def display_name
      name = [first_names, last_names].compact_blank.join(' ')
      name.presence || email
    end

    # Helper methods for role-based access
    def admin_for?(website)
      user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
    end

    def role_for(website)
      user_memberships.active.find_by(website: website)&.role
    end

    def accessible_websites
      websites.where(pwb_user_memberships: { active: true })
    end

    validates :website, presence: true, if: -> { user_memberships.none? } # Require either website or memberships
    validate :within_subscription_user_limit, on: :create

    # Devise hook to check if user should be allowed to sign in
    # This ensures users can only authenticate on their assigned website/subdomain
    # or on websites where they have an active membership
    def active_for_authentication?
      return false unless super

      # If no current website context, allow authentication
      return true if current_website.blank?

      # Allow if user's primary website matches
      return true if website_id == current_website.id

      # Allow if user has an active membership for this website
      return true if user_memberships.active.exists?(website: current_website)

      # Firebase users (identified by firebase_uid) should be allowed
      # Their membership is handled in the Firebase auth controller
      return true if firebase_uid.present?

      false
    end

    # Custom error message when authentication fails due to wrong subdomain
    def inactive_message
      if website.blank? && user_memberships.none?
        :invalid_website
      elsif current_website.present? && !can_access_website?(current_website)
        :invalid_website
      else
        super
      end
    end

    # Check if user can access a specific website
    def can_access_website?(website)
      return false unless website
      website_id == website.id || user_memberships.active.exists?(website: website)
    end

    private

    # Helper to get current website from Pwb::Current
    def current_website
      Pwb::Current.website
    end

    public

    # TODO: - use db col for below
    def default_client_locale
      :en
    end

    def self.find_for_oauth(auth, website: nil)
      authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s).first
      return authorization.user if authorization

      email = auth.info[:email]
      unless email.present?
        # below is a workaround for when email is not available from auth provider
        email = "#{SecureRandom.urlsafe_base64}@example.com"
        # in future might redirect to a page where email can be requested
      end
      user = User.where(email: email).first
      if user
        user.create_authorization(auth)
      else
        # need to prefix Devise with :: to avoid confusion with Pwb::Devise
        password = ::Devise.friendly_token[0, 20]
        # Get current website from parameter or Pwb::Current
        current_website = website || Pwb::Current.website || Pwb::Website.first
        user = User.create!(
          email: email, 
          password: password, 
          password_confirmation: password,
          website: current_website
        )
        user.create_authorization(auth)
      end

      user
    end

    def create_authorization(auth)
      authorizations.create(provider: auth.provider, uid: auth.uid)
    end

    # Get recent authentication activity for this user
    def recent_auth_activity(limit: 20)
      auth_audit_logs.recent.limit(limit)
    end

    # Check if there's suspicious activity for this user
    def suspicious_activity?(threshold: 5, since: 1.hour.ago)
      auth_audit_logs.failures.where('created_at >= ?', since).count >= threshold
    end

    private

    def log_registration
      Pwb::AuthAuditLog.log_registration(user: self, request: nil, website: self.website)
    rescue StandardError => e
      Rails.logger.error("[AuthAuditLog] Failed to log registration: #{e.message}")
    end

    def log_lockout_events
      # Log when account gets locked
      if saved_change_to_locked_at? && locked_at.present?
        Pwb::AuthAuditLog.log_account_locked(user: self)
      end

      # Log when account gets unlocked
      if saved_change_to_locked_at? && locked_at.nil? && locked_at_before_last_save.present?
        unlock_method = unlock_token_before_last_save.present? ? 'email' : 'time'
        Pwb::AuthAuditLog.log_account_unlocked(user: self, unlock_method: unlock_method)
      end
    rescue StandardError => e
      Rails.logger.error("[AuthAuditLog] Failed to log lockout event: #{e.message}")
    end

    # Validate that creating this user doesn't exceed the subscription's user limit
    def within_subscription_user_limit
      return unless website # Skip if no website (validation will catch this separately)
      return unless website.subscription # No subscription = no limits (legacy behavior)

      unless website.can_add_user?
        limit = website.subscription.plan.user_limit
        errors.add(:base, "User limit reached. Your plan allows #{limit} users. Please upgrade to add more.")
      end
    end
  end
end
