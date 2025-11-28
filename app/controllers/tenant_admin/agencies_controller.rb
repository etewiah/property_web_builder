# frozen_string_literal: true

module TenantAdmin
  class AgenciesController < TenantAdminController
    before_action :set_agency, only: [:show, :edit, :update, :destroy]

    def index
      @agencies = Pwb::Agency.unscoped.includes(:website).order(created_at: :desc)
      
      if params[:search].present?
        @agencies = @agencies.where(
          "name ILIKE ? OR address ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
    end

    def show
      # @agency set by before_action
    end

    def new
      @agency = Pwb::Agency.new
      @websites = Pwb::Website.unscoped.order(:subdomain)
    end

    def create
      @agency = Pwb::Agency.new(agency_params)
      
      if @agency.save
        redirect_to tenant_admin_agency_path(@agency), notice: "Agency created successfully."
      else
        @websites = Pwb::Website.unscoped.order(:subdomain)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @websites = Pwb::Website.unscoped.order(:subdomain)
    end

    def update
      if @agency.update(agency_params)
        redirect_to tenant_admin_agency_path(@agency), notice: "Agency updated successfully."
      else
        @websites = Pwb::Website.unscoped.order(:subdomain)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @agency.destroy
      redirect_to tenant_admin_agencies_path, notice: "Agency deleted successfully."
    end

    private

    def set_agency
      @agency = Pwb::Agency.unscoped.find(params[:id])
    end

    def agency_params
      params.require(:pwb_agency).permit(
        :name,
        :address,
        :phone,
        :email,
        :pwb_website_id
      )
    end
  end
end
