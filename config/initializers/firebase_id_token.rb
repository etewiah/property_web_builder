FirebaseIdToken.configure do |config|
  config.project_ids = [ENV['FIREBASE_PROJECT_ID']]
  
  # Only use Redis if it's available and connected
  # Otherwise, certificates will be fetched from Google on each verification
  if defined?(Redis)
    begin
      redis = Redis.new
      redis.ping # Test connection
      config.redis = redis
    rescue => e
      Rails.logger.warn "Redis not available for Firebase certificate caching: #{e.message}"
      # Will fall back to fetching certificates from Google each time
    end
  end
end

# Fetch certificates on initialization
# This prevents the "no certificates" error on first request
if ENV['FIREBASE_PROJECT_ID'].present?
  begin
    Rails.logger.info "Fetching Firebase certificates..."
    FirebaseIdToken::Certificates.request
    Rails.logger.info "Firebase certificates fetched successfully"
  rescue => e
    Rails.logger.warn "Could not fetch Firebase certificates on initialization: #{e.message}"
    Rails.logger.warn "Certificates will be fetched on first token verification"
  end
end
