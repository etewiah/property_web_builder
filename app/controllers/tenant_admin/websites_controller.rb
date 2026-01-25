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
      # Users and Messages are not directly associated with Website in the schema
      @users_count = 0 
      @props_count = Pwb::RealtyAsset.unscoped.where(website_id: @website.id).count rescue 0
      @pages_count = Pwb::Page.unscoped.where(website_id: @website.id).count rescue 0
      @messages_count = 0
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
    def rendering_form
      @themes = Pwb::Theme.enabled
      @client_themes = Pwb::ClientTheme.enabled
    end

    # PATCH /tenant_admin/websites/:id/update_rendering
    def update_rendering
      @themes = Pwb::Theme.enabled
      @client_themes = Pwb::ClientTheme.enabled

      # Handle astro_client_url separately (stored in client_theme_config JSONB)
      handle_astro_client_url_param

      if @website.update(rendering_params)
        flash.now[:notice] = "Rendering settings updated successfully."
        render :rendering_form
      else
        render :rendering_form, status: :unprocessable_entity
      end
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

    def rendering_params
      params.require(:website).permit(:rendering_mode, :theme_name, :client_theme_name)
    end

    # Merge astro_client_url into client_theme_config JSONB field
    def handle_astro_client_url_param
      return unless params[:website]&.key?(:astro_client_url)

      astro_url = params[:website][:astro_client_url].presence
      current_config = @website.client_theme_config || {}

      if astro_url.present?
        @website.client_theme_config = current_config.merge('astro_client_url' => astro_url)
      else
        # Remove the key if URL is blank
        @website.client_theme_config = current_config.except('astro_client_url')
      end
    end
  end
end
