# frozen_string_literal: true

module Video
  # Assembles the final video from photos, audio, and configuration.
  #
  # Uses external video rendering APIs (Shotstack by default) to create
  # professional videos with Ken Burns effects, transitions, captions,
  # and background music.
  #
  # Usage:
  #   result = Video::Assembler.new(
  #     photos: property.prop_photos.ordered,
  #     voiceover_url: "https://example.com/audio.mp3",
  #     scenes: [{ photo_index: 0, duration: 5, caption: "Welcome" }, ...],
  #     options: {
  #       format: :vertical_9_16,
  #       style: :professional,
  #       branding: { logo_url: "...", company_name: "..." }
  #     }
  #   ).assemble
  #
  #   result[:video_url]       # URL to the final video
  #   result[:thumbnail_url]   # URL to the thumbnail
  #   result[:duration_seconds]
  #   result[:cost_cents]
  #
  class Assembler
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class RenderError < Error; end
    class TimeoutError < Error; end

    # Video format configurations
    FORMATS = {
      vertical_9_16: { width: 1080, height: 1920, aspect_ratio: '9:16' },
      horizontal_16_9: { width: 1920, height: 1080, aspect_ratio: '16:9' },
      square_1_1: { width: 1080, height: 1080, aspect_ratio: '1:1' }
    }.freeze

    # Shotstack API endpoints
    SHOTSTACK_API_URL = 'https://api.shotstack.io/v1'.freeze
    SHOTSTACK_SANDBOX_URL = 'https://api.shotstack.io/stage'.freeze

    # Polling configuration
    RENDER_TIMEOUT_SECONDS = 300  # 5 minutes
    POLL_INTERVAL_SECONDS = 5

    # Cost per render (approximate)
    SHOTSTACK_COST_CENTS = 5

    DEFAULT_OPTIONS = {
      format: :vertical_9_16,
      style: :professional,
      music_enabled: true,
      music_volume: 0.2,
      branding: {}
    }.freeze

    def initialize(photos:, voiceover_url:, scenes:, options: {})
      @photos = photos
      @voiceover_url = voiceover_url
      @scenes = scenes
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def assemble
      validate_inputs!
      ensure_configured!

      # Build the template
      template = TemplateBuilder.new(
        photos: photos,
        voiceover_url: voiceover_url,
        scenes: scenes,
        options: options
      ).build

      # Submit render job
      render_response = submit_render(template)
      render_id = render_response['response']['id']

      # Poll for completion
      result = poll_for_completion(render_id)

      # Download and store the video
      video_url = download_and_store(result['url'], 'video.mp4', 'video/mp4')
      thumbnail_url = download_and_store(result['poster'], 'thumbnail.jpg', 'image/jpeg') if result['poster']

      {
        video_url: video_url,
        thumbnail_url: thumbnail_url,
        duration_seconds: calculate_duration,
        resolution: "#{format_config[:width]}x#{format_config[:height]}",
        file_size_bytes: result['file_size'],
        render_id: render_id,
        cost_cents: SHOTSTACK_COST_CENTS
      }
    end

    private

    attr_reader :photos, :voiceover_url, :scenes, :options

    def format_config
      FORMATS[options[:format].to_sym] || FORMATS[:vertical_9_16]
    end

    def validate_inputs!
      raise Error, "Photos are required" if photos.blank?
      raise Error, "Voiceover URL is required" if voiceover_url.blank?
      raise Error, "Scenes are required" if scenes.blank?
      raise Error, "Invalid format" unless FORMATS.key?(options[:format].to_sym)
    end

    def ensure_configured!
      return if shotstack_api_key.present?

      raise ConfigurationError, "Shotstack API key not configured. Add a Video integration in Settings > Integrations."
    end

    def shotstack_api_key
      @shotstack_api_key ||= begin
        if options[:website]
          integration = options[:website].integrations.find_by(category: 'video', provider: 'shotstack')
          integration&.credential(:api_key)
        end
      end || ENV['SHOTSTACK_API_KEY']
    end

    def shotstack_environment
      @shotstack_environment ||= begin
        if options[:website]
          integration = options[:website].integrations.find_by(category: 'video', provider: 'shotstack')
          integration&.setting(:environment)
        end
      end || ENV.fetch('SHOTSTACK_ENVIRONMENT', 'sandbox')
    end

    def api_base_url
      shotstack_environment == 'production' ? SHOTSTACK_API_URL : SHOTSTACK_SANDBOX_URL
    end

    def connection
      @connection ||= Faraday.new(url: api_base_url) do |f|
        f.request :json
        f.response :json
        f.response :raise_error
        f.headers['x-api-key'] = shotstack_api_key
      end
    end

    def submit_render(template)
      response = connection.post('/render', template)
      response.body
    rescue Faraday::Error => e
      raise RenderError, "Failed to submit render: #{e.message}"
    end

    def poll_for_completion(render_id)
      started_at = Time.current

      loop do
        if Time.current - started_at > RENDER_TIMEOUT_SECONDS
          raise TimeoutError, "Render timed out after #{RENDER_TIMEOUT_SECONDS} seconds"
        end

        status = check_render_status(render_id)

        case status['status']
        when 'done'
          return status
        when 'failed'
          raise RenderError, "Render failed: #{status['error']}"
        else
          # queued, fetching, rendering, saving
          sleep POLL_INTERVAL_SECONDS
        end
      end
    end

    def check_render_status(render_id)
      response = connection.get("/render/#{render_id}")
      response.body['response']
    rescue Faraday::Error => e
      raise RenderError, "Failed to check render status: #{e.message}"
    end

    def download_and_store(url, filename, content_type)
      return nil if url.blank?

      response = Faraday.get(url)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(response.body),
        filename: "#{SecureRandom.hex(8)}_#{filename}",
        content_type: content_type
      )

      Rails.application.routes.url_helpers.rails_blob_url(blob)
    rescue Faraday::Error => e
      Rails.logger.error "[Video::Assembler] Failed to download #{url}: #{e.message}"
      nil
    end

    def calculate_duration
      scenes.sum { |s| s[:duration] || s['duration'] || 5 }
    end
  end
end
