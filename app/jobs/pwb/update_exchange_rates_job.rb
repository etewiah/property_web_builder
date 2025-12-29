# frozen_string_literal: true

module Pwb
  # Background job to update currency exchange rates for all websites.
  #
  # This job fetches the latest rates from the European Central Bank
  # and stores them in each website's exchange_rates column.
  #
  # MULTI-TENANCY:
  #   This job operates in two modes:
  #   - Global mode (no website_id): Updates ALL websites' exchange rates
  #   - Single tenant mode (website_id provided): Updates one website
  #
  #   No ActsAsTenant context is set because:
  #   - Updates are made directly via Pwb::Website (cross-tenant namespace)
  #   - Each website's data is updated independently using explicit website_id
  #   - No tenant-scoped queries are performed
  #
  # Schedule: Run daily (configure in config/recurring.yml for Solid Queue)
  #
  # Usage:
  #   # Run manually for all websites
  #   Pwb::UpdateExchangeRatesJob.perform_later
  #
  #   # Run for specific website
  #   Pwb::UpdateExchangeRatesJob.perform_later(website_id: 123)
  #
  class UpdateExchangeRatesJob < ApplicationJob
    queue_as :default

    # Retry on network errors
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(website_id: nil)
      if website_id
        update_single_website(website_id)
      else
        update_all_websites
      end
    end

    private

    def update_single_website(website_id)
      website = Website.find_by(id: website_id)
      return unless website

      ExchangeRateService.update_rates(website)
      Rails.logger.info "[UpdateExchangeRatesJob] Updated rates for website #{website_id}"
    rescue ExchangeRateService::RateFetchError => e
      Rails.logger.error "[UpdateExchangeRatesJob] Failed for website #{website_id}: #{e.message}"
      raise # Re-raise to trigger retry
    end

    def update_all_websites
      count = ExchangeRateService.update_all_rates
      Rails.logger.info "[UpdateExchangeRatesJob] Updated rates for #{count} websites"
    end
  end
end
