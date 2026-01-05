# frozen_string_literal: true
require 'pwb/seeder'
require 'pwb/pages_seeder'
require 'pwb/contents_seeder'

module TenantAdmin
  class WebsitesController < TenantAdminController
    before_action :set_website, only: [:show, :edit, :update, :destroy, :seed, :seed_form, :retry_provisioning]

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
    end

    def update
      if @website.update(website_params)
        redirect_to tenant_admin_website_path(@website), notice: "Website updated successfully."
      else
        @themes = Pwb::Theme.enabled
        @all_themes = @themes
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @website.destroy
      redirect_to tenant_admin_websites_path, notice: "Website deleted successfully."
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
        :landing_hide_for_rent,
        :landing_hide_for_sale,
        :landing_hide_search_bar,
        :available_currencies,
        supported_locales: [],
        available_themes: []
      )
    end
  end
end
