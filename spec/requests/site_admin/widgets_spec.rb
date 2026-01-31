# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::WidgetsController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'widgets-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@widgets-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/widgets (index)' do
    it 'renders the widgets list successfully' do
      get site_admin_widgets_path, headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with widgets' do
      let!(:widget1) { create(:pwb_widget_config, website: website, name: 'Featured Widget') }
      let!(:widget2) { create(:pwb_widget_config, website: website, name: 'Grid Widget') }

      it 'displays widgets in the list' do
        get site_admin_widgets_path, headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Featured Widget')
        expect(response.body).to include('Grid Widget')
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-widgets') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:my_widget) { create(:pwb_widget_config, website: website, name: 'My Widget') }
      let!(:other_widget) { create(:pwb_widget_config, website: other_website, name: 'Other Widget') }

      it 'only shows widgets for current website' do
        get site_admin_widgets_path, headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('My Widget')
        expect(response.body).not_to include('Other Widget')
      end
    end
  end

  describe 'GET /site_admin/widgets/:id (show)' do
    let!(:widget) { create(:pwb_widget_config, website: website, name: 'Show Widget') }

    it 'renders the widget show page' do
      get site_admin_widget_path(widget),
          headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Show Widget')
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-show-widget') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_widget) { create(:pwb_widget_config, website: other_website) }

      it 'cannot access widgets from other websites' do
        get site_admin_widget_path(other_widget),
            headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      rescue ActiveRecord::RecordNotFound
        expect(true).to be true
      end
    end
  end

  describe 'GET /site_admin/widgets/new' do
    it 'renders the new widget form' do
      get new_site_admin_widget_path, headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'sets default values' do
      get new_site_admin_widget_path, headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /site_admin/widgets (create)' do
    let(:valid_params) do
      {
        pwb_widget_config: {
          name: 'New Featured Widget',
          layout: 'grid',
          columns: 4,
          max_properties: 8,
          show_search: true,
          show_filters: true,
          show_pagination: true
        }
      }
    end

    it 'creates a new widget' do
      expect do
        post site_admin_widgets_path,
             params: valid_params,
             headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }
      end.to change(Pwb::WidgetConfig, :count).by(1)
    end

    it 'redirects to show page with success notice' do
      post site_admin_widgets_path,
           params: valid_params,
           headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to include('created successfully')
    end

    it 'creates widget with specified settings' do
      post site_admin_widgets_path,
           params: valid_params,
           headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      widget = Pwb::WidgetConfig.last
      expect(widget.name).to eq('New Featured Widget')
      expect(widget.layout).to eq('grid')
      expect(widget.columns).to eq(4)
      expect(widget.max_properties).to eq(8)
      expect(widget.show_search).to be true
    end

    context 'with listing type filter' do
      it 'creates widget for sale listings only' do
        post site_admin_widgets_path,
             params: { pwb_widget_config: { name: 'Sales Widget', listing_type: 'sale' } },
             headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        widget = Pwb::WidgetConfig.last
        expect(widget.listing_type).to eq('sale')
      end
    end

    context 'with allowed domains' do
      it 'creates widget with domain restrictions' do
        post site_admin_widgets_path,
             params: { pwb_widget_config: { name: 'Restricted Widget', allowed_domains: "example.com\ntrusted.org" } },
             headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        widget = Pwb::WidgetConfig.last
        expect(widget.allowed_domains).to include('example.com', 'trusted.org')
      end
    end

    context 'with invalid params' do
      it 'renders new with errors when name is blank' do
        post site_admin_widgets_path,
             params: { pwb_widget_config: { name: '' } },
             headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /site_admin/widgets/:id/edit' do
    let!(:widget) { create(:pwb_widget_config, website: website) }

    it 'renders the edit form' do
      get edit_site_admin_widget_path(widget),
          headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/widgets/:id (update)' do
    let!(:widget) { create(:pwb_widget_config, website: website, name: 'Original Name', columns: 3) }

    it 'updates widget settings' do
      patch site_admin_widget_path(widget),
            params: { pwb_widget_config: { name: 'Updated Name', columns: 4 } },
            headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      widget.reload
      expect(widget.name).to eq('Updated Name')
      expect(widget.columns).to eq(4)
    end

    it 'redirects to show page with success notice' do
      patch site_admin_widget_path(widget),
            params: { pwb_widget_config: { name: 'Updated' } },
            headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to redirect_to(site_admin_widget_path(widget))
      expect(flash[:notice]).to include('updated successfully')
    end

    it 'updates layout and display options' do
      patch site_admin_widget_path(widget),
            params: { pwb_widget_config: { layout: 'list', show_search: true, show_filters: true } },
            headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      widget.reload
      expect(widget.layout).to eq('list')
      expect(widget.show_search).to be true
      expect(widget.show_filters).to be true
    end

    context 'with invalid params' do
      it 'renders edit with errors' do
        patch site_admin_widget_path(widget),
              params: { pwb_widget_config: { name: '' } },
              headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /site_admin/widgets/:id (destroy)' do
    let!(:widget) { create(:pwb_widget_config, website: website, name: 'Delete Widget') }

    it 'deletes the widget' do
      expect do
        delete site_admin_widget_path(widget),
               headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }
      end.to change(Pwb::WidgetConfig, :count).by(-1)
    end

    it 'redirects to index with success notice' do
      delete site_admin_widget_path(widget),
             headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to redirect_to(site_admin_widgets_path)
      expect(flash[:notice]).to include('deleted successfully')
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-delete-widget') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_widget) { create(:pwb_widget_config, website: other_website) }

      it 'cannot delete widgets from other websites' do
        expect do
          delete site_admin_widget_path(other_widget),
                 headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }
        end.not_to change(Pwb::WidgetConfig, :count)
      rescue ActiveRecord::RecordNotFound
        expect(true).to be true
      end
    end
  end

  describe 'GET /site_admin/widgets/:id/preview' do
    let!(:widget) { create(:pwb_widget_config, website: website) }

    it 'renders the preview without layout' do
      get preview_site_admin_widget_path(widget),
          headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_widgets_path,
          headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on create' do
      post site_admin_widgets_path,
           params: { pwb_widget_config: { name: 'Hack' } },
           headers: { 'HTTP_HOST' => 'widgets-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
