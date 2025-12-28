# frozen_string_literal: true

module SiteAdmin
  # MessagesController
  # Manages messages for the current website
  class MessagesController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::Message,
                     search_columns: %i[origin_email content],
                     limit: 100

    # Override show to mark message as read and log the action
    def show
      @message = find_scoped_resource

      # Mark as read if not already read
      unless @message.read?
        @message.update(read: true)

        # Log the audit entry
        Pwb::AuthAuditLog.log_message_read(
          user: current_user,
          message: @message,
          request: request,
          website: current_website
        )
      end
    end
  end
end
