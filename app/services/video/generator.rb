# frozen_string_literal: true

module Video
  # Orchestrates the full listing video generation workflow.
  #
  # This service coordinates:
  # 1. Validating inputs (property, photos, options)
  # 2. Creating the ListingVideo record
  # 3. Enqueuing the background generation job
  #
  # The actual generation happens asynchronously in GenerateListingVideoJob.
  #
  # Usage:
  #   result = Video::Generator.new(
  #     property: realty_asset,
  #     website: website,
  #     user: current_user,
  #     options: {
  #       format: :vertical_9_16,
  #       style: :professional,
  #       voice: :nova
  #     }
  #   ).generate
  #
  #   if result.success?
  #     video = result.video  # ListingVideo record
  #   else
  #     error = result.error
  #   end
  #
  class Generator
    Result = Struct.new(:success, :video, :error, keyword_init: true) do
      def success?
        success
      end
    end

    FORMATS = %i[vertical_9_16 horizontal_16_9 square_1_1].freeze
    STYLES = %i[professional luxury casual energetic minimal].freeze
    VOICES = %i[alloy echo fable onyx nova shimmer].freeze

    DEFAULT_OPTIONS = {
      format: :vertical_9_16,
      style: :professional,
      voice: :nova,
      include_price: true,
      include_address: true,
      music_enabled: true,
      max_photos: 10,
      duration_target: 60
    }.freeze

    MIN_PHOTOS_REQUIRED = 3

    def initialize(property:, website:, user: nil, options: {})
      @property = property
      @website = website
      @user = user
      @options = DEFAULT_OPTIONS.merge(options.symbolize_keys)
    end

    def generate
      # Validate inputs
      validation_error = validate_inputs
      return Result.new(success: false, error: validation_error) if validation_error

      # Create video record
      video = create_video_record

      # Enqueue generation job
      enqueue_generation_job(video)

      Result.new(success: true, video: video)
    rescue StandardError => e
      Rails.logger.error "[Video::Generator] Error: #{e.message}"
      Result.new(success: false, error: e.message)
    end

    private

    attr_reader :property, :website, :user, :options

    def validate_inputs
      return "Property is required" unless property.present?
      return "Website is required" unless website.present?
      return "Property has no photos" unless property.prop_photos.any?
      return "At least #{MIN_PHOTOS_REQUIRED} photos required" if property.prop_photos.count < MIN_PHOTOS_REQUIRED
      return "Invalid format: #{options[:format]}" unless FORMATS.include?(options[:format])
      return "Invalid style: #{options[:style]}" unless STYLES.include?(options[:style])
      return "Invalid voice: #{options[:voice]}" unless VOICES.include?(options[:voice])

      nil
    end

    def create_video_record
      Pwb::ListingVideo.create!(
        website: website,
        realty_asset: property,
        user: user,
        title: generate_title,
        status: 'pending',
        format: options[:format].to_s,
        style: options[:style].to_s,
        voice: options[:voice].to_s,
        branding: build_branding
      )
    end

    def generate_title
      address = property.street_address.presence || property.city.presence || 'Property'
      "Video for #{address}"
    end

    def build_branding
      agency = website.agency

      {
        logo_url: website.main_logo_url,
        company_name: agency&.display_name || website.company_display_name,
        agent_name: user&.display_name,
        agent_phone: agency&.phone_number_primary,
        primary_color: website.primary_color || '#2563eb'
      }.compact
    end

    def enqueue_generation_job(video)
      GenerateListingVideoJob.perform_later(
        video_id: video.id,
        website_id: website.id
      )
    end
  end
end
