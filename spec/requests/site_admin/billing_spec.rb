# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::BillingController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'billing-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@billing-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/billing (show)' do
    it 'renders the billing page successfully' do
      get site_admin_billing_path, headers: { 'HTTP_HOST' => 'billing-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'without subscription' do
      it 'shows billing page' do
        get site_admin_billing_path, headers: { 'HTTP_HOST' => 'billing-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with usage data' do
      before do
        # Create some properties and users
        create(:pwb_realty_asset, website: website)
        create(:pwb_realty_asset, website: website)
        create(:pwb_user, :with_membership, website: website, email: 'member@test.com')
      end

      it 'shows usage statistics' do
        get site_admin_billing_path, headers: { 'HTTP_HOST' => 'billing-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users' do
      get site_admin_billing_path,
          headers: { 'HTTP_HOST' => 'billing-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
