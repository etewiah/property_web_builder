# frozen_string_literal: true

module Pwb
  # Mailer for sending property search alerts to users.
  # Triggered when new properties match a user's saved search criteria.
  class SearchAlertMailer < ApplicationMailer
    # Callback to mark alert as sent after successful delivery
    after_deliver :mark_alert_delivered

    # Handle delivery errors gracefully
    rescue_from StandardError, with: :handle_delivery_error

    # Send an email alert for new properties matching a saved search
    #
    # @param saved_search [Pwb::SavedSearch] The saved search that triggered the alert
    # @param alert [Pwb::SearchAlert] The alert record tracking this notification
    # @param new_properties [Array<NormalizedProperty>] New properties to show
    #
    def new_properties_alert(saved_search:, alert:, new_properties:)
      @saved_search = saved_search
      @alert = alert
      @new_properties = new_properties
      @website = saved_search.website
      @host = website_host

      @manage_url = @saved_search.manage_url(host: @host)
      @unsubscribe_url = @saved_search.unsubscribe_url(host: @host)

      subject = build_subject(new_properties.size)

      mail(
        to: saved_search.email,
        subject: subject,
        reply_to: @website.admin_email
      )
    end

    private

    def build_subject(count)
      search_name = @saved_search.name.presence || "Property Search"
      property_word = count == 1 ? "property" : "properties"
      "#{count} new #{property_word} matching: #{search_name}"
    end

    def website_host
      # Build the host URL for links in the email
      subdomain = @website.subdomain
      domain = @website.custom_domain.presence || ENV.fetch("APP_DOMAIN", "localhost:3000")

      if @website.custom_domain.present?
        "https://#{domain}"
      elsif subdomain.present?
        protocol = Rails.env.production? ? "https" : "http"
        "#{protocol}://#{subdomain}.#{domain}"
      else
        "http://#{domain}"
      end
    end

    def mark_alert_delivered
      @alert&.mark_delivered!
    rescue StandardError => e
      Rails.logger.error "[SearchAlertMailer] Failed to mark alert delivered: #{e.message}"
    end

    def handle_delivery_error(exception)
      Rails.logger.error "[SearchAlertMailer] Delivery failed: #{exception.message}"
      @alert&.mark_failed!(exception.message)
      raise exception # Re-raise to trigger job retry
    end
  end
end
