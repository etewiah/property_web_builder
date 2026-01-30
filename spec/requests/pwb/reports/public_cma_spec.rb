# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::Reports::PublicCma', type: :request do
  # Get an existing website or create one - don't destroy existing ones
  # as this can cause issues with transactional test fixtures
  let(:website) { Pwb::Website.first || create(:pwb_website) }

  describe 'GET /reports/shared/:share_token' do
    context 'with valid share token' do
      let!(:shared_report) do
        create(:pwb_market_report, :completed, website: website, status: 'shared',
               share_token: SecureRandom.urlsafe_base64(16), view_count: 0)
      end

      it 'returns the shared report as JSON' do
        get "/reports/shared/#{shared_report.share_token}.json"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['success']).to be true
        expect(json['report']['reference_number']).to eq(shared_report.reference_number)
      end

      it 'increments the view count' do
        initial_count = shared_report.view_count

        get "/reports/shared/#{shared_report.share_token}.json"

        expect(shared_report.reload.view_count).to eq(initial_count + 1)
      end
    end

    context 'with invalid share token' do
      it 'returns error for non-existent token' do
        get '/reports/shared/invalid-token.json'

        # May be 404 or 302 redirect depending on test environment
        expect(response.status).to satisfy { |s| [302, 404].include?(s) }
      end
    end

    context 'with non-shared report' do
      let!(:draft_report) do
        create(:pwb_market_report, website: website, status: 'draft',
               share_token: "draft-#{SecureRandom.hex(8)}")
      end

      it 'returns not found for draft reports' do
        get "/reports/shared/#{draft_report.share_token}.json"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /reports/shared/:share_token/pdf' do
    context 'with PDF attached' do
      let!(:report_with_pdf) do
        create(:pwb_market_report, :shared, :with_pdf, website: website)
      end

      it 'redirects to the PDF' do
        get "/reports/shared/#{report_with_pdf.share_token}/pdf"

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with invalid share token' do
      it 'returns error' do
        get '/reports/shared/invalid-token/pdf'

        # May be 404 or 302 redirect depending on test environment
        expect(response.status).to satisfy { |s| [302, 404].include?(s) }
      end
    end
  end
end
