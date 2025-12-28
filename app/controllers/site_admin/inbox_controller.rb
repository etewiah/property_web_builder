# frozen_string_literal: true

module SiteAdmin
  # InboxController
  # Unified inbox combining contacts and messages into a CRM-style view
  #
  # Features:
  # - Contact list with unread message counts
  # - Message thread view per contact
  # - Search across contacts and messages
  # - Mark messages as read when viewing conversation
  class InboxController < SiteAdminController
    before_action :set_contacts, only: [:index]
    before_action :set_selected_contact, only: [:show]

    # GET /site_admin/inbox
    # Shows contact list with optional search
    def index
      # If a contact is selected via query param, show their conversation
      if params[:contact_id].present?
        redirect_to site_admin_inbox_conversation_path(params[:contact_id])
        return
      end

      # Default to first contact with messages if available
      @selected_contact = @contacts.first if @contacts.any?
      load_conversation if @selected_contact
    end

    # GET /site_admin/inbox/:id
    # Shows conversation with a specific contact
    def show
      load_conversation
      mark_messages_as_read
    end

    private

    def set_contacts
      # Get contacts with messages, ordered by most recent message
      base_scope = Pwb::Contact
        .where(website_id: current_website.id)
        .joins(:messages)
        .where(pwb_messages: { website_id: current_website.id })
        .select(
          'pwb_contacts.*',
          'MAX(pwb_messages.created_at) as last_message_at',
          'COUNT(pwb_messages.id) as messages_count',
          'SUM(CASE WHEN pwb_messages.read = false THEN 1 ELSE 0 END) as unread_count'
        )
        .group('pwb_contacts.id')
        .order('last_message_at DESC')

      # Apply search if present
      if params[:search].present?
        search_term = "%#{params[:search].downcase}%"
        base_scope = base_scope.where(
          'LOWER(pwb_contacts.primary_email) LIKE :term OR ' \
          'LOWER(pwb_contacts.first_name) LIKE :term OR ' \
          'LOWER(pwb_contacts.last_name) LIKE :term',
          term: search_term
        )
      end

      @contacts = base_scope.limit(100)

      # Also get orphan messages (messages without contacts)
      @orphan_messages_count = Pwb::Message
        .where(website_id: current_website.id, contact_id: nil)
        .count
    end

    def set_selected_contact
      @selected_contact = Pwb::Contact
        .where(website_id: current_website.id)
        .find(params[:id])

      # Load all contacts for the sidebar
      set_contacts
    end

    def load_conversation
      return unless @selected_contact

      @messages = Pwb::Message
        .where(website_id: current_website.id, contact_id: @selected_contact.id)
        .order(created_at: :asc)
    end

    def mark_messages_as_read
      return unless @selected_contact

      unread_messages = Pwb::Message
        .where(website_id: current_website.id, contact_id: @selected_contact.id, read: false)

      unread_messages.find_each do |message|
        message.update(read: true)

        # Log audit entry for each message read
        if current_user
          Pwb::AuthAuditLog.log_message_read(
            user: current_user,
            message: message,
            request: request,
            website: current_website
          )
        end
      end

      # Update the nav count
      set_nav_counts
    end
  end
end
