# frozen_string_literal: true

module SiteAdmin
  class ImagesController < ::SiteAdminController
    # Skip CSRF for API-style uploads
    skip_before_action :verify_authenticity_token, only: [:create]

    def index
      gallery_builder = Pwb::ImageGalleryBuilder.new(current_website, url_helper: self)
      render json: { images: gallery_builder.build }
    end

    def create
      if params[:image].present?
        # Create a ContentPhoto for general content images
        # Associate it with a generic "uploads" content or create one
        content = find_or_create_uploads_content
        content_photo = Pwb::ContentPhoto.new(content: content)
        content_photo.image.attach(params[:image])

        if content_photo.save
          render json: {
            success: true,
            image: {
              id: "content_#{content_photo.id}",
              type: 'content',
              url: url_for(content_photo.image),
              thumb_url: thumbnail_url(content_photo.image),
              filename: content_photo.image.filename.to_s
            }
          }
        else
          render json: { success: false, errors: content_photo.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { success: false, errors: ['No image provided'] }, status: :bad_request
      end
    end

    private

    def thumbnail_url(image)
      return url_for(image) unless image.variable?

      url_for(image.variant(resize_to_limit: [150, 150]))
    rescue StandardError => e
      Rails.logger.warn "Error generating thumbnail: #{e.message}"
      url_for(image)
    end

    def find_or_create_uploads_content
      # Find or create a generic content record for uploads
      Pwb::Content.find_or_create_by!(
        website_id: current_website.id,
        tag: 'site_admin_uploads'
      )
    end
  end
end
