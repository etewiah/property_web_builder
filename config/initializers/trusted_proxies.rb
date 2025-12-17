# frozen_string_literal: true

# Configure trusted proxies for correct client IP detection
#
# When running behind a reverse proxy (Nginx, Cloudflare, load balancer, Docker),
# the real client IP is passed via X-Forwarded-For header. Rails needs to know
# which proxies to trust to extract the correct IP.
#
# Without this, request.remote_ip returns the proxy's IP (often 127.0.0.1)
# instead of the actual client IP.

Rails.application.config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + [
  # Docker default bridge network
  IPAddr.new('172.16.0.0/12'),

  # Docker internal networks
  IPAddr.new('10.0.0.0/8'),

  # Localhost (for local reverse proxies)
  IPAddr.new('127.0.0.0/8'),

  # Private networks (common for cloud load balancers)
  IPAddr.new('192.168.0.0/16'),

  # Cloudflare IPv4 ranges (if using Cloudflare)
  # https://www.cloudflare.com/ips-v4
  IPAddr.new('173.245.48.0/20'),
  IPAddr.new('103.21.244.0/22'),
  IPAddr.new('103.22.200.0/22'),
  IPAddr.new('103.31.4.0/22'),
  IPAddr.new('141.101.64.0/18'),
  IPAddr.new('108.162.192.0/18'),
  IPAddr.new('190.93.240.0/20'),
  IPAddr.new('188.114.96.0/20'),
  IPAddr.new('197.234.240.0/22'),
  IPAddr.new('198.41.128.0/17'),
  IPAddr.new('162.158.0.0/15'),
  IPAddr.new('104.16.0.0/13'),
  IPAddr.new('104.24.0.0/14'),
  IPAddr.new('172.64.0.0/13'),
  IPAddr.new('131.0.72.0/22')
]
