# frozen_string_literal: true

# Health check controller for monitoring and load balancer health probes
# Provides endpoints for basic liveness checks and detailed readiness checks
class HealthController < ActionController::API
  # Skip any authentication/authorization for health checks
  skip_before_action :verify_authenticity_token, raise: false

  # Restrict detailed health info to authorized requests
  before_action :authorize_detailed_access!, only: [:details]

  # GET /health or /health/live
  # Basic liveness check - returns 200 if the app is running
  # Used by load balancers and container orchestration for basic health
  def live
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601
    }, status: :ok
  end

  # GET /health/ready
  # Readiness check - verifies the app can handle requests
  # Checks database connectivity and other critical dependencies
  # Note: Error details are hidden from public; only status shown
  def ready
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage
    }

    all_healthy = checks.values.all? { |check| check[:status] == 'ok' }
    status_code = all_healthy ? :ok : :service_unavailable

    # Sanitize checks for public response - only show status, not error details
    sanitized_checks = checks.transform_values do |check|
      { status: check[:status] }
    end

    render json: {
      status: all_healthy ? 'ok' : 'degraded',
      timestamp: Time.current.iso8601,
      checks: sanitized_checks
    }, status: status_code
  end

  # GET /health/details
  # Detailed health check with more system information
  # Should be protected in production (via IP allowlist or auth)
  def details
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: app_version,
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      checks: {
        database: check_database,
        redis: check_redis,
        storage: check_storage
      },
      system: {
        hostname: Socket.gethostname,
        pid: Process.pid,
        memory_mb: memory_usage_mb,
        uptime_seconds: uptime_seconds
      }
    }, status: :ok
  end

  private

  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      status: 'ok',
      response_time_ms: response_time,
      adapter: ActiveRecord::Base.connection.adapter_name
    }
  rescue StandardError => e
    Rails.logger.error("[HealthCheck] Database check failed: #{e.message}")
    {
      status: 'error',
      error: e.message
    }
  end

  def check_redis
    return { status: 'skipped', message: 'Redis not configured' } unless redis_configured?

    start_time = Time.current
    redis_client.ping
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      status: 'ok',
      response_time_ms: response_time
    }
  rescue StandardError => e
    Rails.logger.error("[HealthCheck] Redis check failed: #{e.message}")
    {
      status: 'error',
      error: e.message
    }
  end

  def check_storage
    # Check if ActiveStorage is configured and working
    return { status: 'skipped', message: 'ActiveStorage not configured' } unless active_storage_configured?

    {
      status: 'ok',
      service: ActiveStorage::Blob.service.class.name
    }
  rescue StandardError => e
    Rails.logger.error("[HealthCheck] Storage check failed: #{e.message}")
    {
      status: 'error',
      error: e.message
    }
  end

  def redis_configured?
    defined?(Redis) && ENV['REDIS_URL'].present?
  end

  def redis_client
    @redis_client ||= Redis.new(url: ENV['REDIS_URL'])
  end

  def active_storage_configured?
    defined?(ActiveStorage) && ActiveStorage::Blob.service.present?
  rescue StandardError
    false
  end

  def app_version
    # Try to get version from various sources
    ENV['APP_VERSION'] ||
      ENV['GIT_COMMIT'] ||
      git_revision ||
      'unknown'
  end

  def git_revision
    revision_file = Rails.root.join('REVISION')
    return File.read(revision_file).strip if File.exist?(revision_file)

    # Try to get from git directly in development
    `git rev-parse --short HEAD 2>/dev/null`.strip.presence
  rescue StandardError
    nil
  end

  def memory_usage_mb
    # Get memory usage on Linux/macOS
    if File.exist?('/proc/self/status')
      # Linux
      File.read('/proc/self/status').match(/VmRSS:\s+(\d+)/)[1].to_i / 1024
    else
      # macOS fallback
      `ps -o rss= -p #{Process.pid}`.to_i / 1024
    end
  rescue StandardError
    nil
  end

  def uptime_seconds
    # Calculate process uptime
    if defined?(Process::CLOCK_MONOTONIC)
      Process.clock_gettime(Process::CLOCK_MONOTONIC).round
    end
  rescue StandardError
    nil
  end

  # Authorization for detailed health endpoint
  # Allows access via:
  # 1. Bearer token matching HEALTH_CHECK_TOKEN env var
  # 2. Request from allowed IP addresses (internal/monitoring)
  # 3. In development environment (for convenience)
  def authorize_detailed_access!
    return true if Rails.env.development? || Rails.env.test?
    return true if valid_health_token?
    return true if allowed_ip?

    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def valid_health_token?
    token = ENV['HEALTH_CHECK_TOKEN']
    return false if token.blank?

    auth_header = request.headers['Authorization']
    return false if auth_header.blank?

    # Support "Bearer <token>" format
    provided_token = auth_header.sub(/^Bearer\s+/i, '')
    ActiveSupport::SecurityUtils.secure_compare(provided_token, token)
  end

  def allowed_ip?
    allowed_ips = ENV.fetch('HEALTH_CHECK_ALLOWED_IPS', '127.0.0.1,::1').split(',').map(&:strip)
    allowed_ips.include?(request.remote_ip)
  end
end
