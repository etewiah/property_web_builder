# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Navigation Routes', type: :request do
  let(:plan) { create(:pwb_plan, features: %w[analytics custom_domain]) }
  let(:website) { create(:website) }
  let!(:subscription) { create(:pwb_subscription, :active, website: website, plan: plan) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    sign_in admin_user
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
    allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
  end

  describe 'Dashboard' do
    it 'responds to dashboard path' do
      get site_admin_root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Listings section routes (currently Content Management)' do
    it 'responds to props path (All Properties/Listings)' do
      get site_admin_props_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to new prop path (Add Property/Listing)' do
      get new_site_admin_prop_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to property import/export path' do
      get site_admin_property_import_export_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to external feed path' do
      get site_admin_external_feed_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to properties settings path (Labels)' do
      get site_admin_properties_settings_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Leads & Messages section routes (currently Communication)' do
    it 'responds to inbox path' do
      get site_admin_inbox_index_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to contacts path' do
      get site_admin_contacts_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to messages path' do
      get site_admin_messages_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to email templates path' do
      get site_admin_email_templates_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to support tickets path' do
      get site_admin_support_tickets_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Site Design section routes (currently Website)' do
    it 'responds to website settings appearance tab' do
      get site_admin_website_settings_tab_path('appearance')
      expect(response.status).to be_in([200, 302])
    end

    it 'responds to pages path' do
      get site_admin_pages_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to media library path' do
      get site_admin_media_library_index_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to website settings SEO tab' do
      get site_admin_website_settings_tab_path('seo')
      expect(response.status).to be_in([200, 302])
    end

    it 'responds to widgets path' do
      get site_admin_widgets_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to domain path' do
      get site_admin_domain_path
      # May redirect to billing if feature not available
      expect(response.status).to be_in([200, 302])
    end

    it 'responds to onboarding path (Setup Wizard)' do
      get site_admin_onboarding_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Insights section routes' do
    it 'responds to analytics path' do
      get site_admin_analytics_path
      # May redirect to billing if feature not available
      expect(response.status).to be_in([200, 302])
    end

    it 'responds to activity logs path' do
      get site_admin_activity_logs_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to SEO audit path' do
      get site_admin_seo_audit_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to storage stats path' do
      get site_admin_storage_stats_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Settings section routes (currently User Management + Website)' do
    it 'responds to users path (Team & Users)' do
      get site_admin_users_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to edit agency path (Agency Profile)' do
      get edit_site_admin_agency_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to billing path' do
      get site_admin_billing_path
      expect(response).to have_http_status(:success)
    end

    it 'responds to website settings path' do
      get site_admin_website_settings_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'route helpers existence' do
    it 'defines all expected route helpers' do
      expected_helpers = %i[
        site_admin_root_path
        site_admin_props_path
        new_site_admin_prop_path
        site_admin_property_import_export_path
        site_admin_external_feed_path
        site_admin_properties_settings_path
        site_admin_inbox_index_path
        site_admin_contacts_path
        site_admin_messages_path
        site_admin_email_templates_path
        site_admin_support_tickets_path
        site_admin_pages_path
        site_admin_media_library_index_path
        site_admin_widgets_path
        site_admin_domain_path
        site_admin_onboarding_path
        site_admin_analytics_path
        site_admin_activity_logs_path
        site_admin_seo_audit_path
        site_admin_storage_stats_path
        site_admin_users_path
        edit_site_admin_agency_path
        site_admin_billing_path
        site_admin_website_settings_path
      ]

      expected_helpers.each do |helper|
        expect(Rails.application.routes.url_helpers).to respond_to(helper),
          "Expected route helper #{helper} to exist"
      end
    end
  end
end
