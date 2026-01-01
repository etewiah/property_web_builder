# frozen_string_literal: true

# SlaMonitoringJob
# Runs periodically to check for SLA breaches and send notifications
#
# Schedule this job to run every 15 minutes via:
#   - Sidekiq scheduler
#   - Clockwork
#   - Whenever gem
#   - Or any cron-like scheduler
#
# Example with solid_queue recurring:
#   SlaMonitoringJob.set(wait: 15.minutes).perform_later
class SlaMonitoringJob < ApplicationJob
  queue_as :default

  def perform
    check_response_sla_warnings
    check_response_sla_breaches
    check_resolution_sla_warnings
    check_resolution_sla_breaches

    # Re-schedule for continuous monitoring
    # Uncomment if using solid_queue without external scheduler
    # self.class.set(wait: 15.minutes).perform_later
  end

  private

  def check_response_sla_warnings
    # Find tickets approaching response SLA breach (within 1 hour)
    # that haven't had a warning sent yet
    tickets = Pwb::SupportTicket
      .active
      .where(first_response_at: nil)
      .where(sla_response_breached: false)
      .where(sla_warning_sent_at: nil)
      .where("sla_response_due_at <= ? AND sla_response_due_at > ?",
             1.hour.from_now, Time.current)

    tickets.find_each do |ticket|
      send_sla_warning(ticket)
      ticket.update!(sla_warning_sent_at: Time.current)
    end

    Rails.logger.info "[SlaMonitoringJob] Sent #{tickets.count} response SLA warnings" if tickets.any?
  end

  def check_response_sla_breaches
    # Find tickets that have breached response SLA
    tickets = Pwb::SupportTicket.sla_response_breached_pending

    tickets.find_each do |ticket|
      ticket.mark_sla_response_breached!
      send_sla_breach_notification(ticket)
    end

    Rails.logger.info "[SlaMonitoringJob] Marked #{tickets.count} tickets as response SLA breached" if tickets.any?
  end

  def check_resolution_sla_warnings
    # Find tickets approaching resolution SLA breach (within 2 hours)
    # that haven't had a recent warning
    tickets = Pwb::SupportTicket
      .active
      .where(sla_resolution_breached: false)
      .where("sla_resolution_due_at <= ? AND sla_resolution_due_at > ?",
             2.hours.from_now, Time.current)
      .where("sla_warning_sent_at IS NULL OR sla_warning_sent_at < ?", 4.hours.ago)

    tickets.find_each do |ticket|
      send_sla_warning(ticket)
      ticket.update!(sla_warning_sent_at: Time.current)
    end

    Rails.logger.info "[SlaMonitoringJob] Sent #{tickets.count} resolution SLA warnings" if tickets.any?
  end

  def check_resolution_sla_breaches
    # Find tickets that have breached resolution SLA
    tickets = Pwb::SupportTicket.sla_resolution_breached_pending

    tickets.find_each do |ticket|
      ticket.mark_sla_resolution_breached!
      send_sla_breach_notification(ticket)
    end

    Rails.logger.info "[SlaMonitoringJob] Marked #{tickets.count} tickets as resolution SLA breached" if tickets.any?
  end

  def send_sla_warning(ticket)
    TicketNotificationJob.perform_later(ticket.id, :sla_warning)
  rescue => e
    Rails.logger.error "[SlaMonitoringJob] Failed to send SLA warning for ticket #{ticket.id}: #{e.message}"
  end

  def send_sla_breach_notification(ticket)
    TicketNotificationJob.perform_later(ticket.id, :sla_breached)
  rescue => e
    Rails.logger.error "[SlaMonitoringJob] Failed to send SLA breach notification for ticket #{ticket.id}: #{e.message}"
  end
end
