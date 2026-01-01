# frozen_string_literal: true

# TicketNotificationJob
# Handles async notifications for support ticket events
#
# Usage:
#   TicketNotificationJob.perform_later(ticket.id, :created)
#   TicketNotificationJob.perform_later(message.id, :new_message)
#   TicketNotificationJob.perform_later(ticket.id, :status_changed)
#   TicketNotificationJob.perform_later(ticket.id, :assigned)
class TicketNotificationJob < ApplicationJob
  queue_as :default

  def perform(record_id, event_type)
    case event_type.to_sym
    when :created
      handle_ticket_created(record_id)
    when :assigned
      handle_ticket_assigned(record_id)
    when :status_changed
      handle_status_changed(record_id)
    when :new_message
      handle_new_message(record_id)
    else
      Rails.logger.warn "TicketNotificationJob: Unknown event type: #{event_type}"
    end
  end

  private

  def handle_ticket_created(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Send ntfy notification to platform admins
    notify_platform_admins(
      ticket.website,
      title: "New Support Ticket: #{ticket.ticket_number}",
      message: "#{ticket.subject}\n\nFrom: #{ticket.creator.display_name}\nWebsite: #{ticket.website.subdomain}\nPriority: #{ticket.priority.humanize}",
      priority: ticket.priority_urgent? ? "high" : "default",
      tags: ["ticket", ticket.category].compact
    )

    # Email notification could be added here
    # TicketMailer.new_ticket_notification(ticket).deliver_later
  end

  def handle_ticket_assigned(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket&.assigned_to

    # Notify the assignee
    # TicketMailer.ticket_assigned(ticket).deliver_later
  end

  def handle_status_changed(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Notify the website admin about the status change
    # TicketMailer.status_changed(ticket).deliver_later
  end

  def handle_new_message(message_id)
    message = Pwb::TicketMessage.find_by(id: message_id)
    return unless message
    return if message.internal_note # Don't notify for internal notes

    ticket = message.support_ticket

    if message.from_platform_admin
      # Platform replied - notify website admin
      # TicketMailer.new_reply_notification(ticket, message).deliver_later
    else
      # Website admin replied - notify platform team
      notify_platform_admins(
        ticket.website,
        title: "Reply on #{ticket.ticket_number}",
        message: "#{message.content.truncate(200)}\n\nFrom: #{message.author_name}",
        priority: "default",
        tags: ["reply"]
      )

      # Also notify assigned admin if present
      # TicketMailer.customer_replied(ticket, message).deliver_later if ticket.assigned_to
    end
  end

  def notify_platform_admins(website, title:, message:, priority: "default", tags: [])
    return unless website.ntfy_enabled?

    NtfyService.notify_admin(
      website,
      title,
      message,
      priority: priority,
      tags: tags
    )
  rescue => e
    Rails.logger.error "TicketNotificationJob: Failed to send ntfy notification: #{e.message}"
  end
end
