# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::Ai::SocialPosts', type: :request do
  let!(:website) { create(:pwb_website) }
  let!(:property) { create(:pwb_realty_asset, website: website) }

  # Mock LLM response
  let(:mock_llm_response) do
    double(
      'RubyLLM::Message',
      content: '{"caption": "Check out this property!", "hashtags": "#realestate #home", "suggested_photos": ["exterior"], "best_posting_time": "10am"}',
      input_tokens: 100,
      output_tokens: 50,
      role: :assistant
    )
  end

  let(:mock_chat_instance) do
    instance = double('RubyLLM::Chat')
    allow(instance).to receive(:with_instructions).and_return(instance)
    allow(instance).to receive(:ask).and_return(mock_llm_response)
    instance
  end

  before do
    # Set subdomain for tenant resolution (using localhost which is a platform domain)
    host! "#{website.subdomain}.localhost"

    # Also set tenant directly for ActsAsTenant-scoped queries
    ActsAsTenant.current_tenant = website

    # Configure AI
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-api-key')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', anything).and_return('test-api-key')

    # Mock RubyLLM.chat to return a chat instance
    allow(RubyLLM).to receive(:chat).and_return(mock_chat_instance)
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /api_manage/v1/:locale/ai/social_posts' do
    let!(:post1) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }
    let!(:post2) { create(:pwb_social_media_post, :facebook, website: website, postable: property) }

    it 'returns a list of social posts' do
      get '/api_manage/v1/en/ai/social_posts'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['posts'].length).to eq(2)
    end

    it 'filters by platform' do
      get '/api_manage/v1/en/ai/social_posts', params: { platform: 'instagram' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['posts'].length).to eq(1)
      expect(json['posts'][0]['platform']).to eq('instagram')
    end

    it 'filters by status' do
      create(:pwb_social_media_post, :instagram, :scheduled, website: website, postable: property)

      get '/api_manage/v1/en/ai/social_posts', params: { status: 'scheduled' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['posts'].length).to eq(1)
      expect(json['posts'][0]['status']).to eq('scheduled')
    end
  end

  describe 'POST /api_manage/v1/:locale/ai/social_posts' do
    it 'creates a new social post' do
      expect {
        post '/api_manage/v1/en/ai/social_posts', params: {
          property_id: property.id,
          platform: 'instagram',
          category: 'just_listed'
        }
      }.to change(Pwb::SocialMediaPost, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['post']['platform']).to eq('instagram')
    end

    context 'when AI is not configured' do
      before do
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
        allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', anything).and_return(nil)
      end

      it 'returns service unavailable' do
        post '/api_manage/v1/en/ai/social_posts', params: {
          property_id: property.id,
          platform: 'instagram'
        }

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('not configured')
      end
    end
  end

  describe 'POST /api_manage/v1/:locale/ai/social_posts/batch_generate' do
    it 'generates posts for multiple platforms' do
      expect {
        post '/api_manage/v1/en/ai/social_posts/batch_generate', params: {
          property_id: property.id,
          platforms: %w[instagram facebook linkedin]
        }
      }.to change(Pwb::SocialMediaPost, :count).by(3)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['posts'].length).to eq(3)

      platforms = json['posts'].map { |p| p['platform'] }
      expect(platforms).to contain_exactly('instagram', 'facebook', 'linkedin')
    end
  end

  describe 'GET /api_manage/v1/:locale/ai/social_posts/:id' do
    let!(:social_post) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }

    it 'returns the post with images' do
      get "/api_manage/v1/en/ai/social_posts/#{social_post.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['post']['id']).to eq(social_post.id)
      expect(json['post']['platform']).to eq('instagram')
    end
  end

  describe 'PATCH /api_manage/v1/:locale/ai/social_posts/:id' do
    let!(:social_post) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }

    it 'updates the post' do
      patch "/api_manage/v1/en/ai/social_posts/#{social_post.id}", params: {
        post: { caption: 'Updated caption' }
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['post']['caption']).to eq('Updated caption')
    end
  end

  describe 'DELETE /api_manage/v1/:locale/ai/social_posts/:id' do
    let!(:social_post) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }

    it 'deletes the post' do
      expect {
        delete "/api_manage/v1/en/ai/social_posts/#{social_post.id}"
      }.to change(Pwb::SocialMediaPost, :count).by(-1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end

  describe 'POST /api_manage/v1/:locale/ai/social_posts/:id/duplicate' do
    let!(:social_post) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }

    it 'duplicates the post' do
      expect {
        post "/api_manage/v1/en/ai/social_posts/#{social_post.id}/duplicate", params: {
          target_platform: 'facebook'
        }
      }.to change(Pwb::SocialMediaPost, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['post']['platform']).to eq('facebook')
      expect(json['post']['caption']).to eq(social_post.caption)
    end
  end

  describe 'PATCH /api_manage/v1/:locale/ai/social_posts/:id/schedule' do
    let!(:social_post) { create(:pwb_social_media_post, :instagram, website: website, postable: property) }

    it 'schedules the post' do
      scheduled_time = 1.week.from_now.iso8601

      patch "/api_manage/v1/en/ai/social_posts/#{social_post.id}/schedule", params: {
        scheduled_at: scheduled_time
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['post']['status']).to eq('scheduled')
    end

    it 'returns error for invalid time' do
      patch "/api_manage/v1/en/ai/social_posts/#{social_post.id}/schedule", params: {
        scheduled_at: 'invalid'
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:website) }
    let(:other_property) { create(:pwb_realty_asset, website: other_website) }
    let!(:other_post) { create(:pwb_social_media_post, :instagram, website: other_website, postable: other_property) }

    it 'cannot access posts from other websites' do
      get "/api_manage/v1/en/ai/social_posts/#{other_post.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot delete posts from other websites' do
      expect {
        delete "/api_manage/v1/en/ai/social_posts/#{other_post.id}"
      }.not_to change(Pwb::SocialMediaPost, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
