# frozen_string_literal: true

# HttpCacheable provides HTTP caching via ETags and Cache-Control headers
#
# This enables browsers and CDNs to cache responses and use conditional
# GET requests to avoid re-rendering unchanged content.
#
# Usage in controllers:
#   class PropsController < ApplicationController
#     include HttpCacheable
#
#     def show
#       @property = Property.find(params[:id])
#       return if fresh_response?(@property)
#       # ... render logic
#     end
#   end
#
module HttpCacheable
  extend ActiveSupport::Concern

  included do
    # Add ETag support
    etag { current_website&.id }
    etag { I18n.locale }
  end

  # Check if the response is fresh (client has valid cached version)
  # Returns true if we sent a 304 Not Modified response
  def fresh_response?(record_or_options, options = {})
    if record_or_options.is_a?(Hash)
      options = record_or_options
    else
      record = record_or_options
      options[:etag] ||= cache_key_for_record(record)
      options[:last_modified] ||= record.try(:updated_at)
    end

    # Set cache control headers
    set_cache_control_headers(options)

    # Use Rails' fresh_when for conditional GET
    if options[:etag] || options[:last_modified]
      fresh_when(
        etag: options[:etag],
        last_modified: options[:last_modified],
        public: options.fetch(:public, false),
        template: options[:template]
      )
    else
      false
    end
  end

  # Set Cache-Control headers for the response
  def set_cache_control_headers(options = {})
    max_age = options.fetch(:max_age, 5.minutes)
    public_cache = options.fetch(:public, false)
    stale_while_revalidate = options.fetch(:stale_while_revalidate, 1.hour)

    cache_control = []
    cache_control << (public_cache ? "public" : "private")
    cache_control << "max-age=#{max_age.to_i}"
    cache_control << "stale-while-revalidate=#{stale_while_revalidate.to_i}"

    response.headers["Cache-Control"] = cache_control.join(", ")
  end

  # Expire cache for a specific resource
  def expire_cache_for(record)
    key = cache_key_for_record(record)
    Rails.cache.delete(key) if key
  end

  private

  def cache_key_for_record(record)
    return nil unless record

    parts = [
      current_website&.id || "global",
      I18n.locale,
      record.class.name.underscore,
      record.try(:id),
      record.try(:updated_at)&.to_i
    ].compact

    parts.join("/")
  end

  def current_website
    return @current_website if defined?(@current_website)
    @current_website = Pwb::Current.website rescue nil
  end
end
