# frozen_string_literal: true

# Base class for all background jobs
# Jobs in namespaces (e.g., Pwb::ApplicationJob) may extend this
class ApplicationJob < ActiveJob::Base
  # Retry failed jobs with exponential backoff
  # Retries at: 3s, 18s, 83s, ~6min, ~30min (5 attempts)
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # Discard jobs that fail after all retries (logs the error)
  discard_on ActiveJob::DeserializationError do |_job, error|
    Rails.logger.error "Job discarded due to deserialization error: #{error.message}"
  end
end
