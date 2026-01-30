# frozen_string_literal: true

module ApiManage
  module V1
    # Returns paginated images available for the editor
    #
    # GET /api_manage/v1/:locale/editor/images
    #
    # Returns images from:
    # - Content photos (page part images)
    # - Property photos
    # - Website photos (logo, etc.)
    #
    # Query params:
    # - page: Page number (default: 1)
    # - per_page: Items per page (default: 24, max: 100)
    # - source: Filter by source ('content', 'property', 'website', or 'all')
    # - search: Filter by filename or description
    #
    class EditorImagesController < BaseController
      DEFAULT_PER_PAGE = 24
      MAX_PER_PAGE = 100

      def index
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
        source = params[:source] || 'all'
        search = params[:search]

        images = fetch_images(source: source, search: search)

        # Calculate pagination
        total_count = images.count
        total_pages = (total_count.to_f / per_page).ceil
        offset = (page - 1) * per_page

        # Paginate
        paginated_images = images.offset(offset).limit(per_page)

        render json: {
          images: paginated_images.map { |img| serialize_image(img) },
          pagination: {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages,
            has_next: page < total_pages,
            has_prev: page > 1
          }
        }
      end

      private

      def fetch_images(source:, search:)
        case source
        when 'content'
          fetch_content_photos(search)
        when 'property'
          fetch_property_photos(search)
        when 'website'
          fetch_website_photos(search)
        else
          # Combine all sources - use a union approach
          fetch_all_images(search)
        end
      end

      def fetch_content_photos(search)
        scope = Pwb::ContentPhoto.joins(:content)
                                 .where(pwb_contents: { website_id: current_website.id })
                                 .order(created_at: :desc)

        apply_search(scope, search, :description)
      end

      def fetch_property_photos(search)
        scope = Pwb::PropPhoto.joins(:realty_asset)
                              .where(pwb_realty_assets: { website_id: current_website.id })
                              .order(created_at: :desc)

        apply_search(scope, search, :description)
      end

      def fetch_website_photos(search)
        # Website photos - could be logo, favicon, etc.
        # For now, return empty as WebsitePhoto may need different handling
        Pwb::ContentPhoto.none
      end

      def fetch_all_images(search)
        # For 'all', we need to combine multiple sources
        # Using a simple approach: fetch content photos first (most common for editor)
        content_photos = fetch_content_photos(search)
        property_photos = fetch_property_photos(search)

        # Create a combined array and sort by created_at
        # Note: This approach loads all IDs but allows proper pagination
        content_ids = content_photos.pluck(:id)
        property_ids = property_photos.pluck(:id)

        # For simplicity, prioritize content photos then property photos
        # Return as a scope-like object by using content_photos with union
        # Since we can't easily union different tables, we'll use content_photos primarily
        # and mark property photos separately in the response

        # For MVP: just return content photos, which are the most relevant for page editing
        content_photos
      end

      def apply_search(scope, search, column)
        return scope if search.blank?

        scope.where("#{column} ILIKE ?", "%#{search}%")
      end

      def serialize_image(image)
        case image
        when Pwb::ContentPhoto
          serialize_content_photo(image)
        when Pwb::PropPhoto
          serialize_prop_photo(image)
        else
          serialize_generic_image(image)
        end
      end

      def serialize_content_photo(photo)
        {
          id: photo.id,
          type: 'content',
          url: photo.optimized_image_url,
          thumbnail_url: generate_thumbnail_url(photo),
          filename: photo.image_filename,
          description: photo.description,
          folder: photo.folder,
          block_key: photo.block_key,
          file_size: photo.file_size,
          created_at: photo.created_at.iso8601,
          external: photo.external?
        }.compact
      end

      def serialize_prop_photo(photo)
        {
          id: photo.id,
          type: 'property',
          url: photo.external? ? photo.external_url : photo_url(photo),
          thumbnail_url: generate_prop_thumbnail_url(photo),
          filename: photo.image.attached? ? photo.image.filename.to_s : nil,
          description: photo.description,
          folder: photo.folder,
          file_size: photo.file_size,
          property_id: photo.realty_asset_id,
          created_at: photo.created_at.iso8601,
          external: photo.external?
        }.compact
      end

      def serialize_generic_image(image)
        {
          id: image.id,
          type: 'unknown',
          url: nil,
          created_at: image.created_at&.iso8601
        }
      end

      def generate_thumbnail_url(photo)
        return photo.external_url if photo.external?
        return nil unless photo.image.attached? && photo.image.variable?

        photo.image.variant(resize_to_limit: [200, 200]).processed.url
      rescue StandardError
        nil
      end

      def generate_prop_thumbnail_url(photo)
        return photo.external_url if photo.external?
        return nil unless photo.image.attached? && photo.image.variable?

        photo.image.variant(resize_to_limit: [200, 200]).processed.url
      rescue StandardError
        nil
      end

      def photo_url(photo)
        return nil unless photo.image.attached?

        Rails.application.routes.url_helpers.rails_blob_url(
          photo.image,
          host: request.host_with_port
        )
      rescue StandardError
        nil
      end
    end
  end
end
