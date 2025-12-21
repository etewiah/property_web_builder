# frozen_string_literal: true

# SignupSession
#
# Manages the signup wizard session state in a centralized way.
# Provides a clean interface for storing and retrieving signup data
# across the multi-step wizard flow.
#
module SignupSession
  extend ActiveSupport::Concern

  SESSION_KEYS = %i[signup_user_id signup_subdomain signup_website_id].freeze

  included do
    helper_method :signup_session if respond_to?(:helper_method)
  end

  # Get or initialize the signup session manager
  def signup_session
    @signup_session ||= SignupSessionManager.new(session)
  end

  # Clear all signup session data
  def clear_signup_session
    signup_session.clear
  end

  # SignupSessionManager encapsulates all session operations
  class SignupSessionManager
    attr_reader :session

    def initialize(session)
      @session = session
    end

    # User accessors
    def user_id
      session[:signup_user_id]
    end

    def user_id=(id)
      session[:signup_user_id] = id
    end

    def user
      @user ||= Pwb::User.find_by(id: user_id) if user_id
    end

    def user=(user)
      self.user_id = user&.id
      @user = user
    end

    # Subdomain accessors
    def subdomain
      session[:signup_subdomain]
    end

    def subdomain=(name)
      session[:signup_subdomain] = name
    end

    # Website accessors
    def website_id
      session[:signup_website_id]
    end

    def website_id=(id)
      session[:signup_website_id] = id
    end

    def website
      @website ||= Pwb::Website.find_by(id: website_id) if website_id
    end

    def website=(website)
      self.website_id = website&.id
      @website = website
    end

    # State checks
    def has_user?
      user.present?
    end

    def has_website?
      website.present?
    end

    def complete?
      website&.live? && user&.active?
    end

    # Current step determination
    def current_step
      return 4 if complete?
      return 3 if has_website?
      return 2 if has_user?
      1
    end

    # Clear all session data
    def clear
      SESSION_KEYS.each { |key| session.delete(key) }
      @user = nil
      @website = nil
    end

    # Store result from provisioning service
    def store_start_result(result)
      self.user = result[:user]
      self.subdomain = result[:subdomain]&.name
    end

    def store_configure_result(result)
      self.website = result[:website]
    end
  end
end
