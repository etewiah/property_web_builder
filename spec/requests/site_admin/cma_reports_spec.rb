# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::CmaReports', type: :request do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user, :admin, website: website) }
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

    # Sign in user
    sign_in user
  end

  describe 'GET /site_admin/cma_reports' do
    let!(:report1) { create(:pwb_market_report, :completed, website: website) }
    let!(:report2) { create(:pwb_market_report, website: website) }

    it 'renders the index page' do
      get site_admin_cma_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('CMA Reports')
    end

    it 'lists all CMA reports' do
      get site_admin_cma_reports_path

      expect(response.body).to include(report1.reference_number)
      expect(response.body).to include(report2.reference_number)
    end

    context 'with search filter' do
      it 'filters reports by search term' do
        get site_admin_cma_reports_path, params: { search: report1.reference_number }

        expect(response.body).to include(report1.reference_number)
      end
    end

    context 'with status filter' do
      it 'filters reports by status' do
        get site_admin_cma_reports_path, params: { status: 'completed' }

        expect(response.body).to include(report1.reference_number)
        expect(response.body).not_to include(report2.reference_number)
      end
    end

    context 'with reports from different website' do
      let(:other_website) { create(:pwb_website) }
      let!(:other_report) { create(:pwb_market_report, website: other_website) }

      it 'does not show reports from other websites' do
        get site_admin_cma_reports_path

        expect(response.body).not_to include(other_report.reference_number)
      end
    end
  end

  describe 'GET /site_admin/cma_reports/:id' do
    let(:report) { create(:pwb_market_report, :completed, website: website) }

    it 'renders the show page' do
      get site_admin_cma_report_path(report)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(report.reference_number)
      expect(response.body).to include(report.title)
    end

    context 'when report not found' do
      it 'returns not found' do
        get site_admin_cma_report_path(id: 999999)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /site_admin/cma_reports/new' do
    before do
      property # ensure property exists
    end

    it 'renders the new form' do
      get new_site_admin_cma_report_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Generate CMA Report')
    end

    it 'shows available properties' do
      get new_site_admin_cma_report_path

      expect(response.body).to include(property.street_address)
    end
  end

  describe 'POST /site_admin/cma_reports' do
    before do
      # Mock AI service
      allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
      allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!).and_return(true)

      # Mock AI response for insights generator
      mock_response = double(
        content: {
          executive_summary: 'Test summary',
          market_position: 'Average position',
          pricing_rationale: 'Based on data',
          strengths: ['Good location'],
          considerations: ['Needs work'],
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
        post site_admin_cma_reports_path, params: {
          cma_report: {
            property_id: property.id,
            radius_km: 2
          }
        }
      }.to change(Pwb::MarketReport, :count).by(1)
    end

    it 'redirects to the report on success' do
      post site_admin_cma_reports_path, params: {
        cma_report: {
          property_id: property.id,
          radius_km: 2
        }
      }

      expect(response).to redirect_to(site_admin_cma_report_path(Pwb::MarketReport.last))
      follow_redirect!
      expect(response.body).to include('generated successfully')
    end

    context 'when property not selected' do
      it 'renders new form with error' do
        post site_admin_cma_reports_path, params: {
          cma_report: { property_id: '' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Please select a property')
      end
    end

    context 'when AI is not configured' do
      before do
        allow_any_instance_of(Reports::CmaGenerator).to receive(:generate)
          .and_raise(Ai::ConfigurationError, 'AI not configured')
      end

      it 'redirects to integrations page' do
        post site_admin_cma_reports_path, params: {
          cma_report: { property_id: property.id }
        }

        expect(response).to redirect_to(site_admin_integrations_path)
        follow_redirect!
        expect(response.body).to include('AI is not configured')
      end
    end
  end

  describe 'DELETE /site_admin/cma_reports/:id' do
    let!(:report) { create(:pwb_market_report, website: website) }

    it 'deletes the report' do
      expect {
        delete site_admin_cma_report_path(report)
      }.to change(Pwb::MarketReport, :count).by(-1)
    end

    it 'redirects to index with notice' do
      delete site_admin_cma_report_path(report)

      expect(response).to redirect_to(site_admin_cma_reports_path)
      follow_redirect!
      expect(response.body).to include('deleted')
    end
  end

  describe 'POST /site_admin/cma_reports/:id/regenerate' do
    let!(:report) { create(:pwb_market_report, :completed, :with_subject_property, website: website) }

    before do
      allow_any_instance_of(Ai::BaseService).to receive(:configured?).and_return(true)
      allow_any_instance_of(Ai::BaseService).to receive(:ensure_configured!).and_return(true)

      mock_response = double(
        content: { executive_summary: 'Regenerated' }.to_json,
        input_tokens: 1500,
        output_tokens: 500
      )
      allow_any_instance_of(Reports::CmaInsightsGenerator).to receive(:chat).and_return(mock_response)
    end

    it 'creates a new report' do
      expect {
        post regenerate_site_admin_cma_report_path(report)
      }.to change(Pwb::MarketReport, :count).by(1)
    end

    it 'redirects to the new report' do
      post regenerate_site_admin_cma_report_path(report)

      new_report = Pwb::MarketReport.order(created_at: :desc).first
      expect(response).to redirect_to(site_admin_cma_report_path(new_report))
    end
  end

  describe 'POST /site_admin/cma_reports/:id/share' do
    let(:report) { create(:pwb_market_report, :completed, website: website) }

    it 'marks the report as shared' do
      post share_site_admin_cma_report_path(report)

      report.reload
      expect(report.status).to eq('shared')
      expect(report.share_token).to be_present
    end

    it 'redirects with notice containing share URL' do
      post share_site_admin_cma_report_path(report)

      expect(response).to redirect_to(site_admin_cma_report_path(report))
      follow_redirect!
      expect(response.body).to include('shared')
    end

    context 'when report is draft' do
      let(:draft_report) { create(:pwb_market_report, status: 'draft', website: website) }

      it 'shows error' do
        post share_site_admin_cma_report_path(draft_report)

        expect(response).to redirect_to(site_admin_cma_report_path(draft_report))
        follow_redirect!
        expect(response.body).to include('must be completed')
      end
    end
  end

  describe 'GET /site_admin/cma_reports/:id/download' do
    context 'when PDF is ready' do
      let(:report) { create(:pwb_market_report, :completed, :with_pdf, website: website) }

      it 'redirects to PDF download' do
        get download_site_admin_cma_report_path(report)

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when PDF is not ready' do
      let(:report) { create(:pwb_market_report, :completed, website: website) }

      before do
        allow_any_instance_of(Reports::PdfGenerator).to receive(:generate)
      end

      it 'generates PDF on the fly' do
        expect_any_instance_of(Reports::PdfGenerator).to receive(:generate)

        get download_site_admin_cma_report_path(report)
      end
    end
  end

  context 'when not authenticated' do
    before { sign_out user }

    it 'redirects to login' do
      get site_admin_cma_reports_path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
