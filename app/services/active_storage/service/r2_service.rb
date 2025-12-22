# frozen_string_literal: true

require "active_storage/service/s3_service"

# Custom R2 service that uses a public CDN domain for URLs
# while still using the R2 API endpoint for uploads/deletes
class ActiveStorage::Service::R2Service < ActiveStorage::Service::S3Service
  def initialize(public_url: nil, **config)
    @public_url = public_url
    super(**config)
  end

  # Override URL generation to use custom public domain
  def url(key, expires_in:, filename:, disposition:, content_type:)
    if @public_url.present? && public?
      # Use custom CDN domain for public URLs
      "#{@public_url.chomp('/')}/#{key}"
    else
      super
    end
  end

  private

  def public?
    @public
  end
end
