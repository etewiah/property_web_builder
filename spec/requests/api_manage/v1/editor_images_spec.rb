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
      let!(:content) { create(:pwb_content, website: website) }
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
      let!(:content) { create(:pwb_content, website: website) }
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
end
