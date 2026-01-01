# frozen_string_literal: true

module Pwb
  # Background job to download external images and attach them to PropPhotos.
  # This converts external_url references to ActiveStorage attachments,
  # allowing for variant generation and CDN caching.
  #
  # Usage:
  #   Pwb::DownloadScrapedImagesJob.perform_later(realty_asset_id)
  #   Pwb::DownloadScrapedImagesJob.perform_later(realty_asset_id, max_images: 10)
  #
  class DownloadScrapedImagesJob < ApplicationJob
    queue_as :default

    # Retry with exponential backoff for temporary failures
    retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
    retry_on OpenSSL::SSL::SSLError, wait: 30.seconds, attempts: 2

    # Don't retry on permanent failures
    discard_on ActiveRecord::RecordNotFound
    discard_on URI::InvalidURIError

    TIMEOUT = 30 # seconds per image
    MAX_FILE_SIZE = 20.megabytes
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/jpg image/png image/gif image/webp image/avif
    ].freeze

    # @param realty_asset_id [String] UUID of the RealtyAsset
    # @param max_images [Integer] Maximum number of images to download (default: 20)
    # @param replace_external [Boolean] Whether to clear external_url after download (default: true)
    def perform(realty_asset_id, max_images: 20, replace_external: true)
      @realty_asset = RealtyAsset.find(realty_asset_id)
      @replace_external = replace_external

      photos_to_process = @realty_asset.prop_photos
                                       .where.not(external_url: [nil, ""])
                                       .where.missing(:image_attachment)
                                       .limit(max_images)

      Rails.logger.info "[DownloadScrapedImages] Processing #{photos_to_process.count} images for asset #{realty_asset_id}"

      photos_to_process.each_with_index do |photo, index|
        download_and_attach(photo, index)
      end

      Rails.logger.info "[DownloadScrapedImages] Completed for asset #{realty_asset_id}"
    end

    private

    def download_and_attach(photo, index)
      url = photo.external_url
      return if url.blank?

      Rails.logger.info "[DownloadScrapedImages] Downloading image #{index + 1}: #{url.truncate(100)}"

      response = fetch_image(url)
      return unless response

      content_type = response.content_type&.split(";")&.first
      unless valid_content_type?(content_type)
        Rails.logger.warn "[DownloadScrapedImages] Invalid content type: #{content_type} for #{url.truncate(100)}"
        return
      end

      if response.body.bytesize > MAX_FILE_SIZE
        Rails.logger.warn "[DownloadScrapedImages] File too large: #{response.body.bytesize} bytes"
        return
      end

      filename = generate_filename(url, content_type)

      photo.image.attach(
        io: StringIO.new(response.body),
        filename: filename,
        content_type: content_type
      )

      # Clear external_url after successful attachment if requested
      if @replace_external && photo.image.attached?
        photo.update!(external_url: nil)
        Rails.logger.info "[DownloadScrapedImages] Attached and cleared external_url for photo #{photo.id}"
      end
    rescue StandardError => e
      Rails.logger.error "[DownloadScrapedImages] Failed to download #{url.truncate(100)}: #{e.message}"
      # Continue with other images
    end

    def fetch_image(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; PropertyWebBuilder/1.0)"
      request["Accept"] = "image/*"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        # Follow one redirect
        redirect_url = response["location"]
        redirect_url = URI.join(url, redirect_url).to_s unless redirect_url.start_with?("http")
        fetch_image(redirect_url)
      else
        Rails.logger.warn "[DownloadScrapedImages] HTTP #{response.code} for #{url.truncate(100)}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[DownloadScrapedImages] Fetch error: #{e.message}"
      nil
    end

    def valid_content_type?(content_type)
      return false if content_type.blank?

      ALLOWED_CONTENT_TYPES.include?(content_type.downcase)
    end

    def generate_filename(url, content_type)
      # Try to get filename from URL
      uri = URI.parse(url)
      path = uri.path
      basename = File.basename(path)

      if basename.present? && basename.include?(".")
        basename.gsub(/[^\w.\-]/, "_")
      else
        # Generate filename from content type
        extension = Rack::Mime::MIME_TYPES.invert[content_type] || ".jpg"
        extension = ".jpg" if extension == ".jpeg"
        "property_image_#{SecureRandom.hex(4)}#{extension}"
      end
    end
  end
end
