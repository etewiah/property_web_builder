# frozen_string_literal: true

# Helper methods for authentication across views
#
# These helpers provide dynamic login/logout paths based on the
# configured authentication provider (Firebase or Devise).
#
# Usage in views:
#   <%= link_to "Sign In", auth_login_path %>
#   <%= link_to "Sign Up", auth_signup_path %>
#   <%= link_to "Sign Out", auth_logout_path, method: :delete %>
#
module AuthHelper
  # Returns the login path based on configured auth provider
  # @param return_to [String] Optional URL to return to after login
  # @return [String] The login path
  def auth_login_path(return_to: nil)
    base_path = Pwb::AuthConfig.login_path(locale: I18n.locale)
    return_to.present? ? "#{base_path}?return_to=#{CGI.escape(return_to)}" : base_path
  end

  # Returns the signup path based on configured auth provider
  # @return [String] The signup path
  def auth_signup_path
    Pwb::AuthConfig.signup_path(locale: I18n.locale)
  end

  # Returns the forgot password path based on configured auth provider
  # @return [String] The forgot password path
  def auth_forgot_password_path
    Pwb::AuthConfig.forgot_password_path(locale: I18n.locale)
  end

  # Returns the logout path (unified for both providers)
  # @return [String] The logout path
  def auth_logout_path
    Pwb::AuthConfig.logout_path
  end

  # Check if using Firebase authentication
  # @return [Boolean]
  def using_firebase_auth?
    Pwb::AuthConfig.firebase?
  end

  # Check if using Devise authentication
  # @return [Boolean]
  def using_devise_auth?
    Pwb::AuthConfig.devise?
  end

  # Returns the current auth provider name
  # @return [Symbol] :firebase or :devise
  def current_auth_provider
    Pwb::AuthConfig.provider
  end

  # Helper to render login link with appropriate styling
  # @param text [String] Link text (default: "Sign In")
  # @param options [Hash] HTML options for the link
  # @return [String] HTML link tag
  def auth_login_link(text = "Sign In", **options)
    link_to text, auth_login_path, options
  end

  # Helper to render logout link with appropriate method
  # @param text [String] Link text (default: "Sign Out")
  # @param options [Hash] HTML options for the link
  # @return [String] HTML link tag
  def auth_logout_link(text = "Sign Out", **options)
    # Use DELETE method for Devise compatibility
    options[:data] ||= {}
    options[:data][:turbo_method] = :delete
    link_to text, auth_logout_path, options
  end

  # Helper to render signup link
  # @param text [String] Link text (default: "Sign Up")
  # @param options [Hash] HTML options for the link
  # @return [String] HTML link tag
  def auth_signup_link(text = "Sign Up", **options)
    link_to text, auth_signup_path, options
  end
end
