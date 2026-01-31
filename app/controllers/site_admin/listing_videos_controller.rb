# frozen_string_literal: true

module SiteAdmin
  # Controller for managing AI-generated listing videos.
  #
  # Provides functionality to:
  # - List and view generated videos
  # - Generate new videos for properties
  # - Download and share videos
  # - Regenerate failed videos
  class ListingVideosController < ::SiteAdminController
    before_action :set_video, only: %i[show destroy regenerate share download]

    def index
      @videos = current_website.listing_videos
                               .includes(:realty_asset, :user)
                               .recent

      # Apply filters
      @videos = @videos.where(status: params[:status]) if params[:status].present?
      @videos = @videos.where(format: params[:format]) if params[:format].present?

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @videos = @videos.joins(:realty_asset).where(
          'pwb_listing_videos.title ILIKE :term OR pwb_listing_videos.reference_number ILIKE :term OR pwb_realty_assets.street_address ILIKE :term',
          term: search_term
        )
      end

      @pagy, @videos = pagy(@videos, items: 20)
    end

    def show
      @property = @video.realty_asset
      @scenes = @video.scenes || []
    end

    def new
      @video = current_website.listing_videos.new
      @properties = available_properties
    end

    def create
      property = find_property

      unless property
        flash[:alert] = 'Please select a property'
        @properties = available_properties
        @video = current_website.listing_videos.new
        render :new, status: :unprocessable_entity
        return
      end

      unless property.prop_photos.count >= 3
        flash[:alert] = 'Property must have at least 3 photos to generate a video'
        @properties = available_properties
        @video = current_website.listing_videos.new
        render :new, status: :unprocessable_entity
        return
      end

      result = Video::Generator.new(
        property: property,
        website: current_website,
        user: current_user,
        options: video_options
      ).generate

      if result.success?
        redirect_to site_admin_listing_video_path(result.video),
                    notice: 'Video generation started. This may take a few minutes.'
      else
        redirect_to site_admin_listing_videos_path,
                    alert: "Failed to start video generation: #{result.error}"
      end
    rescue Ai::ConfigurationError
      redirect_to site_admin_integrations_path,
                  alert: "AI is not configured. Please set up an AI integration first."
    rescue Video::Assembler::ConfigurationError
      redirect_to site_admin_integrations_path,
                  alert: "Video rendering is not configured. Please set up a Shotstack integration."
    end

    def destroy
      @video.destroy!
      redirect_to site_admin_listing_videos_path,
                  notice: "Video #{@video.reference_number} deleted"
    end

    def regenerate
      unless @video.realty_asset
        redirect_to site_admin_listing_video_path(@video),
                    alert: 'Cannot regenerate: no property linked'
        return
      end

      # Create a new video with same settings
      result = Video::Generator.new(
        property: @video.realty_asset,
        website: current_website,
        user: current_user,
        options: {
          format: @video.format.to_sym,
          style: @video.style.to_sym,
          voice: @video.voice.to_sym
        }
      ).generate

      if result.success?
        redirect_to site_admin_listing_video_path(result.video),
                    notice: 'Video regeneration started'
      else
        redirect_to site_admin_listing_video_path(@video),
                    alert: "Failed to regenerate: #{result.error}"
      end
    rescue Ai::ConfigurationError, Video::Assembler::ConfigurationError => e
      redirect_to site_admin_listing_video_path(@video),
                  alert: e.message
    end

    def share
      unless @video.completed?
        redirect_to site_admin_listing_video_path(@video),
                    alert: 'Video must be completed before sharing'
        return
      end

      @video.mark_shared! unless @video.share_token.present?

      share_url = public_listing_video_url(@video.share_token)

      redirect_to site_admin_listing_video_path(@video),
                  notice: "Video shared! URL: #{share_url}"
    end

    def download
      unless @video.video_ready?
        redirect_to site_admin_listing_video_path(@video),
                    alert: 'Video is not ready for download'
        return
      end

      if @video.video_file.attached?
        redirect_to rails_blob_path(@video.video_file, disposition: 'attachment'),
                    allow_other_host: true
      elsif @video.video_url.present?
        redirect_to @video.video_url, allow_other_host: true
      else
        redirect_to site_admin_listing_video_path(@video),
                    alert: 'Video file not available'
      end
    end

    private

    def set_video
      @video = current_website.listing_videos.find(params[:id])
    end

    def find_property
      property_id = params.dig(:listing_video, :property_id) || params[:property_id]
      return nil if property_id.blank?

      current_website.realty_assets.find_by(id: property_id)
    end

    def video_options
      options = {}

      if params[:listing_video].present?
        video_params = params[:listing_video]
        options[:format] = video_params[:format].to_sym if video_params[:format].present?
        options[:style] = video_params[:style].to_sym if video_params[:style].present?
        options[:voice] = video_params[:voice].to_sym if video_params[:voice].present?
        options[:include_price] = video_params[:include_price] == '1'
        options[:include_address] = video_params[:include_address] == '1'
        options[:music_enabled] = video_params[:music_enabled] != '0'
      end

      options
    end

    def available_properties
      current_website.realty_assets
                     .joins(:prop_photos)
                     .group('pwb_realty_assets.id')
                     .having('COUNT(pwb_prop_photos.id) >= 3')
                     .order(:street_address)
                     .limit(100)
    end
  end
end
