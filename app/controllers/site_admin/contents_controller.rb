# frozen_string_literal: true

module SiteAdmin
  # ContentsController
  # Manages web contents for the current website
  class ContentsController < SiteAdminController
    def index
      @contents = Pwb::Content.order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @contents = @contents.where('tag ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @content = Pwb::Content.find(params[:id])
    end
  end
end
