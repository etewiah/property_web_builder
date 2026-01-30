# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Editor Images API", type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'editor-images-test') }
  let!(:admin_user) { create(:user, :admin, website: website) }

  before do
    host! 'editor-images-test.example.com'
    login_as admin_user, scope: :user
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /api_manage/v1/:locale/editor/images' do
    context 'with no images' do
      it 'returns empty array with pagination' do
        get '/api_manage/v1/en/editor/images'

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['images']).to eq([])
        expect(json['pagination']).to include(
          'page' => 1,
          'per_page' => 24,
          'total_count' => 0,
          'total_pages' => 0
        )
      end
    end

    context 'with content photos' do
      let!(:content) { create(:pwb_content, website: website, key: 'test-content-photos') }
      let!(:content_photo) do
        photo = Pwb::ContentPhoto.create!(
          content: content,
          description: 'Test image',
          external_url: 'https://example.com/image.jpg'
        )
        photo
      end

      it 'returns content photos' do
        get '/api_manage/v1/en/editor/images'

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['images'].length).to eq(1)
        expect(json['images'][0]).to include(
          'id' => content_photo.id,
          'type' => 'content',
          'description' => 'Test image',
          'external' => true
        )
      end

      it 'supports pagination' do
        get '/api_manage/v1/en/editor/images', params: { page: 1, per_page: 10 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['pagination']['per_page']).to eq(10)
      end

      it 'enforces max per_page limit' do
        get '/api_manage/v1/en/editor/images', params: { per_page: 500 }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['pagination']['per_page']).to eq(100)
      end
    end

    context 'with source filter' do
      let!(:content) { create(:pwb_content, website: website, key: 'test-source-filter') }
      let!(:content_photo) do
        Pwb::ContentPhoto.create!(
          content: content,
          description: 'Content image',
          external_url: 'https://example.com/content.jpg'
        )
      end

      it 'filters by content source' do
        get '/api_manage/v1/en/editor/images', params: { source: 'content' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['images'].length).to eq(1)
        expect(json['images'][0]['type']).to eq('content')
      end
    end
  end

  describe 'POST /api_manage/v1/:locale/editor/images' do
    let(:image_file) do
      fixture_file_upload(
        Rails.root.join('spec/fixtures/files/test_image.jpg'),
        'image/jpeg'
      )
    end

    context 'with valid image' do
      before do
        # Create test image fixture if it doesn't exist
        fixture_dir = Rails.root.join('spec/fixtures/files')
        FileUtils.mkdir_p(fixture_dir)
        test_image_path = fixture_dir.join('test_image.jpg')
        unless File.exist?(test_image_path)
          # Create a minimal valid JPEG file (1x1 pixel red)
          File.binwrite(test_image_path, [
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
            0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
            0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
            0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
            0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
            0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
            0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
            0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
            0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
            0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
            0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
            0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
            0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
            0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
            0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
            0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
            0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
            0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
            0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
            0x00, 0x00, 0x3F, 0x00, 0xFB, 0xD5, 0xDB, 0x2A, 0x2B, 0xFF, 0xD9
          ].pack('C*'))
        end
      end

      it 'uploads an image successfully' do
        expect {
          post '/api_manage/v1/en/editor/images',
               params: { image: { file: image_file, description: 'Test upload' } }
        }.to change(Pwb::ContentPhoto, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['success']).to be true
        expect(json['image']).to include(
          'type' => 'content',
          'description' => 'Test upload'
        )
      end

      it 'creates editor content record for uploads' do
        post '/api_manage/v1/en/editor/images',
             params: { image: { file: image_file } }

        expect(response).to have_http_status(:created)

        # Check that the special _editor_uploads content was created
        # Use direct query instead of association (which goes through page_contents)
        editor_content = Pwb::Content.find_by(website: website, key: '_editor_uploads')
        expect(editor_content).to be_present
        expect(editor_content.page_part_key).to eq('_editor_uploads')
      end

      it 'stores folder when provided' do
        post '/api_manage/v1/en/editor/images',
             params: { image: { file: image_file, folder: 'my_folder' } }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['image']['folder']).to eq('my_folder')
      end
    end

    context 'with invalid file' do
      it 'rejects missing file' do
        post '/api_manage/v1/en/editor/images', params: { image: { description: 'No file' } }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json['error']).to eq('No file provided')
      end

      it 'rejects invalid content type' do
        # Create a text file
        text_file = Rack::Test::UploadedFile.new(
          StringIO.new('not an image'),
          'text/plain',
          original_filename: 'test.txt'
        )

        post '/api_manage/v1/en/editor/images',
             params: { image: { file: text_file } }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json['error']).to eq('Invalid file type')
      end
    end
  end

  describe 'DELETE /api_manage/v1/:locale/editor/images/:id' do
    let!(:content) { create(:pwb_content, website: website, key: 'test-delete-content') }
    let!(:content_photo) do
      Pwb::ContentPhoto.create!(
        content: content,
        description: 'Photo to delete',
        external_url: 'https://example.com/delete-me.jpg'
      )
    end

    it 'deletes the image' do
      expect {
        delete "/api_manage/v1/en/editor/images/#{content_photo.id}"
      }.to change(Pwb::ContentPhoto, :count).by(-1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['message']).to eq('Image deleted')
    end

    it 'returns 404 for non-existent image' do
      delete '/api_manage/v1/en/editor/images/999999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Not found')
    end

    context 'with another website\'s image' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-site') }
      let!(:other_content) do
        Pwb::Content.create!(website: other_website, key: 'other-site-content')
      end
      let!(:other_photo) do
        Pwb::ContentPhoto.create!(
          content: other_content,
          description: 'Other site photo',
          external_url: 'https://example.com/other.jpg'
        )
      end

      it 'cannot delete images from other websites' do
        delete "/api_manage/v1/en/editor/images/#{other_photo.id}"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Not found')
      end
    end
  end
end
