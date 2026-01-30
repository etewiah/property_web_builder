# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::AiDescriptions', type: :request do
  let!(:website) { create(:pwb_website) }
  let!(:property) { create(:pwb_realty_asset, :with_sale_listing, website: website) }

  # Mock LLM response (RubyLLM::Message format)
  let(:mock_llm_response) do
    double(
      'RubyLLM::Message',
      content: mock_json_content,
      input_tokens: 100,
      output_tokens: 150,
      role: :assistant
    )
  end

  let(:mock_json_content) do
    {
      title: 'Beautiful Modern Apartment',
      description: 'Spacious 2-bedroom apartment with stunning views.',
      meta_description: '2-bed apartment in Test City.'
    }.to_json
  end

  # Mock chat instance that returns the response when asked
  let(:mock_chat_instance) do
    instance = double('RubyLLM::Chat')
    allow(instance).to receive(:with_instructions).and_return(instance)
    allow(instance).to receive(:ask).and_return(mock_llm_response)
    instance
  end

  before do
    host! "#{website.subdomain}.example.com"

    # Configure AI
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-api-key')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY', anything).and_return('test-api-key')

    # Mock RubyLLM.chat to return a chat instance
    allow(RubyLLM).to receive(:chat).and_return(mock_chat_instance)
  end

  describe 'POST /api_manage/v1/:locale/properties/:property_id/ai_description' do
    let(:endpoint) { "/api_manage/v1/en/properties/#{property.id}/ai_description" }
    let(:valid_params) { { locale: 'en', tone: 'professional' } }

    context 'with valid request' do
      it 'returns success status' do
        post endpoint, params: valid_params, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'returns generated content' do
        post endpoint, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['success']).to be(true)
        expect(json['title']).to eq('Beautiful Modern Apartment')
        expect(json['description']).to include('2-bedroom')
        expect(json['meta_description']).to include('2-bed')
      end

      it 'includes compliance information' do
        post endpoint, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['compliance']).to be_present
        expect(json['compliance']['compliant']).to be(true)
      end

      it 'includes request_id for tracking' do
        post endpoint, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['request_id']).to be_present
      end

      it 'creates an AiGenerationRequest record' do
        expect {
          post endpoint, params: valid_params, as: :json
        }.to change(Pwb::AiGenerationRequest, :count).by(1)
      end
    end

    context 'with different tones' do
      %w[professional casual luxury warm modern].each do |tone|
        it "accepts #{tone} tone" do
          post endpoint, params: { tone: tone }, as: :json
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with different locales' do
      %w[en es fr de].each do |locale|
        it "accepts #{locale} locale" do
          post "/api_manage/v1/#{locale}/properties/#{property.id}/ai_description",
               params: { locale: locale },
               as: :json
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with non-existent property' do
      it 'returns 404' do
        post '/api_manage/v1/en/properties/non-existent-id/ai_description',
             params: valid_params,
             as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with property from different website' do
      let(:other_website) { create(:pwb_website) }
      let(:other_property) { create(:pwb_realty_asset, :with_sale_listing, website: other_website) }

      it 'returns 404 for cross-tenant access' do
        post "/api_manage/v1/en/properties/#{other_property.id}/ai_description",
             params: valid_params,
             as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    # Note: Testing "AI not configured" is difficult in request specs because
    # ENV stubs are applied at a different level. The service layer handles this
    # correctly and is tested in the service specs.

    context 'when rate limited' do
      before do
        # RubyLLM::RateLimitError takes (response, message) as args
        error = RubyLLM::RateLimitError.new(nil, 'Rate limit exceeded')
        allow(RubyLLM).to receive(:chat).and_raise(error)
      end

      it 'returns too many requests status' do
        post endpoint, params: valid_params, as: :json
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'includes retry information' do
        post endpoint, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['error']).to include('Rate limit')
      end
    end

    context 'when LLM returns invalid JSON' do
      let(:mock_json_content) { 'Not valid JSON at all' }

      it 'returns unprocessable entity' do
        post endpoint, params: valid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        post endpoint, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['success']).to be(false)
        expect(json['error']).to be_present
      end
    end
  end

  describe 'GET /api_manage/v1/:locale/properties/:property_id/ai_description/history' do
    let(:history_endpoint) { "/api_manage/v1/en/properties/#{property.id}/ai_description/history" }

    context 'with no previous requests' do
      it 'returns empty array' do
        get history_endpoint
        json = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(json['requests']).to eq([])
      end
    end

    context 'with previous requests' do
      before do
        # Create some generation requests
        3.times do |i|
          Pwb::AiGenerationRequest.create!(
            website: website,
            request_type: 'listing_description',
            status: 'completed',
            locale: 'en',
            input_data: { property_id: property.id, property_class: 'Pwb::RealtyAsset' },
            output_data: {
              title: "Title #{i}",
              description: "Description #{i}",
              meta_description: "Meta #{i}",
              compliance: { compliant: true, violations: [] }
            }
          )
        end
      end

      it 'returns request history' do
        get history_endpoint
        json = JSON.parse(response.body)

        expect(json['requests'].length).to eq(3)
      end

      it 'orders by created_at desc' do
        get history_endpoint
        json = JSON.parse(response.body)

        created_times = json['requests'].map { |r| r['created_at'] }
        expect(created_times).to eq(created_times.sort.reverse)
      end

      it 'includes request details' do
        get history_endpoint
        json = JSON.parse(response.body)

        first_request = json['requests'].first
        expect(first_request).to have_key('id')
        expect(first_request).to have_key('status')
        expect(first_request).to have_key('locale')
        expect(first_request).to have_key('created_at')
      end
    end

    context 'with requests from different types' do
      before do
        # Create a listing_description request
        Pwb::AiGenerationRequest.create!(
          website: website,
          request_type: 'listing_description',
          status: 'completed',
          locale: 'en',
          input_data: { property_id: property.id, property_class: 'Pwb::RealtyAsset' }
        )

        # Create a different type of request (should be filtered out)
        Pwb::AiGenerationRequest.create!(
          website: website,
          request_type: 'social_post',
          status: 'completed',
          locale: 'en',
          input_data: { property_id: property.id, property_class: 'Pwb::RealtyAsset' }
        )
      end

      it 'only returns listing_description requests' do
        get history_endpoint
        json = JSON.parse(response.body)

        expect(json['requests'].length).to eq(1)
      end
    end

    context 'limits results' do
      before do
        15.times do
          Pwb::AiGenerationRequest.create!(
            website: website,
            request_type: 'listing_description',
            status: 'completed',
            locale: 'en',
            input_data: { property_id: property.id, property_class: 'Pwb::RealtyAsset' }
          )
        end
      end

      it 'returns maximum of 10 requests' do
        get history_endpoint
        json = JSON.parse(response.body)

        expect(json['requests'].length).to eq(10)
      end
    end
  end
end
