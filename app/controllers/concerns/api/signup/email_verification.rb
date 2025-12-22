# frozen_string_literal: true

module Api
  module Signup
    # EmailVerification
    #
    # Handles email verification flow for signup API:
    # - verify_email: Verify email address via token link
    # - resend_verification: Resend verification email
    # - complete_registration: Complete registration after Firebase account
    #
    module EmailVerification
      extend ActiveSupport::Concern

      # GET /api/signup/verify_email
      # Verify email address via token (called when user clicks link in email)
      # This does NOT require signup_token - uses the email verification token instead
      #
      def verify_email
        token = params[:token]

        if token.blank?
          return error_response("Verification token is required", status: :bad_request)
        end

        website = Pwb::Website.find_by_verification_token(token)

        unless website
          return error_response("Invalid verification link. Please request a new one.", status: :not_found)
        end

        unless website.locked_pending_email_verification?
          return handle_already_verified(website)
        end

        unless website.email_verification_valid?
          return error_response("Verification link has expired. Please request a new one.", status: :gone)
        end

        process_email_verification(website)
      end

      # POST /api/signup/resend_verification
      # Resend the verification email (requires signup_token)
      #
      def resend_verification
        website = @signup_user.websites.first

        unless website
          return error_response("No website found. Please complete signup first.", status: :not_found)
        end

        validation_error = validate_resend_state(website)
        return error_response(validation_error[:message], status: validation_error[:status]) if validation_error

        website.regenerate_email_verification_token!
        Pwb::EmailVerificationMailer.verification_email(website).deliver_later

        success_response(
          message: "Verification email sent to #{website.owner_email}",
          expires_in_days: Pwb::Website::EMAIL_VERIFICATION_EXPIRY / 1.day
        )
      end

      # POST /api/signup/complete_registration
      # Complete registration after user creates Firebase account
      #
      def complete_registration
        website = @signup_user.websites.first

        unless website
          return error_response("No website found. Please complete signup first.", status: :not_found)
        end

        validation_error = validate_registration_state(website)
        return validation_error if validation_error

        complete_user_registration(website)
      end

      private

      def handle_already_verified(website)
        if website.locked_pending_registration? || website.live?
          redirect_to_registration_or_site(website)
        else
          error_response("Website is not awaiting email verification", status: :unprocessable_entity)
        end
      end

      def process_email_verification(website)
        if website.may_verify_owner_email?
          website.verify_owner_email!
          redirect_to_registration_or_site(website)
        else
          error_response("Unable to verify email. Please contact support.", status: :unprocessable_entity)
        end
      end

      def validate_resend_state(website)
        if website.locked_pending_registration?
          { message: "Email already verified. Please create your account.", status: :unprocessable_entity }
        elsif website.live?
          { message: "Website is already live.", status: :unprocessable_entity }
        elsif !website.locked_pending_email_verification?
          { message: "Website is not awaiting email verification.", status: :unprocessable_entity }
        end
      end

      def validate_registration_state(website)
        if website.locked_pending_email_verification?
          error_response("Please verify your email first.", status: :unprocessable_entity)
        elsif website.live?
          success_response(
            message: "Website is already live",
            website_url: website.primary_url,
            admin_url: "#{website.primary_url}/site_admin"
          )
        elsif !website.locked_pending_registration?
          error_response("Website is not ready for registration.", status: :unprocessable_entity)
        end
      end

      def complete_user_registration(website)
        update_firebase_uid if params[:firebase_uid].present?

        if website.may_complete_owner_registration?
          website.complete_owner_registration!
          finalize_user_onboarding

          success_response(
            message: "Registration complete! Your website is now live.",
            website_url: website.primary_url,
            admin_url: "#{website.primary_url}/site_admin"
          )
        else
          error_response("Unable to complete registration. Please contact support.", status: :unprocessable_entity)
        end
      end

      def update_firebase_uid
        @signup_user.update(firebase_uid: params[:firebase_uid])
      end

      def finalize_user_onboarding
        @signup_user.update(onboarding_step: 4)
        @signup_user.activate! if @signup_user.may_activate?
      end

      def redirect_to_registration_or_site(website)
        if website.locked_pending_registration?
          redirect_to "#{website.primary_url}/pwb_sign_up?token=#{website.email_verification_token}",
                      allow_other_host: true
        elsif website.live?
          redirect_to website.primary_url, allow_other_host: true
        else
          redirect_to website.primary_url || '/', allow_other_host: true
        end
      end
    end
  end
end
