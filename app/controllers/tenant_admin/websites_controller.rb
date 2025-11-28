# frozen_string_literal: true

module TenantAdmin
  class WebsitesController < TenantAdminController
    before_action :set_website, only: [:show, :edit, :update, :destroy]

    def index
      @websites = Pwb::Website.unscoped.order(created_at: :desc)
      
      # Simple search
      if params[:search].present?
        @websites = @websites.where(
          "subdomain ILIKE ? OR company_display_name ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
      
      # Note: Add pagination when implementing (Kaminari or Pagy)
      # @websites = @websites.page(params[:page])
    end

    def show
      # @website set by before_action
      # Users and Messages are not directly associated with Website in the schema
      @users_count = 0 
      @props_count = Pwb::Prop.unscoped.where(website_id: @website.id).count rescue 0
      @pages_count = Pwb::Page.unscoped.where(website_id: @website.id).count rescue 0
      @messages_count = 0
    end

    def new
      @website = Pwb::Website.new
    end

    def create
      @website = Pwb::Website.new(website_params)
      
      if @website.save
        redirect_to tenant_admin_website_path(@website), notice: "Website created successfully."
      else
        render :new, status: :unprocessable_entity
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
