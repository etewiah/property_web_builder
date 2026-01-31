# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertyBulkImportService, type: :service do
  let(:website) { create(:pwb_website) }

  def csv_file(content)
    file = Tempfile.new(['import', '.csv'])
    file.write(content)
    file.rewind
    file
  end

  describe '#import' do
    context 'with valid CSV data' do
      let(:csv_content) do
        <<~CSV
          reference,street_address,city,country,count_bedrooms,count_bathrooms,for_sale,price_sale
          PROP-001,123 Main St,Amsterdam,Netherlands,3,2,true,250000
          PROP-002,456 Oak Ave,Rotterdam,Netherlands,2,1,true,180000
        CSV
      end

      it 'imports properties successfully' do
        result = described_class.new(
          file: csv_file(csv_content),
          website: website
        ).import

        expect(result.success?).to be true
        expect(result.imported.size).to eq(2)
        expect(result.errors).to be_empty
        expect(result.total_rows).to eq(2)
      end

      it 'creates RealtyAsset records' do
        expect {
          described_class.new(file: csv_file(csv_content), website: website).import
        }.to change(Pwb::RealtyAsset, :count).by(2)
      end

      it 'associates properties with the website' do
        described_class.new(file: csv_file(csv_content), website: website).import

        expect(Pwb::RealtyAsset.where(website: website).count).to eq(2)
      end

      it 'sets property attributes correctly' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'PROP-001')
        expect(prop.street_address).to eq('123 Main St')
        expect(prop.city).to eq('Amsterdam')
        expect(prop.country).to eq('Netherlands')
        expect(prop.count_bedrooms).to eq(3)
        expect(prop.count_bathrooms).to eq(2.0)
      end

      it 'creates sale listings when for_sale is true' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'PROP-001')
        expect(prop.sale_listings.count).to eq(1)
        expect(prop.sale_listings.first.price_sale_current_cents).to eq(25_000_000) # 250000 * 100
      end
    end

    context 'with rental properties' do
      let(:csv_content) do
        <<~CSV
          reference,city,for_rent,price_rental_monthly
          RENT-001,Amsterdam,true,1500
        CSV
      end

      it 'creates rental listings' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'RENT-001')
        expect(prop.rental_listings.count).to eq(1)
        expect(prop.rental_listings.first.price_rental_monthly_current_cents).to eq(150_000)
      end
    end

    context 'with missing required fields' do
      let(:csv_content) do
        <<~CSV
          street_address,city
          123 Main St,Amsterdam
        CSV
      end

      it 'reports errors for missing reference' do
        result = described_class.new(file: csv_file(csv_content), website: website).import

        expect(result.success?).to be false
        expect(result.errors.first[:error]).to include('reference')
      end

      it 'does not create properties' do
        expect {
          described_class.new(file: csv_file(csv_content), website: website).import
        }.not_to change(Pwb::RealtyAsset, :count)
      end
    end

    context 'with duplicate references' do
      let!(:existing_property) { create(:pwb_realty_asset, website: website, reference: 'EXISTING-001') }

      let(:csv_content) do
        <<~CSV
          reference,city
          EXISTING-001,Amsterdam
        CSV
      end

      context 'when skip_duplicates is true (default)' do
        it 'skips duplicate rows' do
          result = described_class.new(file: csv_file(csv_content), website: website).import

          expect(result.skipped.size).to eq(1)
          expect(result.skipped.first[:reason]).to eq('Duplicate reference')
        end

        it 'does not create new properties' do
          expect {
            described_class.new(file: csv_file(csv_content), website: website).import
          }.not_to change(Pwb::RealtyAsset, :count)
        end
      end

      context 'when skip_duplicates is false' do
        it 'reports error for duplicates' do
          result = described_class.new(
            file: csv_file(csv_content),
            website: website,
            options: { skip_duplicates: false }
          ).import

          expect(result.errors.size).to eq(1)
          expect(result.errors.first[:error]).to include('Duplicate reference')
        end
      end

      context 'when update_existing is true' do
        let(:csv_content) do
          <<~CSV
            reference,city,count_bedrooms
            EXISTING-001,Rotterdam,5
          CSV
        end

        it 'updates the existing property' do
          result = described_class.new(
            file: csv_file(csv_content),
            website: website,
            options: { update_existing: true }
          ).import

          expect(result.success?).to be true
          expect(result.imported.first[:status]).to eq('updated')

          existing_property.reload
          expect(existing_property.city).to eq('Rotterdam')
          expect(existing_property.count_bedrooms).to eq(5)
        end
      end
    end

    context 'with empty CSV' do
      let(:csv_content) { "reference,city\n" }

      it 'returns error for empty file' do
        result = described_class.new(file: csv_file(csv_content), website: website).import

        expect(result.success?).to be false
        expect(result.errors.first[:error]).to include('empty')
      end
    end

    context 'with malformed CSV' do
      let(:csv_content) { "this is not valid csv content\x00\x01\x02" }

      it 'handles parsing errors gracefully' do
        result = described_class.new(file: csv_file(csv_content), website: website).import

        expect(result.success?).to be false
      end
    end

    context 'with dry_run option' do
      let(:csv_content) do
        <<~CSV
          reference,city
          DRY-001,Amsterdam
        CSV
      end

      it 'validates without creating records' do
        result = described_class.new(
          file: csv_file(csv_content),
          website: website,
          options: { dry_run: true }
        ).import

        expect(result.success?).to be true
        expect(result.imported.first[:status]).to eq('validated')
        expect(Pwb::RealtyAsset.find_by(reference: 'DRY-001')).to be_nil
      end
    end

    context 'with tab-delimited CSV' do
      let(:csv_content) { "reference\tcity\nTAB-001\tAmsterdam" }

      it 'detects and parses tab delimiter' do
        result = described_class.new(file: csv_file(csv_content), website: website).import

        expect(result.success?).to be true
        expect(Pwb::RealtyAsset.find_by(reference: 'TAB-001')).to be_present
      end
    end

    context 'with translated content' do
      let(:csv_content) do
        <<~CSV
          reference,title_en,title_es,description_en,for_sale,price_sale
          TRANS-001,English Title,Título Español,English description,true,100000
        CSV
      end

      it 'sets translations on listings' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'TRANS-001')
        listing = prop.sale_listings.first

        Mobility.with_locale(:en) do
          expect(listing.title).to eq('English Title')
          expect(listing.description).to eq('English description')
        end

        Mobility.with_locale(:es) do
          expect(listing.title).to eq('Título Español')
        end
      end
    end

    context 'with features' do
      let(:csv_content) do
        <<~CSV
          reference,city,features
          FEAT-001,Amsterdam,"pool,garden,garage"
        CSV
      end

      it 'creates feature associations' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'FEAT-001')
        feature_keys = prop.features.pluck(:feature_key)

        expect(feature_keys).to contain_exactly('pool', 'garden', 'garage')
      end
    end

    context 'with price in cents' do
      let(:csv_content) do
        <<~CSV
          reference,for_sale,price_sale_cents
          CENTS-001,true,25000000
        CSV
      end

      it 'uses cents value directly' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'CENTS-001')
        expect(prop.sale_listings.first.price_sale_current_cents).to eq(25_000_000)
      end
    end

    context 'with boolean fields' do
      let(:csv_content) do
        <<~CSV
          reference,for_sale,visible,highlighted,furnished
          BOOL-001,yes,1,true,Y
        CSV
      end

      it 'parses various truthy values' do
        described_class.new(
          file: csv_file(csv_content),
          website: website,
          options: { create_visible: false }
        ).import

        prop = Pwb::RealtyAsset.find_by(reference: 'BOOL-001')
        listing = prop.sale_listings.first

        expect(listing.visible).to be true
        expect(listing.highlighted).to be true
        expect(listing.furnished).to be true
      end
    end

    context 'with currency option' do
      let(:csv_content) do
        <<~CSV
          reference,for_sale,price_sale,currency
          CURR-001,true,100000,USD
        CSV
      end

      it 'uses specified currency' do
        described_class.new(file: csv_file(csv_content), website: website).import

        prop = Pwb::RealtyAsset.find_by(reference: 'CURR-001')
        expect(prop.sale_listings.first.price_sale_current_currency).to eq('USD')
      end

      it 'uses default currency when not specified' do
        csv = csv_file("reference,for_sale,price_sale\nDEF-001,true,100000")

        described_class.new(
          file: csv,
          website: website,
          options: { default_currency: 'GBP' }
        ).import

        prop = Pwb::RealtyAsset.find_by(reference: 'DEF-001')
        expect(prop.sale_listings.first.price_sale_current_currency).to eq('GBP')
      end
    end

    context 'with mixed valid and invalid rows' do
      let(:csv_content) do
        <<~CSV
          reference,city
          VALID-001,Amsterdam
          ,Rotterdam
          VALID-002,Utrecht
        CSV
      end

      it 'imports valid rows and reports errors for invalid ones' do
        result = described_class.new(file: csv_file(csv_content), website: website).import

        expect(result.imported.size).to eq(2)
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:line]).to eq(3) # Line 3 (2nd data row + 1 for header)
      end
    end
  end

  describe 'Result struct' do
    it 'responds to success?' do
      result = described_class::Result.new(success: true, imported: [], errors: [], skipped: [], total_rows: 0)
      expect(result.success?).to be true
    end

    it 'provides access to all fields' do
      result = described_class::Result.new(
        success: true,
        imported: [{ id: 1 }],
        errors: [{ error: 'test' }],
        skipped: [{ reason: 'dup' }],
        total_rows: 3
      )

      expect(result.imported).to eq([{ id: 1 }])
      expect(result.errors).to eq([{ error: 'test' }])
      expect(result.skipped).to eq([{ reason: 'dup' }])
      expect(result.total_rows).to eq(3)
    end
  end
end
