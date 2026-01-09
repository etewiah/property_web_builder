# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Props Edit Labels', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'labels-test-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'labels-test-b') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website_a, email: 'admin@labels-test.test') }

  let!(:realty_asset) do
    Pwb::RealtyAsset.create!(
      reference: 'LABELS-TEST-001',
      website: website_a
    )
  end

  let!(:sale_listing) do
    Pwb::SaleListing.create!(
      realty_asset: realty_asset,
      visible: true,
      price_sale_current_cents: 100_000_00
    )
  end

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website_a)
    begin
      Pwb::ListedProperty.refresh
    rescue StandardError
      nil
    end
  end

  describe 'GET /site_admin/props/:id/edit/labels' do
    context 'with tenant-scoped field keys' do
      before do
        ActsAsTenant.with_tenant(website_a) do
          # Create field keys for website_a
          PwbTenant::FieldKey.create!(
            global_key: 'types.apartment_a',
            tag: 'property-types',
            visible: true
          ).tap do |fk|
            Mobility.with_locale(:en) { fk.label = 'Apartment A' }
            fk.save!
          end
        end

        ActsAsTenant.with_tenant(website_b) do
          # Create field keys for website_b
          PwbTenant::FieldKey.create!(
            global_key: 'types.apartment_b',
            tag: 'property-types',
            visible: true
          ).tap do |fk|
            Mobility.with_locale(:en) { fk.label = 'Apartment B' }
            fk.save!
          end
        end
      end

      it 'only shows field keys belonging to the current tenant' do
        listed_prop = Pwb::ListedProperty.find_by(reference: 'LABELS-TEST-001')
        skip 'Materialized view not populated' unless listed_prop

        ActsAsTenant.with_tenant(website_a) do
          get edit_labels_site_admin_prop_path(listed_prop),
              headers: { 'HTTP_HOST' => 'labels-test-a.e2e.localhost' }

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Apartment A')
          expect(response.body).not_to include('Apartment B')
        end
      end

      it 'does not show duplicate labels' do
        listed_prop = Pwb::ListedProperty.find_by(reference: 'LABELS-TEST-001')
        skip 'Materialized view not populated' unless listed_prop

        ActsAsTenant.with_tenant(website_a) do
          get edit_labels_site_admin_prop_path(listed_prop),
              headers: { 'HTTP_HOST' => 'labels-test-a.e2e.localhost' }

          expect(response).to have_http_status(:success)
          # Count occurrences of the label - should only appear once per category
          apartment_count = response.body.scan('Apartment A').count
          # Each label appears in the checkbox and its label text
          expect(apartment_count).to be <= 2
        end
      end
    end
  end

  describe 'PATCH /site_admin/props/:id with features' do
    before do
      ActsAsTenant.with_tenant(website_a) do
        PwbTenant::FieldKey.create!(
          global_key: 'features.pool',
          tag: 'property-features',
          visible: true
        ).tap do |fk|
          Mobility.with_locale(:en) { fk.label = 'Swimming Pool' }
          fk.save!
        end
      end
    end

    it 'updates property features successfully' do
      listed_prop = Pwb::ListedProperty.find_by(reference: 'LABELS-TEST-001')
      skip 'Materialized view not populated' unless listed_prop

      patch site_admin_prop_path(listed_prop),
            params: { features: ['features.pool'] },
            headers: { 'HTTP_HOST' => 'labels-test-a.e2e.localhost' }

      expect(response).to redirect_to(site_admin_prop_path(listed_prop))

      # Verify feature was added
      realty_asset.reload
      expect(realty_asset.features.pluck(:feature_key)).to include('features.pool')
    end

    it 'clears features when empty array submitted' do
      # First add a feature
      Pwb::Feature.create!(realty_asset_id: realty_asset.id, feature_key: 'features.pool')

      listed_prop = Pwb::ListedProperty.find_by(reference: 'LABELS-TEST-001')
      skip 'Materialized view not populated' unless listed_prop

      patch site_admin_prop_path(listed_prop),
            params: { features: [''] },
            headers: { 'HTTP_HOST' => 'labels-test-a.e2e.localhost' }

      expect(response).to redirect_to(site_admin_prop_path(listed_prop))

      # Verify features were cleared
      realty_asset.reload
      expect(realty_asset.features.where.not(feature_key: [nil, ''])).to be_empty
    end
  end
end
