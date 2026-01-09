# frozen_string_literal: true

module Pwb
  module Zoho
    # Base class for all Zoho sync jobs with common error handling
    #
    class BaseJob < ApplicationJob
      queue_as :zoho_sync

      # Retry rate limit errors with exponential backoff
      retry_on Zoho::RateLimitError, wait: ->(executions) { (executions**2) * 30.seconds }, attempts: 5

      # Retry connection errors with shorter intervals
      retry_on Zoho::ConnectionError, wait: 10.seconds, attempts: 3
      retry_on Zoho::TimeoutError, wait: 10.seconds, attempts: 3

      # Retry API errors (might be temporary)
      retry_on Zoho::ApiError, wait: 30.seconds, attempts: 2

      # Don't retry auth errors - needs manual intervention
      discard_on Zoho::AuthenticationError do |job, error|
        Rails.logger.error "[Zoho] Authentication error in #{job.class.name}: #{error.message}"
        Rails.logger.error "[Zoho] Check Zoho credentials and refresh token"
        # TODO: Send alert to admin
      end

      # Don't retry config errors
      discard_on Zoho::ConfigurationError do |job, error|
        Rails.logger.warn "[Zoho] Not configured, skipping #{job.class.name}: #{error.message}"
      end

      # Don't retry validation errors (bad data)
      discard_on Zoho::ValidationError do |job, error|
        Rails.logger.error "[Zoho] Validation error in #{job.class.name}: #{error.message}"
      end

      private

      def zoho_enabled?
        Zoho::Client.instance.configured?
      end

      def lead_sync_service
        @lead_sync_service ||= Zoho::LeadSyncService.new
      end
    end
  end
end
