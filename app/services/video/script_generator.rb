# frozen_string_literal: true

module Video
  # Generates video scripts and scene breakdowns using AI.
  #
  # Creates a voiceover script tailored to the property and video style,
  # along with a scene-by-scene breakdown for video assembly.
  #
  # Usage:
  #   result = Video::ScriptGenerator.new(
  #     property: realty_asset,
  #     style: :professional,
  #     options: { duration_target: 60 }
  #   ).generate
  #
  #   result[:script]    # "Welcome to this stunning 3-bedroom home..."
  #   result[:scenes]    # [{ photo_index: 0, duration: 5, caption: "..." }, ...]
  #   result[:music_mood] # "uplifting"
  #
  class ScriptGenerator < ::Ai::BaseService
    STYLE_CONFIGS = {
      professional: {
        tone: 'confident and informative',
        pace: 'moderate',
        language: 'formal, feature-focused',
        emoji: false,
        seconds_per_photo: 5
      },
      luxury: {
        tone: 'sophisticated and exclusive',
        pace: 'slower, deliberate',
        language: 'elegant, aspirational',
        emoji: false,
        seconds_per_photo: 7
      },
      casual: {
        tone: 'friendly and approachable',
        pace: 'upbeat',
        language: 'conversational, warm',
        emoji: false,
        seconds_per_photo: 4
      },
      energetic: {
        tone: 'exciting and dynamic',
        pace: 'fast, punchy',
        language: 'action words, enthusiasm',
        emoji: false,
        seconds_per_photo: 3
      },
      minimal: {
        tone: 'simple and direct',
        pace: 'steady',
        language: 'brief, factual',
        emoji: false,
        seconds_per_photo: 5
      }
    }.freeze

    MUSIC_MOODS = {
      professional: 'corporate, uplifting',
      luxury: 'classical, ambient',
      casual: 'acoustic, warm',
      energetic: 'electronic, upbeat',
      minimal: 'minimal, subtle'
    }.freeze

    def initialize(property:, style: :professional, options: {})
      @property = property
      @style = style.to_sym
      @options = {
        duration_target: 60,
        include_price: true,
        include_cta: true,
        locale: :en,
        max_photos: 10
      }.merge(options)

      super()
    end

    def generate
      ensure_configured!

      response = chat(
        messages: build_messages,
        response_format: { type: 'json_object' }
      )

      parse_response(response.content)
    end

    private

    attr_reader :property, :style, :options

    def style_config
      STYLE_CONFIGS[style] || STYLE_CONFIGS[:professional]
    end

    def build_messages
      [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ]
    end

    def system_prompt
      <<~PROMPT
        You are a professional real estate video scriptwriter. Your scripts are used for
        automated voice-over in property listing videos.

        Style for this video: #{style.to_s.titleize}
        - Tone: #{style_config[:tone]}
        - Pace: #{style_config[:pace]}
        - Language: #{style_config[:language]}

        Guidelines:
        - Write naturally flowing prose suitable for voice-over (no bullet points)
        - Keep sentences short and easy to speak
        - Avoid jargon; use accessible language
        - Highlight key selling points naturally
        - Create smooth transitions between scenes
        - Include a call-to-action at the end if requested
        - Aim for approximately #{words_for_duration} words (#{options[:duration_target]} seconds)

        You must respond with valid JSON only.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Create a video script for this property listing:

        ## Property Details
        #{property_details}

        ## Photo Count
        #{photo_count} photos available (will show #{[photo_count, options[:max_photos]].min} in video)

        ## Requirements
        - Target duration: #{options[:duration_target]} seconds
        - Include price: #{options[:include_price]}
        - Include call-to-action: #{options[:include_cta]}

        ## Response Format
        Return a JSON object with this structure:
        {
          "script": "The full voiceover script as a single string...",
          "scenes": [
            {
              "photo_index": 0,
              "duration": 5,
              "caption": "Short caption for this scene",
              "transition": "fade"
            }
          ],
          "music_mood": "uplifting",
          "estimated_duration": 58,
          "word_count": 145
        }

        Notes:
        - photo_index corresponds to the photo order (0-indexed)
        - duration is in seconds
        - transition can be: fade, slide, zoom, dissolve
        - music_mood should match the style: #{MUSIC_MOODS[style]}
        - Create #{[photo_count, options[:max_photos]].min} scenes (one per photo)
      PROMPT
    end

    def property_details
      details = []

      details << "Address: #{property.street_address}, #{property.city}" if property.street_address.present?
      details << "Type: #{property.prop_type_key&.titleize}"
      details << "Bedrooms: #{property.count_bedrooms}" if property.count_bedrooms.present?
      details << "Bathrooms: #{property.count_bathrooms}" if property.count_bathrooms.present?
      details << "Size: #{property.constructed_area} sqft" if property.constructed_area.present?
      details << "Year Built: #{property.year_construction}" if property.year_construction.present?

      if options[:include_price] && property.for_sale? && property.sale_listings.any?
        price = property.sale_listings.first.price_sale_current_cents
        currency = property.sale_listings.first.price_sale_current_currency || 'USD'
        details << "Price: #{format_price(price, currency)}"
      end

      if property.description.present?
        details << "\nDescription:\n#{property.description.truncate(500)}"
      end

      details.join("\n")
    end

    def photo_count
      @photo_count ||= property.prop_photos.count
    end

    def words_for_duration
      # Average speaking rate is ~150 words per minute
      (options[:duration_target] * 2.5).round
    end

    def format_price(cents, currency)
      symbol = { 'USD' => '$', 'EUR' => "\u20AC", 'GBP' => "\u00A3" }[currency] || currency
      "#{symbol}#{(cents / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    def parse_response(content)
      data = JSON.parse(content).deep_symbolize_keys

      {
        script: data[:script],
        scenes: data[:scenes] || build_default_scenes,
        music_mood: data[:music_mood] || MUSIC_MOODS[style],
        estimated_duration: data[:estimated_duration] || options[:duration_target],
        word_count: data[:word_count] || data[:script]&.split&.length || 0
      }
    rescue JSON::ParserError => e
      Rails.logger.error "[Video::ScriptGenerator] JSON parse error: #{e.message}"
      build_fallback_result
    end

    def build_default_scenes
      count = [photo_count, options[:max_photos]].min
      duration_per_photo = options[:duration_target] / count

      count.times.map do |i|
        {
          photo_index: i,
          duration: duration_per_photo,
          caption: "",
          transition: i.zero? ? 'fade' : 'slide'
        }
      end
    end

    def build_fallback_result
      {
        script: "Welcome to this beautiful property. Contact us today to schedule a viewing.",
        scenes: build_default_scenes,
        music_mood: MUSIC_MOODS[style],
        estimated_duration: options[:duration_target],
        word_count: 12
      }
    end
  end
end
