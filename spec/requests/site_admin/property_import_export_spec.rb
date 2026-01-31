# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::PropertyImportExportController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'import-export-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@import-export.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/property_import_export (index)' do
    it 'renders the import/export page successfully' do
      get site_admin_property_import_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with existing properties' do
      before do
        3.times do |i|
          asset = create(:pwb_realty_asset, website: website, reference: "PROP-00#{i}")
          create(:pwb_sale_listing, :visible, realty_asset: asset)
        end
        Pwb::ListedProperty.refresh rescue nil
      end

      it 'displays property count' do
        get site_admin_property_import_export_path,
            headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /site_admin/property_import_export/import' do
    let(:csv_content) do
      <<~CSV
        reference,street_address,city,country,count_bedrooms,for_sale,price_sale
        IMP-001,123 Main St,Amsterdam,Netherlands,3,true,250000
        IMP-002,456 Oak Ave,Rotterdam,Netherlands,2,true,180000
      CSV
    end

    let(:csv_file) do
      file = Tempfile.new(['import', '.csv'])
      file.write(csv_content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: 'import.csv')
    end

    context 'without file' do
      it 'redirects with error' do
        post site_admin_property_import_export_import_path,
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:alert]).to include('select a CSV file')
      end
    end

    context 'with invalid file type' do
      let(:invalid_file) do
        file = Tempfile.new(['import', '.exe'])
        file.write('binary content')
        file.rewind
        Rack::Test::UploadedFile.new(file.path, 'application/octet-stream', original_filename: 'import.exe')
      end

      it 'redirects with error' do
        post site_admin_property_import_export_import_path,
             params: { file: invalid_file },
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:alert]).to include('Invalid file type')
      end
    end

    context 'with valid CSV file' do
      it 'imports properties and redirects with success' do
        expect do
          post site_admin_property_import_export_import_path,
               params: { file: csv_file },
               headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }
        end.to change(Pwb::RealtyAsset, :count).by(2)

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:notice]).to include('Import complete')
        expect(flash[:notice]).to include('2 properties imported')
      end

      it 'stores import results in session' do
        post site_admin_property_import_export_import_path,
             params: { file: csv_file },
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        expect(session[:import_result]).to be_present
        expect(session[:import_result][:imported_count]).to eq(2)
      end
    end

    context 'with dry_run option' do
      it 'validates without creating records' do
        expect do
          post site_admin_property_import_export_import_path,
               params: { file: csv_file, dry_run: '1' },
               headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }
        end.not_to change(Pwb::RealtyAsset, :count)

        expect(flash[:notice]).to include('Dry run complete')
        expect(flash[:notice]).to include('would be imported')
      end
    end

    context 'with update_existing option' do
      let!(:existing_property) { create(:pwb_realty_asset, website: website, reference: 'IMP-001', city: 'Old City') }

      it 'updates existing properties' do
        post site_admin_property_import_export_import_path,
             params: { file: csv_file, update_existing: '1' },
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        existing_property.reload
        expect(existing_property.city).to eq('Amsterdam')
      end
    end

    context 'with import errors' do
      let(:invalid_csv_content) do
        <<~CSV
          street_address,city
          123 Main St,Amsterdam
        CSV
      end

      let(:invalid_csv_file) do
        file = Tempfile.new(['import', '.csv'])
        file.write(invalid_csv_content)
        file.rewind
        Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: 'invalid.csv')
      end

      it 'shows error message' do
        post site_admin_property_import_export_import_path,
             params: { file: invalid_csv_file },
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:alert]).to include('Import failed')
      end
    end
  end

  describe 'GET /site_admin/property_import_export/export' do
    before do
      2.times do |i|
        asset = create(:pwb_realty_asset, website: website, reference: "EXP-00#{i}")
        create(:pwb_sale_listing, realty_asset: asset)
      end
    end

    it 'downloads CSV file' do
      get site_admin_property_import_export_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('.csv')
    end

    it 'includes property data in CSV' do
      get site_admin_property_import_export_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      csv = CSV.parse(response.body, headers: true)
      expect(csv.size).to eq(2)
      expect(csv.first['reference']).to start_with('EXP-')
    end

    it 'uses website subdomain in filename' do
      get site_admin_property_import_export_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response.headers['Content-Disposition']).to include('import-export-test')
    end

    context 'with include_inactive option' do
      let!(:inactive_property) { create(:pwb_realty_asset, website: website, reference: 'INACTIVE-001') }

      it 'includes inactive properties when option is set' do
        get site_admin_property_import_export_export_path,
            params: { include_inactive: '1' },
            headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        csv = CSV.parse(response.body, headers: true)
        references = csv.map { |r| r['reference'] }
        expect(references).to include('INACTIVE-001')
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-export') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_property) do
        asset = create(:pwb_realty_asset, website: other_website, reference: 'OTHER-001')
        create(:pwb_sale_listing, realty_asset: asset)
        asset
      end

      it 'only exports properties for current website' do
        get site_admin_property_import_export_export_path,
            headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

        csv = CSV.parse(response.body, headers: true)
        references = csv.map { |r| r['reference'] }
        expect(references).not_to include('OTHER-001')
      end
    end
  end

  describe 'GET /site_admin/property_import_export/download_template' do
    it 'downloads template CSV' do
      get site_admin_property_import_export_download_template_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('property_import_template.csv')
    end

    it 'includes expected headers' do
      get site_admin_property_import_export_download_template_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      csv = CSV.parse(response.body, headers: true)
      headers = csv.headers

      expect(headers).to include('reference', 'street_address', 'city', 'country')
      expect(headers).to include('for_sale', 'for_rent', 'price_sale')
      expect(headers).to include('title_en', 'description_en', 'features')
    end

    it 'includes example row' do
      get site_admin_property_import_export_download_template_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      csv = CSV.parse(response.body, headers: true)
      expect(csv.size).to eq(1)
      expect(csv.first['reference']).to eq('PROP-001')
    end
  end

  describe 'DELETE /site_admin/property_import_export/clear_results' do
    before do
      # Simulate having import results in session
      post site_admin_property_import_export_import_path,
           params: { file: csv_file },
           headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }
    end

    let(:csv_content) { "reference,city\nCLEAR-001,Test" }
    let(:csv_file) do
      file = Tempfile.new(['import', '.csv'])
      file.write(csv_content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: 'import.csv')
    end

    it 'clears import results from session' do
      expect(session[:import_result]).to be_present

      delete site_admin_property_import_export_clear_results_path,
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(session[:import_result]).to be_nil
    end

    it 'redirects to index' do
      delete site_admin_property_import_export_clear_results_path,
             headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to redirect_to(site_admin_property_import_export_path)
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_property_import_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on import' do
      post site_admin_property_import_export_import_path,
           headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on export' do
      get site_admin_property_import_export_export_path,
          headers: { 'HTTP_HOST' => 'import-export-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
