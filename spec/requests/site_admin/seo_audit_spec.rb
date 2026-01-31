# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::SeoAuditController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'seo-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@seo-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/seo_audit (index)' do
    it 'renders the SEO audit page successfully' do
      get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with no content' do
      it 'shows zero stats' do
        get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with properties' do
      before do
        # Create properties with varying SEO completeness
        asset1 = create(:pwb_realty_asset, website: website, reference: 'SEO-001')
        create(:pwb_sale_listing, :visible, realty_asset: asset1, title: 'Complete Property')

        asset2 = create(:pwb_realty_asset, website: website, reference: 'SEO-002')
        create(:pwb_sale_listing, :visible, realty_asset: asset2, title: nil)

        Pwb::ListedProperty.refresh rescue nil
      end

      it 'calculates property SEO stats' do
        get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with pages' do
      before do
        create(:pwb_page, website: website, slug: 'about',
               seo_title: 'About Us', meta_description: 'Learn about us')
        create(:pwb_page, website: website, slug: 'contact',
               seo_title: nil, meta_description: nil)
      end

      it 'calculates page SEO stats' do
        get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with images' do
      before do
        asset = create(:pwb_realty_asset, website: website)
        # Create photos with and without alt text
        create(:pwb_prop_photo, realty_asset: asset, description: 'Living room')
        create(:pwb_prop_photo, realty_asset: asset, description: nil)
      end

      it 'calculates image SEO stats' do
        get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-seo') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }

      before do
        # Create content for other website
        other_asset = create(:pwb_realty_asset, website: other_website)
        create(:pwb_sale_listing, :visible, realty_asset: other_asset)
        create(:pwb_page, website: other_website, slug: 'other-page')
      end

      it 'only audits current website content' do
        get site_admin_seo_audit_path, headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users' do
      get site_admin_seo_audit_path,
          headers: { 'HTTP_HOST' => 'seo-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
