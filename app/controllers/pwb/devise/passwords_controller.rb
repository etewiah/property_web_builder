# frozen_string_literal: true

class Pwb::Devise::PasswordsController < Devise::PasswordsController
  # POST /users/password
  # Request password reset
  def create
    # Log the password reset request
    Pwb::AuthAuditLog.log_password_reset_request(
      email: resource_params[:email],
      request: request
    )
    super
  end

  # PUT /users/password
  # Reset password with token
  def update
    super do |resource|
      if resource.errors.empty?
        # Log successful password reset
        Pwb::AuthAuditLog.log_password_reset_success(
          user: resource,
          request: request
        )
      else
        # Log failed password reset attempt
        Pwb::AuthAuditLog.log_login_failure(
          email: resource.email,
          reason: 'password_reset_failed',
          request: request
        )
      end
    end
  end
end
