# frozen_string_literal: true

module TenantAdmin
  class PropsController < TenantAdminController
    before_action :set_prop, only: [:show]

    def index
      props = Pwb::RealtyAsset.includes(:website).order(created_at: :desc)

      # Search by reference, title, or address
      if params[:search].present?
        props = props.where(
          "reference ILIKE ? OR title ILIKE ? OR street_address ILIKE ? OR city ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end

      # Filter by website
      if params[:website_id].present?
        props = props.where(website_id: params[:website_id])
      end

      @pagy, @props = pagy(props, limit: 25)
    end

    def show
      # @prop set by before_action
    end

    private

    def set_prop
      @prop = Pwb::RealtyAsset.find(params[:id])
    end
  end
end
