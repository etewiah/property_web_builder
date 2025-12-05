# frozen_string_literal: true

module SiteAdmin
  # ContentsController
  # Manages web contents for the current website
  class ContentsController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @contents = Pwb::Content.where(website_id: current_website&.id).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @contents = @contents.where('tag ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @content = Pwb::Content.where(website_id: current_website&.id).find(params[:id])
    end
  end
end
