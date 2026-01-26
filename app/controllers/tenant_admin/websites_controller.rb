# frozen_string_literal: true
require 'pwb/seeder'
require 'pwb/pages_seeder'
require 'pwb/contents_seeder'

module TenantAdmin
  class WebsitesController < TenantAdminController
    before_action :set_website, only: [:show, :edit, :update, :destroy, :seed, :seed_form, :retry_provisioning, :shard_form, :assign_shard, :shard_history, :appearance_form, :update_appearance, :rendering_form, :update_rendering]

    def index
      websites = Pwb::Website.unscoped.order(created_at: :desc)

      # Simple search
      if params[:search].present?
        websites = websites.where(
          "subdomain ILIKE ? OR company_display_name ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end

      @pagy, @websites = pagy(websites, limit: 20)
    end

    def show
      # @website set by before_action
      @users_count = count_website_users(@website)
      @props_count = Pwb::RealtyAsset.unscoped.where(website_id: @website.id).count rescue 0
      @pages_count = Pwb::Page.unscoped.where(website_id: @website.id).count rescue 0
      @messages_count = Pwb::Message.unscoped.where(website_id: @website.id).count rescue 0
    end

    def new
      @website = Pwb::Website.new
      @themes = Pwb::Theme.enabled
      @all_themes = @themes
      @client_themes = Pwb::ClientTheme.enabled
    end

    def create
      @website = Pwb::Website.new(website_params)
      
      if @website.save
        if params[:website][:seed_data] == "1"
          seed_website_content(@website, params[:website][:skip_property_seeding] == "1")
          flash[:notice] = "Website created and seeded successfully."
        else
          flash[:notice] = "Website created successfully."
        end
        redirect_to tenant_admin_website_path(@website)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def seed
      if params[:pack_name].present?
        # New SeedPack based seeding
        begin
          pack = Pwb::SeedPack.find(params[:pack_name])
          
          # Construct options based on checkboxes
          # Note: The form sends parameters for what to INCLUDE, apply! expects what to SKIP.
          # So we invert the logic.
          options = {
            skip_website: params[:seed_scope_website] != "1",
            skip_agency: params[:seed_scope_agency] != "1",
            skip_users: params[:seed_scope_users] != "1",
            skip_field_keys: params[:seed_scope_field_keys] != "1", 
            skip_links: params[:seed_scope_links] != "1",
            skip_pages: params[:seed_scope_pages] != "1",
            skip_page_parts: params[:seed_scope_pages] != "1", # content structure
            skip_content: params[:seed_scope_content] != "1",  # text overwrite
            skip_translations: params[:seed_scope_content] != "1", # text overwrite (translations)
            skip_properties: params[:seed_scope_properties] != "1",
            verbose: true
          }

          pack.apply!(website: @website, options: options)
          
          flash[:notice] = "Seeding completed successfully using pack '#{pack.display_name}'."
        rescue StandardError => e
          flash[:alert] = "Seeding failed: #{e.message}"
        end
      else
        # Legacy fallback (simple button)
        seed_website_content(@website, params[:skip_property_seeding] == "1")
        flash[:notice] = "Website seeded successfully (Legacy Mode)."
      end
      
      redirect_to tenant_admin_website_path(@website)
    end

    def seed_form
      # @website set by before_action
      @seed_packs = Pwb::SeedPack.available
      @current_pack_name = @website.seed_pack_name || 'base'
    end

    def retry_provisioning
      unless @website.failed?
        redirect_to tenant_admin_website_path(@website), alert: "Website is not in failed state."
        return
      end

      service = Pwb::ProvisioningService.new
      result = service.retry_provisioning(website: @website)

      if result[:success]
        redirect_to tenant_admin_website_path(@website), notice: "Provisioning completed successfully."
      else
        redirect_to tenant_admin_website_path(@website), alert: "Provisioning failed: #{result[:errors].join(', ')}"
      end
    end

    def edit
      # @website set by before_action
      @themes = Pwb::Theme.enabled
      @all_themes = @themes
      @client_themes = Pwb::ClientTheme.enabled
    end

    def update
      if @website.update(website_params)
        redirect_to tenant_admin_website_path(@website), notice: "Website updated successfully."
      else
        @themes = Pwb::Theme.enabled
        @all_themes = @themes
        @client_themes = Pwb::ClientTheme.enabled
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @website.destroy
      redirect_to tenant_admin_websites_path, notice: "Website deleted successfully."
    end

    # GET /tenant_admin/websites/:id/shard
    def shard_form
      @available_shards = Pwb::ShardService.configured_shards
      @current_shard = @website.shard_name || 'default'
      @shard_health = Pwb::ShardHealthCheck.check(@current_shard)
      @audit_logs = @website.shard_audit_logs.recent.limit(5)
    end

    # PATCH /tenant_admin/websites/:id/assign_shard
    def assign_shard
      result = Pwb::ShardService.assign_shard(
        website: @website,
        new_shard: params[:shard_name],
        changed_by: current_user.email,
        notes: params[:notes]
      )

      respond_to do |format|
        if result.success?
          format.html do
            redirect_to tenant_admin_website_path(@website),
                        notice: "Website assigned to shard '#{params[:shard_name]}'"
          end
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                "shard_badge_#{@website.id}",
                partial: "tenant_admin/shared/shard_badge",
                locals: { website: @website.reload }
              ),
              turbo_stream.prepend(
                "flash_messages",
                partial: "shared/flash",
                locals: { type: :notice, message: "Assigned to #{params[:shard_name]}" }
              )
            ]
          end
        else
          format.html do
            flash.now[:alert] = result.error
            @available_shards = Pwb::ShardService.configured_shards
            @current_shard = @website.shard_name || 'default'
            @shard_health = Pwb::ShardHealthCheck.check(@current_shard)
            @audit_logs = @website.shard_audit_logs.recent.limit(5)
            render :shard_form, status: :unprocessable_entity
          end
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "shard_form",
              partial: "tenant_admin/websites/shard_form",
              locals: { website: @website, error: result.error }
            )
          end
        end
      end
    end

    # GET /tenant_admin/websites/:id/shard_history
    def shard_history
      @audit_logs = @website.shard_audit_logs.recent
      @pagy, @audit_logs = pagy(@audit_logs, limit: 20)
    end

    # GET /tenant_admin/websites/:id/appearance
    def appearance_form
      @themes = Pwb::Theme.enabled
      @all_theme_palettes = @themes.each_with_object({}) do |theme, hash|
        hash[theme.name] = theme.palettes.transform_values do |p|
          {
            name: p['name'],
            description: p['description'],
            preview_colors: p['preview_colors'],
            colors: p['colors'],
            is_default: p['is_default']
          }
        end
      end
    end

    # PATCH /tenant_admin/websites/:id/update_appearance
    def update_appearance
      if @website.update(appearance_params)
        redirect_to tenant_admin_website_path(@website), notice: "Appearance settings updated successfully."
      else
        @themes = Pwb::Theme.enabled
        @all_theme_palettes = @themes.each_with_object({}) do |theme, hash|
          hash[theme.name] = theme.palettes.transform_values do |p|
            {
              name: p['name'],
              description: p['description'],
              preview_colors: p['preview_colors'],
              colors: p['colors'],
              is_default: p['is_default']
            }
          end
        end
        render :appearance_form, status: :unprocessable_entity
      end
    end

    # GET /tenant_admin/websites/:id/rendering
    #
    # Displays the rendering pipeline configuration form for a website.
    # Allows switching between Rails Mode (B Themes) and Client Mode (A Themes).
    #
    # @see #update_rendering for the form submission handler
    # @see app/views/tenant_admin/websites/rendering_form.html.erb for the form view
    def rendering_form
      Rails.logger.info("[TenantAdmin::Rendering] GET rendering_form for website #{@website.id} (#{@website.subdomain})")
      @themes = Pwb::Theme.enabled
      @client_themes = Pwb::ClientTheme.enabled
      Rails.logger.debug("[TenantAdmin::Rendering] Current settings: rendering_mode=#{@website.rendering_mode}, theme_name=#{@website.theme_name}, client_theme_name=#{@website.client_theme_name}")
    end

    # PATCH /tenant_admin/websites/:id/update_rendering
    #
    # Updates the rendering pipeline settings for a website.
    #
    # == Parameter Structure (IMPORTANT)
    #
    # This action expects parameters nested under the `website` key:
    #
    #   params[:website][:rendering_mode]    # 'rails' or 'client'
    #   params[:website][:theme_name]        # For Rails Mode (B Theme)
    #   params[:website][:client_theme_name] # For Client Mode (A Theme)
    #   params[:website][:astro_client_url]  # Optional custom Astro server URL
    #
    # The form MUST use `scope: :website` in form_with to ensure proper nesting:
    #
    #   <%= form_with url: update_rendering_tenant_admin_website_path(@website),
    #       method: :patch,
    #       scope: :website,  # <-- REQUIRED for proper param nesting
    #       local: true do |f| %>
    #
    # Without scope: :website, form fields generate top-level params like:
    #   params[:theme_name] instead of params[:website][:theme_name]
    #
    # This causes a 422 Unprocessable Entity because rendering_params requires:
    #   params.require(:website).permit(...)
    #
    # == Troubleshooting 422 Errors
    #
    # If this action returns 422, check the Rails logs for:
    # - "[TenantAdmin::Rendering] Raw params received:" shows actual param structure
    # - "[TenantAdmin::Rendering] WARNING: params[:website] is nil" indicates missing scope
    # - Look for theme_name/client_theme_name at the top level of params
    #
    # Fix: Ensure the form uses `scope: :website` parameter.
    #
    # @see #rendering_params for permitted parameters
    # @see app/views/tenant_admin/websites/rendering_form.html.erb
    def update_rendering
      Rails.logger.info("[TenantAdmin::Rendering] PATCH update_rendering for website #{@website.id} (#{@website.subdomain})")
      Rails.logger.info("[TenantAdmin::Rendering] Raw params received: #{params.to_unsafe_h.except(:controller, :action, :id).inspect}")

      # Validate param structure - helps diagnose form issues
      if params[:website].nil?
        Rails.logger.warn("[TenantAdmin::Rendering] WARNING: params[:website] is nil!")
        Rails.logger.warn("[TenantAdmin::Rendering] This usually means the form is missing 'scope: :website'")
        Rails.logger.warn("[TenantAdmin::Rendering] Top-level params present: #{params.keys.inspect}")

        # Check if params are at top level (common form scope mistake)
        if params[:rendering_mode].present? || params[:theme_name].present? || params[:client_theme_name].present?
          Rails.logger.error("[TenantAdmin::Rendering] FORM SCOPE ERROR: Found rendering params at top level instead of nested under :website")
          Rails.logger.error("[TenantAdmin::Rendering] rendering_mode=#{params[:rendering_mode]}, theme_name=#{params[:theme_name]}, client_theme_name=#{params[:client_theme_name]}")
          Rails.logger.error("[TenantAdmin::Rendering] Fix: Add 'scope: :website' to form_with in rendering_form.html.erb")
        end
      else
        Rails.logger.debug("[TenantAdmin::Rendering] Permitted params: #{rendering_params.to_h.inspect}")
      end

      @themes = Pwb::Theme.enabled
      @client_themes = Pwb::ClientTheme.enabled

      # Handle astro URLs separately (stored in client_theme_config JSONB)
      handle_astro_url_params

      Rails.logger.info("[TenantAdmin::Rendering] Before update: rendering_mode=#{@website.rendering_mode}, theme_name=#{@website.theme_name}, client_theme_name=#{@website.client_theme_name}")

      if @website.update(rendering_params)
        Rails.logger.info("[TenantAdmin::Rendering] SUCCESS: Updated website #{@website.id}")
        Rails.logger.info("[TenantAdmin::Rendering] After update: rendering_mode=#{@website.rendering_mode}, theme_name=#{@website.theme_name}, client_theme_name=#{@website.client_theme_name}")
        flash.now[:notice] = "Rendering settings updated successfully."
        render :rendering_form
      else
        Rails.logger.warn("[TenantAdmin::Rendering] FAILED: Could not update website #{@website.id}")
        Rails.logger.warn("[TenantAdmin::Rendering] Validation errors: #{@website.errors.full_messages.inspect}")
        render :rendering_form, status: :unprocessable_entity
      end
    # NOTE: ActionController::ParameterMissing is now handled by
    # TenantAdminController#handle_parameter_missing which provides
    # detailed logging and returns 422 with helpful error messages.
    end

    private

    def set_website
      @website = Pwb::Website.unscoped.find(params[:id])
    end

    def seed_website_content(website, skip_properties)
      Pwb::Current.website = website
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!
      Pwb::PagesSeeder.seed_page_basics!(website: website)
      Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
    end

    def website_params
      params.require(:website).permit(
        :subdomain,
        :company_display_name,
        :theme_name,
        :default_currency,
        :default_area_unit,
        :default_client_locale,
        :analytics_id,
        :analytics_id_type,
        :raw_css,
        :rendering_mode,
        :client_theme_name,
        :landing_hide_for_rent,
        :landing_hide_for_sale,
        :landing_hide_search_bar,
        :available_currencies,
        supported_locales: [],
        available_themes: []
      )
    end

    def appearance_params
      params.require(:website).permit(:theme_name, :selected_palette)
    end

    # Strong parameters for rendering pipeline updates
    #
    # Requires params to be nested under :website key.
    # If params[:website] is nil, this will raise ActionController::ParameterMissing
    # and return a 422 response.
    #
    # == Expected param structure:
    #   {
    #     website: {
    #       rendering_mode: 'rails' | 'client',
    #       theme_name: 'theme_name',           # B Theme for Rails mode
    #       client_theme_name: 'theme_name'     # A Theme for Client mode
    #     }
    #   }
    #
    # == Common error:
    # If the form omits `scope: :website`, params will look like:
    #   { rendering_mode: 'rails', theme_name: 'default' }
    # This causes params.require(:website) to fail with 422.
    #
    # @return [ActionController::Parameters] permitted parameters
    # @raise [ActionController::ParameterMissing] if params[:website] is missing
    def rendering_params
      params.require(:website).permit(:rendering_mode, :theme_name, :client_theme_name)
    end

    # Merge astro URLs into client_theme_config JSONB field
    #
    # The astro_client_url and astro_content_management_url are stored in the
    # client_theme_config JSONB column rather than as top-level attributes.
    # This allows flexible storage of client-side rendering configuration.
    #
    # - astro_client_url: URL for public Astro client pages
    # - astro_content_management_url: URL for /manage-content routes (admin)
    #
    # @note This is called before update to merge URLs into existing config
    def handle_astro_url_params
      current_config = @website.client_theme_config || {}

      # Handle astro_client_url
      if params[:website]&.key?(:astro_client_url)
        astro_url = params[:website][:astro_client_url].presence
        if astro_url.present?
          current_config = current_config.merge('astro_client_url' => astro_url)
        else
          current_config = current_config.except('astro_client_url')
        end
      end

      # Handle astro_content_management_url
      if params[:website]&.key?(:astro_content_management_url)
        content_url = params[:website][:astro_content_management_url].presence
        if content_url.present?
          current_config = current_config.merge('astro_content_management_url' => content_url)
        else
          current_config = current_config.except('astro_content_management_url')
        end
      end

      @website.client_theme_config = current_config
    end

    # Count users associated with a website
    #
    # Users can be associated with a website in two ways:
    # 1. Direct association via `website_id` column on pwb_users table
    # 2. Through `user_memberships` join table (for multi-website access)
    #
    # This method counts the union of both, using DISTINCT to avoid
    # double-counting users who have both a direct association AND a membership.
    #
    # @param website [Pwb::Website] The website to count users for
    # @return [Integer] Total unique users associated with the website
    def count_website_users(website)
      Pwb::User.unscoped.where(
        "website_id = :id OR id IN (SELECT user_id FROM pwb_user_memberships WHERE website_id = :id)",
        id: website.id
      ).distinct.count
    rescue StandardError
      0
    end
  end
end
