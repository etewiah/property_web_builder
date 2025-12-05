# frozen_string_literal: true

module SiteAdmin
  # MessagesController
  # Manages messages for the current website
  class MessagesController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @messages = Pwb::Message.where(website_id: current_website&.id).order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @messages = @messages.where('origin_email ILIKE ? OR content ILIKE ?',
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @message = Pwb::Message.where(website_id: current_website&.id).find(params[:id])
    end
  end
end
