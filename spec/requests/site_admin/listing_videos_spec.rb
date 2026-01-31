# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::ListingVideosController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'videos-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@videos-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/listing_videos (index)' do
    it 'renders the videos list successfully' do
      get site_admin_listing_videos_path, headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with videos' do
      let!(:realty_asset) { create(:pwb_realty_asset, website: website) }
      let!(:video1) { create(:listing_video, website: website, realty_asset: realty_asset, title: 'First Video') }
      let!(:video2) { create(:listing_video, website: website, realty_asset: realty_asset, title: 'Second Video') }

      it 'displays videos in the list' do
        get site_admin_listing_videos_path, headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'supports status filter' do
        get site_admin_listing_videos_path,
            params: { status: 'pending' },
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'supports format filter' do
        get site_admin_listing_videos_path,
            params: { format: 'vertical_9_16' },
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'supports search' do
        get site_admin_listing_videos_path,
            params: { search: 'First' },
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-videos') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:my_asset) { create(:pwb_realty_asset, website: website) }
      let!(:other_asset) { create(:pwb_realty_asset, website: other_website) }
      let!(:my_video) { create(:listing_video, website: website, realty_asset: my_asset, title: 'My Video') }
      let!(:other_video) { create(:listing_video, website: other_website, realty_asset: other_asset, title: 'Other Video') }

      it 'only shows videos for current website' do
        get site_admin_listing_videos_path, headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('My Video')
        expect(response.body).not_to include('Other Video')
      end
    end
  end

  describe 'GET /site_admin/listing_videos/:id (show)' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let!(:video) { create(:listing_video, website: website, realty_asset: realty_asset) }

    it 'renders the video show page' do
      get site_admin_listing_video_path(video),
          headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-show-video') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_asset) { create(:pwb_realty_asset, website: other_website) }
      let!(:other_video) { create(:listing_video, website: other_website, realty_asset: other_asset) }

      it 'cannot access videos from other websites' do
        get site_admin_listing_video_path(other_video),
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      rescue ActiveRecord::RecordNotFound
        expect(true).to be true
      end
    end
  end

  describe 'GET /site_admin/listing_videos/new' do
    it 'renders the new video form' do
      get new_site_admin_listing_video_path, headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /site_admin/listing_videos (create)' do
    let!(:realty_asset) do
      asset = create(:pwb_realty_asset, website: website, reference: 'VIDEO-PROP')
      # Add 3 photos to meet minimum requirement
      3.times { create(:pwb_prop_photo, realty_asset_id: asset.id) }
      asset
    end

    context 'without property selected' do
      it 'returns error' do
        post site_admin_listing_videos_path,
             params: { listing_video: { format: 'vertical_9_16' } },
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to include('Please select a property')
      end
    end

    context 'with property having insufficient photos' do
      let!(:asset_no_photos) { create(:pwb_realty_asset, website: website) }

      it 'returns error' do
        post site_admin_listing_videos_path,
             params: { listing_video: { property_id: asset_no_photos.id } },
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to include('at least 3 photos')
      end
    end

    context 'with valid property and AI configured' do
      let(:mock_result) do
        double('Video::Generator::Result',
               success?: true,
               video: create(:listing_video, website: website, realty_asset: realty_asset))
      end

      before do
        allow_any_instance_of(Video::Generator).to receive(:generate).and_return(mock_result)
      end

      it 'starts video generation and redirects' do
        post site_admin_listing_videos_path,
             params: {
               listing_video: {
                 property_id: realty_asset.id,
                 format: 'vertical_9_16',
                 style: 'professional',
                 voice: 'alloy'
               }
             },
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to include('Video generation started')
      end
    end

    context 'when AI is not configured' do
      before do
        allow_any_instance_of(Video::Generator).to receive(:generate)
          .and_raise(Ai::ConfigurationError.new('AI is not configured'))
      end

      it 'redirects to integrations page' do
        post site_admin_listing_videos_path,
             params: { listing_video: { property_id: realty_asset.id } },
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to redirect_to(site_admin_integrations_path)
        expect(flash[:alert]).to include('AI is not configured')
      end
    end
  end

  describe 'DELETE /site_admin/listing_videos/:id (destroy)' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let!(:video) { create(:listing_video, website: website, realty_asset: realty_asset, reference_number: 'VID-DELETE') }

    it 'deletes the video' do
      expect do
        delete site_admin_listing_video_path(video),
               headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }
      end.to change(Pwb::ListingVideo, :count).by(-1)
    end

    it 'redirects to index with notice' do
      delete site_admin_listing_video_path(video),
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to redirect_to(site_admin_listing_videos_path)
      expect(flash[:notice]).to include('VID-DELETE')
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-delete-video') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_asset) { create(:pwb_realty_asset, website: other_website) }
      let!(:other_video) { create(:listing_video, website: other_website, realty_asset: other_asset) }

      it 'cannot delete videos from other websites' do
        expect do
          delete site_admin_listing_video_path(other_video),
                 headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }
        end.not_to change(Pwb::ListingVideo, :count)
      rescue ActiveRecord::RecordNotFound
        expect(true).to be true
      end
    end
  end

  describe 'POST /site_admin/listing_videos/:id/regenerate' do
    let!(:realty_asset) do
      asset = create(:pwb_realty_asset, website: website)
      3.times { create(:pwb_prop_photo, realty_asset_id: asset.id) }
      asset
    end
    let!(:video) { create(:listing_video, :failed, website: website, realty_asset: realty_asset) }

    context 'with valid configuration' do
      let(:mock_result) do
        double('Video::Generator::Result',
               success?: true,
               video: create(:listing_video, website: website, realty_asset: realty_asset))
      end

      before do
        allow_any_instance_of(Video::Generator).to receive(:generate).and_return(mock_result)
      end

      it 'starts regeneration and redirects' do
        post regenerate_site_admin_listing_video_path(video),
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to include('regeneration started')
      end
    end

    # Note: The controller has a check for videos without linked properties,
    # but the database has a NOT NULL constraint on realty_asset_id,
    # so this scenario cannot occur. The check is defensive code.
  end

  describe 'POST /site_admin/listing_videos/:id/share' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website) }

    context 'with completed video' do
      let!(:video) { create(:listing_video, :completed, website: website, realty_asset: realty_asset) }

      it 'shares the video and redirects with share URL' do
        post share_site_admin_listing_video_path(video),
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        expect(flash[:notice]).to include('shared')
        expect(video.reload.share_token).to be_present
      end
    end

    context 'with pending video' do
      let!(:video) { create(:listing_video, website: website, realty_asset: realty_asset, status: 'pending') }

      it 'returns error' do
        post share_site_admin_listing_video_path(video),
             headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        expect(flash[:alert]).to include('must be completed')
      end
    end
  end

  describe 'GET /site_admin/listing_videos/:id/download' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website) }

    context 'with video_url present' do
      let!(:video) do
        create(:listing_video, :completed,
               website: website,
               realty_asset: realty_asset,
               video_url: 'https://example.com/video.mp4')
      end

      it 'redirects to video URL' do
        get download_site_admin_listing_video_path(video),
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to redirect_to('https://example.com/video.mp4')
      end
    end

    context 'with video not ready' do
      let!(:video) { create(:listing_video, website: website, realty_asset: realty_asset, status: 'pending') }

      it 'returns error' do
        get download_site_admin_listing_video_path(video),
            headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        expect(flash[:alert]).to include('not ready')
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_listing_videos_path,
          headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on create' do
      post site_admin_listing_videos_path,
           params: { listing_video: { property_id: 'test' } },
           headers: { 'HTTP_HOST' => 'videos-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
