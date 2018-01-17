module Pwb
  class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :trackable, :validatable, :omniauthable, omniauth_providers: [:facebook]

    has_many :authorizations

    # TODO: - use db col for below
    def default_client_locale
      :en
    end

    def self.find_for_oauth(auth)
      authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s).first
      return authorization.user if authorization
 
      email = auth.info[:email]
      user = User.where(email: email).first
      if user
        user.create_authorization(auth)
      else
        password = Devise.friendly_token[0, 20]
        user = User.create!(email: email, password: password, password_confirmation: password)
        user.create_authorization(auth)
      end
 
      user
    end
 
    def create_authorization(auth)
      self.authorizations.create(provider: auth.provider, uid: auth.uid)
    end
  end
end
