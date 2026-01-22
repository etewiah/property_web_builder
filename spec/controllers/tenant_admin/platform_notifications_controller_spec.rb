# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::PlatformNotificationsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns metrics' do
      get :index
      expect(assigns(:metrics)).to be_present
      expect(assigns(:metrics)).to have_key(:signups_today)
      expect(assigns(:metrics)).to have_key(:total_active_websites)
    end

    it 'assigns config_status' do
      get :index
      expect(assigns(:config_status)).to be_present
      expect(assigns(:config_status)).to have_key(:enabled)
      expect(assigns(:config_status)).to have_key(:server_url)
      expect(assigns(:config_status)).to have_key(:topic)
      expect(assigns(:config_status)).to have_key(:has_access_token)
    end
  end

  describe 'POST #test' do
    it 'calls PlatformNtfyService.test_configuration' do
      expect(PlatformNtfyService).to receive(:test_configuration).and_return(
        { success: true, message: 'Test sent' }
      )

      post :test
      expect(response).to redirect_to(tenant_admin_platform_notifications_path)
      expect(flash[:notice]).to include('Test')
    end

    context 'when test fails' do
      it 'shows error message' do
        allow(PlatformNtfyService).to receive(:test_configuration).and_return(
          { success: false, message: 'Not configured' }
        )

        post :test
        expect(response).to redirect_to(tenant_admin_platform_notifications_path)
        expect(flash[:alert]).to include('Not configured')
      end
    end
  end

  describe 'POST #send_daily_summary' do
    it 'calls PlatformNtfyService.notify_daily_summary' do
      expect(PlatformNtfyService).to receive(:notify_daily_summary).and_return(true)

      post :send_daily_summary
      expect(response).to redirect_to(tenant_admin_platform_notifications_path)
      expect(flash[:notice]).to include('summary sent')
    end
  end

  describe 'POST #send_test_alert' do
    it 'sends a test alert with provided params' do
      expect(PlatformNtfyService).to receive(:notify_system_alert).with(
        'Custom Title',
        'Custom Message',
        priority: 5
      ).and_return(true)

      post :send_test_alert, params: {
        title: 'Custom Title',
        message: 'Custom Message',
        priority: '5'
      }

      expect(response).to redirect_to(tenant_admin_platform_notifications_path)
      expect(flash[:notice]).to include('alert sent')
    end

    it 'uses default values when params are missing' do
      expect(PlatformNtfyService).to receive(:notify_system_alert).with(
        'Test Alert',
        'This is a test alert from the admin panel',
        priority: 3
      ).and_return(true)

      post :send_test_alert
      expect(response).to redirect_to(tenant_admin_platform_notifications_path)
    end
  end
end
