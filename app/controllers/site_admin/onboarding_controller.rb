# frozen_string_literal: true

module SiteAdmin
  # OnboardingController
  # Guides newly provisioned users through initial site setup.
  #
  # Steps:
  # 1. Welcome - Introduction and what to expect
  # 2. Profile - Set up agency/company details
  # 3. Property - Add first property (optional)
  # 4. Theme - Choose theme and basic customization
  # 5. Complete - Summary and next steps
  #
  class OnboardingController < SiteAdminController
    skip_before_action :require_admin!, only: [:show, :update, :skip_step, :complete]
    before_action :ensure_can_access_onboarding
    before_action :set_onboarding_step, except: [:complete, :restart]

    STEPS = {
      1 => { name: 'welcome', title: 'Welcome', description: 'Get started with your new website' },
      2 => { name: 'profile', title: 'Your Profile', description: 'Set up your agency details' },
      3 => { name: 'property', title: 'First Property', description: 'Add your first listing' },
      4 => { name: 'theme', title: 'Choose Theme', description: 'Customize your look' },
      5 => { name: 'complete', title: 'All Done!', description: 'You\'re ready to go' }
    }.freeze

    MAX_STEP = STEPS.keys.max

    helper SiteAdmin::OnboardingHelper

    # GET /site_admin/onboarding
    # GET /site_admin/onboarding/:step
    def show
      @steps = STEPS
      @current_step_info = STEPS[@step]

      case @step
      when 1
        render :welcome
      when 2
        @agency = current_website.agency || current_website.build_agency
        @website = current_website
        render :profile
      when 3
        @property = current_website.realty_assets.new
        @property_types = current_website.field_keys.where(tag: 'property-types')
        render :property
      when 4
        @themes = available_themes
        @current_theme = current_website.theme_name
        render :theme
      when 5
        complete_onboarding!
        @website = current_website
        @stats = {
          properties: current_website.realty_assets.count,
          pages: current_website.pages.count,
          theme: current_website.theme_name&.titleize || 'Default'
        }
        render :complete
      end
    end

    # POST /site_admin/onboarding/:step
    def update
      case @step
      when 1
        # Welcome step - just advance
        advance_step!
      when 2
        save_profile
      when 3
        save_property
      when 4
        save_theme
      end
    end

    # POST /site_admin/onboarding/:step/skip
    def skip_step
      if @step == 3 # Only property step is skippable
        advance_step!
      else
        redirect_to site_admin_onboarding_path(step: @step), alert: "This step cannot be skipped."
      end
    end

    # GET /site_admin/onboarding/complete
    def complete
      @step = MAX_STEP
      @steps = STEPS
      @website = current_website
      @stats = {
        properties: current_website.realty_assets.count,
        pages: current_website.pages.count,
        theme: current_website.theme_name&.titleize || 'Default'
      }
    end

    # POST /site_admin/onboarding/restart
    def restart
      current_user.update!(
        onboarding_step: 1,
        site_admin_onboarding_completed_at: nil
      )
      redirect_to site_admin_onboarding_path(step: 1), notice: "Onboarding restarted."
    end

    private

    def ensure_can_access_onboarding
      unless current_user && current_website
        redirect_to root_path, alert: "Please sign in to continue."
        return
      end

      # Verify user has access to this website
      unless current_user.can_access_website?(current_website)
        redirect_to root_path, alert: "You don't have access to this website."
      end
    end

    def set_onboarding_step
      @step = (params[:step] || current_user.onboarding_step || 1).to_i
      @step = 1 if @step < 1
      @step = MAX_STEP if @step > MAX_STEP

      # If user has completed onboarding, redirect to dashboard unless explicitly visiting
      if onboarding_completed? && params[:step].blank?
        redirect_to site_admin_root_path
      end
    end

    def onboarding_completed?
      current_user.site_admin_onboarding_completed_at.present?
    end

    def advance_step!
      next_step = [@step + 1, MAX_STEP].min
      current_user.update!(onboarding_step: next_step)
      redirect_to site_admin_onboarding_path(step: next_step)
    end

    def complete_onboarding!
      return if onboarding_completed?

      current_user.update!(
        site_admin_onboarding_completed_at: Time.current,
        onboarding_step: MAX_STEP
      )

      # Mark user as fully active if they were in onboarding state
      current_user.activate! if current_user.respond_to?(:may_activate?) && current_user.may_activate?
    end

    # Step 2: Save profile/agency
    def save_profile
      @agency = current_website.agency || current_website.build_agency
      @website = current_website

      agency_params = params.require(:pwb_agency).permit(
        :display_name, :email_primary, :phone_number_primary,
        :company_name
      )

      # Save currency to website (this is a permanent setting)
      currency = params[:default_currency]
      if currency.present? && Pwb::Config::CURRENCIES.key?(currency)
        current_website.update!(default_currency: currency)
      end

      if @agency.update(agency_params)
        advance_step!
      else
        @steps = STEPS
        @current_step_info = STEPS[@step]
        flash.now[:error] = "Please fix the errors below."
        render :profile, status: :unprocessable_entity
      end
    end

    # Step 3: Save first property
    def save_property
      @property = current_website.realty_assets.new(property_params)
      @property.website = current_website

      if @property.save
        advance_step!
      else
        @steps = STEPS
        @current_step_info = STEPS[@step]
        @property_types = current_website.field_keys.where(tag: 'property-types')
        flash.now[:error] = "Please fix the errors below."
        render :property, status: :unprocessable_entity
      end
    end

    # Step 4: Save theme selection
    def save_theme
      theme_name = params[:theme_name]

      if theme_name.present? && available_themes.include?(theme_name)
        current_website.update!(theme_name: theme_name)
        advance_step!
      else
        @steps = STEPS
        @current_step_info = STEPS[@step]
        @themes = available_themes
        @current_theme = current_website.theme_name
        flash.now[:error] = "Please select a valid theme."
        render :theme, status: :unprocessable_entity
      end
    end

    def property_params
      # Map form field names to model column names
      permitted = params.require(:pwb_realty_asset).permit(
        :title, :description, :price_sale_current_cents,
        :price_rental_monthly_current_cents, :for_sale, :for_rent,
        :bedrooms, :bathrooms, :plot_size, :constructed_size,
        :street_address, :city, :postal_code, :country,
        :property_type_key
      )

      # Rename bedrooms/bathrooms to count_bedrooms/count_bathrooms
      result = permitted.to_h
      result[:count_bedrooms] = result.delete(:bedrooms) if result.key?(:bedrooms)
      result[:count_bathrooms] = result.delete(:bathrooms) if result.key?(:bathrooms)
      result[:plot_area] = result.delete(:plot_size) if result.key?(:plot_size)
      result[:constructed_area] = result.delete(:constructed_size) if result.key?(:constructed_size)
      result
    end

    def available_themes
      # Return list of enabled theme names from Pwb::Theme
      Pwb::Theme.enabled.map(&:name)
    end
  end
end
