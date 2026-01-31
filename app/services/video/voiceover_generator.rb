# frozen_string_literal: true

module Video
  # Generates voiceover audio from text using Text-to-Speech APIs.
  #
  # Supports multiple TTS providers:
  # - OpenAI TTS (default, Phase 1)
  # - ElevenLabs (Phase 2, premium voices)
  #
  # Usage:
  #   result = Video::VoiceoverGenerator.new(
  #     script: "Welcome to this stunning home...",
  #     voice: :nova,
  #     provider: :openai
  #   ).generate
  #
  #   result[:audio_url]        # URL to the generated audio file
  #   result[:duration_seconds] # Audio duration
  #   result[:cost_cents]       # Generation cost
  #
  class VoiceoverGenerator
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end

    # OpenAI TTS voices
    OPENAI_VOICES = {
      alloy: { description: 'Neutral, balanced', best_for: 'General purpose' },
      echo: { description: 'Warm, conversational', best_for: 'Casual style' },
      fable: { description: 'Expressive, dynamic', best_for: 'Energetic style' },
      onyx: { description: 'Deep, authoritative', best_for: 'Luxury style' },
      nova: { description: 'Friendly, professional', best_for: 'Professional style' },
      shimmer: { description: 'Clear, pleasant', best_for: 'Any style' }
    }.freeze

    # OpenAI TTS pricing: $15 per 1M characters
    OPENAI_COST_PER_CHAR = 0.000015

    # ElevenLabs voices (Phase 2)
    ELEVENLABS_VOICES = {
      rachel: { description: 'Professional female', voice_id: '21m00Tcm4TlvDq8ikWAM' },
      adam: { description: 'Professional male', voice_id: 'pNInz6obpgDQGcFmaJgB' }
      # Add more as needed
    }.freeze

    DEFAULT_OPTIONS = {
      provider: :openai,
      model: 'tts-1',  # or 'tts-1-hd' for higher quality
      speed: 1.0,
      response_format: 'mp3'
    }.freeze

    def initialize(script:, voice: :nova, options: {})
      @script = script
      @voice = voice.to_sym
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def generate
      validate_inputs!

      case provider
      when :openai
        generate_with_openai
      when :elevenlabs
        generate_with_elevenlabs
      else
        raise ConfigurationError, "Unknown TTS provider: #{provider}"
      end
    end

    private

    attr_reader :script, :voice, :options

    def provider
      @options[:provider].to_sym
    end

    def validate_inputs!
      raise Error, "Script is required" if script.blank?
      raise Error, "Script is too long (max 4096 characters)" if script.length > 4096

      case provider
      when :openai
        raise Error, "Invalid OpenAI voice: #{voice}" unless OPENAI_VOICES.key?(voice)
      when :elevenlabs
        raise Error, "Invalid ElevenLabs voice: #{voice}" unless ELEVENLABS_VOICES.key?(voice)
      end
    end

    # =========================================================================
    # OpenAI TTS Implementation
    # =========================================================================

    def generate_with_openai
      ensure_openai_configured!

      response = openai_client.audio.speech(
        parameters: {
          model: options[:model],
          input: script,
          voice: voice.to_s,
          response_format: options[:response_format],
          speed: options[:speed]
        }
      )

      # Response is raw audio bytes
      audio_data = response

      # Upload to storage
      audio_url = upload_audio(audio_data, "voiceover_#{SecureRandom.hex(8)}.mp3")

      # Estimate duration (rough: ~150 words per minute)
      word_count = script.split.length
      estimated_duration = (word_count / 2.5).round

      {
        audio_url: audio_url,
        duration_seconds: estimated_duration,
        cost_cents: calculate_openai_cost,
        provider: 'openai',
        voice: voice.to_s,
        model: options[:model]
      }
    rescue Faraday::Error => e
      raise ApiError, "OpenAI TTS API error: #{e.message}"
    end

    def ensure_openai_configured!
      return if openai_api_key.present?

      raise ConfigurationError, "OpenAI API key not configured"
    end

    def openai_client
      @openai_client ||= OpenAI::Client.new(access_token: openai_api_key)
    end

    def openai_api_key
      # Try website integration first, fall back to ENV
      @openai_api_key ||= begin
        if options[:website]
          integration = options[:website].integration_for(:ai)
          integration&.credential(:api_key) if integration&.provider == 'openai'
        end
      end || ENV['OPENAI_API_KEY']
    end

    def calculate_openai_cost
      # Cost in cents
      (script.length * OPENAI_COST_PER_CHAR * 100).ceil
    end

    # =========================================================================
    # ElevenLabs TTS Implementation (Phase 2)
    # =========================================================================

    def generate_with_elevenlabs
      ensure_elevenlabs_configured!

      voice_config = ELEVENLABS_VOICES[voice]

      response = elevenlabs_request(
        voice_id: voice_config[:voice_id],
        text: script,
        model_id: 'eleven_monolingual_v1'
      )

      audio_url = upload_audio(response.body, "voiceover_#{SecureRandom.hex(8)}.mp3")

      {
        audio_url: audio_url,
        duration_seconds: estimate_duration,
        cost_cents: calculate_elevenlabs_cost,
        provider: 'elevenlabs',
        voice: voice.to_s
      }
    end

    def ensure_elevenlabs_configured!
      return if elevenlabs_api_key.present?

      raise ConfigurationError, "ElevenLabs API key not configured"
    end

    def elevenlabs_api_key
      @elevenlabs_api_key ||= begin
        if options[:website]
          integration = options[:website].integrations.find_by(category: 'tts', provider: 'elevenlabs')
          integration&.credential(:api_key)
        end
      end || ENV['ELEVENLABS_API_KEY']
    end

    def elevenlabs_request(voice_id:, text:, model_id:)
      connection = Faraday.new(url: 'https://api.elevenlabs.io') do |f|
        f.request :json
        f.response :raise_error
      end

      connection.post("/v1/text-to-speech/#{voice_id}") do |req|
        req.headers['xi-api-key'] = elevenlabs_api_key
        req.headers['Accept'] = 'audio/mpeg'
        req.body = {
          text: text,
          model_id: model_id,
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.75
          }
        }.to_json
      end
    end

    def calculate_elevenlabs_cost
      # ElevenLabs: ~$0.30 per 1000 characters (varies by plan)
      (script.length * 0.0003 * 100).ceil
    end

    # =========================================================================
    # Shared Helpers
    # =========================================================================

    def upload_audio(audio_data, filename)
      # Upload to ActiveStorage / R2
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(audio_data),
        filename: filename,
        content_type: 'audio/mpeg'
      )

      # Return URL (this will be a signed URL in production)
      Rails.application.routes.url_helpers.rails_blob_url(blob)
    end

    def estimate_duration
      # Rough estimate: 150 words per minute
      word_count = script.split.length
      (word_count / 2.5).round
    end
  end
end
