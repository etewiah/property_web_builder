# frozen_string_literal: true

module SiteAdmin
  # PropsController
  # Manages properties for the current website
  class PropsController < SiteAdminController
    def index
      @props = Pwb::Prop.order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @props = @props.where('reference ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @prop = Pwb::Prop.find(params[:id])
    end
  end
end
