# frozen_string_literal: true

module TenantAdmin
  class ContentsController < TenantAdminController
    before_action :set_content, only: [:show]

    def index
      @contents = Pwb::Content.unscoped.includes(:website).order(created_at: :desc).limit(100)
      
      # Search by key or tag
      if params[:search].present?
        @contents = @contents.where(
          "key ILIKE ? OR tag ILIKE ?",
          "%#{params[:search]}%",
          "%#{params[:search]}%"
        )
      end
      
      # Filter by website
      if params[:website_id].present?
        @contents = @contents.where(website_id: params[:website_id])
      end
    end

    def show
      # @content set by before_action
    end

    private

    def set_content
      @content = Pwb::Content.unscoped.find(params[:id])
    end
  end
end
