# frozen_string_literal: true

module Pwb
  # Handles the multi-step signup wizard for new tenant provisioning.
  #
  # Flow:
  # 1. GET /signup - Show email capture form (step 1)
  # 2. POST /signup/start - Capture email, reserve subdomain, create lead
  # 3. GET /signup/configure - Show site configuration form (step 2)
  # 4. POST /signup/configure - Configure subdomain & site type, create website
  # 5. GET /signup/provisioning - Show provisioning progress (step 3)
  # 6. POST /signup/provision - Trigger provisioning
  # 7. GET /signup/complete - Show completion page (step 4)
  #
  class SignupController < ActionController::Base
    include SignupSession

    protect_from_forgery with: :exception
    layout 'pwb/signup'

    before_action :require_signup_user, except: [:new, :start]
    before_action :redirect_if_completed, only: [:new, :configure, :provisioning]

    # ===================
    # Step 1: Email Capture
    # ===================

    def new
      @step = 1
    end

    def start
      @step = 1
      email = params[:email]&.strip&.downcase

      log_signup_event('Step 1: Email submission', email: email)

      unless valid_email?(email)
        log_signup_warning('Invalid email format', email: email)
        flash.now[:error] = "Please enter a valid email address"
        return render :new
      end

      result = ProvisioningService.new.start_signup(email: email)

      if result[:success]
        signup_session.store_start_result(result)
        log_signup_event('Step 1 completed', email: email, user_id: result[:user].id)
        redirect_to signup_configure_path
      else
        log_signup_warning('Step 1 failed', email: email, errors: result[:errors])
        flash.now[:error] = result[:errors].first || "Unable to start signup"
        render :new
      end
    end

    # ===================
    # Step 2: Site Configuration
    # ===================

    def configure
      @step = 2
      @suggested_subdomain = signup_session.subdomain || SubdomainGenerator.generate
      @site_types = Website::SITE_TYPES
    end

    def save_configuration
      @step = 2
      subdomain = params[:subdomain]&.strip&.downcase
      site_type = params[:site_type]

      log_signup_event('Step 2: Site configuration', subdomain: subdomain, site_type: site_type)

      result = ProvisioningService.new.configure_site(
        user: signup_session.user,
        subdomain_name: subdomain,
        site_type: site_type
      )

      if result[:success]
        signup_session.store_configure_result(result)
        log_signup_event('Step 2 completed', website_id: result[:website].id)
        redirect_to signup_provisioning_path
      else
        log_signup_warning('Step 2 failed', subdomain: subdomain, errors: result[:errors])
        @suggested_subdomain = subdomain
        @site_types = Website::SITE_TYPES
        flash.now[:error] = result[:errors].first || "Unable to configure site"
        render :configure
      end
    end

    # ===================
    # Step 3: Provisioning
    # ===================

    def provisioning
      @step = 3
      @website = signup_session.website

      unless @website
        flash[:error] = "Website not found. Please start over."
        return redirect_to signup_path
      end

      redirect_to signup_complete_path if @website.live?
    end

    def provision
      @website = signup_session.website

      unless @website
        log_signup_warning('Provision attempt for missing website')
        return render json: { success: false, error: "Website not found" }, status: :not_found
      end

      return render json: { success: true, status: 'live', progress: 100 } if @website.live?

      log_signup_event('Step 3: Starting provisioning', website_id: @website.id)

      result = ProvisioningService.new.provision_website(website: @website)

      if result[:success]
        log_signup_event('Step 3 completed: Website is live', website_id: @website.id)
        render json: provisioning_status_json
      else
        log_signup_error('Step 3 failed', website_id: @website.id, errors: result[:errors])
        render json: provisioning_status_json.merge(success: false, error: result[:errors].first),
               status: :unprocessable_entity
      end
    end

    def status
      @website = signup_session.website

      unless @website
        return render json: { success: false, error: "Website not found" }, status: :not_found
      end

      render json: provisioning_status_json.merge(complete: @website.live?)
    end

    # ===================
    # Step 4: Completion
    # ===================

    def complete
      @step = 4
      @website = signup_session.website
      @user = signup_session.user

      unless @website&.live?
        return redirect_to signup_provisioning_path
      end

      clear_signup_session
    end

    # ===================
    # API Endpoints
    # ===================

    def check_subdomain
      name = params[:name]&.strip&.downcase
      email = signup_session.user&.email

      result = SubdomainGenerator.validate_custom_name(name, reserved_by_email: email)

      render json: {
        available: result[:valid],
        normalized: result[:normalized],
        errors: result[:errors]
      }
    end

    def suggest_subdomain
      render json: { subdomain: SubdomainGenerator.generate }
    end

    private

    # ===================
    # Filters
    # ===================

    def require_signup_user
      unless signup_session.has_user?
        flash[:error] = "Please start by entering your email"
        redirect_to signup_path
      end
    end

    def redirect_if_completed
      redirect_to signup_complete_path if signup_session.complete?
    end

    # ===================
    # Helpers
    # ===================

    def valid_email?(email)
      email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def provisioning_status_json
      @website.reload
      {
        success: true,
        status: @website.provisioning_state,
        progress: @website.provisioning_progress,
        message: @website.provisioning_status_message
      }
    end

    # ===================
    # Logging
    # ===================

    def log_signup_event(message, **details)
      StructuredLogger.info("[Signup] #{message}", **details.merge(origin_ip: request.ip))
    end

    def log_signup_warning(message, **details)
      StructuredLogger.warn("[Signup] #{message}", **details.merge(origin_ip: request.ip))
    end

    def log_signup_error(message, **details)
      StructuredLogger.error("[Signup] #{message}", **details.merge(origin_ip: request.ip))
    end
  end
end
