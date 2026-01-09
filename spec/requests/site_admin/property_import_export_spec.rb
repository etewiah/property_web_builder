# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::PropertyImportExport', type: :request do
  let(:website) { create(:pwb_website, subdomain: 'test-import') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    sign_in user
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.example.com"
  end

  describe 'GET /site_admin/property_import_export' do
    it 'returns success' do
      get site_admin_property_import_export_path
      expect(response).to have_http_status(:success)
    end

    it 'displays the import/export page' do
      get site_admin_property_import_export_path
      expect(response.body).to include('Import')
      expect(response.body).to include('Export')
    end

    it 'shows property count' do
      create_list(:pwb_realty_asset, 3, website: website)
      get site_admin_property_import_export_path
      expect(response.body).to include('3')
    end

    context 'when not signed in' do
      before { sign_out user }

      it 'blocks access' do
        get site_admin_property_import_export_path
        # May redirect to login or return 403 depending on configuration
        expect(response.status).to be_in([302, 403])
      end
    end
  end

  describe 'POST /site_admin/property_import_export/import' do
    let(:csv_content) do
      <<~CSV
        reference,street_address,city,country,for_sale,price_sale,currency,title_en
        PROP-001,123 Main St,Barcelona,Spain,true,250000,EUR,Beautiful Apartment
        PROP-002,456 Oak Ave,Madrid,Spain,true,350000,EUR,Luxury Villa
      CSV
    end

    let(:csv_file) do
      file = Tempfile.new(['properties', '.csv'], encoding: 'UTF-8')
      file.write(csv_content.encode('UTF-8'))
      file.rewind
      Rack::Test::UploadedFile.new(file.path, 'text/csv', true, original_filename: 'properties.csv')
    end

    context 'with valid CSV file' do
      it 'imports properties successfully' do
        expect do
          post site_admin_property_import_export_import_path, params: { file: csv_file }
        end.to change { website.realty_assets.count }.by(2)

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:notice]).to include('2')
      end

      it 'creates sale listings for properties marked for_sale' do
        post site_admin_property_import_export_import_path, params: { file: csv_file }

        prop = website.realty_assets.find_by(reference: 'PROP-001')
        expect(prop.sale_listings.count).to eq(1)
        expect(prop.sale_listings.first.price_sale_current_cents).to eq(25_000_000)
      end
    end

    context 'with dry_run option' do
      it 'validates but does not save' do
        expect do
          post site_admin_property_import_export_import_path, params: {
            file: csv_file,
            dry_run: '1'
          }
        end.not_to(change { website.realty_assets.count })

        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:notice]).to include('Dry run')
      end
    end

    context 'with duplicate references' do
      before do
        create(:pwb_realty_asset, website: website, reference: 'PROP-001')
      end

      it 'skips duplicates by default' do
        expect do
          post site_admin_property_import_export_import_path, params: { file: csv_file }
        end.to change { website.realty_assets.count }.by(1)
      end

      it 'updates existing when update_existing is set' do
        post site_admin_property_import_export_import_path, params: {
          file: csv_file,
          update_existing: '1'
        }

        prop = website.realty_assets.find_by(reference: 'PROP-001')
        expect(prop.street_address).to eq('123 Main St')
      end
    end

    context 'without file' do
      it 'redirects with error' do
        post site_admin_property_import_export_import_path
        expect(response).to redirect_to(site_admin_property_import_export_path)
        expect(flash[:alert]).to include('select a CSV file')
      end
    end

    context 'with invalid CSV' do
      let(:invalid_csv) do
        file = Tempfile.new(['invalid', '.csv'])
        file.write("not,valid\n\"unclosed quote")
        file.rewind
        Rack::Test::UploadedFile.new(file.path, 'text/csv', true, original_filename: 'invalid.csv')
      end

      it 'handles parsing errors gracefully' do
        post site_admin_property_import_export_import_path, params: { file: invalid_csv }
        expect(response).to redirect_to(site_admin_property_import_export_path)
      end
    end
  end

  describe 'GET /site_admin/property_import_export/export' do
    before do
      asset = create(:pwb_realty_asset,
        website: website,
        reference: 'EXPORT-001',
        street_address: '123 Export St',
        city: 'Barcelona')
      create(:pwb_sale_listing,
        realty_asset: asset,
        active: true,
        visible: true,
        price_sale_current_cents: 50_000_000)
    end

    it 'returns CSV file' do
      get site_admin_property_import_export_export_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
    end

    it 'includes property data' do
      get site_admin_property_import_export_export_path
      expect(response.body).to include('EXPORT-001')
      expect(response.body).to include('Barcelona')
    end

    it 'sets appropriate filename' do
      get site_admin_property_import_export_export_path
      expect(response.headers['Content-Disposition']).to include('properties_')
      expect(response.headers['Content-Disposition']).to include('.csv')
    end

    context 'with include_inactive option' do
      before do
        create(:pwb_realty_asset, website: website, reference: 'INACTIVE-001')
      end

      it 'includes inactive properties when requested' do
        get site_admin_property_import_export_export_path, params: { include_inactive: '1' }
        expect(response.body).to include('INACTIVE-001')
      end

      it 'excludes inactive properties by default' do
        get site_admin_property_import_export_export_path
        expect(response.body).not_to include('INACTIVE-001')
      end
    end
  end

  describe 'GET /site_admin/property_import_export/download_template' do
    it 'returns CSV template' do
      get site_admin_property_import_export_download_template_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
    end

    it 'includes header row' do
      get site_admin_property_import_export_download_template_path
      expect(response.body).to include('reference')
      expect(response.body).to include('street_address')
      expect(response.body).to include('for_sale')
    end

    it 'includes example row' do
      get site_admin_property_import_export_download_template_path
      expect(response.body).to include('PROP-001')
    end

    it 'sets appropriate filename' do
      get site_admin_property_import_export_download_template_path
      expect(response.headers['Content-Disposition']).to include('property_import_template.csv')
    end
  end

  describe 'DELETE /site_admin/property_import_export/clear_results' do
    before do
      # Simulate stored import results
      file = Tempfile.new(['test', '.csv'])
      file.write("reference\nTEST-001")
      file.rewind
      post site_admin_property_import_export_import_path, params: {
        file: Rack::Test::UploadedFile.new(file.path, 'text/csv', true, original_filename: 'test.csv')
      }
    end

    it 'clears import results from session' do
      delete site_admin_property_import_export_clear_results_path
      expect(response).to redirect_to(site_admin_property_import_export_path)
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:pwb_website, subdomain: 'other-import') }

    before do
      create(:pwb_realty_asset, website: website, reference: 'OWN-001')
      create(:pwb_realty_asset, website: other_website, reference: 'OTHER-001')
    end

    it 'only exports current website properties' do
      # Create listing to make property active
      asset = website.realty_assets.first
      create(:pwb_sale_listing, realty_asset: asset, active: true, visible: true)

      get site_admin_property_import_export_export_path, params: { include_inactive: '1' }

      expect(response.body).to include('OWN-001')
      expect(response.body).not_to include('OTHER-001')
    end

    it 'only counts current website properties' do
      get site_admin_property_import_export_path
      # Should only show count of 1 (own website)
      expect(assigns(:property_count)).to eq(1)
    end
  end
end
