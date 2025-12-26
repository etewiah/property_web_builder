# frozen_string_literal: true

module SiteAdmin
  class MediaLibraryController < SiteAdminController
    before_action :set_folder, only: [:index]
    before_action :set_media, only: [:show, :edit, :update, :destroy]

    def index
      @media = current_website.media
                              .by_folder(@folder)
                              .search(params[:q])
                              .recent
                              .page(params[:page])
                              .per(24)

      @folders = current_website.media_folders.root.ordered
      @current_folder = @folder
      @stats = calculate_stats

      respond_to do |format|
        format.html
        format.json { render json: media_json(@media) }
      end
    end

    def show
      respond_to do |format|
        format.html
        format.json { render json: media_item_json(@media) }
      end
    end

    def new
      @media = current_website.media.new
      @folders = current_website.media_folders.ordered
    end

    def create
      uploaded_files = Array(params[:files] || params[:file])
      
      if uploaded_files.empty?
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, alert: 'Please select files to upload.' }
          format.json { render json: { error: 'No files provided' }, status: :unprocessable_entity }
        end
        return
      end

      results = upload_files(uploaded_files)
      
      respond_to do |format|
        format.html do
          if results[:errors].empty?
            redirect_to site_admin_media_library_index_path, notice: "#{results[:uploaded].size} file(s) uploaded successfully."
          else
            redirect_to site_admin_media_library_index_path, alert: "#{results[:uploaded].size} uploaded, #{results[:errors].size} failed."
          end
        end
        format.json { render json: results }
      end
    end

    def edit
      @folders = current_website.media_folders.ordered
    end

    def update
      if @media.update(media_params)
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, notice: 'Media updated successfully.' }
          format.json { render json: media_item_json(@media) }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { errors: @media.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @media.destroy
      
      respond_to do |format|
        format.html { redirect_to site_admin_media_library_index_path, notice: 'Media deleted successfully.' }
        format.json { head :no_content }
      end
    end

    # Bulk operations
    def bulk_destroy
      ids = params[:ids] || []
      deleted = current_website.media.where(id: ids).destroy_all
      
      respond_to do |format|
        format.html { redirect_to site_admin_media_library_index_path, notice: "#{deleted.size} file(s) deleted." }
        format.json { render json: { deleted: deleted.size } }
      end
    end

    def bulk_move
      ids = params[:ids] || []
      folder_id = params[:folder_id]
      
      folder = folder_id.present? ? current_website.media_folders.find_by(id: folder_id) : nil
      moved = current_website.media.where(id: ids).update_all(folder_id: folder&.id)
      
      respond_to do |format|
        format.html { redirect_to site_admin_media_library_index_path, notice: "#{moved} file(s) moved." }
        format.json { render json: { moved: moved } }
      end
    end

    # Folder management
    def folders
      @folders = current_website.media_folders.includes(:children, :media).root.ordered
      
      respond_to do |format|
        format.html
        format.json { render json: folders_json(@folders) }
      end
    end

    def create_folder
      @folder = current_website.media_folders.new(folder_params)
      
      if @folder.save
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path(folder: @folder.id), notice: 'Folder created.' }
          format.json { render json: folder_json(@folder), status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, alert: @folder.errors.full_messages.join(', ') }
          format.json { render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def update_folder
      @folder = current_website.media_folders.find(params[:id])
      
      if @folder.update(folder_params)
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path(folder: @folder.id), notice: 'Folder updated.' }
          format.json { render json: folder_json(@folder) }
        end
      else
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, alert: @folder.errors.full_messages.join(', ') }
          format.json { render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy_folder
      @folder = current_website.media_folders.find(params[:id])
      
      if @folder.empty?
        @folder.destroy
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, notice: 'Folder deleted.' }
          format.json { head :no_content }
        end
      else
        respond_to do |format|
          format.html { redirect_to site_admin_media_library_index_path, alert: 'Cannot delete folder with contents.' }
          format.json { render json: { error: 'Folder is not empty' }, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_folder
      @folder = params[:folder].present? ? current_website.media_folders.find_by(id: params[:folder]) : nil
    end

    def set_media
      @media = current_website.media.find(params[:id])
    end

    def media_params
      params.require(:media).permit(:title, :alt_text, :description, :caption, :folder_id, tags: [])
    end

    def folder_params
      params.require(:folder).permit(:name, :parent_id)
    end

    def upload_files(files)
      results = { uploaded: [], errors: [] }
      folder_id = params[:folder_id]

      files.each do |file|
        media = current_website.media.new(
          folder_id: folder_id,
          file: file,
          filename: file.original_filename,
          source_type: 'upload'
        )

        if media.save
          results[:uploaded] << media_item_json(media)
        else
          results[:errors] << { filename: file.original_filename, errors: media.errors.full_messages }
        end
      end

      results
    end

    def calculate_stats
      {
        total_files: current_website.media.count,
        total_images: current_website.media.images.count,
        total_documents: current_website.media.documents.count,
        total_folders: current_website.media_folders.count,
        storage_used: current_website.media.sum(:byte_size)
      }
    end

    def media_json(media)
      {
        items: media.map { |m| media_item_json(m) },
        pagination: {
          current_page: media.current_page,
          total_pages: media.total_pages,
          total_count: media.total_count
        }
      }
    end

    def media_item_json(media)
      {
        id: media.id,
        filename: media.filename,
        title: media.title,
        alt_text: media.alt_text,
        description: media.description,
        content_type: media.content_type,
        byte_size: media.byte_size,
        human_size: media.human_file_size,
        width: media.width,
        height: media.height,
        dimensions: media.dimensions,
        url: media.url,
        thumbnail_url: media.image? ? media.variant_url(:thumb) : nil,
        is_image: media.image?,
        folder_id: media.folder_id,
        tags: media.tags,
        created_at: media.created_at.iso8601,
        usage_count: media.usage_count
      }
    end

    def folders_json(folders)
      folders.map { |f| folder_json(f) }
    end

    def folder_json(folder)
      {
        id: folder.id,
        name: folder.name,
        slug: folder.slug,
        path: folder.path,
        parent_id: folder.parent_id,
        media_count: folder.media.count,
        children: folders_json(folder.children.ordered)
      }
    end
  end
end
