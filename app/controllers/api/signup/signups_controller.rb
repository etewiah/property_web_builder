# frozen_string_literal: true

module Api
  module Signup
    # API controller for signup operations
    # These endpoints are called by external signup UIs to persist data
    #
    # Uses token-based tracking (not sessions) to support cross-domain API calls.
    # The signup_token returned from /start must be included in all subsequent requests.
    #
    # POST /api/signup/start             - Start signup with email → returns signup_token
    # POST /api/signup/configure         - Configure subdomain and site type (requires signup_token)
    # POST /api/signup/provision         - Trigger website provisioning (requires signup_token)
    # GET  /api/signup/status            - Get provisioning status (requires signup_token)
    # GET  /api/signup/check_subdomain   - Check subdomain availability
    # GET  /api/signup/suggest_subdomain - Get random subdomain suggestion
    # GET  /api/signup/site_types        - Get available site types
    # GET  /api/signup/lookup_subdomain  - Look up full subdomain by email
    #
    class SignupsController < Api::BaseController
      before_action :load_signup_user_from_token, only: [:configure, :provision, :status]

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
          success_response(
            signup_token: params[:signup_token],
            stage: 'provisioning',
            email: @signup_user.email,
            subdomain: website.subdomain,
            provisioning_status: website.provisioning_state,
            progress: calculate_progress(website.provisioning_state),
            message: status_message(website.provisioning_state),
            complete: website.live?,
            website_url: website.live? ? website.primary_url : nil,
            admin_url: website.live? ? "#{website.primary_url}/site_admin" : nil
          )
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
      # Generate a random available subdomain
      #
      # Returns:
      #   { subdomain: "sunny-meadow-42" }
      #
      def suggest_subdomain
        json_response(subdomain: Pwb::SubdomainGenerator.generate)
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
        when 'live' then 'Your website is live!'
        when 'failed' then 'Setup failed'
        else 'Unknown status'
        end
      end
    end
  end
end
