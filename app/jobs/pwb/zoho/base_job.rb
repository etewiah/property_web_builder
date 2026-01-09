# frozen_string_literal: true

require_relative '../../../services/pwb/zoho/errors'

module Pwb
  module Zoho
    # Base class for all Zoho sync jobs with common error handling
    #
    class BaseJob < ApplicationJob
      queue_as :zoho_sync

      # Retry rate limit errors with exponential backoff
      retry_on Pwb::Zoho::RateLimitError, wait: ->(executions) { (executions**2) * 30.seconds }, attempts: 5

      # Retry connection errors with shorter intervals
      retry_on Pwb::Zoho::ConnectionError, wait: 10.seconds, attempts: 3
      retry_on Pwb::Zoho::TimeoutError, wait: 10.seconds, attempts: 3

      # Retry API errors (might be temporary)
      retry_on Pwb::Zoho::ApiError, wait: 30.seconds, attempts: 2

      # Don't retry auth errors - needs manual intervention
      discard_on Pwb::Zoho::AuthenticationError do |job, error|
        Rails.logger.error "[Zoho] Authentication error in #{job.class.name}: #{error.message}"
        Rails.logger.error "[Zoho] Check Zoho credentials and refresh token"
        # TODO: Send alert to admin
      end

      # Don't retry config errors
      discard_on Pwb::Zoho::ConfigurationError do |job, error|
        Rails.logger.warn "[Zoho] Not configured, skipping #{job.class.name}: #{error.message}"
      end

      # Don't retry validation errors (bad data)
      discard_on Pwb::Zoho::ValidationError do |job, error|
        Rails.logger.error "[Zoho] Validation error in #{job.class.name}: #{error.message}"
      end

      private

      def zoho_enabled?
        Pwb::Zoho::Client.instance.configured?
      end

      def lead_sync_service
        @lead_sync_service ||= Pwb::Zoho::LeadSyncService.new
      end
    end
  end
end
