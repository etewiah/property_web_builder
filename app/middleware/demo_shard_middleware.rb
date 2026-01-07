# frozen_string_literal: true

class DemoShardMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    subdomain = extract_subdomain(request)

    if demo_subdomain?(subdomain)
      PwbTenant::ApplicationRecord.connected_to(shard: :demo, role: :writing) do
        env['pwb.demo_shard'] = true
        @app.call(env)
      end
    else
      @app.call(env)
    end
  end

  private

  def extract_subdomain(request)
    request.subdomains.first&.downcase
  rescue StandardError
    nil
  end

  def demo_subdomain?(subdomain)
    return false if subdomain.blank?

    demo_subdomains.include?(subdomain)
  end

  def demo_subdomains
    @demo_subdomains ||= (defined?(DEMO_SUBDOMAINS) ? DEMO_SUBDOMAINS.keys : []).map(&:to_s)
  end
end
