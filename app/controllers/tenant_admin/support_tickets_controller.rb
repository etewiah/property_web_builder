# frozen_string_literal: true

module TenantAdmin
  # SupportTicketsController
  # Platform-wide support ticket management for tenant admins
  #
  # Features:
  # - View all support tickets across all websites
  # - Filter by status, priority, website, assignee
  # - Assign tickets to platform team members
  # - Change ticket status
  # - Reply to tickets with public messages or internal notes
  class SupportTicketsController < TenantAdminController
    before_action :set_ticket, only: [:show, :assign, :change_status, :add_message]

    # GET /tenant_admin/support_tickets
    def index
      @tickets = Pwb::SupportTicket
                   .includes(:website, :creator, :assigned_to)
                   .recent

      # Apply filters
      @tickets = apply_filters(@tickets)

      @pagy, @tickets = pagy(@tickets, limit: 25)

      # Stats for dashboard header
      @stats = {
        total: Pwb::SupportTicket.count,
        open: Pwb::SupportTicket.status_open.count,
        in_progress: Pwb::SupportTicket.status_in_progress.count,
        waiting: Pwb::SupportTicket.status_waiting_on_customer.count,
        needs_response: Pwb::SupportTicket.needs_response.count,
        unassigned: Pwb::SupportTicket.unassigned.active.count
      }

      # For filter dropdowns
      @websites = Pwb::Website.order(:subdomain)
      @platform_admins = platform_admin_users
    end

    # GET /tenant_admin/support_tickets/:id
    def show
      # Platform admins see ALL messages including internal notes
      @messages = @ticket.messages
                    .includes(:user)
                    .chronological

      @platform_admins = platform_admin_users
    end

    # PATCH /tenant_admin/support_tickets/:id/assign
    def assign
      if params[:user_id].present?
        assignee = Pwb::User.find(params[:user_id])
        @ticket.assign_to!(assignee)

        # Queue notification
        # TicketNotificationJob.perform_later(@ticket.id, :assigned)

        redirect_to tenant_admin_support_ticket_path(@ticket),
                    notice: "Ticket assigned to #{assignee.display_name}"
      else
        @ticket.unassign!
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    notice: "Ticket unassigned"
      end
    end

    # PATCH /tenant_admin/support_tickets/:id/change_status
    def change_status
      new_status = params[:status]

      unless Pwb::SupportTicket.statuses.key?(new_status)
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    alert: "Invalid status"
        return
      end

      old_status = @ticket.status

      case new_status
      when "resolved"
        @ticket.resolve!
      when "closed"
        @ticket.close!
      when "open"
        @ticket.reopen!
      else
        @ticket.update!(status: new_status)
      end

      # Create status change message for audit trail
      @ticket.messages.create!(
        website: @ticket.website,
        user: current_user,
        content: "Status changed from #{old_status.humanize} to #{new_status.humanize}",
        from_platform_admin: true,
        status_changed_from: old_status,
        status_changed_to: new_status
      )

      # Queue notification to website admin
      # TicketNotificationJob.perform_later(@ticket.id, :status_changed)

      redirect_to tenant_admin_support_ticket_path(@ticket),
                  notice: "Ticket status updated to #{new_status.humanize}"
    end

    # POST /tenant_admin/support_tickets/:id/add_message
    def add_message
      if params[:message].blank? || params[:message][:content].blank?
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    alert: "Message content cannot be blank"
        return
      end

      is_internal = params[:message][:internal_note] == "1"

      @message = @ticket.messages.build(
        website: @ticket.website,
        user: current_user,
        content: params[:message][:content],
        from_platform_admin: true,
        internal_note: is_internal
      )

      if @message.save
        # Update ticket status if sending a public reply and ticket is open
        if !is_internal && @ticket.status_open?
          @ticket.update!(status: :waiting_on_customer)
        end

        # Queue notification to website admin (only for non-internal messages)
        # TicketNotificationJob.perform_later(@message.id, :new_message) unless is_internal

        notice = is_internal ? "Internal note added" : "Reply sent to customer"
        redirect_to tenant_admin_support_ticket_path(@ticket), notice: notice
      else
        redirect_to tenant_admin_support_ticket_path(@ticket),
                    alert: "Could not add message. Please try again."
      end
    end

    private

    def set_ticket
      @ticket = Pwb::SupportTicket.includes(:website, :creator, :assigned_to).find(params[:id])
    end

    def apply_filters(scope)
      # Filter by status
      if params[:status].present? && Pwb::SupportTicket.statuses.key?(params[:status])
        scope = scope.where(status: params[:status])
      end

      # Filter by priority
      if params[:priority].present? && Pwb::SupportTicket.priorities.key?(params[:priority])
        scope = scope.where(priority: params[:priority])
      end

      # Filter by website
      if params[:website_id].present?
        scope = scope.where(website_id: params[:website_id])
      end

      # Filter by assignee
      if params[:assigned_to].present?
        if params[:assigned_to] == "unassigned"
          scope = scope.unassigned
        else
          scope = scope.where(assigned_to_id: params[:assigned_to])
        end
      end

      # Filter by category
      if params[:category].present?
        scope = scope.where(category: params[:category])
      end

      # Search by subject or ticket number
      if params[:search].present?
        search_term = "%#{params[:search].downcase}%"
        scope = scope.where(
          "LOWER(subject) LIKE :term OR LOWER(ticket_number) LIKE :term",
          term: search_term
        )
      end

      scope
    end

    def platform_admin_users
      # Get users who are in the TENANT_ADMIN_EMAILS list
      allowed_emails = ENV.fetch("TENANT_ADMIN_EMAILS", "")
                         .split(",")
                         .map(&:strip)
                         .map(&:downcase)

      Pwb::User.where("LOWER(email) IN (?)", allowed_emails).order(:email)
    end
  end
end
