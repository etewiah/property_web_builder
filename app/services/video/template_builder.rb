# frozen_string_literal: true

module Video
  # Builds Shotstack-compatible JSON templates for video rendering.
  #
  # Creates a multi-track timeline with:
  # - Track 1: Photos with Ken Burns (zoom/pan) effects
  # - Track 2: Caption overlays
  # - Track 3: Logo/branding watermark
  # - Track 4: Voiceover audio
  # - Track 5: Background music (optional)
  #
  # Usage:
  #   template = Video::TemplateBuilder.new(
  #     photos: property.prop_photos,
  #     voiceover_url: "https://...",
  #     scenes: [{ photo_index: 0, duration: 5, caption: "Welcome" }],
  #     options: { format: :vertical_9_16, style: :professional }
  #   ).build
  #
  class TemplateBuilder
    # Style-specific configurations
    STYLE_CONFIGS = {
      professional: {
        font: 'Open Sans',
        font_size: 32,
        font_color: '#ffffff',
        caption_background: '#000000',
        caption_opacity: 0.7,
        transition_duration: 0.5,
        ken_burns_scale: 1.1
      },
      luxury: {
        font: 'Playfair Display',
        font_size: 36,
        font_color: '#ffffff',
        caption_background: '#1a1a1a',
        caption_opacity: 0.8,
        transition_duration: 1.0,
        ken_burns_scale: 1.05
      },
      casual: {
        font: 'Montserrat',
        font_size: 30,
        font_color: '#ffffff',
        caption_background: '#2563eb',
        caption_opacity: 0.9,
        transition_duration: 0.3,
        ken_burns_scale: 1.15
      },
      energetic: {
        font: 'Roboto',
        font_size: 34,
        font_color: '#ffffff',
        caption_background: '#dc2626',
        caption_opacity: 0.9,
        transition_duration: 0.2,
        ken_burns_scale: 1.2
      },
      minimal: {
        font: 'Inter',
        font_size: 28,
        font_color: '#ffffff',
        caption_background: '#000000',
        caption_opacity: 0.5,
        transition_duration: 0.5,
        ken_burns_scale: 1.03
      }
    }.freeze

    # Background music options by mood
    MUSIC_LIBRARY = {
      'uplifting' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/upbeat-corporate.mp3',
      'corporate' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/corporate.mp3',
      'classical' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/classical-elegant.mp3',
      'ambient' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/ambient.mp3',
      'acoustic' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/acoustic-warm.mp3',
      'electronic' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/electronic-upbeat.mp3',
      'minimal' => 'https://shotstack-assets.s3.ap-southeast-2.amazonaws.com/music/minimal-background.mp3'
    }.freeze

    # Video format configurations
    FORMATS = {
      vertical_9_16: { width: 1080, height: 1920, resolution: 'hd' },
      horizontal_16_9: { width: 1920, height: 1080, resolution: 'hd' },
      square_1_1: { width: 1080, height: 1080, resolution: 'hd' }
    }.freeze

    def initialize(photos:, voiceover_url:, scenes:, options: {})
      @photos = photos.to_a
      @voiceover_url = voiceover_url
      @scenes = scenes
      @options = options
    end

    def build
      {
        timeline: build_timeline,
        output: build_output
      }
    end

    private

    attr_reader :photos, :voiceover_url, :scenes, :options

    def style
      @style ||= (options[:style] || :professional).to_sym
    end

    def style_config
      STYLE_CONFIGS[style] || STYLE_CONFIGS[:professional]
    end

    def format
      @format ||= (options[:format] || :vertical_9_16).to_sym
    end

    def format_config
      FORMATS[format] || FORMATS[:vertical_9_16]
    end

    def total_duration
      @total_duration ||= scenes.sum { |s| s[:duration] || s['duration'] || 5 }
    end

    # =========================================================================
    # Timeline Builder
    # =========================================================================

    def build_timeline
      tracks = []

      # Track 1: Photos (bottom layer)
      tracks << build_photo_track

      # Track 2: Captions
      tracks << build_caption_track if captions_enabled?

      # Track 3: Logo watermark
      tracks << build_logo_track if logo_url.present?

      # Track 4: Voiceover audio
      tracks << build_voiceover_track

      # Track 5: Background music (lowest audio layer)
      tracks << build_music_track if music_enabled?

      {
        background: '#000000',
        tracks: tracks.compact
      }
    end

    # =========================================================================
    # Photo Track (Ken Burns effects)
    # =========================================================================

    def build_photo_track
      clips = []
      current_time = 0

      scenes.each_with_index do |scene, index|
        photo_index = scene[:photo_index] || scene['photo_index'] || index
        photo = photos[photo_index]
        next unless photo

        duration = scene[:duration] || scene['duration'] || 5
        transition = scene[:transition] || scene['transition'] || 'fade'

        clips << build_photo_clip(photo, current_time, duration, transition, index)
        current_time += duration
      end

      { clips: clips }
    end

    def build_photo_clip(photo, start_time, duration, transition, index)
      # Alternate zoom direction for variety
      zoom_in = index.even?

      clip = {
        asset: {
          type: 'image',
          src: photo_url(photo)
        },
        start: start_time,
        length: duration,
        fit: 'cover',
        effect: build_ken_burns_effect(zoom_in)
      }

      # Add transition (except for first clip)
      if start_time.positive?
        clip[:transition] = {
          in: transition_type(transition),
          out: transition_type(transition)
        }
      end

      clip
    end

    def build_ken_burns_effect(zoom_in)
      scale = style_config[:ken_burns_scale]

      if zoom_in
        "zoomIn" # Shotstack built-in effect
      else
        "zoomOut"
      end
    end

    def transition_type(name)
      # Map our transition names to Shotstack transitions
      {
        'fade' => 'fade',
        'slide' => 'slideLeft',
        'zoom' => 'zoom',
        'dissolve' => 'fade'
      }[name.to_s] || 'fade'
    end

    def photo_url(photo)
      # Get the URL for the photo
      if photo.respond_to?(:image) && photo.image.attached?
        Rails.application.routes.url_helpers.rails_blob_url(photo.image)
      elsif photo.respond_to?(:external_url) && photo.external_url.present?
        photo.external_url
      else
        # Fallback placeholder
        'https://via.placeholder.com/1920x1080?text=No+Image'
      end
    end

    # =========================================================================
    # Caption Track
    # =========================================================================

    def build_caption_track
      clips = []
      current_time = 0

      scenes.each do |scene|
        caption = scene[:caption] || scene['caption']
        duration = scene[:duration] || scene['duration'] || 5

        if caption.present?
          clips << build_caption_clip(caption, current_time, duration)
        end

        current_time += duration
      end

      { clips: clips }
    end

    def build_caption_clip(text, start_time, duration)
      {
        asset: {
          type: 'title',
          text: text,
          style: 'minimal',
          size: 'small',
          position: 'bottom'
        },
        start: start_time,
        length: duration,
        transition: {
          in: 'fade',
          out: 'fade'
        }
      }
    end

    def captions_enabled?
      scenes.any? { |s| (s[:caption] || s['caption']).present? }
    end

    # =========================================================================
    # Logo/Branding Track
    # =========================================================================

    def build_logo_track
      {
        clips: [
          {
            asset: {
              type: 'image',
              src: logo_url
            },
            start: 0,
            length: total_duration,
            position: logo_position,
            scale: 0.15,
            opacity: 0.8
          }
        ]
      }
    end

    def logo_url
      options.dig(:branding, :logo_url)
    end

    def logo_position
      # Position logo in top-right corner
      'topRight'
    end

    # =========================================================================
    # Audio Tracks
    # =========================================================================

    def build_voiceover_track
      {
        clips: [
          {
            asset: {
              type: 'audio',
              src: voiceover_url,
              volume: 1.0
            },
            start: 0,
            length: total_duration
          }
        ]
      }
    end

    def build_music_track
      music_url = select_music_url

      return nil unless music_url

      {
        clips: [
          {
            asset: {
              type: 'audio',
              src: music_url,
              volume: options[:music_volume] || 0.2
            },
            start: 0,
            length: total_duration
          }
        ]
      }
    end

    def music_enabled?
      options[:music_enabled] != false
    end

    def select_music_url
      mood = options[:music_mood] || 'uplifting'
      MUSIC_LIBRARY[mood.to_s] || MUSIC_LIBRARY['uplifting']
    end

    # =========================================================================
    # Output Configuration
    # =========================================================================

    def build_output
      {
        format: 'mp4',
        resolution: format_config[:resolution],
        aspectRatio: aspect_ratio,
        fps: 30,
        quality: 'high',
        poster: {
          capture: 1  # Capture poster at 1 second
        }
      }
    end

    def aspect_ratio
      case format
      when :vertical_9_16 then '9:16'
      when :horizontal_16_9 then '16:9'
      when :square_1_1 then '1:1'
      else '9:16'
      end
    end
  end
end
