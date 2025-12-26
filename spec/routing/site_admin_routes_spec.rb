# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Routes', type: :routing do
  describe 'Property Import/Export routes' do
    it 'routes GET /site_admin/property_import_export to property_import_export#index' do
      expect(get: '/site_admin/property_import_export').to route_to(
        controller: 'site_admin/property_import_export',
        action: 'index'
      )
    end

    it 'routes POST /site_admin/property_import_export/import to property_import_export#import' do
      expect(post: '/site_admin/property_import_export/import').to route_to(
        controller: 'site_admin/property_import_export',
        action: 'import'
      )
    end

    it 'routes GET /site_admin/property_import_export/export to property_import_export#export' do
      expect(get: '/site_admin/property_import_export/export').to route_to(
        controller: 'site_admin/property_import_export',
        action: 'export'
      )
    end

    it 'routes GET /site_admin/property_import_export/download_template to property_import_export#download_template' do
      expect(get: '/site_admin/property_import_export/download_template').to route_to(
        controller: 'site_admin/property_import_export',
        action: 'download_template'
      )
    end

    it 'routes DELETE /site_admin/property_import_export/clear_results to property_import_export#clear_results' do
      expect(delete: '/site_admin/property_import_export/clear_results').to route_to(
        controller: 'site_admin/property_import_export',
        action: 'clear_results'
      )
    end

    describe 'route helpers' do
      it 'generates site_admin_property_import_export_path' do
        expect(site_admin_property_import_export_path).to eq('/site_admin/property_import_export')
      end

      it 'generates import_site_admin_property_import_export_path' do
        expect(import_site_admin_property_import_export_path).to eq('/site_admin/property_import_export/import')
      end

      it 'generates export_site_admin_property_import_export_path' do
        expect(export_site_admin_property_import_export_path).to eq('/site_admin/property_import_export/export')
      end

      it 'generates download_template_site_admin_property_import_export_path' do
        expect(download_template_site_admin_property_import_export_path).to eq('/site_admin/property_import_export/download_template')
      end

      it 'generates clear_results_site_admin_property_import_export_path' do
        expect(clear_results_site_admin_property_import_export_path).to eq('/site_admin/property_import_export/clear_results')
      end
    end
  end

  describe 'Media Library routes' do
    it 'routes GET /site_admin/media_library to media_library#index' do
      expect(get: '/site_admin/media_library').to route_to(
        controller: 'site_admin/media_library',
        action: 'index'
      )
    end

    it 'routes GET /site_admin/media_library/:id to media_library#show' do
      expect(get: '/site_admin/media_library/1').to route_to(
        controller: 'site_admin/media_library',
        action: 'show',
        id: '1'
      )
    end

    it 'routes GET /site_admin/media_library/new to media_library#new' do
      expect(get: '/site_admin/media_library/new').to route_to(
        controller: 'site_admin/media_library',
        action: 'new'
      )
    end

    it 'routes POST /site_admin/media_library to media_library#create' do
      expect(post: '/site_admin/media_library').to route_to(
        controller: 'site_admin/media_library',
        action: 'create'
      )
    end

    it 'routes GET /site_admin/media_library/:id/edit to media_library#edit' do
      expect(get: '/site_admin/media_library/1/edit').to route_to(
        controller: 'site_admin/media_library',
        action: 'edit',
        id: '1'
      )
    end

    it 'routes PATCH /site_admin/media_library/:id to media_library#update' do
      expect(patch: '/site_admin/media_library/1').to route_to(
        controller: 'site_admin/media_library',
        action: 'update',
        id: '1'
      )
    end

    it 'routes DELETE /site_admin/media_library/:id to media_library#destroy' do
      expect(delete: '/site_admin/media_library/1').to route_to(
        controller: 'site_admin/media_library',
        action: 'destroy',
        id: '1'
      )
    end

    it 'routes POST /site_admin/media_library/bulk_destroy to media_library#bulk_destroy' do
      expect(post: '/site_admin/media_library/bulk_destroy').to route_to(
        controller: 'site_admin/media_library',
        action: 'bulk_destroy'
      )
    end

    it 'routes POST /site_admin/media_library/bulk_move to media_library#bulk_move' do
      expect(post: '/site_admin/media_library/bulk_move').to route_to(
        controller: 'site_admin/media_library',
        action: 'bulk_move'
      )
    end

    it 'routes GET /site_admin/media_library/folders to media_library#folders' do
      expect(get: '/site_admin/media_library/folders').to route_to(
        controller: 'site_admin/media_library',
        action: 'folders'
      )
    end

    it 'routes POST /site_admin/media_library/create_folder to media_library#create_folder' do
      expect(post: '/site_admin/media_library/create_folder').to route_to(
        controller: 'site_admin/media_library',
        action: 'create_folder'
      )
    end

    it 'routes PATCH /site_admin/media_library/folders/:id to media_library#update_folder' do
      expect(patch: '/site_admin/media_library/folders/1').to route_to(
        controller: 'site_admin/media_library',
        action: 'update_folder',
        id: '1'
      )
    end

    it 'routes DELETE /site_admin/media_library/folders/:id to media_library#destroy_folder' do
      expect(delete: '/site_admin/media_library/folders/1').to route_to(
        controller: 'site_admin/media_library',
        action: 'destroy_folder',
        id: '1'
      )
    end

    describe 'route helpers' do
      it 'generates site_admin_media_library_index_path' do
        expect(site_admin_media_library_index_path).to eq('/site_admin/media_library')
      end

      it 'generates site_admin_media_library_path' do
        expect(site_admin_media_library_path(1)).to eq('/site_admin/media_library/1')
      end

      it 'generates new_site_admin_media_library_path' do
        expect(new_site_admin_media_library_path).to eq('/site_admin/media_library/new')
      end

      it 'generates edit_site_admin_media_library_path' do
        expect(edit_site_admin_media_library_path(1)).to eq('/site_admin/media_library/1/edit')
      end

      it 'generates bulk_destroy_site_admin_media_library_index_path' do
        expect(bulk_destroy_site_admin_media_library_index_path).to eq('/site_admin/media_library/bulk_destroy')
      end

      it 'generates bulk_move_site_admin_media_library_index_path' do
        expect(bulk_move_site_admin_media_library_index_path).to eq('/site_admin/media_library/bulk_move')
      end

      it 'generates folders_site_admin_media_library_index_path' do
        expect(folders_site_admin_media_library_index_path).to eq('/site_admin/media_library/folders')
      end

      it 'generates create_folder_site_admin_media_library_index_path' do
        expect(create_folder_site_admin_media_library_index_path).to eq('/site_admin/media_library/create_folder')
      end
    end
  end

  describe 'Billing routes' do
    it 'routes GET /site_admin/billing to billing#show' do
      expect(get: '/site_admin/billing').to route_to(
        controller: 'site_admin/billing',
        action: 'show'
      )
    end

    it 'generates site_admin_billing_path' do
      expect(site_admin_billing_path).to eq('/site_admin/billing')
    end
  end

  describe 'Agency routes' do
    it 'routes GET /site_admin/agency/edit to agency#edit' do
      expect(get: '/site_admin/agency/edit').to route_to(
        controller: 'site_admin/agency',
        action: 'edit'
      )
    end

    it 'routes PATCH /site_admin/agency to agency#update' do
      expect(patch: '/site_admin/agency').to route_to(
        controller: 'site_admin/agency',
        action: 'update'
      )
    end

    it 'generates edit_site_admin_agency_path' do
      expect(edit_site_admin_agency_path).to eq('/site_admin/agency/edit')
    end

    it 'generates site_admin_agency_path' do
      expect(site_admin_agency_path).to eq('/site_admin/agency')
    end
  end

  describe 'Activity Logs routes' do
    it 'routes GET /site_admin/activity_logs to activity_logs#index' do
      expect(get: '/site_admin/activity_logs').to route_to(
        controller: 'site_admin/activity_logs',
        action: 'index'
      )
    end

    it 'routes GET /site_admin/activity_logs/:id to activity_logs#show' do
      expect(get: '/site_admin/activity_logs/1').to route_to(
        controller: 'site_admin/activity_logs',
        action: 'show',
        id: '1'
      )
    end

    it 'generates site_admin_activity_logs_path' do
      expect(site_admin_activity_logs_path).to eq('/site_admin/activity_logs')
    end

    it 'generates site_admin_activity_log_path' do
      expect(site_admin_activity_log_path(1)).to eq('/site_admin/activity_logs/1')
    end
  end

  describe 'Users routes' do
    it 'routes GET /site_admin/users to users#index' do
      expect(get: '/site_admin/users').to route_to(
        controller: 'site_admin/users',
        action: 'index'
      )
    end

    it 'routes GET /site_admin/users/new to users#new' do
      expect(get: '/site_admin/users/new').to route_to(
        controller: 'site_admin/users',
        action: 'new'
      )
    end

    it 'routes POST /site_admin/users to users#create' do
      expect(post: '/site_admin/users').to route_to(
        controller: 'site_admin/users',
        action: 'create'
      )
    end

    it 'routes GET /site_admin/users/:id/edit to users#edit' do
      expect(get: '/site_admin/users/1/edit').to route_to(
        controller: 'site_admin/users',
        action: 'edit',
        id: '1'
      )
    end

    it 'routes PATCH /site_admin/users/:id to users#update' do
      expect(patch: '/site_admin/users/1').to route_to(
        controller: 'site_admin/users',
        action: 'update',
        id: '1'
      )
    end

    it 'routes DELETE /site_admin/users/:id to users#destroy' do
      expect(delete: '/site_admin/users/1').to route_to(
        controller: 'site_admin/users',
        action: 'destroy',
        id: '1'
      )
    end
  end

  describe 'Website Settings routes' do
    it 'routes GET /site_admin/website/settings to website/settings#show' do
      expect(get: '/site_admin/website/settings').to route_to(
        controller: 'site_admin/website/settings',
        action: 'show'
      )
    end

    it 'routes GET /site_admin/website/settings/:tab to website/settings#show' do
      expect(get: '/site_admin/website/settings/appearance').to route_to(
        controller: 'site_admin/website/settings',
        action: 'show',
        tab: 'appearance'
      )
    end

    it 'routes PATCH /site_admin/website/settings to website/settings#update' do
      expect(patch: '/site_admin/website/settings').to route_to(
        controller: 'site_admin/website/settings',
        action: 'update'
      )
    end

    it 'generates site_admin_website_settings_path' do
      expect(site_admin_website_settings_path).to eq('/site_admin/website/settings')
    end

    it 'generates site_admin_website_settings_tab_path' do
      expect(site_admin_website_settings_tab_path('appearance')).to eq('/site_admin/website/settings/appearance')
    end
  end

  describe 'Domain routes' do
    it 'routes GET /site_admin/domain to domains#show' do
      expect(get: '/site_admin/domain').to route_to(
        controller: 'site_admin/domains',
        action: 'show'
      )
    end

    it 'routes PATCH /site_admin/domain to domains#update' do
      expect(patch: '/site_admin/domain').to route_to(
        controller: 'site_admin/domains',
        action: 'update'
      )
    end

    it 'routes POST /site_admin/domain/verify to domains#verify' do
      expect(post: '/site_admin/domain/verify').to route_to(
        controller: 'site_admin/domains',
        action: 'verify'
      )
    end
  end
end
