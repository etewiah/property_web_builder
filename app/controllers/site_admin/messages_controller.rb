# frozen_string_literal: true

module SiteAdmin
  # MessagesController
  # Manages messages for the current website
  class MessagesController < SiteAdminController
    def index
      @messages = Pwb::Message.order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @messages = @messages.where('email ILIKE ? OR message ILIKE ?',
                                   "%#{params[:search]}%",
                                   "%#{params[:search]}%")
      end
    end

    def show
      @message = Pwb::Message.find(params[:id])
    end
  end
end
