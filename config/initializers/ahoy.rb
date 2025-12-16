# frozen_string_literal: true

# Ahoy configuration for multi-tenant analytics
# Each website (tenant) gets isolated analytics data

class Ahoy::Store < Ahoy::DatabaseStore
  # Inject website_id from current tenant into visits
  def track_visit(data)
    data[:website_id] = Pwb::Current.website&.id
    super(data)
  end

  # Inject website_id from current tenant into events
  def track_event(data)
    data[:website_id] = Pwb::Current.website&.id
    super(data)
  end

  # Exclude admin/site_admin paths from tracking
  def exclude?
    return true unless Pwb::Current.website.present?
    return true if bot?

    # Don't track admin areas
    request_path = request.path.to_s
    return true if request_path.start_with?("/site_admin")
    return true if request_path.start_with?("/admin")
    return true if request_path.start_with?("/rails/")

    false
  end
end

# API-based tracking (works with Turbo/SPA)
Ahoy.api = true

# Use cookies for visitor tracking (or :none for cookie-less)
# Cookie-less is more privacy-friendly but less accurate for returning visitors
Ahoy.cookies = true

# Mask IP addresses for privacy (mask last octet)
Ahoy.mask_ips = true

# Geocoding for visitor location
# Set to false to disable, :async for background processing
Ahoy.geocode = false # Enable later: :async

# Visit duration (how long before a new visit is created)
Ahoy.visit_duration = 4.hours

# Server-side bot detection
Ahoy.server_side_visits = :when_needed

# Track bots? (default: false)
Ahoy.track_bots = false

# Custom user agent parser (optional)
# Ahoy.user_agent_parser = :device_detector
