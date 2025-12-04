require 'rails_helper'

module Pwb
  RSpec.describe RealtyAsset, type: :model do
    let(:website) { create(:pwb_website) }
    let(:realty_asset) { create(:pwb_realty_asset, website: website) }

    describe 'associations' do
      it 'belongs to website (optional)' do
        asset = build(:pwb_realty_asset, website: nil)
        expect(asset).to be_valid
      end

      it 'has many sale_listings' do
        expect(realty_asset.sale_listings).to be_an(ActiveRecord::Associations::CollectionProxy)
      end

      it 'has many rental_listings' do
        expect(realty_asset.rental_listings).to be_an(ActiveRecord::Associations::CollectionProxy)
      end

      it 'has many prop_photos' do
        expect(realty_asset.prop_photos).to be_an(ActiveRecord::Associations::CollectionProxy)
      end

      it 'has many features' do
        expect(realty_asset.features).to be_an(ActiveRecord::Associations::CollectionProxy)
      end

      it 'destroys dependent sale_listings' do
        asset = create(:pwb_realty_asset, :with_sale_listing, website: website)
        listing_id = asset.sale_listings.first.id
        asset.destroy
        expect(Pwb::SaleListing.exists?(listing_id)).to be false
      end

      it 'destroys dependent rental_listings' do
        asset = create(:pwb_realty_asset, :with_rental_listing, website: website)
        listing_id = asset.rental_listings.first.id
        asset.destroy
        expect(Pwb::RentalListing.exists?(listing_id)).to be false
      end
    end

    describe 'factory' do
      it 'has a valid factory' do
        expect(realty_asset).to be_valid
        expect(realty_asset).to be_persisted
      end

      it 'creates with sale listing trait' do
        asset = create(:pwb_realty_asset, :with_sale_listing, website: website)
        expect(asset.sale_listings.count).to eq(1)
        expect(asset.sale_listings.first).to be_visible
      end

      it 'creates with rental listing trait' do
        asset = create(:pwb_realty_asset, :with_rental_listing, website: website)
        expect(asset.rental_listings.count).to eq(1)
        expect(asset.rental_listings.first).to be_visible
      end
    end

    describe 'helper methods' do
      it '#bedrooms returns count_bedrooms' do
        realty_asset.count_bedrooms = 3
        expect(realty_asset.bedrooms).to eq(3)
      end

      it '#bathrooms returns count_bathrooms' do
        realty_asset.count_bathrooms = 2
        expect(realty_asset.bathrooms).to eq(2)
      end

      it '#surface_area returns constructed_area' do
        realty_asset.constructed_area = 150.0
        expect(realty_asset.surface_area).to eq(150.0)
      end

      it '#location returns formatted address' do
        realty_asset.street_address = '123 Main St'
        realty_asset.city = 'Madrid'
        realty_asset.postal_code = '28001'
        realty_asset.country = 'Spain'
        expect(realty_asset.location).to eq('123 Main St, Madrid, 28001, Spain')
      end

      it '#geocodeable_address returns address for geocoding' do
        realty_asset.street_address = '123 Main St'
        realty_asset.city = 'Madrid'
        realty_asset.region = 'Madrid'
        realty_asset.postal_code = '28001'
        expect(realty_asset.geocodeable_address).to eq('123 Main St, Madrid, Madrid, 28001')
      end
    end

    describe 'listing status methods' do
      context 'with active sale listing' do
        let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }

        it '#for_sale? returns true' do
          expect(realty_asset.for_sale?).to be true
        end

        it '#visible? returns true' do
          expect(realty_asset.visible?).to be true
        end
      end

      context 'with active rental listing' do
        let!(:rental_listing) { create(:pwb_rental_listing, :visible, :long_term, realty_asset: realty_asset) }

        it '#for_rent? returns true' do
          expect(realty_asset.for_rent?).to be true
        end

        it '#visible? returns true' do
          expect(realty_asset.visible?).to be true
        end
      end

      context 'without any listings' do
        it '#for_sale? returns false' do
          expect(realty_asset.for_sale?).to be false
        end

        it '#for_rent? returns false' do
          expect(realty_asset.for_rent?).to be false
        end

        it '#visible? returns false' do
          expect(realty_asset.visible?).to be false
        end
      end
    end

    describe 'title and description' do
      # RealtyAsset represents the physical property, not the listing.
      # Title and description belong to listings (SaleListing/RentalListing).

      it 'returns nil for title (marketing text belongs to listings)' do
        expect(realty_asset.title).to be_nil
      end

      it 'returns nil for description (marketing text belongs to listings)' do
        expect(realty_asset.description).to be_nil
      end

      it 'listings have their own title and description' do
        asset = create(:pwb_realty_asset, website: website)
        listing = create(:pwb_sale_listing, :visible, :with_translations, realty_asset: asset)
        expect(listing.title).to eq('Test Property Title')
        expect(listing.description).to eq('A beautiful test property')
      end
    end

    describe 'feature methods' do
      let(:asset_with_features) { create(:pwb_realty_asset, :with_features, website: website) }

      it '#get_features returns hash of features' do
        features = asset_with_features.get_features
        expect(features).to be_a(Hash)
        expect(features['pool']).to be true
        expect(features['garden']).to be true
      end

      it '#set_features= adds new features' do
        realty_asset.set_features = { 'terrace' => true, 'parking' => true }
        expect(realty_asset.features.pluck(:feature_key)).to contain_exactly('terrace', 'parking')
      end

      it '#set_features= removes features when set to false' do
        asset_with_features.set_features = { 'pool' => false }
        expect(asset_with_features.features.pluck(:feature_key)).to eq(['garden'])
      end
    end

    describe 'price method' do
      context 'with sale listing' do
        let!(:sale_listing) do
          create(:pwb_sale_listing, :visible,
                 realty_asset: realty_asset,
                 price_sale_current_cents: 300_000_00)
        end

        it 'returns formatted sale price' do
          expect(realty_asset.price).to include('300,000')
        end
      end

      context 'with rental listing only' do
        let!(:rental_listing) do
          create(:pwb_rental_listing, :visible, :long_term,
                 realty_asset: realty_asset,
                 price_rental_monthly_current_cents: 1_500_00)
        end

        it 'returns formatted rental price' do
          expect(realty_asset.price).to include('1,500')
        end
      end

      context 'without any listings' do
        it 'returns nil' do
          expect(realty_asset.price).to be_nil
        end
      end
    end

    describe 'materialized view refresh' do
      it 'triggers refresh after create' do
        expect(Pwb::ListedProperty).to receive(:refresh)
        create(:pwb_realty_asset, website: website)
      end

      it 'triggers refresh after update' do
        realty_asset # create it first
        expect(Pwb::ListedProperty).to receive(:refresh)
        realty_asset.update(count_bedrooms: 5)
      end

      it 'triggers refresh after destroy' do
        realty_asset # create it first
        expect(Pwb::ListedProperty).to receive(:refresh)
        realty_asset.destroy
      end
    end
  end
end
