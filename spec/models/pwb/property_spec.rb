require 'rails_helper'

module Pwb
  RSpec.describe Property, type: :model do
    # Disable automatic refresh during test setup to control when it happens
    before(:each) do
      allow_any_instance_of(Pwb::RealtyAsset).to receive(:refresh_properties_view)
      allow_any_instance_of(Pwb::SaleListing).to receive(:refresh_properties_view)
      allow_any_instance_of(Pwb::RentalListing).to receive(:refresh_properties_view)
    end

    let(:website) { create(:pwb_website) }

    # Helper to refresh the view and reload
    def refresh_and_find(id)
      Pwb::Property.refresh
      Pwb::Property.find(id)
    end

    describe 'materialized view basics' do
      let!(:asset) { create(:pwb_realty_asset, website: website, reference: 'TEST-001') }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      it 'is backed by a materialized view' do
        expect(Property.table_name).to eq('pwb_properties')
      end

      it 'contains data from realty_assets' do
        property = Property.find(asset.id)
        expect(property.reference).to eq('TEST-001')
      end

      it 'is read-only' do
        property = Property.first
        expect(property.readonly?).to be true
      end

      it 'raises error when trying to update' do
        property = Property.first
        expect { property.update(reference: 'NEW') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

    describe '.refresh' do
      let!(:asset) { create(:pwb_realty_asset, website: website) }

      it 'updates the materialized view' do
        # Initially no listing
        Pwb::Property.refresh
        property = Property.find(asset.id)
        expect(property.for_sale).to be false

        # Add a sale listing
        create(:pwb_sale_listing, :visible, realty_asset: asset)
        Pwb::Property.refresh

        # Now should show for_sale
        property = Property.find(asset.id)
        expect(property.for_sale).to be true
      end

      it 'can refresh concurrently' do
        expect { Pwb::Property.refresh(concurrently: true) }.not_to raise_error
      end

      it 'can refresh non-concurrently' do
        expect { Pwb::Property.refresh(concurrently: false) }.not_to raise_error
      end
    end

    describe 'scopes' do
      let!(:sale_asset) { create(:pwb_realty_asset, website: website, count_bedrooms: 3) }
      let!(:rental_asset) { create(:pwb_realty_asset, website: website, count_bedrooms: 2) }
      let!(:hidden_asset) { create(:pwb_realty_asset, website: website) }

      let!(:sale_listing) { create(:pwb_sale_listing, :visible, :highlighted, realty_asset: sale_asset, price_sale_current_cents: 300_000_00) }
      let!(:rental_listing) { create(:pwb_rental_listing, :visible, :long_term, realty_asset: rental_asset, price_rental_monthly_current_cents: 1_500_00) }

      before { Pwb::Property.refresh }

      describe '.visible' do
        it 'returns properties with visible listings' do
          expect(Property.visible).to include(
            have_attributes(id: sale_asset.id),
            have_attributes(id: rental_asset.id)
          )
        end

        it 'excludes properties without visible listings' do
          expect(Property.visible.map(&:id)).not_to include(hidden_asset.id)
        end
      end

      describe '.for_sale' do
        it 'returns properties with visible sale listings' do
          for_sale = Property.for_sale
          expect(for_sale.map(&:id)).to include(sale_asset.id)
          expect(for_sale.map(&:id)).not_to include(rental_asset.id)
        end
      end

      describe '.for_rent' do
        it 'returns properties with visible rental listings' do
          for_rent = Property.for_rent
          expect(for_rent.map(&:id)).to include(rental_asset.id)
          expect(for_rent.map(&:id)).not_to include(sale_asset.id)
        end
      end

      describe '.highlighted' do
        it 'returns only highlighted properties' do
          highlighted = Property.highlighted
          expect(highlighted.map(&:id)).to include(sale_asset.id)
          expect(highlighted.map(&:id)).not_to include(rental_asset.id)
        end
      end

      describe 'price scopes' do
        it '.for_sale_price_from filters by minimum sale price' do
          results = Property.for_sale_price_from(200_000_00)
          expect(results.map(&:id)).to include(sale_asset.id)

          results = Property.for_sale_price_from(400_000_00)
          expect(results.map(&:id)).not_to include(sale_asset.id)
        end

        it '.for_sale_price_till filters by maximum sale price' do
          results = Property.for_sale_price_till(400_000_00)
          expect(results.map(&:id)).to include(sale_asset.id)

          results = Property.for_sale_price_till(200_000_00)
          expect(results.map(&:id)).not_to include(sale_asset.id)
        end
      end

      describe 'bedroom/bathroom scopes' do
        it '.count_bedrooms filters by minimum bedrooms' do
          results = Property.count_bedrooms(3)
          expect(results.map(&:id)).to include(sale_asset.id)
          expect(results.map(&:id)).not_to include(rental_asset.id)
        end

        it '.bedrooms_from filters by minimum bedrooms' do
          # Filter visible properties with at least 2 bedrooms
          results = Property.visible.bedrooms_from(2)
          expect(results.count).to eq(2)
          expect(results.map(&:id)).to include(sale_asset.id, rental_asset.id)
        end
      end
    end

    describe 'associations' do
      let!(:asset) { create(:pwb_realty_asset, :with_photos, :with_features, :with_translations, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      it 'has access to prop_photos' do
        property = Property.find(asset.id)
        expect(property.prop_photos.count).to eq(2)
      end

      it 'has access to features' do
        property = Property.find(asset.id)
        expect(property.features.count).to eq(2)
      end

      it 'has access to translations' do
        property = Property.find(asset.id)
        expect(property.translations.count).to eq(2)
      end

      it 'belongs to website' do
        property = Property.find(asset.id)
        expect(property.website).to eq(website)
      end
    end

    describe 'underlying model access' do
      let!(:asset) { create(:pwb_realty_asset, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }
      let!(:rental_listing) { create(:pwb_rental_listing, :visible, :long_term, realty_asset: asset) }

      before { Pwb::Property.refresh }

      it '#realty_asset returns the underlying RealtyAsset' do
        property = Property.find(asset.id)
        expect(property.realty_asset).to be_a(RealtyAsset)
        expect(property.realty_asset.id).to eq(asset.id)
      end

      it '#sale_listing returns the associated SaleListing' do
        property = Property.find(asset.id)
        expect(property.sale_listing).to be_a(SaleListing)
        expect(property.sale_listing.id).to eq(sale_listing.id)
      end

      it '#rental_listing returns the associated RentalListing' do
        property = Property.find(asset.id)
        expect(property.rental_listing).to be_a(RentalListing)
        expect(property.rental_listing.id).to eq(rental_listing.id)
      end
    end

    describe 'title and description' do
      let!(:asset) { create(:pwb_realty_asset, :with_translations, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      it '#title returns translated title' do
        property = Property.find(asset.id)
        expect(property.title).to eq('Test Property Title')
      end

      it '#description returns translated description' do
        property = Property.find(asset.id)
        expect(property.description).to eq('A beautiful test property')
      end

      it 'provides locale-specific title methods' do
        property = Property.find(asset.id)
        expect(property.title_en).to eq('Test Property Title')
        expect(property.title_es).to eq('Titulo de Propiedad de Prueba')
      end
    end

    describe 'helper methods' do
      let!(:asset) do
        create(:pwb_realty_asset,
               website: website,
               count_bedrooms: 4,
               count_bathrooms: 2,
               count_garages: 1,
               constructed_area: 150.0,
               street_address: '123 Main St',
               city: 'Madrid',
               postal_code: '28001',
               country: 'Spain',
               latitude: 40.4168,
               longitude: -3.7038)
      end
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      let(:property) { Property.find(asset.id) }

      it '#bedrooms returns count_bedrooms' do
        expect(property.bedrooms).to eq(4)
      end

      it '#bathrooms returns count_bathrooms' do
        expect(property.bathrooms).to eq(2)
      end

      it '#surface_area returns constructed_area' do
        expect(property.surface_area).to eq(150.0)
      end

      it '#location returns formatted address' do
        expect(property.location).to eq('123 Main St, Madrid, 28001, Spain')
      end

      it '#has_garage returns true when garages > 0' do
        expect(property.has_garage).to be true
      end

      it '#show_map returns true when coordinates present' do
        expect(property.show_map).to be true
      end
    end

    describe 'price methods' do
      context 'with sale listing' do
        let!(:asset) { create(:pwb_realty_asset, website: website) }
        let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 350_000_00) }

        before { Pwb::Property.refresh }

        let(:property) { Property.find(asset.id) }

        it '#contextual_price returns sale price for for_sale' do
          price = property.contextual_price('for_sale')
          expect(price).to be_a(Money)
          expect(price.cents).to eq(350_000_00)
        end

        it '#contextual_price_with_currency returns formatted price' do
          formatted = property.contextual_price_with_currency('for_sale')
          expect(formatted).to include('350,000')
        end
      end

      context 'with rental listing' do
        let!(:asset) { create(:pwb_realty_asset, website: website) }
        let!(:rental_listing) { create(:pwb_rental_listing, :visible, :long_term, realty_asset: asset, price_rental_monthly_current_cents: 2_000_00) }

        before { Pwb::Property.refresh }

        let(:property) { Property.find(asset.id) }

        it '#contextual_price returns rental price for for_rent' do
          price = property.contextual_price('for_rent')
          expect(price).to be_a(Money)
          expect(price.cents).to eq(2_000_00)
        end
      end

      context 'with seasonal rental' do
        let!(:asset) { create(:pwb_realty_asset, website: website) }
        let!(:rental_listing) do
          create(:pwb_rental_listing, :visible, :short_term,
                 realty_asset: asset,
                 price_rental_monthly_low_season_cents: 800_00,
                 price_rental_monthly_current_cents: 1_500_00,
                 price_rental_monthly_high_season_cents: 2_500_00)
        end

        before { Pwb::Property.refresh }

        let(:property) { Property.find(asset.id) }

        it '#rental_price returns the lowest seasonal price' do
          expect(property.rental_price.cents).to eq(800_00)
        end

        it '#lowest_short_term_price returns minimum of seasonal prices' do
          expect(property.lowest_short_term_price.cents).to eq(800_00)
        end
      end
    end

    describe 'feature methods' do
      let!(:asset) { create(:pwb_realty_asset, :with_features, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      let(:property) { Property.find(asset.id) }

      it '#get_features returns hash of features' do
        features = property.get_features
        expect(features).to be_a(Hash)
        expect(features['pool']).to be true
        expect(features['garden']).to be true
      end

      it '#extras_for_display returns translated feature names' do
        # This depends on I18n translations being set up
        extras = property.extras_for_display
        expect(extras).to be_an(Array)
      end
    end

    describe 'photo methods' do
      let!(:asset) { create(:pwb_realty_asset, :with_photos, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      let(:property) { Property.find(asset.id) }

      it '#ordered_photo returns photo by position' do
        photo = property.ordered_photo(1)
        expect(photo).to be_a(PropPhoto)
      end

      it '#primary_image_url returns URL or empty string' do
        # Without attached images, returns empty string
        expect(property.primary_image_url).to be_a(String)
      end
    end

    describe 'URL methods' do
      let!(:asset) { create(:pwb_realty_asset, :with_translations, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      let(:property) { Property.find(asset.id) }

      it '#url_friendly_title returns parameterized title' do
        expect(property.url_friendly_title).to eq('test-property-title')
      end

      it '#contextual_show_path returns route path' do
        path = property.contextual_show_path('for_sale')
        expect(path).to include(property.id)
      end
    end

    describe '.properties_search' do
      let!(:cheap_sale) do
        asset = create(:pwb_realty_asset, website: website, count_bedrooms: 2)
        create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 100_000_00)
        asset
      end

      let!(:expensive_sale) do
        asset = create(:pwb_realty_asset, website: website, count_bedrooms: 4)
        create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 500_000_00)
        asset
      end

      let!(:rental) do
        asset = create(:pwb_realty_asset, website: website, count_bedrooms: 3)
        create(:pwb_rental_listing, :visible, :long_term, realty_asset: asset)
        asset
      end

      before { Pwb::Property.refresh }

      it 'returns sale properties for sale_or_rental: sale' do
        results = Property.properties_search(sale_or_rental: 'sale')
        expect(results.map(&:id)).to include(cheap_sale.id, expensive_sale.id)
        expect(results.map(&:id)).not_to include(rental.id)
      end

      it 'returns rental properties for sale_or_rental: rental' do
        results = Property.properties_search(sale_or_rental: 'rental')
        expect(results.map(&:id)).to include(rental.id)
        expect(results.map(&:id)).not_to include(cheap_sale.id)
      end

      it 'filters by bedroom count' do
        results = Property.properties_search(sale_or_rental: 'sale', count_bedrooms: 3)
        expect(results.map(&:id)).to include(expensive_sale.id)
        expect(results.map(&:id)).not_to include(cheap_sale.id)
      end
    end

    describe 'JSON serialization' do
      let!(:asset) { create(:pwb_realty_asset, :with_translations, :with_photos, website: website) }
      let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

      before { Pwb::Property.refresh }

      let(:property) { Property.find(asset.id) }

      it '#as_json includes title and description' do
        json = property.as_json
        expect(json['title']).to eq('Test Property Title')
        expect(json['description']).to eq('A beautiful test property')
      end

      it '#as_json includes prop_photos' do
        json = property.as_json
        expect(json['prop_photos']).to be_an(Array)
        expect(json['prop_photos'].length).to eq(2)
      end
    end
  end
end
