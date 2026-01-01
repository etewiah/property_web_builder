# frozen_string_literal: true

# TicketNotificationJob
# Handles async notifications for support ticket events
#
# Usage:
#   TicketNotificationJob.perform_later(ticket.id, :created)
#   TicketNotificationJob.perform_later(message.id, :new_message)
#   TicketNotificationJob.perform_later(ticket.id, :status_changed, old_status: 'open')
#   TicketNotificationJob.perform_later(ticket.id, :assigned)
#   TicketNotificationJob.perform_later(ticket.id, :resolved)
#   TicketNotificationJob.perform_later(ticket.id, :sla_warning)
#   TicketNotificationJob.perform_later(ticket.id, :sla_breached)
class TicketNotificationJob < ApplicationJob
  queue_as :default

  def perform(record_id, event_type, options = {})
    case event_type.to_sym
    when :created
      handle_ticket_created(record_id)
    when :assigned
      handle_ticket_assigned(record_id)
    when :status_changed
      handle_status_changed(record_id, options[:old_status])
    when :new_message
      handle_new_message(record_id)
    when :resolved
      handle_ticket_resolved(record_id)
    when :sla_warning
      handle_sla_warning(record_id)
    when :sla_breached
      handle_sla_breached(record_id)
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

    # Send email notification to platform admins
    if email_notifications_enabled?
      Pwb::TicketMailer.new_ticket_notification(ticket).deliver_later
    end
  end

  def handle_ticket_assigned(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket&.assigned_to

    # Notify the assignee via email
    if email_notifications_enabled?
      Pwb::TicketMailer.ticket_assigned(ticket).deliver_later
    end
  end

  def handle_status_changed(ticket_id, old_status)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Notify the website admin about the status change via email
    if email_notifications_enabled? && old_status.present?
      Pwb::TicketMailer.status_changed(ticket, old_status).deliver_later
    end
  end

  def handle_ticket_resolved(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Send resolution notification to customer
    if email_notifications_enabled?
      Pwb::TicketMailer.ticket_resolved(ticket).deliver_later
    end
  end

  def handle_new_message(message_id)
    message = Pwb::TicketMessage.find_by(id: message_id)
    return unless message
    return if message.internal_note # Don't notify for internal notes

    ticket = message.support_ticket

    if message.from_platform_admin
      # Platform replied - notify website admin via email
      if email_notifications_enabled?
        Pwb::TicketMailer.new_reply_notification(ticket, message).deliver_later
      end
    else
      # Website admin replied - notify platform team via ntfy
      notify_platform_admins(
        ticket.website,
        title: "Reply on #{ticket.ticket_number}",
        message: "#{message.content.truncate(200)}\n\nFrom: #{message.author_name}",
        priority: "default",
        tags: ["reply"]
      )

      # Also notify assigned admin via email if present
      if email_notifications_enabled?
        Pwb::TicketMailer.customer_replied(ticket, message).deliver_later
      end
    end
  end

  def handle_sla_warning(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Send SLA warning to assignee or platform admins
    if email_notifications_enabled?
      Pwb::TicketMailer.sla_warning(ticket).deliver_later
    end

    # Also send ntfy notification for urgency
    notify_platform_admins(
      ticket.website,
      title: "SLA Warning: #{ticket.ticket_number}",
      message: "#{ticket.subject}\n\nTime remaining: #{ticket.time_until_sla_breach_in_words}",
      priority: "high",
      tags: ["sla", "warning"]
    )
  end

  def handle_sla_breached(ticket_id)
    ticket = Pwb::SupportTicket.find_by(id: ticket_id)
    return unless ticket

    # Send SLA breach notification
    if email_notifications_enabled?
      Pwb::TicketMailer.sla_breached(ticket).deliver_later
    end

    # Send urgent ntfy notification
    notify_platform_admins(
      ticket.website,
      title: "SLA BREACH: #{ticket.ticket_number}",
      message: "#{ticket.subject}\n\nImmediate action required!",
      priority: "urgent",
      tags: ["sla", "breach", "urgent"]
    )
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

  def email_notifications_enabled?
    # Enable email notifications when TICKET_EMAIL_NOTIFICATIONS env var is set
    # or when not in development/test environment
    return true if ENV['TICKET_EMAIL_NOTIFICATIONS'] == 'true'
    return false if Rails.env.development? || Rails.env.test?

    true
  end
end
