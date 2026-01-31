# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::TourController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'tour-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@tour-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'POST /site_admin/tour/complete' do
    it 'marks tour as completed' do
      post site_admin_tour_complete_path,
           headers: { 'HTTP_HOST' => 'tour-test.test.localhost' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns success JSON' do
      post site_admin_tour_complete_path,
           headers: { 'HTTP_HOST' => 'tour-test.test.localhost' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['message']).to include('completed')
    end

    it 'updates user onboarding timestamp' do
      expect(admin_user.site_admin_onboarding_completed_at).to be_nil

      post site_admin_tour_complete_path,
           headers: { 'HTTP_HOST' => 'tour-test.test.localhost' }

      admin_user.reload
      expect(admin_user.site_admin_onboarding_completed_at).to be_present
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users' do
      post site_admin_tour_complete_path,
           headers: { 'HTTP_HOST' => 'tour-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden).or have_http_status(:unauthorized)
    end
  end
end
