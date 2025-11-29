module Pwb
  class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    devise :database_authenticatable, :registerable,
      :recoverable, :rememberable, :trackable,
      :validatable, :omniauthable, omniauth_providers: [:facebook]

    belongs_to :website
    has_many :authorizations

    validates :website, presence: true

    # Devise hook to check if user should be allowed to sign in
    # This ensures users can only authenticate on their assigned website/subdomain
    def active_for_authentication?
      super && website.present?
    end

    # Custom error message when authentication fails due to wrong subdomain
    def inactive_message
      website.present? ? super : :invalid_website
    end

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
  end
end
