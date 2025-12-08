# frozen_string_literal: true

# Service for sending push notifications via ntfy.sh
#
# ntfy.sh is a simple HTTP-based pub-sub notification service.
# Each website can configure their own ntfy settings including:
# - Custom server URL (for self-hosted instances)
# - Topic prefix for tenant isolation
# - Access token for authenticated topics
# - Channel toggles for different notification types
#
# Usage:
#   NtfyService.notify_inquiry(website, message)
#   NtfyService.notify_listing_change(website, listing, action)
#   NtfyService.notify_security_event(website, event_type, details)
#
class NtfyService
  # Notification channels
  CHANNEL_INQUIRIES = 'inquiries'
  CHANNEL_LISTINGS = 'listings'
  CHANNEL_USERS = 'users'
  CHANNEL_SECURITY = 'security'
  CHANNEL_ADMIN = 'admin'

  # Priority levels (ntfy uses 1-5, with 3 as default)
  PRIORITY_MIN = 1
  PRIORITY_LOW = 2
  PRIORITY_DEFAULT = 3
  PRIORITY_HIGH = 4
  PRIORITY_URGENT = 5

  class << self
    include Rails.application.routes.url_helpers

    # Send a notification for a new inquiry/contact form submission
    #
    # @param website [Pwb::Website] The website receiving the inquiry
    # @param message [Pwb::Message] The message/inquiry record
    def notify_inquiry(website, message)
      return unless enabled_for?(website, :inquiries)

      publish(
        website: website,
        channel: CHANNEL_INQUIRIES,
        title: "New Inquiry: #{message.title.presence || 'Property Inquiry'}",
        message: build_inquiry_message(message),
        priority: PRIORITY_HIGH,
        tags: ['house', 'incoming_envelope'],
        click_url: site_admin_message_url(message, host: website_host(website))
      )
    end

    # Send a notification when a property listing changes status
    #
    # @param website [Pwb::Website] The website
    # @param listing [Pwb::SaleListing, Pwb::RentalListing] The listing
    # @param action [Symbol] :published, :archived, :sold, :rented, :price_changed
    def notify_listing_change(website, listing, action)
      return unless enabled_for?(website, :listings)

      title, message, tags = listing_change_content(listing, action)

      publish(
        website: website,
        channel: CHANNEL_LISTINGS,
        title: title,
        message: message,
        priority: action == :published ? PRIORITY_HIGH : PRIORITY_DEFAULT,
        tags: tags,
        click_url: site_admin_prop_url(listing.realty_asset, host: website_host(website))
      )
    end

    # Send a notification for user-related events
    #
    # @param website [Pwb::Website] The website
    # @param user [Pwb::User] The user
    # @param event [Symbol] :registered, :activated, :deactivated
    def notify_user_event(website, user, event)
      return unless enabled_for?(website, :users)

      title, message, tags = user_event_content(user, event)

      publish(
        website: website,
        channel: CHANNEL_USERS,
        title: title,
        message: message,
        priority: PRIORITY_DEFAULT,
        tags: tags,
        click_url: site_admin_users_url(host: website_host(website))
      )
    end

    # Send a notification for security events
    #
    # @param website [Pwb::Website] The website
    # @param event_type [String] Type from AuthAuditLog (e.g., 'login_failed', 'account_locked')
    # @param details [Hash] Event details
    def notify_security_event(website, event_type, details = {})
      return unless enabled_for?(website, :security)

      title, message, priority, tags = security_event_content(event_type, details)

      publish(
        website: website,
        channel: CHANNEL_SECURITY,
        title: title,
        message: message,
        priority: priority,
        tags: tags
      )
    end

    # Send a generic admin notification
    #
    # @param website [Pwb::Website] The website
    # @param title [String] Notification title
    # @param message [String] Notification body
    # @param options [Hash] Additional options (priority, tags, click_url)
    def notify_admin(website, title, message, options = {})
      return unless website&.ntfy_enabled?

      publish(
        website: website,
        channel: CHANNEL_ADMIN,
        title: title,
        message: message,
        priority: options[:priority] || PRIORITY_DEFAULT,
        tags: options[:tags] || ['bell'],
        click_url: options[:click_url]
      )
    end

    # Low-level publish method for sending notifications
    #
    # @param website [Pwb::Website] The website
    # @param channel [String] The notification channel
    # @param title [String] Notification title
    # @param message [String] Notification body
    # @param priority [Integer] Priority level (1-5)
    # @param tags [Array<String>] Emoji tags
    # @param click_url [String] URL to open when notification is clicked
    # @param actions [Array<Hash>] Action buttons
    def publish(website:, channel:, message:, title: nil, priority: PRIORITY_DEFAULT, tags: [], click_url: nil, actions: nil)
      return false unless website&.ntfy_enabled?
      return false if message.blank?

      topic = build_topic(website, channel)
      server_url = website.ntfy_server_url.presence || 'https://ntfy.sh'

      headers = build_headers(
        title: title,
        priority: priority,
        tags: tags,
        click_url: click_url,
        actions: actions,
        access_token: website.ntfy_access_token
      )

      perform_request(server_url, topic, message, headers)
    end

    # Test the ntfy configuration by sending a test notification
    #
    # @param website [Pwb::Website] The website to test
    # @return [Hash] Result with :success and :message keys
    def test_configuration(website)
      return { success: false, message: 'ntfy is not enabled' } unless website&.ntfy_enabled?
      return { success: false, message: 'Topic prefix is required' } if website.ntfy_topic_prefix.blank?

      result = publish(
        website: website,
        channel: 'test',
        title: 'Test Notification',
        message: "This is a test from #{website.company_display_name || website.subdomain}",
        priority: PRIORITY_DEFAULT,
        tags: ['white_check_mark', 'test_tube']
      )

      if result
        { success: true, message: 'Test notification sent successfully' }
      else
        { success: false, message: 'Failed to send test notification' }
      end
    end

    private

    def enabled_for?(website, channel)
      return false unless website&.ntfy_enabled?
      return false if website.ntfy_topic_prefix.blank?

      case channel
      when :inquiries then website.ntfy_notify_inquiries?
      when :listings then website.ntfy_notify_listings?
      when :users then website.ntfy_notify_users?
      when :security then website.ntfy_notify_security?
      else true
      end
    end

    def build_topic(website, channel)
      prefix = website.ntfy_topic_prefix.presence || "pwb-#{website.id}"
      "#{prefix}-#{channel}"
    end

    def build_headers(title:, priority:, tags:, click_url:, actions:, access_token:)
      headers = {
        'Content-Type' => 'text/plain; charset=utf-8'
      }

      headers['Title'] = title if title.present?
      headers['Priority'] = priority.to_s if priority != PRIORITY_DEFAULT
      headers['Tags'] = tags.join(',') if tags.present?
      headers['Click'] = click_url if click_url.present?
      headers['Actions'] = format_actions(actions) if actions.present?
      headers['Authorization'] = "Bearer #{access_token}" if access_token.present?

      headers
    end

    def format_actions(actions)
      return nil if actions.blank?

      actions.map do |action|
        parts = ["action=#{action[:type]}", "label=#{action[:label]}"]
        parts << "url=#{action[:url]}" if action[:url]
        parts << "method=#{action[:method]}" if action[:method]
        parts.join(', ')
      end.join('; ')
    end

    def perform_request(server_url, topic, message, headers)
      uri = URI.parse("#{server_url}/#{topic}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = message.to_s.encode('UTF-8')

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        Rails.logger.info("[NtfyService] Notification sent to #{topic}")
        true
      else
        Rails.logger.error("[NtfyService] Failed to send notification: #{response.code} #{response.message}")
        false
      end
    rescue StandardError => e
      Rails.logger.error("[NtfyService] Error sending notification: #{e.message}")
      false
    end

    def build_inquiry_message(message)
      parts = []
      # Message has a contact association with name/email/phone
      if message.contact.present?
        parts << "From: #{message.contact.first_name}" if message.contact.first_name.present?
        parts << "Email: #{message.contact.primary_email}" if message.contact.primary_email.present?
        parts << "Phone: #{message.contact.primary_phone_number}" if message.contact.primary_phone_number.present?
      end
      parts << ""
      parts << message.content.to_s.truncate(200) if message.content.present?
      parts.join("\n")
    end

    def listing_change_content(listing, action)
      property = listing.realty_asset
      property_name = property.title.presence || property.reference || "Property ##{property.id}"
      listing_type = listing.is_a?(Pwb::SaleListing) ? 'Sale' : 'Rental'

      case action
      when :published
        [
          "#{listing_type} Listing Published",
          "#{property_name} is now live",
          ['house', 'white_check_mark']
        ]
      when :archived
        [
          "#{listing_type} Listing Archived",
          "#{property_name} has been archived",
          ['house', 'file_folder']
        ]
      when :sold
        [
          "Property Sold!",
          "#{property_name} has been marked as sold",
          ['house', 'moneybag', 'tada']
        ]
      when :rented
        [
          "Property Rented!",
          "#{property_name} has been rented",
          ['house', 'key', 'tada']
        ]
      when :price_changed
        [
          "Price Updated",
          "#{property_name} price has been changed",
          ['house', 'chart_with_upwards_trend']
        ]
      else
        [
          "Listing Updated",
          "#{property_name} has been updated",
          ['house']
        ]
      end
    end

    def user_event_content(user, event)
      user_name = [user.first_names, user.last_names].compact.join(' ').presence || user.email

      case event
      when :registered
        [
          "New User Registration",
          "#{user_name} has registered",
          ['bust_in_silhouette', 'wave']
        ]
      when :activated
        [
          "User Activated",
          "#{user_name} account has been activated",
          ['bust_in_silhouette', 'white_check_mark']
        ]
      when :deactivated
        [
          "User Deactivated",
          "#{user_name} account has been deactivated",
          ['bust_in_silhouette', 'no_entry']
        ]
      else
        [
          "User Update",
          "#{user_name} account has been updated",
          ['bust_in_silhouette']
        ]
      end
    end

    def security_event_content(event_type, details)
      case event_type.to_s
      when 'login_failed'
        [
          "Failed Login Attempt",
          "Failed login for #{details[:email] || 'unknown'} from #{details[:ip] || 'unknown IP'}",
          PRIORITY_HIGH,
          ['warning', 'lock']
        ]
      when 'account_locked'
        [
          "Account Locked",
          "Account #{details[:email] || 'unknown'} has been locked due to multiple failed attempts",
          PRIORITY_URGENT,
          ['rotating_light', 'lock']
        ]
      when 'password_reset_requested'
        [
          "Password Reset Requested",
          "Password reset requested for #{details[:email] || 'unknown'}",
          PRIORITY_DEFAULT,
          ['key', 'email']
        ]
      when 'suspicious_activity'
        [
          "Suspicious Activity Detected",
          details[:message] || "Unusual activity detected",
          PRIORITY_URGENT,
          ['rotating_light', 'warning']
        ]
      else
        [
          "Security Event",
          "Security event: #{event_type}",
          PRIORITY_DEFAULT,
          ['shield']
        ]
      end
    end

    def website_host(website)
      if website.custom_domain_active?
        website.custom_domain
      else
        "#{website.subdomain}.#{default_host}"
      end
    end

    def default_host
      ENV.fetch('PLATFORM_DOMAIN', 'propertywebbuilder.com')
    end

    def default_url_options
      { host: default_host }
    end
  end
end
