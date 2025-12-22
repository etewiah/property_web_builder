# frozen_string_literal: true

module Api
  module Signup
    # API controller for signup operations
    # These endpoints are called by external signup UIs to persist data
    #
    # Uses token-based tracking (not sessions) to support cross-domain API calls.
    # The signup_token returned from /start must be included in all subsequent requests.
    #
    # POST /api/signup/start                - Start signup with email
    # POST /api/signup/configure            - Configure subdomain and site type
    # POST /api/signup/provision            - Trigger website provisioning
    # GET  /api/signup/status               - Get provisioning status
    # GET  /api/signup/verify_email         - Verify email address
    # POST /api/signup/resend_verification  - Resend verification email
    # POST /api/signup/complete_registration- Complete registration
    # GET  /api/signup/check_subdomain      - Check subdomain availability
    # GET  /api/signup/suggest_subdomain    - Get random subdomain suggestion
    # GET  /api/signup/site_types           - Get available site types
    # GET  /api/signup/lookup_subdomain     - Look up subdomain by email
    #
    class SignupsController < Api::BaseController
      include Api::Signup::EmailVerification
      include Api::Signup::SubdomainOperations

      before_action :load_signup_user_from_token,
                    only: [:configure, :provision, :status, :resend_verification, :complete_registration]

      # POST /api/signup/start
      # Start signup process - creates lead user, reserves subdomain, returns token
      #
      def start
        email = params[:email]&.strip&.downcase

        unless valid_email?(email)
          return error_response("Please enter a valid email address", status: :bad_request)
        end

        result = signup_service.start_signup(email: email)

        if result[:success]
          success_response(
            signup_token: result[:signup_token],
            subdomain: extract_subdomain_name(result[:subdomain]),
            message: "Signup started successfully. Use the signup_token in subsequent requests."
          )
        else
          error_response(result[:errors].first || "Unable to start signup")
        end
      end

      # POST /api/signup/configure
      # Configure website - creates website record with subdomain and site type
      #
      def configure
        subdomain = params[:subdomain]&.strip&.downcase
        site_type = params[:site_type]

        return error_response("Subdomain is required", status: :bad_request) if subdomain.blank?
        return error_response("Site type is required", status: :bad_request) if site_type.blank?

        result = signup_service.configure_site(
          user: @signup_user,
          subdomain_name: subdomain,
          site_type: site_type
        )

        if result[:success]
          website = result[:website]
          success_response(
            signup_token: params[:signup_token],
            website_id: website.id,
            subdomain: website.subdomain,
            site_type: website.site_type,
            message: "Site configured successfully"
          )
        else
          error_response(result[:errors].first || "Unable to configure site")
        end
      end

      # POST /api/signup/provision
      # Trigger website provisioning
      #
      def provision
        website = @signup_user.websites.first

        unless website
          return error_response("No website configured. Please call /configure first.", status: :not_found)
        end

        return provision_already_live_response(website) if website.live?
        return provision_locked_response(website) if website.locked?

        result = signup_service.provision_website(website: website)

        if result[:success]
          website.reload
          success_response(
            signup_token: params[:signup_token],
            provisioning_status: website.provisioning_state,
            progress: website.provisioning_progress,
            message: website.provisioning_status_message,
            complete: website.live?
          )
        else
          error_response(result[:errors].first || "Provisioning failed", status: :unprocessable_entity)
        end
      end

      # GET /api/signup/status
      # Check signup/provisioning status (for polling)
      #
      def status
        presenter = SignupStatusPresenter.new(user: @signup_user, signup_token: params[:signup_token])
        success_response(**presenter.to_h)
      end

      # GET /api/signup/site_types
      # Get available site types
      #
      def site_types
        types = [
          { value: 'residential', label: 'Residential', description: 'Houses, apartments, condos', icon: '🏠' },
          { value: 'commercial', label: 'Commercial', description: 'Offices, retail, warehouses', icon: '🏢' },
          { value: 'vacation_rental', label: 'Vacation Rentals', description: 'Holiday homes, short-term rentals', icon: '🏖️' }
        ]

        json_response(site_types: types)
      end

      private

      def signup_service
        @signup_service ||= Pwb::SignupApiService.new
      end

      def load_signup_user_from_token
        token = params[:signup_token]

        if token.blank?
          return render json: {
            success: false,
            error: "signup_token is required",
            errors: ["signup_token is required"]
          }, status: :bad_request
        end

        @signup_user = signup_service.find_user_by_token(token)

        unless @signup_user
          render json: {
            success: false,
            error: "Invalid or expired signup token. Please start a new signup.",
            errors: ["Invalid or expired signup token"]
          }, status: :unauthorized
        end
      end

      def valid_email?(email)
        email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def extract_subdomain_name(subdomain)
        subdomain.is_a?(Pwb::Subdomain) ? subdomain.name : subdomain
      end

      def provision_already_live_response(website)
        success_response(
          signup_token: params[:signup_token],
          provisioning_status: 'live',
          progress: 100,
          message: "Website is already live"
        )
      end

      def provision_locked_response(website)
        success_response(
          signup_token: params[:signup_token],
          provisioning_status: website.provisioning_state,
          progress: website.provisioning_progress,
          message: website.provisioning_status_message,
          locked: true,
          locked_mode: website.locked_mode
        )
      end
    end
  end
end
