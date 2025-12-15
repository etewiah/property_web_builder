# frozen_string_literal: true

# Logs email delivery for tracking and debugging
# Registers as an ActionMailer observer to capture successful deliveries
#
class MailDeliveryObserver
  def self.delivered_email(mail)
    StructuredLogger.info('[Email] Delivered',
      to: mail.to&.join(', '),
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

# Also log failed deliveries if using a delivery interceptor
class MailDeliveryInterceptor
  def self.delivering_email(mail)
    StructuredLogger.info('[Email] Sending',
      to: mail.to&.join(', '),
      subject: mail.subject
    )
  rescue StandardError => e
    Rails.logger.error("[MailDeliveryInterceptor] Error logging: #{e.message}")
  end
end

ActionMailer::Base.register_observer(MailDeliveryObserver)
ActionMailer::Base.register_interceptor(MailDeliveryInterceptor)
