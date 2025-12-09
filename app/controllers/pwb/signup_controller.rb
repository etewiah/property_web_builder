module Pwb
  # Handles the multi-step signup wizard for new tenant provisioning.
  # This controller manages the user journey from email capture to
  # fully provisioned website.
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
    protect_from_forgery with: :exception

    layout 'pwb/signup'

    before_action :load_current_signup, except: [:new, :start]
    before_action :redirect_if_completed, only: [:new, :configure, :provisioning]

    # Step 1: Email capture
    def new
      @step = 1
    end

    # Step 1 submission: Create lead and reserve subdomain
    def start
      @step = 1
      email = params[:email]&.strip&.downcase

      if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        flash.now[:error] = "Please enter a valid email address"
        return render :new
      end

      service = ProvisioningService.new
      result = service.start_signup(email: email)

      if result[:success]
        session[:signup_user_id] = result[:user].id
        session[:signup_subdomain] = result[:subdomain]&.name
        redirect_to signup_configure_path
      else
        flash.now[:error] = result[:errors].first || "Unable to start signup"
        render :new
      end
    end

    # Step 2: Site configuration form
    def configure
      @step = 2
      @suggested_subdomain = session[:signup_subdomain] || SubdomainGenerator.generate
      @site_types = Website::SITE_TYPES
    end

    # Step 2 submission: Configure site
    def save_configuration
      @step = 2
      subdomain = params[:subdomain]&.strip&.downcase
      site_type = params[:site_type]

      service = ProvisioningService.new
      result = service.configure_site(
        user: @current_signup_user,
        subdomain_name: subdomain,
        site_type: site_type
      )

      if result[:success]
        session[:signup_website_id] = result[:website].id
        redirect_to signup_provisioning_path
      else
        @suggested_subdomain = subdomain
        @site_types = Website::SITE_TYPES
        flash.now[:error] = result[:errors].first || "Unable to configure site"
        render :configure
      end
    end

    # Step 3: Show provisioning progress
    def provisioning
      @step = 3
      @website = Website.find_by(id: session[:signup_website_id])

      unless @website
        flash[:error] = "Website not found. Please start over."
        return redirect_to signup_path
      end

      # If already live, redirect to complete
      if @website.live?
        redirect_to signup_complete_path
      end
    end

    # Step 3 API: Trigger provisioning (called via AJAX or form submit)
    def provision
      @website = Website.find_by(id: session[:signup_website_id])

      unless @website
        return render json: { success: false, error: "Website not found" }, status: :not_found
      end

      if @website.live?
        return render json: { success: true, status: 'live', progress: 100 }
      end

      # Run provisioning synchronously for now (will be async later)
      service = ProvisioningService.new
      result = service.provision_website(website: @website)

      if result[:success]
        render json: {
          success: true,
          status: @website.reload.provisioning_state,
          progress: @website.provisioning_progress,
          message: @website.provisioning_status_message
        }
      else
        render json: {
          success: false,
          error: result[:errors].first,
          status: @website.reload.provisioning_state,
          progress: @website.provisioning_progress
        }, status: :unprocessable_entity
      end
    end

    # Step 3 API: Check provisioning status (polling endpoint)
    def status
      @website = Website.find_by(id: session[:signup_website_id])

      unless @website
        return render json: { success: false, error: "Website not found" }, status: :not_found
      end

      render json: {
        success: true,
        status: @website.provisioning_state,
        progress: @website.provisioning_progress,
        message: @website.provisioning_status_message,
        complete: @website.live?
      }
    end

    # Step 4: Completion page
    def complete
      @step = 4
      @website = Website.find_by(id: session[:signup_website_id])
      @user = @current_signup_user

      unless @website&.live?
        redirect_to signup_provisioning_path
        return
      end

      # Clear signup session
      clear_signup_session
    end

    # API: Check subdomain availability
    def check_subdomain
      name = params[:name]&.strip&.downcase
      email = @current_signup_user&.email

      result = SubdomainGenerator.validate_custom_name(name, reserved_by_email: email)

      render json: {
        available: result[:valid],
        normalized: result[:normalized],
        errors: result[:errors]
      }
    end

    # API: Suggest a random subdomain
    def suggest_subdomain
      render json: {
        subdomain: SubdomainGenerator.generate
      }
    end

    private

    def load_current_signup
      @current_signup_user = User.find_by(id: session[:signup_user_id])

      unless @current_signup_user
        flash[:error] = "Please start by entering your email"
        redirect_to signup_path
      end
    end

    def redirect_if_completed
      website = Website.find_by(id: session[:signup_website_id])
      if website&.live? && @current_signup_user&.active?
        redirect_to signup_complete_path
      end
    end

    def clear_signup_session
      session.delete(:signup_user_id)
      session.delete(:signup_subdomain)
      session.delete(:signup_website_id)
    end
  end
end
