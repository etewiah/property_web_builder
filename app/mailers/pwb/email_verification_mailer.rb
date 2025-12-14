# frozen_string_literal: true

module Pwb
  class EmailVerificationMailer < Pwb::ApplicationMailer
    # Send verification email to website owner
    # Contains a link they must click to verify their email address
    #
    # @param website [Pwb::Website] The website to verify
    def verification_email(website)
      @website = website
      @owner_email = website.owner_email
      @verification_url = build_verification_url(website)
      @expires_in = Website::EMAIL_VERIFICATION_EXPIRY / 1.day # days

      mail(
        to: @owner_email,
        subject: "Verify your email to activate #{website.subdomain}",
        template_path: "pwb/mailers",
        template_name: "email_verification"
      )
    end

    # Send a new verification email (resend functionality)
    # Regenerates the token before sending
    #
    # @param website [Pwb::Website] The website to verify
    def resend_verification_email(website)
      website.regenerate_email_verification_token!
      verification_email(website)
    end

    private

    def build_verification_url(website)
      base_url = ENV.fetch('SIGNUP_BASE_URL') { 'http://localhost:3000' }
      "#{base_url}/api/signup/verify_email?token=#{website.email_verification_token}"
    end
  end
end
