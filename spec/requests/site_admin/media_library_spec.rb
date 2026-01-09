# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::MediaLibrary', type: :request do
  let(:website) { create(:pwb_website, subdomain: 'test-media') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    sign_in user
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.example.com"
  end

  describe 'GET /site_admin/media_library' do
    it 'returns success' do
      get site_admin_media_library_index_path
      expect(response).to have_http_status(:success)
    end

    it 'displays the media library page' do
      get site_admin_media_library_index_path
      expect(response.body).to include('Media Library')
    end

    it 'shows media statistics' do
      get site_admin_media_library_index_path
      expect(assigns(:stats)).to include(:total_files, :total_images, :total_documents)
    end

    context 'with existing media' do
      let!(:media) { create(:pwb_media, website: website, filename: 'test-image.jpg') }

      it 'lists media items' do
        get site_admin_media_library_index_path
        expect(assigns(:media)).to include(media)
      end
    end

    context 'with folder filter' do
      let!(:folder) { create(:pwb_media_folder, website: website, name: 'Test Folder') }
      let!(:media_in_folder) { create(:pwb_media, website: website, folder: folder, filename: 'in-folder.jpg') }
      let!(:media_no_folder) { create(:pwb_media, website: website, folder: nil, filename: 'no-folder.jpg') }

      it 'filters by folder' do
        get site_admin_media_library_index_path, params: { folder: folder.id }
        expect(assigns(:media)).to include(media_in_folder)
        expect(assigns(:media)).not_to include(media_no_folder)
      end
    end

    context 'with search query' do
      let!(:matching_media) { create(:pwb_media, website: website, filename: 'sunset-beach.jpg', title: 'Beach Photo') }
      let!(:non_matching_media) { create(:pwb_media, website: website, filename: 'mountains.jpg', title: 'Mountains') }

      it 'searches by filename' do
        get site_admin_media_library_index_path, params: { q: 'sunset' }
        expect(assigns(:media)).to include(matching_media)
        expect(assigns(:media)).not_to include(non_matching_media)
      end

      it 'searches by title' do
        get site_admin_media_library_index_path, params: { q: 'Beach' }
        expect(assigns(:media)).to include(matching_media)
        expect(assigns(:media)).not_to include(non_matching_media)
      end
    end

    context 'with JSON format' do
      let!(:media) { create(:pwb_media, website: website, filename: 'api-test.jpg') }

      it 'returns JSON response' do
        get site_admin_media_library_index_path, as: :json
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end

      it 'includes media items in JSON' do
        get site_admin_media_library_index_path, as: :json
        json = response.parsed_body
        expect(json['items']).to be_an(Array)
      end

      it 'includes pagination in JSON' do
        get site_admin_media_library_index_path, as: :json
        json = response.parsed_body
        expect(json['pagination']).to include('current_page', 'total_pages')
      end
    end

    context 'when not signed in' do
      before { sign_out user }

      it 'blocks access' do
        get site_admin_media_library_index_path
        # May redirect to login or return 403 depending on configuration
        expect(response.status).to be_in([302, 403])
      end
    end
  end

  describe 'GET /site_admin/media_library/:id' do
    let!(:media) { create(:pwb_media, website: website, filename: 'show-test.jpg') }

    it 'returns success' do
      get site_admin_media_library_path(media)
      expect(response).to have_http_status(:success)
    end

    context 'with JSON format' do
      it 'returns media details as JSON' do
        get site_admin_media_library_path(media), as: :json
        json = response.parsed_body
        expect(json['id']).to eq(media.id)
        expect(json['filename']).to eq('show-test.jpg')
      end
    end

    context 'with media from another website' do
      let(:other_website) { create(:pwb_website, subdomain: 'other-media') }
      let!(:other_media) { create(:pwb_media, website: other_website, filename: 'other.jpg') }

      it 'returns not found or raises error' do
        get site_admin_media_library_path(other_media)
        expect(response).to have_http_status(:not_found)
      rescue ActiveRecord::RecordNotFound
        # Expected behavior - exception is raised
      end
    end
  end

  describe 'GET /site_admin/media_library/new' do
    it 'returns success' do
      get new_site_admin_media_library_path
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new media object' do
      get new_site_admin_media_library_path
      expect(assigns(:media)).to be_a_new(Pwb::Media)
    end
  end

  describe 'POST /site_admin/media_library' do
    let(:image_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/test_image.jpg'),
        'image/jpeg'
      )
    end

    context 'with valid file' do
      before do
        # Create test fixture if it doesn't exist
        fixture_path = Rails.root.join('spec/fixtures/files')
        FileUtils.mkdir_p(fixture_path)
        unless File.exist?(fixture_path.join('test_image.jpg'))
          # Create a minimal valid JPEG
          File.write(fixture_path.join('test_image.jpg'), "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9")
        end
      end

      it 'creates media successfully' do
        expect do
          post site_admin_media_library_index_path, params: { files: [image_file] }
        end.to change { website.media.count }.by(1)
      end

      it 'redirects with success message' do
        post site_admin_media_library_index_path, params: { files: [image_file] }
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:notice]).to include('uploaded')
      end
    end

    context 'without file' do
      it 'redirects with error' do
        post site_admin_media_library_index_path
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:alert]).to include('select files')
      end
    end

    context 'with JSON format' do
      it 'returns JSON response' do
        post site_admin_media_library_index_path, as: :json
        expect(response.content_type).to include('application/json')
      end
    end
  end

  describe 'GET /site_admin/media_library/:id/edit' do
    let!(:media) { create(:pwb_media, website: website, filename: 'edit-test.jpg') }

    it 'returns success' do
      get edit_site_admin_media_library_path(media)
      expect(response).to have_http_status(:success)
    end

    it 'assigns the media' do
      get edit_site_admin_media_library_path(media)
      expect(assigns(:media)).to eq(media)
    end

    it 'assigns folders for dropdown' do
      create(:pwb_media_folder, website: website, name: 'Folder 1')
      get edit_site_admin_media_library_path(media)
      expect(assigns(:folders)).not_to be_empty
    end
  end

  describe 'PATCH /site_admin/media_library/:id' do
    let!(:media) { create(:pwb_media, website: website, filename: 'update-test.jpg') }

    context 'with valid params' do
      let(:valid_params) do
        {
          media: {
            title: 'Updated Title',
            alt_text: 'Updated alt text',
            description: 'Updated description'
          }
        }
      end

      it 'updates the media' do
        patch site_admin_media_library_path(media), params: valid_params
        media.reload
        expect(media.title).to eq('Updated Title')
        expect(media.alt_text).to eq('Updated alt text')
      end

      it 'redirects with success message' do
        patch site_admin_media_library_path(media), params: valid_params
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:notice]).to include('updated')
      end
    end

    context 'with folder assignment' do
      let!(:folder) { create(:pwb_media_folder, website: website, name: 'Target Folder') }

      it 'moves media to folder' do
        patch site_admin_media_library_path(media), params: { media: { folder_id: folder.id } }
        media.reload
        expect(media.folder).to eq(folder)
      end
    end

    context 'with JSON format' do
      it 'returns updated media as JSON' do
        patch site_admin_media_library_path(media), params: { media: { title: 'JSON Update' } }, as: :json
        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['title']).to eq('JSON Update')
      end
    end
  end

  describe 'DELETE /site_admin/media_library/:id' do
    let!(:media) { create(:pwb_media, website: website, filename: 'delete-test.jpg') }

    it 'deletes the media' do
      expect do
        delete site_admin_media_library_path(media)
      end.to change { website.media.count }.by(-1)
    end

    it 'redirects with success message' do
      delete site_admin_media_library_path(media)
      expect(response).to redirect_to(site_admin_media_library_index_path)
      expect(flash[:notice]).to include('deleted')
    end

    context 'with JSON format' do
      it 'returns no content' do
        delete site_admin_media_library_path(media), as: :json
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'POST /site_admin/media_library/bulk_destroy' do
    let!(:media1) { create(:pwb_media, website: website, filename: 'bulk1.jpg') }
    let!(:media2) { create(:pwb_media, website: website, filename: 'bulk2.jpg') }
    let!(:media3) { create(:pwb_media, website: website, filename: 'bulk3.jpg') }

    it 'deletes multiple media items' do
      expect do
        post bulk_destroy_site_admin_media_library_index_path, params: { ids: [media1.id, media2.id] }
      end.to change { website.media.count }.by(-2)
    end

    it 'does not delete unspecified items' do
      post bulk_destroy_site_admin_media_library_index_path, params: { ids: [media1.id, media2.id] }
      expect(website.media).to include(media3)
    end

    it 'redirects with count message' do
      post bulk_destroy_site_admin_media_library_index_path, params: { ids: [media1.id, media2.id] }
      expect(response).to redirect_to(site_admin_media_library_index_path)
      expect(flash[:notice]).to include('2')
    end
  end

  describe 'POST /site_admin/media_library/bulk_move' do
    let!(:folder) { create(:pwb_media_folder, website: website, name: 'Target') }
    let!(:media1) { create(:pwb_media, website: website, filename: 'move1.jpg', folder: nil) }
    let!(:media2) { create(:pwb_media, website: website, filename: 'move2.jpg', folder: nil) }

    it 'moves multiple media items to folder' do
      post bulk_move_site_admin_media_library_index_path, params: { ids: [media1.id, media2.id], folder_id: folder.id }

      media1.reload
      media2.reload
      expect(media1.folder).to eq(folder)
      expect(media2.folder).to eq(folder)
    end

    it 'moves to root when folder_id is blank' do
      media1.update!(folder: folder)

      post bulk_move_site_admin_media_library_index_path, params: { ids: [media1.id], folder_id: '' }

      media1.reload
      expect(media1.folder).to be_nil
    end
  end

  describe 'GET /site_admin/media_library/folders' do
    let!(:folder1) { create(:pwb_media_folder, website: website, name: 'Folder A') }
    let!(:folder2) { create(:pwb_media_folder, website: website, name: 'Folder B') }

    it 'returns success' do
      get folders_site_admin_media_library_index_path
      expect(response).to have_http_status(:success)
    end

    it 'assigns folders' do
      get folders_site_admin_media_library_index_path
      expect(assigns(:folders)).to include(folder1, folder2)
    end

    context 'with JSON format' do
      it 'returns folders as JSON' do
        get folders_site_admin_media_library_index_path, as: :json
        json = response.parsed_body
        expect(json).to be_an(Array)
        expect(json.pluck('name')).to include('Folder A', 'Folder B')
      end
    end
  end

  describe 'POST /site_admin/media_library/create_folder' do
    context 'with valid params' do
      it 'creates a folder' do
        expect do
          post create_folder_site_admin_media_library_index_path, params: { folder: { name: 'New Folder' } }
        end.to change { website.media_folders.count }.by(1)
      end

      it 'redirects with success message' do
        post create_folder_site_admin_media_library_index_path, params: { folder: { name: 'New Folder' } }
        expect(response).to redirect_to(site_admin_media_library_index_path(folder: assigns(:folder).id))
        expect(flash[:notice]).to include('created')
      end
    end

    context 'with nested folder' do
      let!(:parent) { create(:pwb_media_folder, website: website, name: 'Parent') }

      it 'creates child folder' do
        post create_folder_site_admin_media_library_index_path, params: { folder: { name: 'Child', parent_id: parent.id } }

        child = website.media_folders.find_by(name: 'Child')
        expect(child.parent).to eq(parent)
      end
    end

    context 'with invalid params' do
      it 'redirects with error' do
        post create_folder_site_admin_media_library_index_path, params: { folder: { name: '' } }
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH /site_admin/media_library/folders/:id' do
    let!(:folder) { create(:pwb_media_folder, website: website, name: 'Original Name') }

    it 'updates the folder' do
      patch update_folder_site_admin_media_library_index_path(id: folder.id), params: { folder: { name: 'Updated Name' } }
      folder.reload
      expect(folder.name).to eq('Updated Name')
    end

    it 'redirects with success message' do
      patch update_folder_site_admin_media_library_index_path(id: folder.id), params: { folder: { name: 'Updated Name' } }
      expect(response).to redirect_to(site_admin_media_library_index_path(folder: folder.id))
      expect(flash[:notice]).to include('updated')
    end
  end

  describe 'DELETE /site_admin/media_library/folders/:id' do
    context 'with empty folder' do
      let!(:folder) { create(:pwb_media_folder, website: website, name: 'Empty Folder') }

      it 'deletes the folder' do
        expect do
          delete destroy_folder_site_admin_media_library_index_path(id: folder.id)
        end.to change { website.media_folders.count }.by(-1)
      end

      it 'redirects with success message' do
        delete destroy_folder_site_admin_media_library_index_path(id: folder.id)
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:notice]).to include('deleted')
      end
    end

    context 'with non-empty folder' do
      let!(:folder) { create(:pwb_media_folder, website: website, name: 'Non-empty Folder') }
      let!(:media) { create(:pwb_media, website: website, folder: folder, filename: 'in-folder.jpg') }

      it 'does not delete the folder' do
        expect do
          delete destroy_folder_site_admin_media_library_index_path(id: folder.id)
        end.not_to(change { website.media_folders.count })
      end

      it 'redirects with error message' do
        delete destroy_folder_site_admin_media_library_index_path(id: folder.id)
        expect(response).to redirect_to(site_admin_media_library_index_path)
        expect(flash[:alert]).to include('contents')
      end
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:pwb_website, subdomain: 'other-media') }
    let!(:own_media) { create(:pwb_media, website: website, filename: 'own.jpg') }
    let!(:own_folder) { create(:pwb_media_folder, website: website, name: 'Own Folder') }
    let!(:other_media) { create(:pwb_media, website: other_website, filename: 'other.jpg') }
    let!(:other_folder) { create(:pwb_media_folder, website: other_website, name: 'Other Folder') }

    it 'only shows own media in index' do
      get site_admin_media_library_index_path
      expect(assigns(:media)).to include(own_media)
      expect(assigns(:media)).not_to include(other_media)
    end

    it 'only shows own folders' do
      get site_admin_media_library_index_path
      expect(assigns(:folders)).to include(own_folder)
      expect(assigns(:folders)).not_to include(other_folder)
    end

    it 'cannot access other website media' do
      get site_admin_media_library_path(other_media)
      expect(response).to have_http_status(:not_found)
    rescue ActiveRecord::RecordNotFound
      # Expected behavior - exception is raised
    end

    it 'cannot delete other website media' do
      delete site_admin_media_library_path(other_media)
      expect(response).to have_http_status(:not_found)
    rescue ActiveRecord::RecordNotFound
      # Expected behavior - exception is raised
    end

    it 'only counts own media in stats' do
      get site_admin_media_library_index_path
      expect(assigns(:stats)[:total_files]).to eq(1)
    end
  end
end
