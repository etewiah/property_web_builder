# frozen_string_literal: true

# Amazon SES Configuration
#
# This initializer sets up Amazon SES for email delivery.
# It supports both SMTP delivery (via ActionMailer) and the SES API (for advanced features).
#
# Environment Variables:
#
# Required for SMTP delivery:
#   SMTP_ADDRESS        - SES SMTP endpoint (e.g., email-smtp.us-east-1.amazonaws.com)
#   SMTP_PORT           - SMTP port (typically 587)
#   SMTP_USERNAME       - SES SMTP username (from AWS console)
#   SMTP_PASSWORD       - SES SMTP password (from AWS console)
#
# Required for SES API (advanced features):
#   AWS_SES_ACCESS_KEY_ID     - AWS access key with SES permissions
#   AWS_SES_SECRET_ACCESS_KEY - AWS secret key
#   AWS_SES_REGION            - AWS region (e.g., us-east-1)
#
# Optional:
#   SMTP_AUTH           - Authentication type (default: login)
#   SMTP_DOMAIN         - HELO domain (default: MAILER_HOST)
#   DEFAULT_FROM_EMAIL  - Default sender address
#   MAILER_HOST         - Host for email links
#
# SES Regional SMTP Endpoints:
#   US East (N. Virginia):  email-smtp.us-east-1.amazonaws.com
#   US West (Oregon):       email-smtp.us-west-2.amazonaws.com
#   EU (Ireland):           email-smtp.eu-west-1.amazonaws.com
#   EU (Frankfurt):         email-smtp.eu-central-1.amazonaws.com
#   Asia Pacific (Sydney):  email-smtp.ap-southeast-2.amazonaws.com
#   Asia Pacific (Tokyo):   email-smtp.ap-northeast-1.amazonaws.com
#   Asia Pacific (Mumbai):  email-smtp.ap-south-1.amazonaws.com
#

module Pwb
  module SES
    class << self
      # Check if SES SMTP is configured
      def smtp_configured?
        ENV["SMTP_ADDRESS"].present? &&
          ENV["SMTP_USERNAME"].present? &&
          ENV["SMTP_PASSWORD"].present?
      end

      # Check if SES API is configured (for advanced features)
      def api_configured?
        (ENV["AWS_SES_ACCESS_KEY_ID"].present? && ENV["AWS_SES_SECRET_ACCESS_KEY"].present?) ||
          ENV["AWS_ACCESS_KEY_ID"].present? # Falls back to default AWS credentials
      end

      # Get the configured AWS region for SES
      def region
        ENV.fetch("AWS_SES_REGION") { ENV.fetch("AWS_REGION", "us-east-1") }
      end

      # Get the SES v2 client for API operations
      # @return [Aws::SESV2::Client, nil]
      def client
        return nil unless api_configured?

        @client ||= begin
          require "aws-sdk-sesv2"

          credentials = if ENV["AWS_SES_ACCESS_KEY_ID"].present?
            Aws::Credentials.new(
              ENV["AWS_SES_ACCESS_KEY_ID"],
              ENV["AWS_SES_SECRET_ACCESS_KEY"]
            )
          else
            nil # Use default credential chain
          end

          options = { region: region }
          options[:credentials] = credentials if credentials

          Aws::SESV2::Client.new(options)
        end
      end

      # Get account sending quota and statistics
      # @return [Hash] Account details including quota and send statistics
      def account_info
        return { error: "SES API not configured" } unless api_configured?

        begin
          response = client.get_account
          {
            production_access: response.production_access_enabled,
            sending_enabled: response.send_quota.present?,
            send_quota: {
              max_24_hour_send: response.send_quota&.max_24_hour_send,
              max_send_rate: response.send_quota&.max_send_rate,
              sent_last_24_hours: response.send_quota&.sent_last_24_hours
            },
            enforcement_status: response.enforcement_status
          }
        rescue Aws::SESV2::Errors::ServiceError => e
          { error: e.message }
        end
      end

      # List verified email identities (domains and email addresses)
      # @return [Array<Hash>] List of verified identities
      def verified_identities
        return [] unless api_configured?

        begin
          response = client.list_email_identities
          response.email_identities.map do |identity|
            {
              name: identity.identity_name,
              type: identity.identity_type,
              sending_enabled: identity.sending_enabled
            }
          end
        rescue Aws::SESV2::Errors::ServiceError => e
          [{ error: e.message }]
        end
      end

      # Check if an email address or domain is verified
      # @param identity [String] Email address or domain to check
      # @return [Boolean]
      def identity_verified?(identity)
        return false unless api_configured?

        begin
          response = client.get_email_identity(email_identity: identity)
          response.verified_for_sending_status
        rescue Aws::SESV2::Errors::NotFoundException
          false
        rescue Aws::SESV2::Errors::ServiceError
          false
        end
      end

      # Send a test email using SES API
      # @param to [String] Recipient email address
      # @param from [String] Sender email address (must be verified)
      # @return [Hash] Result with message_id or error
      def send_test_email(to:, from: nil)
        return { error: "SES API not configured" } unless api_configured?

        from ||= ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@example.com")

        begin
          response = client.send_email(
            from_email_address: from,
            destination: { to_addresses: [to] },
            content: {
              simple: {
                subject: { data: "SES Test Email from PropertyWebBuilder" },
                body: {
                  text: { data: "This is a test email sent via Amazon SES API.\n\nTimestamp: #{Time.current}" },
                  html: { data: "<h1>SES Test Email</h1><p>This is a test email sent via Amazon SES API.</p><p><strong>Timestamp:</strong> #{Time.current}</p>" }
                }
              }
            }
          )
          { success: true, message_id: response.message_id }
        rescue Aws::SESV2::Errors::ServiceError => e
          { error: e.message }
        end
      end

      # Get configuration summary for diagnostics
      # @return [Hash]
      def configuration_summary
        {
          smtp: {
            configured: smtp_configured?,
            address: ENV["SMTP_ADDRESS"],
            port: ENV.fetch("SMTP_PORT", 587),
            username: ENV["SMTP_USERNAME"].present? ? "(set)" : "(not set)",
            auth: ENV.fetch("SMTP_AUTH", "login")
          },
          api: {
            configured: api_configured?,
            region: region,
            access_key: ENV["AWS_SES_ACCESS_KEY_ID"].present? ? "(set)" : "(using default chain)"
          },
          mailer: {
            host: ENV["MAILER_HOST"] || ENV["APP_HOST"],
            from: ENV["DEFAULT_FROM_EMAIL"]
          }
        }
      end
    end
  end
end
