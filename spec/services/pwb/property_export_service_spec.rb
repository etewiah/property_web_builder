# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertyExportService, type: :service do
  let(:website) { create(:pwb_website) }

  describe '#export' do
    context 'with no properties' do
      it 'returns CSV with headers only' do
        csv = described_class.new(website: website).export

        lines = csv.split("\n")
        expect(lines.size).to eq(1) # Headers only
        expect(lines.first).to include('reference')
      end
    end

    context 'with a sale property' do
      let!(:realty_asset) do
        create(:pwb_realty_asset,
               website: website,
               reference: 'SALE-001',
               street_address: '123 Main St',
               city: 'Amsterdam',
               country: 'Netherlands',
               count_bedrooms: 3,
               count_bathrooms: 2,
               constructed_area: 150.0)
      end

      let!(:sale_listing) do
        create(:pwb_sale_listing,
               realty_asset: realty_asset,
               visible: true,
               highlighted: true,
               price_sale_current_cents: 350_000_00,
               price_sale_current_currency: 'EUR')
      end

      it 'exports property data correctly' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)

        expect(rows.size).to eq(1)
        row = rows.first

        expect(row['reference']).to eq('SALE-001')
        expect(row['street_address']).to eq('123 Main St')
        expect(row['city']).to eq('Amsterdam')
        expect(row['country']).to eq('Netherlands')
        expect(row['count_bedrooms']).to eq('3')
        expect(row['count_bathrooms']).to eq('2.0')
        expect(row['constructed_area']).to eq('150.0')
      end

      it 'exports sale listing data correctly' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)
        row = rows.first

        expect(row['for_sale']).to eq('true')
        expect(row['for_rent']).to eq('false')
        expect(row['price_sale']).to eq('350000.0')
        expect(row['currency']).to eq('EUR')
        expect(row['visible']).to eq('true')
        expect(row['highlighted']).to eq('true')
      end

      it 'exports translations' do
        Mobility.with_locale(:en) do
          sale_listing.title = 'Beautiful Amsterdam Apartment'
          sale_listing.description = 'A stunning property in the heart of the city'
        end
        Mobility.with_locale(:es) do
          sale_listing.title = 'Hermoso Apartamento en Amsterdam'
          sale_listing.description = 'Una propiedad impresionante'
        end
        sale_listing.save!

        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)
        row = rows.first

        expect(row['title_en']).to eq('Beautiful Amsterdam Apartment')
        expect(row['description_en']).to eq('A stunning property in the heart of the city')
        expect(row['title_es']).to eq('Hermoso Apartamento en Amsterdam')
        expect(row['description_es']).to eq('Una propiedad impresionante')
      end
    end

    context 'with a rental property' do
      let!(:realty_asset) do
        create(:pwb_realty_asset,
               website: website,
               reference: 'RENT-001',
               city: 'Rotterdam')
      end

      let!(:rental_listing) do
        create(:pwb_rental_listing,
               realty_asset: realty_asset,
               visible: true,
               for_rent_long_term: true,
               for_rent_short_term: false,
               price_rental_monthly_current_cents: 1_500_00,
               price_rental_monthly_high_season_cents: 2_000_00,
               price_rental_monthly_low_season_cents: 1_200_00,
               price_rental_monthly_current_currency: 'EUR')
      end

      it 'exports rental listing data correctly' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)
        row = rows.first

        expect(row['for_sale']).to eq('false')
        expect(row['for_rent']).to eq('true')
        expect(row['for_rent_long_term']).to eq('true')
        expect(row['for_rent_short_term']).to eq('false')
        expect(row['price_rental_monthly']).to eq('1500.0')
        expect(row['price_rental_high_season']).to eq('2000.0')
        expect(row['price_rental_low_season']).to eq('1200.0')
      end
    end

    context 'with features' do
      let!(:realty_asset) { create(:pwb_realty_asset, website: website, reference: 'FEAT-001') }
      let!(:sale_listing) { create(:pwb_sale_listing, realty_asset: realty_asset) }

      before do
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'pool')
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'garden')
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'garage')
      end

      it 'exports features as comma-separated list' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)
        row = rows.first

        features = row['features'].split(',')
        expect(features).to contain_exactly('pool', 'garden', 'garage')
      end
    end

    context 'with multiple properties' do
      before do
        3.times do |i|
          asset = create(:pwb_realty_asset, website: website, reference: "PROP-00#{i + 1}")
          create(:pwb_sale_listing, realty_asset: asset)
        end
      end

      it 'exports all properties' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)

        expect(rows.size).to eq(3)
      end

      it 'orders by reference' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)

        references = rows.map { |r| r['reference'] }
        expect(references).to eq(references.sort)
      end
    end

    context 'with include_inactive option' do
      let!(:active_property) do
        asset = create(:pwb_realty_asset, website: website, reference: 'ACTIVE-001')
        create(:pwb_sale_listing, realty_asset: asset)
        asset
      end

      let!(:inactive_property) do
        create(:pwb_realty_asset, website: website, reference: 'INACTIVE-001')
        # No listing created - property is inactive
      end

      it 'excludes inactive properties by default' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)

        expect(rows.size).to eq(1)
        expect(rows.first['reference']).to eq('ACTIVE-001')
      end

      it 'includes inactive properties when option is true' do
        csv = described_class.new(
          website: website,
          options: { include_inactive: true }
        ).export
        rows = CSV.parse(csv, headers: true)

        expect(rows.size).to eq(2)
        references = rows.map { |r| r['reference'] }
        expect(references).to include('ACTIVE-001', 'INACTIVE-001')
      end
    end

    context 'with custom delimiter' do
      let!(:realty_asset) { create(:pwb_realty_asset, website: website, reference: 'TAB-001') }
      let!(:sale_listing) { create(:pwb_sale_listing, realty_asset: realty_asset) }

      it 'uses tab delimiter when specified' do
        csv = described_class.new(
          website: website,
          options: { delimiter: "\t" }
        ).export

        rows = CSV.parse(csv, headers: true, col_sep: "\t")
        expect(rows.first['reference']).to eq('TAB-001')
      end
    end

    context 'with both sale and rental listings' do
      let!(:realty_asset) { create(:pwb_realty_asset, website: website, reference: 'BOTH-001') }

      let!(:sale_listing) do
        create(:pwb_sale_listing,
               realty_asset: realty_asset,
               price_sale_current_cents: 500_000_00,
               price_sale_current_currency: 'EUR')
      end

      let!(:rental_listing) do
        create(:pwb_rental_listing,
               realty_asset: realty_asset,
               price_rental_monthly_current_cents: 2_000_00)
      end

      it 'exports both sale and rental data' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)
        row = rows.first

        expect(row['for_sale']).to eq('true')
        expect(row['for_rent']).to eq('true')
        expect(row['price_sale']).to eq('500000.0')
        expect(row['price_rental_monthly']).to eq('2000.0')
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website) }

      let!(:my_property) do
        asset = create(:pwb_realty_asset, website: website, reference: 'MY-PROP')
        create(:pwb_sale_listing, realty_asset: asset)
        asset
      end

      let!(:other_property) do
        asset = create(:pwb_realty_asset, website: other_website, reference: 'OTHER-PROP')
        create(:pwb_sale_listing, realty_asset: asset)
        asset
      end

      it 'only exports properties for the specified website' do
        csv = described_class.new(website: website).export
        rows = CSV.parse(csv, headers: true)

        expect(rows.size).to eq(1)
        expect(rows.first['reference']).to eq('MY-PROP')
      end
    end
  end

  describe '#export_to_file' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website, reference: 'FILE-001') }
    let!(:sale_listing) { create(:pwb_sale_listing, realty_asset: realty_asset) }

    it 'writes CSV to file' do
      filepath = Rails.root.join('tmp', 'test_export.csv')

      begin
        described_class.new(website: website).export_to_file(filepath)

        expect(File.exist?(filepath)).to be true

        content = File.read(filepath)
        rows = CSV.parse(content, headers: true)
        expect(rows.first['reference']).to eq('FILE-001')
      ensure
        File.delete(filepath) if File.exist?(filepath)
      end
    end
  end

  describe '#count' do
    before do
      3.times do |i|
        asset = create(:pwb_realty_asset, website: website, reference: "COUNT-00#{i + 1}")
        create(:pwb_sale_listing, realty_asset: asset)
      end
    end

    it 'returns the count of properties to be exported' do
      count = described_class.new(website: website).count
      expect(count).to eq(3)
    end
  end

  describe 'EXPORT_COLUMNS' do
    it 'defines all expected columns' do
      columns = described_class::EXPORT_COLUMNS

      # Identity
      expect(columns).to include('reference')

      # Location
      expect(columns).to include('street_address', 'city', 'country', 'postal_code')

      # Property details
      expect(columns).to include('count_bedrooms', 'count_bathrooms', 'constructed_area')

      # Listing flags
      expect(columns).to include('for_sale', 'for_rent')

      # Pricing
      expect(columns).to include('price_sale', 'price_rental_monthly', 'currency')

      # Translations
      expect(columns).to include('title_en', 'title_es', 'description_en', 'description_es')

      # Status
      expect(columns).to include('visible', 'highlighted', 'furnished')

      # Features
      expect(columns).to include('features')
    end
  end
end
