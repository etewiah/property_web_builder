# frozen_string_literal: true

module Pwb
  # Background job for batch URL import processing.
  # Processes URLs asynchronously and can notify on completion.
  #
  # Usage:
  #   Pwb::BatchUrlImportJob.perform_later(website_id, urls: ["url1", "url2"])
  #   Pwb::BatchUrlImportJob.perform_later(website_id, csv_content: csv_string)
  #
  class BatchUrlImportJob < ApplicationJob
    queue_as :low_priority

    # Don't retry on validation errors
    discard_on ActiveRecord::RecordNotFound

    def perform(website_id, urls: nil, csv_content: nil, notify_email: nil)
      website = Website.find(website_id)

      Rails.logger.info "[BatchUrlImportJob] Starting batch import for website #{website.id}"

      service = BatchUrlImportService.new(
        website,
        urls: urls,
        csv_content: csv_content
      )

      result = service.call

      Rails.logger.info "[BatchUrlImportJob] #{result.summary}"

      # Send notification email if requested
      if notify_email.present?
        send_completion_notification(website, result, notify_email)
      end

      result
    end

    private

    def send_completion_notification(website, result, email)
      # Use existing mailer infrastructure if available
      # For now, just log the completion
      Rails.logger.info "[BatchUrlImportJob] Would notify #{email}: #{result.summary}"

      # Could be implemented as:
      # BatchImportMailer.completion_notification(website, result, email).deliver_later
    end
  end
end
