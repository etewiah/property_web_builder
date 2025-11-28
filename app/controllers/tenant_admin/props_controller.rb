# frozen_string_literal: true

module TenantAdmin
  class PropsController < TenantAdminController
    before_action :set_prop, only: [:show]

    def index
      @props = Pwb::Prop.unscoped.includes(:website).order(created_at: :desc).limit(100)
      
      # Search by reference or title
      if params[:search].present?
        @props = @props.where(
          "reference ILIKE ? OR title ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
      
      # Filter by website
      if params[:website_id].present?
        @props = @props.where(pwb_website_id: params[:website_id])
      end
    end

    def show
      # @prop set by before_action
    end

    private

    def set_prop
      @prop = Pwb::Prop.unscoped.find(params[:id])
    end
  end
end
