# frozen_string_literal: true

module TenantAdmin
  class PagesController < TenantAdminController
    before_action :set_page, only: [:show]

    def index
      @pages = Pwb::Page.unscoped.includes(:website).order(created_at: :desc).limit(100)
      
      # Search by title or slug
      if params[:search].present?
        @pages = @pages.where(
          "title ILIKE ? OR slug ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
      
      # Filter by website
      if params[:website_id].present?
        @pages = @pages.where(pwb_website_id: params[:website_id])
      end
    end

    def show
      # @page set by before_action
    end

    private

    def set_page
      @page = Pwb::Page.unscoped.find(params[:id])
    end
  end
end
