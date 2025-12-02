# frozen_string_literal: true

module TenantAdmin
  class PagePartsController < TenantAdminController
    before_action :set_page_part, only: [:show]

    def index
      @page_parts = Pwb::PagePart.all.includes(:website, :page).order(created_at: :desc).limit(100)
      
      # Search by key or page slug
      if params[:search].present?
        @page_parts = @page_parts.where(
          "page_part_key ILIKE ? OR page_slug ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
      
      # Filter by website
      if params[:website_id].present?
        @page_parts = @page_parts.where(website_id: params[:website_id])
      end
    end

    def show
      # @page_part set by before_action
    end

    private

    def set_page_part
      @page_part = Pwb::PagePart.find(params[:id])
    end
  end
end
