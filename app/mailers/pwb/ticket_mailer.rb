# frozen_string_literal: true

module Pwb
  class TicketMailer < Pwb::ApplicationMailer
    # Sent to platform admins when a new ticket is created
    def new_ticket_notification(ticket)
      @ticket = ticket
      @website = ticket.website
      @creator = ticket.creator

      mail(
        to: platform_admin_emails,
        subject: "[#{ticket.priority.upcase}] New Ticket #{ticket.ticket_number}: #{ticket.subject}"
      )
    end

    # Sent to the assignee when a ticket is assigned to them
    def ticket_assigned(ticket)
      @ticket = ticket
      @website = ticket.website
      @assignee = ticket.assigned_to

      return unless @assignee&.email

      mail(
        to: @assignee.email,
        subject: "Ticket Assigned: #{ticket.ticket_number} - #{ticket.subject}"
      )
    end

    # Sent to the website admin when ticket status changes
    def status_changed(ticket, old_status)
      @ticket = ticket
      @website = ticket.website
      @old_status = old_status
      @new_status = ticket.status

      mail(
        to: @ticket.creator.email,
        subject: "Ticket #{ticket.ticket_number} Status Updated: #{@new_status.humanize}"
      )
    end

    # Sent to the website admin when platform team replies
    def new_reply_notification(ticket, message)
      @ticket = ticket
      @message = message
      @website = ticket.website

      mail(
        to: @ticket.creator.email,
        subject: "New Reply on Ticket #{ticket.ticket_number}: #{ticket.subject}"
      )
    end

    # Sent to platform team/assignee when customer replies
    def customer_replied(ticket, message)
      @ticket = ticket
      @message = message
      @website = ticket.website

      recipients = []
      recipients << ticket.assigned_to.email if ticket.assigned_to&.email
      recipients += platform_admin_emails if recipients.empty?
      recipients = recipients.uniq.compact

      return if recipients.empty?

      mail(
        to: recipients,
        subject: "Customer Reply on #{ticket.ticket_number}: #{ticket.subject}"
      )
    end

    # Sent when a ticket is resolved
    def ticket_resolved(ticket)
      @ticket = ticket
      @website = ticket.website

      mail(
        to: @ticket.creator.email,
        subject: "Ticket #{ticket.ticket_number} Resolved: #{ticket.subject}"
      )
    end

    # SLA warning email sent when ticket is approaching SLA breach
    def sla_warning(ticket)
      @ticket = ticket
      @website = ticket.website
      @time_remaining = ticket.time_until_sla_breach

      recipients = []
      recipients << ticket.assigned_to.email if ticket.assigned_to&.email
      recipients += platform_admin_emails if recipients.empty?

      mail(
        to: recipients.uniq.compact,
        subject: "[SLA Warning] Ticket #{ticket.ticket_number} approaching deadline"
      )
    end

    # SLA breach notification
    def sla_breached(ticket)
      @ticket = ticket
      @website = ticket.website

      mail(
        to: platform_admin_emails,
        subject: "[SLA BREACH] Ticket #{ticket.ticket_number}: #{ticket.subject}"
      )
    end

    private

    def platform_admin_emails
      emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip)
      emails.reject(&:blank?)
    end
  end
end
