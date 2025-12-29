# frozen_string_literal: true

require "active_storage/service/s3_service"

# Custom R2 service that uses a public CDN domain for URLs
# while still using the R2 API endpoint for uploads/deletes
#
# Configuration options:
#   public_url: CDN domain for public URLs (e.g., "https://cdn.example.com")
#   use_cdn: Set to false to force signed S3 URLs instead of CDN (default: true)
#
# Environment variable override:
#   R2_USE_CDN=false - Disables CDN URLs, uses signed S3 URLs instead
#
class ActiveStorage::Service::R2Service < ActiveStorage::Service::S3Service
  def initialize(public_url: nil, use_cdn: true, **config)
    @public_url = public_url
    @use_cdn = use_cdn && ENV.fetch("R2_USE_CDN", "true") != "false"
    super(**config)
  end

  # Override URL generation to use custom public domain
  def url(key, expires_in:, filename:, disposition:, content_type:)
    if cdn_enabled? && @public_url.present? && public?
      # Use custom CDN domain for public URLs
      "#{@public_url.chomp('/')}/#{key}"
    else
      # Fall back to signed S3 URLs (works without CDN)
      super
    end
  end

  private

  def public?
    @public
  end

  def cdn_enabled?
    @use_cdn
  end
end
