# frozen_string_literal: true

module ApiManage
  module V1
    # Manages images for the editor
    #
    # GET /api_manage/v1/:locale/editor/images
    #   Returns paginated images from content photos, property photos, etc.
    #
    # POST /api_manage/v1/:locale/editor/images
    #   Uploads a new image for use in the editor
    #
    # DELETE /api_manage/v1/:locale/editor/images/:id
    #   Deletes an image
    #
    # Query params (GET):
    # - page: Page number (default: 1)
    # - per_page: Items per page (default: 24, max: 100)
    # - source: Filter by source ('content', 'property', 'website', or 'all')
    # - search: Filter by filename or description
    #
    # Body params (POST):
    # - image[file]: The image file (multipart)
    # - image[description]: Optional description
    # - image[folder]: Optional folder name for organization
    #
    class EditorImagesController < BaseController
      DEFAULT_PER_PAGE = 24
      MAX_PER_PAGE = 100
      MAX_FILE_SIZE = 10.megabytes
      ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

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

      # POST /api_manage/v1/:locale/editor/images
      def create
        uploaded_file = image_params[:file]

        unless uploaded_file
          return render json: { error: 'No file provided', message: 'image[file] is required' }, status: :bad_request
        end

        # Validate file type
        unless ALLOWED_CONTENT_TYPES.include?(uploaded_file.content_type)
          return render json: {
            error: 'Invalid file type',
            message: "Allowed types: #{ALLOWED_CONTENT_TYPES.join(', ')}"
          }, status: :unprocessable_entity
        end

        # Validate file size
        if uploaded_file.size > MAX_FILE_SIZE
          return render json: {
            error: 'File too large',
            message: "Maximum file size is #{MAX_FILE_SIZE / 1.megabyte}MB"
          }, status: :unprocessable_entity
        end

        # Create a standalone content for editor uploads (not associated with a page part)
        content = find_or_create_editor_content

        # Create the photo record
        photo = Pwb::ContentPhoto.new(
          content: content,
          description: image_params[:description],
          folder: image_params[:folder] || 'editor_uploads',
          file_size: uploaded_file.size
        )

        # Attach the image
        photo.image.attach(uploaded_file)

        if photo.save
          render json: {
            success: true,
            image: serialize_content_photo(photo)
          }, status: :created
        else
          render json: {
            error: 'Upload failed',
            errors: photo.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api_manage/v1/:locale/editor/images/:id
      def destroy
        photo = Pwb::ContentPhoto.joins(:content)
                                 .where(pwb_contents: { website_id: current_website.id })
                                 .find(params[:id])

        photo.destroy!

        render json: { success: true, message: 'Image deleted' }
      end

      private

      def image_params
        params.require(:image).permit(:file, :description, :folder)
      rescue ActionController::ParameterMissing
        # Allow empty params for validation in create action
        {}
      end

      # Find or create a content record for editor uploads
      # This keeps uploaded images organized separately from page part content
      #
      # Note: We can't use current_website.contents because that association goes
      # through page_contents, which would try to create a PageContent record
      def find_or_create_editor_content
        Pwb::Content.find_or_create_by!(website: current_website, key: '_editor_uploads') do |c|
          c.page_part_key = '_editor_uploads'
        end
      end

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
