# frozen_string_literal: true

module SiteAdmin
  # SupportTicketsController
  # Allows website admins to create and manage support tickets
  #
  # Features:
  # - Create new support tickets with category and priority
  # - View ticket history and status
  # - Add replies to existing tickets
  # - Receive updates from platform support team
  class SupportTicketsController < SiteAdminController
    before_action :load_ticket, only: [:show, :add_message]

    # GET /site_admin/support_tickets
    def index
      @tickets = current_website.support_tickets
                   .includes(:creator, :assigned_to)
                   .recent

      # Filter by status if provided
      if params[:status].present? && Pwb::SupportTicket.statuses.key?(params[:status])
        @tickets = @tickets.where(status: params[:status])
      end

      # Simple search
      if params[:search].present?
        search_term = "%#{params[:search].downcase}%"
        @tickets = @tickets.where(
          "LOWER(subject) LIKE :term OR ticket_number LIKE :term",
          term: search_term
        )
      end

      @tickets = @tickets.limit(50)

      # Stats for the header
      @stats = {
        total: current_website.support_tickets.count,
        open: current_website.support_tickets.status_open.count,
        in_progress: current_website.support_tickets.status_in_progress.count,
        resolved: current_website.support_tickets.status_resolved.count
      }
    end

    # GET /site_admin/support_tickets/:id
    def show
      # Website admins only see public messages, not internal notes
      @messages = @ticket.messages
                    .public_messages
                    .includes(:user)
                    .chronological
    end

    # GET /site_admin/support_tickets/new
    def new
      @ticket = current_website.support_tickets.build(priority: :normal)
    end

    # POST /site_admin/support_tickets
    def create
      @ticket = current_website.support_tickets.build(ticket_params)
      @ticket.creator = current_user

      if @ticket.save
        # Queue notification to platform admins
        # TicketNotificationJob.perform_later(@ticket.id, :created)

        redirect_to site_admin_support_ticket_path(@ticket),
                    notice: "Support ticket created successfully. Your ticket number is #{@ticket.ticket_number}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    # POST /site_admin/support_tickets/:id/add_message
    def add_message
      if params[:message].blank? || params[:message][:content].blank?
        redirect_to site_admin_support_ticket_path(@ticket),
                    alert: "Message content cannot be blank"
        return
      end

      @message = @ticket.messages.build(
        website: current_website,
        user: current_user,
        content: params[:message][:content],
        from_platform_admin: false
      )

      if @message.save
        # Reopen ticket if it was waiting on customer
        if @ticket.status_waiting_on_customer?
          @ticket.update!(status: :open)
        end

        # Queue notification to platform admins
        # TicketNotificationJob.perform_later(@message.id, :new_message)

        redirect_to site_admin_support_ticket_path(@ticket),
                    notice: "Your reply has been added"
      else
        redirect_to site_admin_support_ticket_path(@ticket),
                    alert: "Could not add your reply. Please try again."
      end
    end

    private

    def load_ticket
      @ticket = current_website.support_tickets.find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:subject, :description, :category, :priority)
    end
  end
end
