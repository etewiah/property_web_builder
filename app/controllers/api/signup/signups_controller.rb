# frozen_string_literal: true

module Api
  module Signup
    # API controller for signup operations
    # These endpoints are called by external signup UIs to persist data
    #
    # Uses token-based tracking (not sessions) to support cross-domain API calls.
    # The signup_token returned from /start must be included in all subsequent requests.
    #
    # POST /api/signup/start                - Start signup with email → returns signup_token
    # POST /api/signup/configure            - Configure subdomain and site type (requires signup_token)
    # POST /api/signup/provision            - Trigger website provisioning (requires signup_token)
    # GET  /api/signup/status               - Get provisioning status (requires signup_token)
    # GET  /api/signup/verify_email         - Verify email address (via token in link)
    # POST /api/signup/resend_verification  - Resend verification email (requires signup_token)
    # POST /api/signup/complete_registration- Complete registration after Firebase account (requires signup_token)
    # GET  /api/signup/check_subdomain      - Check subdomain availability
    # GET  /api/signup/suggest_subdomain    - Get random subdomain suggestion
    # GET  /api/signup/site_types           - Get available site types
    # GET  /api/signup/lookup_subdomain     - Look up full subdomain by email
    #
    class SignupsController < Api::BaseController
      before_action :load_signup_user_from_token, only: [:configure, :provision, :status, :resend_verification, :complete_registration]

      # POST /api/signup/start
      # Start signup process - creates lead user, reserves subdomain, returns token
      #
      # Params:
      #   email (required) - User's email address
      #
      # Returns:
      #   { success: true, signup_token: "abc123", subdomain: "sunny-meadow-42" }
      #
      def start
        email = params[:email]&.strip&.downcase

        if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
          return error_response("Please enter a valid email address", status: :bad_request)
        end

        service = Pwb::SignupApiService.new
        result = service.start_signup(email: email)

        if result[:success]
          subdomain = result[:subdomain]
          subdomain_name = subdomain.is_a?(Pwb::Subdomain) ? subdomain.name : subdomain

          success_response(
            signup_token: result[:signup_token],
            subdomain: subdomain_name,
            message: "Signup started successfully. Use the signup_token in subsequent requests."
          )
        else
          error_response(result[:errors].first || "Unable to start signup")
        end
      end

      # POST /api/signup/configure
      # Configure website - creates website record with subdomain and site type
      #
      # Params:
      #   signup_token (required) - Token from /start
      #   subdomain (required) - Chosen subdomain
      #   site_type (required) - Type of site (residential, commercial, etc.)
      #
      # Returns:
      #   { success: true, website_id: 456, subdomain: "my-site" }
      #
      def configure
        subdomain = params[:subdomain]&.strip&.downcase
        site_type = params[:site_type]

        if subdomain.blank?
          return error_response("Subdomain is required", status: :bad_request)
        end

        if site_type.blank?
          return error_response("Site type is required", status: :bad_request)
        end

        service = Pwb::SignupApiService.new
        result = service.configure_site(
          user: @signup_user,
          subdomain_name: subdomain,
          site_type: site_type
        )

        if result[:success]
          success_response(
            signup_token: params[:signup_token], # Echo back token for convenience
            website_id: result[:website].id,
            subdomain: result[:website].subdomain,
            site_type: result[:website].site_type,
            message: "Site configured successfully"
          )
        else
          error_response(result[:errors].first || "Unable to configure site")
        end
      end

      # POST /api/signup/provision
      # Trigger website provisioning
      #
      # Params:
      #   signup_token (required) - Token from /start
      #
      # Returns:
      #   { success: true, status: "configuring", progress: 40 }
      #
      def provision
        # Find the user's website
        website = @signup_user.websites.first

        unless website
          return error_response("No website configured. Please call /configure first.", status: :not_found)
        end

        if website.live?
          return success_response(
            signup_token: params[:signup_token],
            provisioning_status: 'live',
            progress: 100,
            message: "Website is already live"
          )
        end

        # Also consider locked states as "provisioned" - just awaiting verification
        if website.locked?
          return success_response(
            signup_token: params[:signup_token],
            provisioning_status: website.provisioning_state,
            progress: website.provisioning_progress,
            message: website.provisioning_status_message,
            locked: true,
            locked_mode: website.locked_mode
          )
        end

        service = Pwb::SignupApiService.new
        result = service.provision_website(website: website)

        if result[:success]
          website.reload
          success_response(
            signup_token: params[:signup_token],
            provisioning_status: website.provisioning_state,
            progress: calculate_progress(website.provisioning_state),
            message: status_message(website.provisioning_state),
            complete: website.live?
          )
        else
          error_response(
            result[:errors].first || "Provisioning failed",
            status: :unprocessable_entity
          )
        end
      end

      # GET /api/signup/status
      # Check signup/provisioning status (for polling)
      # Works at any stage of the signup process
      #
      # Params:
      #   signup_token (required) - Token from /start
      #
      # Returns:
      #   { success: true, stage: "email_captured", provisioning_status: "pending", ... }
      #
      def status
        # @signup_user is loaded by before_action

        # Check what stage we're at
        website = @signup_user.websites.first
        reserved_subdomain = Pwb::Subdomain.find_by(reserved_by_email: @signup_user.email, aasm_state: 'reserved')

        if website
          # Website exists - return provisioning status
          response_data = {
            signup_token: params[:signup_token],
            stage: 'provisioning',
            email: @signup_user.email,
            subdomain: website.subdomain,
            provisioning_status: website.provisioning_state,
            progress: website.provisioning_progress,
            message: website.provisioning_status_message,
            complete: website.live?,
            website_url: website.live? ? website.primary_url : nil,
            admin_url: website.live? ? "#{website.primary_url}/site_admin" : nil
          }

          # Add locked state information
          if website.locked?
            response_data[:locked] = true
            response_data[:locked_mode] = website.locked_mode
            response_data[:email_verified] = website.email_verified?
            response_data[:registration_url] = "#{website.primary_url}/pwb_sign_up"
          end

          success_response(**response_data)
        elsif reserved_subdomain
          # Subdomain reserved but website not yet configured
          success_response(
            signup_token: params[:signup_token],
            stage: 'subdomain_reserved',
            email: @signup_user.email,
            subdomain: reserved_subdomain.name,
            provisioning_status: 'pending',
            progress: 10,
            message: 'Subdomain reserved. Please configure your site.',
            complete: false,
            next_step: 'configure'
          )
        else
          # Only email captured (shouldn't happen in normal flow, but handle gracefully)
          success_response(
            signup_token: params[:signup_token],
            stage: 'email_captured',
            email: @signup_user.email,
            subdomain: nil,
            provisioning_status: 'pending',
            progress: 5,
            message: 'Email captured. Please choose a subdomain.',
            complete: false,
            next_step: 'configure'
          )
        end
      end

      # GET /api/signup/check_subdomain
      # Check if a subdomain is available
      #
      # Params:
      #   name (required) - Subdomain to check
      #
      # Returns:
      #   { available: true, normalized: "my-site", errors: [] }
      #
      def check_subdomain
        name = params[:name]&.strip&.downcase
        email = session[:signup_user_id] ? Pwb::User.find_by(id: session[:signup_user_id])&.email : nil

        result = Pwb::SubdomainGenerator.validate_custom_name(name, reserved_by_email: email)

        json_response(
          available: result[:valid],
          normalized: result[:normalized],
          errors: result[:errors]
        )
      end

      # GET /api/signup/suggest_subdomain
      # Get a random available subdomain from the pool
      #
      # Returns:
      #   { subdomain: "sunny-meadow-42" }
      #
      def suggest_subdomain
        # Pick a random available subdomain from the pool (without reserving it)
        # Exclude any subdomains already used by existing websites
        subdomain = Pwb::Subdomain
          .available
          .where.not(name: Pwb::Website.select(:subdomain))
          .order('RANDOM()')
          .first

        if subdomain
          json_response(subdomain: subdomain.name)
        else
          # Fallback to generating if pool is empty
          json_response(subdomain: Pwb::SubdomainGenerator.generate)
        end
      end

      # GET /api/signup/site_types
      # Get available site types
      #
      # Returns:
      #   { site_types: [{ value: "residential", label: "Residential", ... }] }
      #
      def site_types
        types = [
          { value: 'residential', label: 'Residential', description: 'Houses, apartments, condos', icon: '🏠' },
          { value: 'commercial', label: 'Commercial', description: 'Offices, retail, warehouses', icon: '🏢' },
          { value: 'vacation_rental', label: 'Vacation Rentals', description: 'Holiday homes, short-term rentals', icon: '🏖️' }
        ]

        json_response(site_types: types)
      end

      # GET /api/signup/verify_email
      # Verify email address via token (called when user clicks link in email)
      # This does NOT require signup_token - uses the email verification token instead
      #
      # Params:
      #   token (required) - Email verification token from the link
      #
      # Returns:
      #   Redirects to registration page on success, or renders error
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
          if website.locked_pending_registration? || website.live?
            # Already verified - redirect to appropriate page
            return redirect_to_registration_or_site(website)
          else
            return error_response("Website is not awaiting email verification", status: :unprocessable_entity)
          end
        end

        unless website.email_verification_valid?
          return error_response("Verification link has expired. Please request a new one.", status: :gone)
        end

        # Transition to pending registration state
        if website.may_verify_owner_email?
          website.verify_owner_email!

          # Redirect to the registration page on the website
          redirect_to_registration_or_site(website)
        else
          error_response("Unable to verify email. Please contact support.", status: :unprocessable_entity)
        end
      end

      # POST /api/signup/resend_verification
      # Resend the verification email (requires signup_token)
      #
      # Params:
      #   signup_token (required) - Token from /start
      #
      # Returns:
      #   { success: true, message: "Verification email sent" }
      #
      def resend_verification
        website = @signup_user.websites.first

        unless website
          return error_response("No website found. Please complete signup first.", status: :not_found)
        end

        unless website.locked_pending_email_verification?
          if website.locked_pending_registration?
            return error_response("Email already verified. Please create your account.", status: :unprocessable_entity)
          elsif website.live?
            return error_response("Website is already live.", status: :unprocessable_entity)
          else
            return error_response("Website is not awaiting email verification.", status: :unprocessable_entity)
          end
        end

        # Regenerate token and send email
        website.regenerate_email_verification_token!
        Pwb::EmailVerificationMailer.verification_email(website).deliver_later

        success_response(
          message: "Verification email sent to #{website.owner_email}",
          expires_in_days: Pwb::Website::EMAIL_VERIFICATION_EXPIRY / 1.day
        )
      end

      # POST /api/signup/complete_registration
      # Complete registration after user creates Firebase account
      # Called by the frontend after successful Firebase authentication
      #
      # Params:
      #   signup_token (required) - Token from /start
      #   firebase_uid (optional) - Firebase user ID for linking
      #
      # Returns:
      #   { success: true, website_url: "https://...", admin_url: "https://.../admin" }
      #
      def complete_registration
        website = @signup_user.websites.first

        unless website
          return error_response("No website found. Please complete signup first.", status: :not_found)
        end

        unless website.locked_pending_registration?
          if website.locked_pending_email_verification?
            return error_response("Please verify your email first.", status: :unprocessable_entity)
          elsif website.live?
            return success_response(
              message: "Website is already live",
              website_url: website.primary_url,
              admin_url: "#{website.primary_url}/site_admin"
            )
          else
            return error_response("Website is not ready for registration.", status: :unprocessable_entity)
          end
        end

        # Update user with Firebase UID if provided
        if params[:firebase_uid].present?
          @signup_user.update(firebase_uid: params[:firebase_uid])
        end

        # Transition to live state
        if website.may_complete_owner_registration?
          website.complete_owner_registration!

          # Complete user onboarding
          @signup_user.update(onboarding_step: 4)
          @signup_user.activate! if @signup_user.may_activate?

          success_response(
            message: "Registration complete! Your website is now live.",
            website_url: website.primary_url,
            admin_url: "#{website.primary_url}/site_admin"
          )
        else
          error_response("Unable to complete registration. Please contact support.", status: :unprocessable_entity)
        end
      end

      # GET /api/signup/lookup_subdomain
      # Look up the full subdomain for a user by email
      #
      # Params:
      #   email (required) - User's email address
      #
      # Returns:
      #   { success: true, email: "user@example.com", subdomain: "my-site", full_subdomain: "my-site.propertywebbuilder.com" }
      #
      def lookup_subdomain
        email = params[:email]&.strip&.downcase

        if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
          return error_response("Please provide a valid email address", status: :bad_request)
        end

        # First check for a user with a website
        user = Pwb::User.find_by(email: email)

        if user
          website = user.websites.first
          if website
            base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
            full_subdomain = "#{website.subdomain}.#{base_domain}"

            return success_response(
              email: email,
              subdomain: website.subdomain,
              full_subdomain: full_subdomain,
              website_live: website.live?,
              website_url: website.live? ? website.primary_url : nil
            )
          end
        end

        # Check for a reserved subdomain (signup in progress)
        reserved_subdomain = Pwb::Subdomain.find_by(reserved_by_email: email, aasm_state: 'reserved')

        if reserved_subdomain
          base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
          full_subdomain = "#{reserved_subdomain.name}.#{base_domain}"

          return success_response(
            email: email,
            subdomain: reserved_subdomain.name,
            full_subdomain: full_subdomain,
            website_live: false,
            status: 'reserved',
            message: 'Subdomain is reserved but website not yet provisioned'
          )
        end

        # No subdomain found for this email
        error_response("No subdomain found for this email address", status: :not_found)
      end

      private

      def load_signup_user_from_token
        token = params[:signup_token]

        if token.blank?
          return render json: {
            success: false,
            error: "signup_token is required",
            errors: ["signup_token is required"]
          }, status: :bad_request
        end

        service = Pwb::SignupApiService.new
        @signup_user = service.find_user_by_token(token)

        unless @signup_user
          render json: {
            success: false,
            error: "Invalid or expired signup token. Please start a new signup.",
            errors: ["Invalid or expired signup token"]
          }, status: :unauthorized
        end
      end

      def calculate_progress(state)
        case state
        when 'pending' then 0
        when 'subdomain_allocated' then 20
        when 'configuring' then 40
        when 'seeding' then 70
        when 'ready' then 95
        when 'live' then 100
        else 0
        end
      end

      def status_message(state)
        case state
        when 'pending' then 'Waiting to start...'
        when 'subdomain_allocated' then 'Subdomain assigned'
        when 'configuring' then 'Setting up your website...'
        when 'seeding' then 'Adding sample content...'
        when 'ready' then 'Almost done! Finalizing...'
        when 'locked_pending_email_verification' then 'Please verify your email'
        when 'locked_pending_registration' then 'Email verified! Please create your account'
        when 'live' then 'Your website is live!'
        when 'failed' then 'Setup failed'
        else 'Unknown status'
        end
      end

      # Redirect to registration page or main site depending on state
      def redirect_to_registration_or_site(website)
        if website.locked_pending_registration?
          # Redirect to registration page
          redirect_to "#{website.primary_url}/pwb_sign_up", allow_other_host: true
        elsif website.live?
          # Redirect to main site
          redirect_to website.primary_url, allow_other_host: true
        else
          # Fallback to main site
          redirect_to website.primary_url || '/', allow_other_host: true
        end
      end
    end
  end
end
