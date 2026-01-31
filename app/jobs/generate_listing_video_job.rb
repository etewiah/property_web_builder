# frozen_string_literal: true

# Background job to generate listing videos.
#
# Orchestrates the full video generation pipeline:
# 1. Generate AI script and scene breakdown
# 2. Generate voiceover audio via TTS
# 3. Assemble video with Shotstack
# 4. Store final assets
#
# Uses TenantAwareJob to ensure proper multi-tenant context.
#
# Usage:
#   GenerateListingVideoJob.perform_later(video_id: video.id, website_id: website.id)
#
class GenerateListingVideoJob < ApplicationJob
  include TenantAwareJob

  queue_as :default

  # Retry on transient failures with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on Ai::ConfigurationError
  discard_on Video::Assembler::ConfigurationError

  def perform(video_id:, website_id:)
    set_tenant!(website_id)

    video = Pwb::ListingVideo.find(video_id)
    property = video.realty_asset

    Rails.logger.info "[GenerateListingVideoJob] Starting generation for video #{video.reference_number}"

    video.mark_generating!

    # Step 1: Generate script and scenes
    Rails.logger.info "[GenerateListingVideoJob] Step 1: Generating script..."
    script_result = generate_script(property, video)

    video.update!(
      script: script_result[:script],
      scenes: script_result[:scenes]
    )

    # Step 2: Generate voiceover
    Rails.logger.info "[GenerateListingVideoJob] Step 2: Generating voiceover..."
    voiceover_result = generate_voiceover(script_result[:script], video)

    video.update!(voiceover_url: voiceover_result[:audio_url])

    # Step 3: Assemble video
    Rails.logger.info "[GenerateListingVideoJob] Step 3: Assembling video..."
    assembly_result = assemble_video(property, video, voiceover_result[:audio_url], script_result)

    # Step 4: Update video record with results
    video.mark_completed!(
      video_url: assembly_result[:video_url],
      thumbnail_url: assembly_result[:thumbnail_url],
      duration_seconds: assembly_result[:duration_seconds],
      resolution: assembly_result[:resolution],
      file_size_bytes: assembly_result[:file_size_bytes],
      render_id: assembly_result[:render_id],
      cost_cents: calculate_total_cost(voiceover_result, assembly_result)
    )

    Rails.logger.info "[GenerateListingVideoJob] Video #{video.reference_number} generated successfully"

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[GenerateListingVideoJob] Video not found: #{video_id}"
    raise
  rescue StandardError => e
    Rails.logger.error "[GenerateListingVideoJob] Error generating video: #{e.message}\n#{e.backtrace.first(10).join("\n")}"

    # Mark video as failed
    if video
      video.mark_failed!(e.message)
    end

    raise
  ensure
    clear_tenant!
  end

  private

  def generate_script(property, video)
    Video::ScriptGenerator.new(
      property: property,
      style: video.style.to_sym,
      options: {
        website: video.website,
        duration_target: calculate_target_duration(property),
        include_price: true,
        include_cta: true
      }
    ).generate
  end

  def generate_voiceover(script, video)
    Video::VoiceoverGenerator.new(
      script: script,
      voice: video.voice.to_sym,
      options: {
        website: video.website,
        model: 'tts-1'  # Standard quality, can use 'tts-1-hd' for higher quality
      }
    ).generate
  end

  def assemble_video(property, video, voiceover_url, script_result)
    Video::Assembler.new(
      photos: property.prop_photos.ordered,
      voiceover_url: voiceover_url,
      scenes: script_result[:scenes],
      options: {
        website: video.website,
        format: video.format.to_sym,
        style: video.style.to_sym,
        music_enabled: true,
        music_mood: script_result[:music_mood],
        music_volume: 0.2,
        branding: video.branding
      }
    ).assemble
  end

  def calculate_target_duration(property)
    # Base duration on photo count
    photo_count = property.prop_photos.count
    base_duration = [photo_count * 5, 30].max  # At least 30 seconds
    [base_duration, 120].min  # Cap at 2 minutes
  end

  def calculate_total_cost(voiceover_result, assembly_result)
    tts_cost = voiceover_result[:cost_cents] || 0
    render_cost = assembly_result[:cost_cents] || 0
    tts_cost + render_cost
  end
end
