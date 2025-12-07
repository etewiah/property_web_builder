# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and brute force protection
#
# This protects authentication endpoints from abuse:
# - Login attempts (brute force password guessing)
# - Password reset requests (email enumeration/spam)
# - Account registration (spam accounts)
#
# Rate limits are more lenient in development/test environments.

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache for rate limiting storage
  # In production, this should be backed by Redis for multi-server deployments
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Safelist trusted clients ###
  # Safelist all requests from localhost in development/test
  safelist('allow-localhost') do |req|
    Rails.env.local? && (req.ip == '127.0.0.1' || req.ip == '::1')
  end

  ### Throttle Strategies ###

  # Throttle login attempts by IP address
  # Limit: 5 requests per 20 seconds per IP
  # This prevents rapid brute-force attempts from a single source
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email address
  # Limit: 5 requests per 60 seconds per email
  # This prevents distributed attacks targeting a single account
  throttle('logins/email', limit: 5, period: 60.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      # Normalize email to lowercase for consistent tracking
      req.params.dig('user', 'email')&.to_s&.downcase&.gsub(/\s+/, '')
    end
  end

  # Throttle password reset requests by IP
  # Limit: 3 requests per 60 seconds per IP
  # Prevents email enumeration and spam
  throttle('password_reset/ip', limit: 3, period: 60.seconds) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end

  # Throttle password reset by email
  # Limit: 3 requests per 5 minutes per email
  # Prevents spamming a specific email address
  throttle('password_reset/email', limit: 3, period: 5.minutes) do |req|
    if req.path == '/users/password' && req.post?
      req.params.dig('user', 'email')&.to_s&.downcase&.gsub(/\s+/, '')
    end
  end

  # Throttle account registration by IP
  # Limit: 3 registrations per hour per IP
  # Prevents spam account creation
  throttle('registrations/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # Throttle unlock account requests
  # Limit: 3 requests per 60 seconds per IP
  throttle('unlock/ip', limit: 3, period: 60.seconds) do |req|
    if req.path == '/users/unlock' && req.post?
      req.ip
    end
  end

  # Throttle confirmation resend requests
  # Limit: 3 requests per 60 seconds per IP
  throttle('confirmation/ip', limit: 3, period: 60.seconds) do |req|
    if req.path == '/users/confirmation' && req.post?
      req.ip
    end
  end

  ### Exponential Backoff for Repeated Failures ###

  # Track failed login attempts and apply exponential backoff
  # After 5 failed attempts, block for increasing durations
  # This is more aggressive than simple throttling for persistent attackers

  # Block IPs with excessive failed login attempts
  # Blocklist for 1 hour after 20 failed attempts in 1 hour
  blocklist('fail2ban/login') do |req|
    # `filter` returns false if the request is allowed, or a truthy value if blocked
    Rack::Attack::Fail2Ban.filter("login-#{req.ip}", maxretry: 20, findtime: 1.hour, bantime: 1.hour) do
      # Count failed login attempts
      # This is triggered when the response is a redirect back to login (failed attempt)
      req.path == '/users/sign_in' && req.post?
    end
  end

  ### Custom Responses ###

  # Return a 429 Too Many Requests with retry information
  self.throttled_responder = lambda do |req|
    match_data = req.env['rack.attack.match_data']
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    headers = {
      'Content-Type' => 'text/html',
      'Retry-After' => retry_after.to_s
    }

    # Different messages based on what was throttled
    if req.env['rack.attack.matched'] =~ /login/
      body = <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Too Many Login Attempts</title></head>
        <body>
          <h1>Too Many Login Attempts</h1>
          <p>You have made too many login attempts. Please wait #{retry_after} seconds before trying again.</p>
          <p>If you've forgotten your password, please use the <a href="/users/password/new">password reset</a> feature.</p>
        </body>
        </html>
      HTML
    else
      body = <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Rate Limit Exceeded</title></head>
        <body>
          <h1>Rate Limit Exceeded</h1>
          <p>You have made too many requests. Please wait #{retry_after} seconds before trying again.</p>
        </body>
        </html>
      HTML
    end

    [429, headers, [body]]
  end

  # Custom response for blocklisted IPs
  self.blocklisted_responder = lambda do |req|
    headers = { 'Content-Type' => 'text/html' }
    body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Access Temporarily Blocked</title></head>
      <body>
        <h1>Access Temporarily Blocked</h1>
        <p>Your IP address has been temporarily blocked due to suspicious activity.</p>
        <p>Please try again later or contact support if you believe this is an error.</p>
      </body>
      </html>
    HTML

    [403, headers, [body]]
  end

  ### Logging ###

  # Log throttled and blocked requests for monitoring
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled #{req.env['rack.attack.matched']} " \
      "from #{req.ip} to #{req.path}"
    )
  end

  ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Blocked #{req.env['rack.attack.matched']} " \
      "from #{req.ip} to #{req.path}"
    )
  end
end

# Enable Rack::Attack middleware
Rails.application.config.middleware.use Rack::Attack
