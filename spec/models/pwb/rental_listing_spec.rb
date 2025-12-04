require 'rails_helper'

module Pwb
  RSpec.describe RentalListing, type: :model do
    let(:website) { create(:pwb_website) }
    let(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let(:rental_listing) { create(:pwb_rental_listing, realty_asset: realty_asset) }

    describe 'associations' do
      it 'belongs to realty_asset' do
        expect(rental_listing.realty_asset).to be_a(Pwb::RealtyAsset)
        expect(rental_listing.realty_asset.id).to eq(realty_asset.id)
      end
    end

    describe 'factory' do
      it 'has a valid factory' do
        expect(rental_listing).to be_valid
        expect(rental_listing).to be_persisted
      end

      it 'creates visible listing with trait' do
        listing = create(:pwb_rental_listing, :visible, realty_asset: realty_asset)
        expect(listing).to be_visible
      end

      it 'creates long term rental with trait' do
        listing = create(:pwb_rental_listing, :long_term, realty_asset: realty_asset)
        expect(listing.for_rent_long_term).to be true
      end

      it 'creates short term rental with trait' do
        listing = create(:pwb_rental_listing, :short_term, realty_asset: realty_asset)
        expect(listing.for_rent_short_term).to be true
        expect(listing.price_rental_monthly_low_season_cents).to be > 0
        expect(listing.price_rental_monthly_high_season_cents).to be > 0
      end

      it 'creates vacation rental with trait' do
        listing = create(:pwb_rental_listing, :vacation, realty_asset: realty_asset)
        expect(listing.for_rent_short_term).to be true
        expect(listing).to be_furnished
      end
    end

    describe 'scopes' do
      let!(:visible_long_term) { create(:pwb_rental_listing, :visible, :long_term, realty_asset: realty_asset) }
      let!(:visible_short_term) { create(:pwb_rental_listing, :visible, :short_term, realty_asset: create(:pwb_realty_asset, website: website)) }
      let!(:hidden_listing) { create(:pwb_rental_listing, realty_asset: create(:pwb_realty_asset, website: website)) }
      let!(:archived_listing) { create(:pwb_rental_listing, :archived, realty_asset: create(:pwb_realty_asset, website: website)) }

      it '.visible returns only visible listings' do
        expect(RentalListing.visible).to include(visible_long_term, visible_short_term)
        expect(RentalListing.visible).not_to include(hidden_listing, archived_listing)
      end

      it '.for_rent_long_term returns only long term rentals' do
        expect(RentalListing.for_rent_long_term).to include(visible_long_term)
        expect(RentalListing.for_rent_long_term).not_to include(visible_short_term)
      end

      it '.for_rent_short_term returns only short term rentals' do
        expect(RentalListing.for_rent_short_term).to include(visible_short_term)
        expect(RentalListing.for_rent_short_term).not_to include(visible_long_term)
      end

      it '.active returns visible and non-archived listings' do
        expect(RentalListing.active).to include(visible_long_term, visible_short_term)
        expect(RentalListing.active).not_to include(hidden_listing, archived_listing)
      end
    end

    describe 'monetization' do
      let(:seasonal_listing) { create(:pwb_rental_listing, :short_term, realty_asset: realty_asset) }

      it 'monetizes price_rental_monthly_current_cents' do
        rental_listing.price_rental_monthly_current_cents = 2_000_00
        expect(rental_listing.price_rental_monthly_current).to be_a(Money)
        expect(rental_listing.price_rental_monthly_current.cents).to eq(2_000_00)
      end

      it 'monetizes price_rental_monthly_low_season_cents' do
        expect(seasonal_listing.price_rental_monthly_low_season).to be_a(Money)
        expect(seasonal_listing.price_rental_monthly_low_season.cents).to eq(800_00)
      end

      it 'monetizes price_rental_monthly_high_season_cents' do
        expect(seasonal_listing.price_rental_monthly_high_season).to be_a(Money)
        expect(seasonal_listing.price_rental_monthly_high_season.cents).to eq(2_500_00)
      end
    end

    describe '#vacation_rental?' do
      it 'returns true for short term rentals' do
        listing = create(:pwb_rental_listing, :short_term, realty_asset: realty_asset)
        expect(listing.vacation_rental?).to be true
      end

      it 'returns false for long term rentals' do
        listing = create(:pwb_rental_listing, :long_term, realty_asset: realty_asset)
        expect(listing.vacation_rental?).to be false
      end
    end

    describe 'delegation to realty_asset' do
      before do
        realty_asset.update(
          reference: 'RENT-REF',
          count_bedrooms: 3,
          street_address: '789 Rental St',
          city: 'Valencia'
        )
      end

      it 'delegates reference' do
        expect(rental_listing.reference).to eq('RENT-REF')
      end

      it 'delegates count_bedrooms' do
        expect(rental_listing.count_bedrooms).to eq(3)
      end

      it 'delegates street_address' do
        expect(rental_listing.street_address).to eq('789 Rental St')
      end

      it 'delegates city' do
        expect(rental_listing.city).to eq('Valencia')
      end
    end

    describe 'materialized view refresh' do
      # These tests verify that listing changes trigger view refresh.
      # We stub the refresh method to track when it's called.

      it 'triggers refresh after create' do
        # Set expectation before creating the listing
        allow(Pwb::ListedProperty).to receive(:refresh)
        create(:pwb_rental_listing, realty_asset: realty_asset)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end

      it 'triggers refresh after update' do
        # Create listing first, then set expectation for update
        listing = create(:pwb_rental_listing, realty_asset: realty_asset)
        allow(Pwb::ListedProperty).to receive(:refresh)
        listing.update(price_rental_monthly_current_cents: 2_500_00)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end

      it 'triggers refresh after destroy' do
        # Create listing first, then set expectation for destroy
        listing = create(:pwb_rental_listing, realty_asset: realty_asset)
        allow(Pwb::ListedProperty).to receive(:refresh)
        listing.destroy
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end
    end
  end
end
