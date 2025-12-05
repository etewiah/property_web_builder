# frozen_string_literal: true

module SiteAdmin
  # PagePartsController
  # Manages page parts for the current website
  class PagePartsController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @page_parts = Pwb::PagePart.where(website_id: current_website&.id).includes(:page).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @page_parts = @page_parts.where('page_part_key ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @page_part = Pwb::PagePart.where(website_id: current_website&.id).find(params[:id])
    end
  end
end
