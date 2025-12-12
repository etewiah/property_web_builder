# frozen_string_literal: true

module Api
  module Signup
    # API controller for signup operations
    # These endpoints are called by external signup UIs to persist data
    #
    # POST /api/signup/start           - Start signup with email
    # POST /api/signup/configure       - Configure subdomain and site type
    # POST /api/signup/provision       - Trigger website provisioning
    # GET  /api/signup/status          - Get provisioning status
    # GET  /api/signup/check_subdomain - Check subdomain availability
    # GET  /api/signup/suggest_subdomain - Get random subdomain suggestion
    #
    class SignupsController < Api::BaseController
      before_action :load_signup_session, only: [:configure, :provision, :status]

      # POST /api/signup/start
      # Start signup process - creates lead user and reserves subdomain
      #
      # Params:
      #   email (required) - User's email address
      #
      # Returns:
      #   { success: true, user_id: 123, subdomain: "sunny-meadow-42" }
      #
      def start
        email = params[:email]&.strip&.downcase

        if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
          return error_response("Please enter a valid email address", status: :bad_request)
        end

        service = Pwb::SignupApiService.new
        result = service.start_signup(email: email)

        if result[:success]
          # Store in session for subsequent requests
          session[:signup_user_id] = result[:user].id
          session[:signup_subdomain] = result[:subdomain]

          success_response(
            user_id: result[:user].id,
            subdomain: result[:subdomain],
            message: "Signup started successfully"
          )
        else
          error_response(result[:errors].first || "Unable to start signup")
        end
      end

      # POST /api/signup/configure
      # Configure website - creates website record with subdomain and site type
      #
      # Params:
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
          session[:signup_website_id] = result[:website].id

          success_response(
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
      # Returns:
      #   { success: true, status: "configuring", progress: 40 }
      #
      def provision
        website = Pwb::Website.find_by(id: session[:signup_website_id])

        unless website
          return error_response("Website not found", status: :not_found)
        end

        if website.live?
          return success_response(
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
      # Check provisioning status (for polling)
      #
      # Returns:
      #   { success: true, status: "seeding", progress: 70, complete: false }
      #
      def status
        website = Pwb::Website.find_by(id: session[:signup_website_id])

        unless website
          return error_response("Website not found", status: :not_found)
        end

        success_response(
          provisioning_status: website.provisioning_state,
          progress: calculate_progress(website.provisioning_state),
          message: status_message(website.provisioning_state),
          complete: website.live?,
          website_url: website.live? ? website.primary_url : nil,
          admin_url: website.live? ? "#{website.primary_url}/site_admin" : nil
        )
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

      private

      def load_signup_session
        @signup_user = Pwb::User.find_by(id: session[:signup_user_id])

        unless @signup_user
          render json: {
            success: false,
            error: "Please start by entering your email",
            errors: ["Please start by entering your email"]
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
