# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::ListingVideos', type: :request do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, :admin, website: website) }
  let(:property) do
    create(:pwb_realty_asset,
           website: website,
           street_address: '123 Main St',
           city: 'Test City')
  end

  before do
    # Set up multi-tenant context
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.example.com"

    # Sign in user
    sign_in user

    # Create photos for the property (need at least 3)
    3.times do
      create(:pwb_prop_photo, :with_image, realty_asset: property)
    end
  end

  describe 'GET /site_admin/listing_videos' do
    it 'renders the index page' do
      get site_admin_listing_videos_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Listing Videos')
    end

    context 'with existing videos' do
      let!(:video) { create(:listing_video, website: website, realty_asset: property) }

      it 'lists videos' do
        get site_admin_listing_videos_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(video.reference_number)
      end

      it 'filters by status' do
        get site_admin_listing_videos_path, params: { status: 'pending' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by format' do
        get site_admin_listing_videos_path, params: { format: 'vertical_9_16' }

        expect(response).to have_http_status(:success)
      end

      it 'searches by reference number' do
        get site_admin_listing_videos_path, params: { search: video.reference_number }

        expect(response).to have_http_status(:success)
        expect(response.body).to include(video.reference_number)
      end
    end
  end

  describe 'GET /site_admin/listing_videos/new' do
    it 'renders the new video form' do
      get new_site_admin_listing_video_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Generate Listing Video')
      expect(response.body).to include('Select Property')
    end

    it 'shows properties with at least 3 photos' do
      get new_site_admin_listing_video_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(property.street_address)
    end
  end

  describe 'GET /site_admin/listing_videos/:id' do
    let(:video) { create(:listing_video, website: website, realty_asset: property) }

    it 'renders the video detail page' do
      get site_admin_listing_video_path(video)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(video.title)
      expect(response.body).to include(video.reference_number)
    end

    context 'when video has a script' do
      let(:video) { create(:listing_video, website: website, realty_asset: property, script: 'Welcome to this beautiful home.') }

      it 'displays the script' do
        get site_admin_listing_video_path(video)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Welcome to this beautiful home')
      end
    end
  end

  describe 'POST /site_admin/listing_videos' do
    context 'with valid params' do
      let(:valid_params) do
        {
          listing_video: {
            property_id: property.id,
            format: 'vertical_9_16',
            style: 'professional',
            voice: 'nova'
          }
        }
      end

      it 'creates a video and redirects' do
        new_video = create(:listing_video, website: website, realty_asset: property)
        allow(Video::Generator).to receive(:new).and_return(
          double(generate: double(success?: true, video: new_video))
        )

        post site_admin_listing_videos_path, params: valid_params

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).to include('generation started')
      end
    end

    context 'without property selected' do
      it 'renders new with error' do
        post site_admin_listing_videos_path, params: { listing_video: {} }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Please select a property')
      end
    end

    context 'with property with insufficient photos' do
      let(:property_few_photos) do
        create(:pwb_realty_asset, website: website, street_address: '456 Oak Ave')
      end

      before do
        create(:pwb_prop_photo, :with_image, realty_asset: property_few_photos)  # Only 1 photo
      end

      it 'renders new with error' do
        post site_admin_listing_videos_path, params: {
          listing_video: { property_id: property_few_photos.id }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('at least 3 photos')
      end
    end
  end

  describe 'DELETE /site_admin/listing_videos/:id' do
    let!(:video) { create(:listing_video, website: website, realty_asset: property) }

    it 'deletes the video' do
      expect {
        delete site_admin_listing_video_path(video)
      }.to change(Pwb::ListingVideo, :count).by(-1)

      expect(response).to redirect_to(site_admin_listing_videos_path)
      follow_redirect!
      expect(response.body).to include('deleted')
    end
  end

  describe 'POST /site_admin/listing_videos/:id/regenerate' do
    let(:video) { create(:listing_video, :completed, website: website, realty_asset: property) }

    it 'regenerates the video' do
      new_video = create(:listing_video, website: website, realty_asset: property)
      allow(Video::Generator).to receive(:new).and_return(
        double(generate: double(success?: true, video: new_video))
      )

      post regenerate_site_admin_listing_video_path(video)

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('regeneration started')
    end
  end

  describe 'POST /site_admin/listing_videos/:id/share' do
    context 'when video is completed' do
      let(:video) { create(:listing_video, :completed, website: website, realty_asset: property) }

      it 'generates a share link' do
        post share_site_admin_listing_video_path(video)

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        follow_redirect!
        expect(response.body).to include('shared')
        expect(video.reload.share_token).to be_present
      end
    end

    context 'when video is not completed' do
      let(:video) { create(:listing_video, website: website, realty_asset: property, status: 'pending') }

      it 'shows error' do
        post share_site_admin_listing_video_path(video)

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        follow_redirect!
        expect(response.body).to include('must be completed')
      end
    end
  end

  describe 'GET /site_admin/listing_videos/:id/download' do
    context 'when video is ready' do
      let(:video) { create(:listing_video, :completed, website: website, realty_asset: property) }

      it 'redirects to video URL' do
        get download_site_admin_listing_video_path(video)

        expect(response).to redirect_to(video.video_url)
      end
    end

    context 'when video is not ready' do
      let(:video) { create(:listing_video, website: website, realty_asset: property, status: 'pending') }

      it 'shows error' do
        get download_site_admin_listing_video_path(video)

        expect(response).to redirect_to(site_admin_listing_video_path(video))
        follow_redirect!
        expect(response.body).to include('not ready')
      end
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:pwb_website) }
    let(:other_property) { create(:pwb_realty_asset, website: other_website) }
    let!(:other_video) { create(:listing_video, website: other_website, realty_asset: other_property) }

    it 'does not show videos from other websites' do
      get site_admin_listing_videos_path

      expect(response.body).not_to include(other_video.reference_number)
    end

    it 'cannot access videos from other websites' do
      get site_admin_listing_video_path(other_video)
      expect(response).to have_http_status(:not_found)
    rescue ActiveRecord::RecordNotFound
      # Expected behavior - exception is raised before rescue_from handles it
    end
  end

  context 'when not authenticated' do
    before { sign_out user }

    it 'returns forbidden' do
      get site_admin_listing_videos_path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
