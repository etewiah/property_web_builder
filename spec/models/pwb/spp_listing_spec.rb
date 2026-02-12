# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SppListing, type: :model do
    let(:website) { create(:pwb_website) }
    let(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let(:spp_listing) { create(:pwb_spp_listing, realty_asset: realty_asset) }

    describe 'associations' do
      it 'belongs to realty_asset' do
        expect(spp_listing.realty_asset).to be_a(Pwb::RealtyAsset)
        expect(spp_listing.realty_asset.id).to eq(realty_asset.id)
      end

      it 'is accessible from realty_asset' do
        spp_listing # create it
        expect(realty_asset.spp_listings).to include(spp_listing)
      end

      it 'is destroyed when realty_asset is destroyed' do
        spp_listing.update!(active: false)
        expect { realty_asset.destroy }.to change(SppListing, :count).by(-1)
      end
    end

    describe 'factory' do
      it 'has a valid factory' do
        expect(spp_listing).to be_valid
        expect(spp_listing).to be_persisted
      end

      it 'creates sale listing by default' do
        expect(spp_listing.listing_type).to eq('sale')
      end

      it 'creates rental listing with trait' do
        listing = create(:pwb_spp_listing, :rental, realty_asset: realty_asset)
        expect(listing.listing_type).to eq('rental')
        expect(listing.price_cents).to eq(2_500_00)
      end

      it 'creates published listing with trait' do
        listing = create(:pwb_spp_listing, :published, realty_asset: realty_asset)
        expect(listing).to be_active
        expect(listing).to be_visible
        expect(listing.published_at).to be_present
        expect(listing.live_url).to be_present
      end
    end

    describe 'validations' do
      it 'requires realty_asset_id' do
        listing = SppListing.new(listing_type: 'sale')
        expect(listing).not_to be_valid
        expect(listing.errors[:realty_asset_id]).to be_present
      end

      it 'requires listing_type' do
        listing = SppListing.new(realty_asset: realty_asset, listing_type: nil)
        expect(listing).not_to be_valid
        expect(listing.errors[:listing_type]).to be_present
      end

      it 'only allows sale or rental listing_type' do
        listing = SppListing.new(realty_asset: realty_asset, listing_type: 'auction')
        expect(listing).not_to be_valid
        expect(listing.errors[:listing_type]).to be_present
      end

      it 'accepts sale listing_type' do
        listing = build(:pwb_spp_listing, realty_asset: realty_asset, listing_type: 'sale')
        expect(listing).to be_valid
      end

      it 'accepts rental listing_type' do
        listing = build(:pwb_spp_listing, realty_asset: realty_asset, listing_type: 'rental')
        expect(listing).to be_valid
      end
    end

    describe 'scopes' do
      let!(:sale_listing) { create(:pwb_spp_listing, :sale, realty_asset: realty_asset) }
      let!(:rental_listing) do
        create(:pwb_spp_listing, :rental, realty_asset: realty_asset)
      end

      it '.sale returns only sale listings' do
        expect(SppListing.sale).to include(sale_listing)
        expect(SppListing.sale).not_to include(rental_listing)
      end

      it '.rental returns only rental listings' do
        expect(SppListing.rental).to include(rental_listing)
        expect(SppListing.rental).not_to include(sale_listing)
      end

      it '.active_listing returns only active listings' do
        inactive = create(:pwb_spp_listing, realty_asset: create(:pwb_realty_asset, website: website), active: false)
        expect(SppListing.active_listing).to include(sale_listing)
        expect(SppListing.active_listing).not_to include(inactive)
      end
    end

    describe 'monetization' do
      it 'monetizes price_cents' do
        spp_listing.price_cents = 500_000_00
        expect(spp_listing.price).to be_a(Money)
        expect(spp_listing.price.cents).to eq(500_000_00)
      end

      it 'respects price_currency' do
        spp_listing.price_cents = 100_00
        spp_listing.price_currency = 'USD'
        expect(spp_listing.price.currency.iso_code).to eq('USD')
      end
    end

    describe 'delegation to realty_asset' do
      before do
        realty_asset.update(
          reference: 'SPP-REF',
          count_bedrooms: 3,
          count_bathrooms: 2,
          street_address: '789 Beach Road',
          city: 'Biarritz'
        )
      end

      it 'delegates reference' do
        expect(spp_listing.reference).to eq('SPP-REF')
      end

      it 'delegates count_bedrooms' do
        expect(spp_listing.count_bedrooms).to eq(3)
      end

      it 'delegates city' do
        expect(spp_listing.city).to eq('Biarritz')
      end

      it 'delegates website' do
        expect(spp_listing.website).to eq(website)
      end

      it 'delegates website_id' do
        expect(spp_listing.website_id).to eq(website.id)
      end
    end

    describe 'active listing management (ListingStateable)' do
      describe 'uniqueness scoped by listing_type' do
        it 'allows one active sale and one active rental for same property' do
          sale = create(:pwb_spp_listing, :sale, realty_asset: realty_asset, active: true)
          rental = create(:pwb_spp_listing, :rental, realty_asset: realty_asset, active: true)

          expect(sale).to be_active
          expect(rental).to be_active
        end

        it 'prevents two active sale listings for same property via activate!' do
          sale1 = create(:pwb_spp_listing, :sale, realty_asset: realty_asset, active: true)
          sale2 = create(:pwb_spp_listing, :sale, realty_asset: realty_asset, active: false)

          sale2.activate!
          sale1.reload

          expect(sale1).not_to be_active
          expect(sale2).to be_active
        end

        it 'activating sale listing does not deactivate rental listing' do
          rental = create(:pwb_spp_listing, :rental, realty_asset: realty_asset, active: true)
          sale = create(:pwb_spp_listing, :sale, realty_asset: realty_asset, active: false)

          sale.activate!
          rental.reload

          expect(sale).to be_active
          expect(rental).to be_active
        end
      end

      describe '#activate!' do
        it 'sets the listing as active' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: false)
          listing.activate!
          expect(listing.reload).to be_active
        end

        it 'unarchives when activated' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: false, archived: true)
          listing.activate!
          expect(listing.reload).not_to be_archived
        end
      end

      describe '#deactivate!' do
        it 'sets the listing as inactive' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: true)
          listing.deactivate!
          expect(listing.reload).not_to be_active
        end
      end

      describe '#archive!' do
        it 'archives a non-active listing' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: false, visible: true)
          listing.archive!
          expect(listing.reload).to be_archived
          expect(listing).not_to be_visible
        end

        it 'raises error when archiving an active listing' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: true)
          expect { listing.archive! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      describe '#can_destroy?' do
        it 'returns false for active listing' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: true)
          expect(listing.can_destroy?).to be false
        end

        it 'returns true for non-active listing' do
          listing = create(:pwb_spp_listing, realty_asset: realty_asset, active: false)
          expect(listing.can_destroy?).to be true
        end
      end
    end

    describe '#ordered_photos' do
      let!(:photo1) { create(:pwb_prop_photo, realty_asset_id: realty_asset.id, sort_order: 1) }
      let!(:photo2) { create(:pwb_prop_photo, realty_asset_id: realty_asset.id, sort_order: 2) }
      let!(:photo3) { create(:pwb_prop_photo, realty_asset_id: realty_asset.id, sort_order: 3) }

      context 'with curated photo_ids_ordered' do
        before { spp_listing.update!(photo_ids_ordered: [photo3.id, photo1.id]) }

        it 'returns photos in the specified order' do
          photos = spp_listing.ordered_photos
          expect(photos.map(&:id)).to eq([photo3.id, photo1.id])
        end

        it 'excludes photos not in the list' do
          photos = spp_listing.ordered_photos
          expect(photos).not_to include(photo2)
        end
      end

      context 'without curated photo_ids_ordered' do
        it 'falls back to property default photo order' do
          photos = spp_listing.ordered_photos
          expect(photos.map(&:id)).to eq([photo1.id, photo2.id, photo3.id])
        end
      end

      context 'with empty photo_ids_ordered' do
        before { spp_listing.update!(photo_ids_ordered: []) }

        it 'falls back to property default photo order' do
          photos = spp_listing.ordered_photos
          expect(photos.map(&:id)).to eq([photo1.id, photo2.id, photo3.id])
        end
      end
    end

    describe '#display_features' do
      before do
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'sea_views')
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'pool')
        create(:pwb_feature, realty_asset_id: realty_asset.id, feature_key: 'garden')
        realty_asset.reload
      end

      context 'with highlighted_features' do
        before { spp_listing.update!(highlighted_features: %w[sea_views pool]) }

        it 'returns only highlighted features' do
          features = spp_listing.display_features
          expect(features.length).to eq(2)
          expect(features.map(&:feature_key)).to match_array(%w[sea_views pool])
        end
      end

      context 'without highlighted_features' do
        it 'falls back to all property features' do
          features = spp_listing.display_features
          expect(features.length).to eq(3)
        end
      end

      context 'with empty highlighted_features' do
        before { spp_listing.update!(highlighted_features: []) }

        it 'falls back to all property features' do
          features = spp_listing.display_features
          expect(features.length).to eq(3)
        end
      end
    end

    describe 'Mobility translations' do
      it 'stores and retrieves translated title' do
        spp_listing.title_en = 'Dream Mediterranean Retreat'
        spp_listing.save!
        spp_listing.reload
        expect(spp_listing.title_en).to eq('Dream Mediterranean Retreat')
      end

      it 'stores translations per locale independently' do
        spp_listing.title_en = 'English Title'
        spp_listing.title_es = 'Titulo Espanol'
        spp_listing.save!
        spp_listing.reload
        expect(spp_listing.title_en).to eq('English Title')
        expect(spp_listing.title_es).to eq('Titulo Espanol')
      end
    end

    describe 'materialized view refresh' do
      it 'triggers refresh after create' do
        allow(Pwb::ListedProperty).to receive(:refresh)
        create(:pwb_spp_listing, realty_asset: realty_asset)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end

      it 'triggers refresh after update' do
        listing = create(:pwb_spp_listing, realty_asset: realty_asset)
        allow(Pwb::ListedProperty).to receive(:refresh)
        listing.update(price_cents: 600_000_00)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end
    end

    describe 'extra_data JSONB expansion field' do
      it 'stores arbitrary JSON data' do
        spp_listing.update!(extra_data: {
          'agent_name' => 'Marie Dupont',
          'video_tour_url' => 'https://youtube.com/watch?v=abc'
        })
        spp_listing.reload
        expect(spp_listing.extra_data['agent_name']).to eq('Marie Dupont')
        expect(spp_listing.extra_data['video_tour_url']).to eq('https://youtube.com/watch?v=abc')
      end
    end

    describe 'spp_settings JSONB field' do
      it 'stores SPP-specific configuration' do
        spp_listing.update!(spp_settings: {
          'color_scheme' => 'dark',
          'layout' => 'wide'
        })
        spp_listing.reload
        expect(spp_listing.spp_settings['color_scheme']).to eq('dark')
      end
    end
  end
end
