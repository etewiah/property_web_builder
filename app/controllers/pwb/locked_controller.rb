# frozen_string_literal: true

module Pwb
  # Controller for handling locked website pages
  # Locked websites are in a state where they need email verification or registration
  class LockedController < Pwb::ApplicationController
    # Skip the check_locked_website filter since we're handling the locked state here
    skip_before_action :check_locked_website

    before_action :require_locked_website, only: [:resend_verification, :submit_resend_verification]

    # GET /resend_verification
    # Show form for user to enter email to resend verification
    def resend_verification
      @email = params[:email]
      render layout: 'pwb/locked'
    end

    # POST /resend_verification
    # Process the resend verification form
    def submit_resend_verification
      @email = params[:email]&.strip&.downcase

      if @email.blank?
        @error = "Please enter your email address"
        return render :resend_verification, layout: 'pwb/locked'
      end

      unless @email.match?(URI::MailTo::EMAIL_REGEXP)
        @error = "Please enter a valid email address"
        return render :resend_verification, layout: 'pwb/locked'
      end

      # Check if the email matches the website's owner email
      unless @email == @current_website.owner_email&.downcase
        @error = "This email address doesn't match our records for this website. Please check your email and try again."
        return render :resend_verification, layout: 'pwb/locked'
      end

      # Check if the website is in the right state
      unless @current_website.locked_pending_email_verification?
        if @current_website.locked_pending_registration?
          @error = "Your email has already been verified. Please create your account."
        elsif @current_website.live?
          @error = "This website is already active."
        else
          @error = "Unable to resend verification email. Please contact support."
        end
        return render :resend_verification, layout: 'pwb/locked'
      end

      # Regenerate token and send email
      @current_website.regenerate_email_verification_token!
      mailer = Pwb::EmailVerificationMailer.verification_email(@current_website)
      # Use deliver_now in development for immediate letter_opener preview
      if Rails.env.development?
        mailer.deliver_now
      else
        mailer.deliver_later
      end

      @success = "Verification email sent! Please check your inbox (and spam folder) for an email from us."
      render :resend_verification, layout: 'pwb/locked'
    end

    private

    # Ensure we're on a locked website
    def require_locked_website
      unless @current_website&.locked?
        redirect_to root_path
      end
    end
  end
end
