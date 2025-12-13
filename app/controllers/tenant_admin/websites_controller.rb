# frozen_string_literal: true
require 'pwb/seeder'
require 'pwb/pages_seeder'
require 'pwb/contents_seeder'

module TenantAdmin
  class WebsitesController < TenantAdminController
    before_action :set_website, only: [:show, :edit, :update, :destroy, :seed, :retry_provisioning]

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
    end

    def create
      @website = Pwb::Website.new(website_params)
      
      if @website.save
        if params[:website][:seed_data] == "1"
          seed_website_content(@website, params[:website][:skip_properties] == "1")
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
      seed_website_content(@website, params[:skip_properties] == "1")
      redirect_to tenant_admin_website_path(@website), notice: "Website seeded successfully."
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
    end

    def update
      if @website.update(website_params)
        redirect_to tenant_admin_website_path(@website), notice: "Website updated successfully."
      else
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
        supported_locales: []
      )
    end
  end
end
