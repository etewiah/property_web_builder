# frozen_string_literal: true

module Pwb
  # Background job to execute a saved search and send email alerts
  # for new properties that match the search criteria.
  #
  # Usage:
  #   Pwb::SearchAlertJob.perform_later(saved_search.id)
  #
  class SearchAlertJob < ApplicationJob
    include TenantAwareJob

    queue_as :search_alerts

    # Don't retry too many times for search alerts
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(saved_search_id)
      saved_search = Pwb::SavedSearch.find_by(id: saved_search_id)

      unless saved_search
        Rails.logger.warn "[SearchAlertJob] SavedSearch not found: #{saved_search_id}"
        return
      end

      unless saved_search.enabled?
        Rails.logger.info "[SearchAlertJob] SavedSearch #{saved_search_id} is disabled, skipping"
        return
      end

      with_tenant(saved_search.website_id) do
        execute_search_alert(saved_search)
      end
    end

    private

    def execute_search_alert(saved_search)
      website = saved_search.website

      unless website.external_feed_enabled?
        Rails.logger.info "[SearchAlertJob] External feed not enabled for website #{website.id}"
        return
      end

      feed = website.external_feed

      unless feed.configured?
        Rails.logger.warn "[SearchAlertJob] External feed not configured for website #{website.id}"
        return
      end

      # Execute the search
      search_params = saved_search.search_criteria_hash.merge(
        page: 1,
        per_page: 50 # Get a reasonable number of results
      )

      result = feed.search(search_params)

      if result.error?
        Rails.logger.error "[SearchAlertJob] Search failed: #{result.error}"
        return
      end

      # Find new properties
      current_refs = result.properties.map(&:reference)
      new_refs = saved_search.find_new_properties(current_refs)

      Rails.logger.info "[SearchAlertJob] Search #{saved_search.id}: #{result.total_count} total, " \
                        "#{current_refs.size} in page, #{new_refs.size} new"

      # Update tracking regardless of new properties
      saved_search.mark_run!(result_count: result.total_count)

      # If there are new properties, create alert and send email
      if new_refs.any?
        new_properties = result.properties.select { |p| new_refs.include?(p.reference) }
        create_and_send_alert(saved_search, new_properties, result.total_count)
        saved_search.record_new_properties!(new_refs)
      end
    end

    def create_and_send_alert(saved_search, new_properties, total_count)
      # Store property data as hashes for persistence
      property_data = new_properties.map(&:to_h)

      alert = saved_search.alerts.create!(
        new_properties: property_data,
        properties_count: new_properties.size,
        total_results_count: total_count,
        email_status: "pending"
      )

      # Send the email
      begin
        Pwb::SearchAlertMailer.new_properties_alert(
          saved_search: saved_search,
          alert: alert,
          new_properties: new_properties
        ).deliver_later

        alert.mark_sent!
        Rails.logger.info "[SearchAlertJob] Alert #{alert.id} sent for search #{saved_search.id}"
      rescue StandardError => e
        alert.mark_failed!(e.message)
        Rails.logger.error "[SearchAlertJob] Failed to send alert #{alert.id}: #{e.message}"
        raise # Re-raise to trigger job retry
      end
    end
  end
end
