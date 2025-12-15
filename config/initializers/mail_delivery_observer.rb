# frozen_string_literal: true

# Logs email delivery for tracking and debugging
# Registers as an ActionMailer observer to capture successful deliveries
#
class MailDeliveryObserver
  def self.delivered_email(mail)
    StructuredLogger.info('[Email] Delivered',
      to: mail.to&.join(', '),
      bcc: mail.bcc&.join(', '),
      from: mail.from&.join(', '),
      subject: mail.subject,
      message_id: mail.message_id,
      mailer: mail['X-Mailer']&.value
    )
  rescue StandardError => e
    # Don't let logging errors break email delivery
    Rails.logger.error("[MailDeliveryObserver] Error logging delivery: #{e.message}")
  end
end

# Intercepts emails before sending to:
# 1. Log the sending attempt
# 2. Add BCC recipients from EMAIL_BCC_COPIES environment variable
#
# Set EMAIL_BCC_COPIES to a comma-separated list of email addresses
# to receive copies of all outgoing emails (useful for monitoring/debugging)
#
# Example: EMAIL_BCC_COPIES=admin@example.com,alerts@example.com
#
class MailDeliveryInterceptor
  def self.delivering_email(mail)
    # Add BCC recipients from environment variable
    add_bcc_copies(mail)

    StructuredLogger.info('[Email] Sending',
      to: mail.to&.join(', '),
      bcc: mail.bcc&.join(', '),
      subject: mail.subject
    )
  rescue StandardError => e
    Rails.logger.error("[MailDeliveryInterceptor] Error: #{e.message}")
  end

  def self.add_bcc_copies(mail)
    bcc_list = ENV['EMAIL_BCC_COPIES']
    return if bcc_list.blank?

    # Parse comma-separated list and clean up whitespace
    bcc_addresses = bcc_list.split(',').map(&:strip).reject(&:blank?)
    return if bcc_addresses.empty?

    # Merge with any existing BCC addresses
    existing_bcc = mail.bcc || []
    mail.bcc = (existing_bcc + bcc_addresses).uniq
  end
end

ActionMailer::Base.register_observer(MailDeliveryObserver)
ActionMailer::Base.register_interceptor(MailDeliveryInterceptor)
