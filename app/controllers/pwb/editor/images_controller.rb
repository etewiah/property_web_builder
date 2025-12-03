module Pwb
  module Editor
    class ImagesController < Pwb::ApplicationController
      layout false
      # Skip theme path setup since we return JSON
      skip_before_action :set_theme_path
      skip_before_action :nav_links
      skip_before_action :footer_content
      # Skip CSRF for API calls
      skip_before_action :verify_authenticity_token

      def index
        images = []

        # Content photos (website content images) - filter by website
        content_photos = Pwb::ContentPhoto.joins(:content)
                                          .where(pwb_contents: { website_id: @current_website&.id })
                                          .limit(50)
        content_photos.each do |photo|
          next unless photo.image.attached?
          begin
            images << {
              id: "content_#{photo.id}",
              type: 'content',
              url: url_for(photo.image),
              thumb_url: thumbnail_url(photo.image),
              filename: photo.image.filename.to_s,
              description: photo.description
            }
          rescue => e
            Rails.logger.warn "Error processing content photo #{photo.id}: #{e.message}"
          end
        end

        # Website photos (logo, backgrounds, etc.)
        Pwb::WebsitePhoto.all.limit(20).each do |photo|
          next unless photo.image.attached?
          begin
            images << {
              id: "website_#{photo.id}",
              type: 'website',
              url: url_for(photo.image),
              thumb_url: thumbnail_url(photo.image),
              filename: photo.image.filename.to_s,
              description: photo.try(:description)
            }
          rescue => e
            Rails.logger.warn "Error processing website photo #{photo.id}: #{e.message}"
          end
        end

        # Property photos - filter by website
        prop_photos = Pwb::PropPhoto.joins(:prop)
                                    .where(pwb_props: { website_id: @current_website&.id })
                                    .limit(30)
        prop_photos.each do |photo|
          next unless photo.image.attached?
          begin
            images << {
              id: "prop_#{photo.id}",
              type: 'property',
              url: url_for(photo.image),
              thumb_url: thumbnail_url(photo.image),
              filename: photo.image.filename.to_s,
              description: photo.prop&.title
            }
          rescue => e
            Rails.logger.warn "Error processing prop photo #{photo.id}: #{e.message}"
          end
        end

        render json: { images: images }
      end

      def create
        if params[:image].present?
          content_photo = Pwb::ContentPhoto.new
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
      rescue => e
        Rails.logger.warn "Error generating thumbnail: #{e.message}"
        url_for(image)
      end
    end
  end
end
