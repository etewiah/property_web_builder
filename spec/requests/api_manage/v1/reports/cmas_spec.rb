# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::Reports::Cmas', type: :request do
  let(:website) { create(:pwb_website) }
  let(:property) do
    create(:pwb_realty_asset, :with_location, :with_sale_listing,
           website: website,
           count_bedrooms: 3,
           count_bathrooms: 2,
           constructed_area: 150.0,
           city: 'Test City',
           street_address: '123 Main St')
  end

  before do
    # Set up multi-tenant context
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.example.com"
    Pwb::ListedProperty.refresh(concurrently: false)
  end

  describe 'GET /api_manage/v1/:locale/reports/cmas' do
    let!(:report1) { create(:pwb_market_report, :completed, website: website) }
    let!(:report2) { create(:pwb_market_report, website: website) }

    it 'returns list of CMA reports' do
      get '/api_manage/v1/en/reports/cmas'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['reports']).to be_an(Array)
      expect(json['reports'].length).to eq(2)
    end

    it 'returns reports in order of most recent first' do
      get '/api_manage/v1/en/reports/cmas'

      json = JSON.parse(response.body)
      timestamps = json['reports'].map { |r| Time.parse(r['created_at']) }

      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    context 'with reports from different website' do
      let(:other_website) { create(:pwb_website) }
      let!(:other_report) { create(:pwb_market_report, website: other_website) }

      it 'only returns reports from current website' do
        get '/api_manage/v1/en/reports/cmas'

        json = JSON.parse(response.body)
        report_ids = json['reports'].map { |r| r['id'] }

        expect(report_ids).to include(report1.id, report2.id)
        expect(report_ids).not_to include(other_report.id)
      end
    end
  end

  describe 'POST /api_manage/v1/:locale/reports/cmas' do
    before do
      allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
      allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!).and_return(true)

      # Mock AI response
      mock_response = double(
        content: {
          executive_summary: 'Property analysis complete.',
          market_position: 'Average market position.',
          pricing_rationale: 'Based on comparable sales.',
          strengths: ['Good location'],
          considerations: ['Needs updates'],
          recommendation: 'List at $350,000',
          time_to_sell_estimate: '45 days',
          suggested_price_low_cents: 330_000_00,
          suggested_price_high_cents: 370_000_00,
          confidence_level: 'medium'
        }.to_json,
        input_tokens: 1500,
        output_tokens: 500
      )
      allow_any_instance_of(Reports::CmaInsightsGenerator).to receive(:chat).and_return(mock_response)
    end

    it 'creates a new CMA report' do
      expect {
        post '/api_manage/v1/en/reports/cmas', params: { property_id: property.id }
      }.to change(Pwb::MarketReport, :count).by(1)
    end

    it 'returns success response' do
      post '/api_manage/v1/en/reports/cmas', params: { property_id: property.id }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['report']).to be_present
      expect(json['report']['reference_number']).to match(/CMA-\d{8}-[A-Z0-9]+/)
    end

    it 'accepts optional parameters' do
      post '/api_manage/v1/en/reports/cmas', params: {
        property_id: property.id,
        radius_km: 5,
        title: 'Custom Report Title',
        generate_pdf: false
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json['report']['title']).to eq('Custom Report Title')
    end

    context 'when property not found' do
      it 'returns not found error' do
        post '/api_manage/v1/en/reports/cmas', params: { property_id: 'invalid-id' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when property_id is missing' do
      it 'returns bad request error' do
        post '/api_manage/v1/en/reports/cmas', params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when AI is not configured' do
      before do
        allow_any_instance_of(Reports::CmaGenerator).to receive(:generate)
          .and_raise(Ai::ConfigurationError, 'AI not configured')
      end

      it 'returns service unavailable' do
        post '/api_manage/v1/en/reports/cmas', params: { property_id: property.id }

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['error']).to include('AI is not configured')
      end
    end

    context 'when rate limited' do
      before do
        allow_any_instance_of(Reports::CmaGenerator).to receive(:generate)
          .and_raise(Ai::RateLimitError.new('Rate limit exceeded', retry_after: 60))
      end

      it 'returns too many requests' do
        post '/api_manage/v1/en/reports/cmas', params: { property_id: property.id }

        expect(response).to have_http_status(:too_many_requests)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['retry_after']).to eq(60)
      end
    end
  end

  describe 'GET /api_manage/v1/:locale/reports/cmas/:id' do
    let(:report) { create(:pwb_market_report, :completed, website: website) }

    it 'returns the report with details' do
      get "/api_manage/v1/en/reports/cmas/#{report.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['report']['id']).to eq(report.id)
      expect(json['report']['statistics']).to be_present
      expect(json['report']['insights']).to be_present
    end

    context 'when report not found' do
      it 'returns not found error' do
        get '/api_manage/v1/en/reports/cmas/0'

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when report belongs to different website' do
      let(:other_website) { create(:pwb_website) }
      let(:other_report) { create(:pwb_market_report, website: other_website) }

      it 'returns not found error' do
        get "/api_manage/v1/en/reports/cmas/#{other_report.id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api_manage/v1/:locale/reports/cmas/:id' do
    let!(:report) { create(:pwb_market_report, website: website) }

    it 'deletes the report' do
      expect {
        delete "/api_manage/v1/en/reports/cmas/#{report.id}"
      }.to change(Pwb::MarketReport, :count).by(-1)
    end

    it 'returns success response' do
      delete "/api_manage/v1/en/reports/cmas/#{report.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['message']).to include('deleted')
    end
  end

  describe 'GET /api_manage/v1/:locale/reports/cmas/:id/pdf' do
    let(:report) { create(:pwb_market_report, :completed, :with_pdf, website: website) }

    it 'redirects to PDF download' do
      get "/api_manage/v1/en/reports/cmas/#{report.id}/pdf"

      expect(response).to have_http_status(:redirect)
    end

    context 'when PDF not ready' do
      let(:report_without_pdf) { create(:pwb_market_report, :completed, website: website) }

      before do
        # Mock PDF generator
        allow_any_instance_of(Reports::PdfGenerator).to receive(:generate)
      end

      it 'generates PDF on the fly' do
        expect_any_instance_of(Reports::PdfGenerator).to receive(:generate)

        get "/api_manage/v1/en/reports/cmas/#{report_without_pdf.id}/pdf"
      end
    end
  end

  describe 'POST /api_manage/v1/:locale/reports/cmas/:id/share' do
    let(:report) { create(:pwb_market_report, :completed, website: website) }

    it 'generates share link' do
      post "/api_manage/v1/en/reports/cmas/#{report.id}/share"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['share_token']).to be_present
      expect(json['share_url']).to include(json['share_token'])
    end

    it 'marks report as shared' do
      post "/api_manage/v1/en/reports/cmas/#{report.id}/share"

      report.reload
      expect(report.status).to eq('shared')
      expect(report.shared_at).to be_present
    end

    context 'when report is draft' do
      let(:draft_report) { create(:pwb_market_report, website: website, status: 'draft') }

      it 'returns error' do
        post "/api_manage/v1/en/reports/cmas/#{draft_report.id}/share"

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['error']).to include('must be completed')
      end
    end
  end
end
