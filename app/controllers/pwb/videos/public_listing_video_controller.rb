# frozen_string_literal: true

require_dependency 'pwb/application_controller'

module Pwb
  module Videos
    # Public controller for viewing shared listing videos.
    #
    # Accessed via /videos/shared/:share_token route.
    # No authentication required - videos are accessed by share token.
    #
    class PublicListingVideoController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:show]

      def show
        @video = Pwb::ListingVideo
                   .where(website_id: @current_website&.id)
                   .where.not(share_token: nil)
                   .find_by(share_token: params[:share_token])

        if @video.nil?
          render_not_found
          return
        end

        # Record the view
        @video.record_view!

        # Set page title for SEO
        @page_title = @video.title

        respond_to do |format|
          format.html { render layout: 'pwb/application' }
          format.json { render json: video_json }
        end
      end

      private

      def render_not_found
        respond_to do |format|
          format.html { render plain: "Video not found or no longer shared", status: :not_found }
          format.json { render json: { success: false, error: "Video not found or no longer shared" }, status: :not_found }
        end
      end

      def video_json
        {
          success: true,
          video: {
            reference_number: @video.reference_number,
            title: @video.title,
            format: @video.format,
            style: @video.style,
            duration_seconds: @video.duration_seconds,
            video_url: @video.video_url,
            thumbnail_url: @video.thumbnail_url,
            branding: @video.branding,
            generated_at: @video.generated_at&.iso8601
          }.compact
        }
      end
    end
  end
end
