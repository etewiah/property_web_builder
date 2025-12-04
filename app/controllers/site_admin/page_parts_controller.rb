# frozen_string_literal: true

module SiteAdmin
  # PagePartsController
  # Manages page parts for the current website
  class PagePartsController < SiteAdminController
    def index
      @page_parts = Pwb::PagePart.includes(:page).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @page_parts = @page_parts.where('page_part_key ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @page_part = Pwb::PagePart.find(params[:id])
    end
  end
end
