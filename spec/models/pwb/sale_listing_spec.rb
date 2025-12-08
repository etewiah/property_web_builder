require 'rails_helper'

module Pwb
  RSpec.describe SaleListing, type: :model do
    let(:website) { create(:pwb_website) }
    let(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let(:sale_listing) { create(:pwb_sale_listing, realty_asset: realty_asset) }

    describe 'associations' do
      it 'belongs to realty_asset' do
        expect(sale_listing.realty_asset).to be_a(Pwb::RealtyAsset)
        expect(sale_listing.realty_asset.id).to eq(realty_asset.id)
      end
    end

    describe 'factory' do
      it 'has a valid factory' do
        expect(sale_listing).to be_valid
        expect(sale_listing).to be_persisted
      end

      it 'creates visible listing with trait' do
        listing = create(:pwb_sale_listing, :visible, realty_asset: realty_asset)
        expect(listing).to be_visible
      end

      it 'creates highlighted listing with trait' do
        listing = create(:pwb_sale_listing, :highlighted, realty_asset: realty_asset)
        expect(listing).to be_highlighted
        expect(listing).to be_visible
      end

      it 'creates luxury listing with trait' do
        listing = create(:pwb_sale_listing, :luxury, realty_asset: realty_asset)
        expect(listing.price_sale_current_cents).to eq(150_000_000)
      end
    end

    describe 'scopes' do
      let!(:visible_listing) { create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }
      let!(:hidden_listing) { create(:pwb_sale_listing, realty_asset: create(:pwb_realty_asset, website: website)) }
      let!(:highlighted_listing) { create(:pwb_sale_listing, :highlighted, realty_asset: create(:pwb_realty_asset, website: website)) }
      let!(:archived_listing) { create(:pwb_sale_listing, :archived, realty_asset: create(:pwb_realty_asset, website: website)) }

      it '.visible returns only visible listings' do
        expect(SaleListing.visible).to include(visible_listing, highlighted_listing)
        expect(SaleListing.visible).not_to include(hidden_listing, archived_listing)
      end

      it '.highlighted returns only highlighted listings' do
        expect(SaleListing.highlighted).to include(highlighted_listing)
        expect(SaleListing.highlighted).not_to include(visible_listing)
      end

      it '.archived returns only archived listings' do
        expect(SaleListing.archived).to include(archived_listing)
        expect(SaleListing.archived).not_to include(visible_listing)
      end

      it '.active returns visible and non-archived listings' do
        expect(SaleListing.active).to include(visible_listing, highlighted_listing)
        expect(SaleListing.active).not_to include(hidden_listing, archived_listing)
      end
    end

    describe 'monetization' do
      it 'monetizes price_sale_current_cents' do
        sale_listing.price_sale_current_cents = 500_000_00
        expect(sale_listing.price_sale_current).to be_a(Money)
        expect(sale_listing.price_sale_current.cents).to eq(500_000_00)
      end

      it 'monetizes commission_cents' do
        sale_listing.commission_cents = 15_000_00
        expect(sale_listing.commission).to be_a(Money)
        expect(sale_listing.commission.cents).to eq(15_000_00)
      end
    end

    describe 'delegation to realty_asset' do
      before do
        realty_asset.update(
          reference: 'TEST-REF',
          count_bedrooms: 4,
          count_bathrooms: 2,
          street_address: '456 Test Ave',
          city: 'Barcelona'
        )
      end

      it 'delegates reference' do
        expect(sale_listing.reference).to eq('TEST-REF')
      end

      it 'delegates count_bedrooms' do
        expect(sale_listing.count_bedrooms).to eq(4)
      end

      it 'delegates count_bathrooms' do
        expect(sale_listing.count_bathrooms).to eq(2)
      end

      it 'delegates street_address' do
        expect(sale_listing.street_address).to eq('456 Test Ave')
      end

      it 'delegates city' do
        expect(sale_listing.city).to eq('Barcelona')
      end
    end

    describe 'materialized view refresh' do
      # These tests verify that listing changes trigger view refresh.
      # We stub the refresh method to track when it's called.

      it 'triggers refresh after create' do
        # Set expectation before creating the listing
        allow(Pwb::ListedProperty).to receive(:refresh)
        create(:pwb_sale_listing, realty_asset: realty_asset)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end

      it 'triggers refresh after update' do
        # Create listing first, then set expectation for update
        listing = create(:pwb_sale_listing, realty_asset: realty_asset)
        allow(Pwb::ListedProperty).to receive(:refresh)
        listing.update(price_sale_current_cents: 600_000_00)
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end

      it 'triggers refresh after destroy' do
        # Create listing first, then set expectation for destroy
        listing = create(:pwb_sale_listing, realty_asset: realty_asset)
        allow(Pwb::ListedProperty).to receive(:refresh)
        listing.destroy
        expect(Pwb::ListedProperty).to have_received(:refresh).at_least(:once)
      end
    end

    describe 'active listing management' do
      let(:realty_asset2) { create(:pwb_realty_asset, website: website) }

      describe 'only one active listing per realty asset' do
        it 'allows only one active listing per realty asset via activate! method' do
          listing1 = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          listing2 = create(:pwb_sale_listing, realty_asset: realty_asset, active: false)

          # Use activate! method to properly handle deactivation of other listings
          listing2.activate!
          listing1.reload

          expect(listing1).not_to be_active
          expect(listing2).to be_active
        end

        it 'allows different realty assets to each have an active listing' do
          listing1 = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          listing2 = create(:pwb_sale_listing, realty_asset: realty_asset2, active: true)

          expect(listing1).to be_active
          expect(listing2).to be_active
        end
      end

      describe '#activate!' do
        it 'sets the listing as active' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: false)
          listing.activate!

          expect(listing.reload).to be_active
        end

        it 'deactivates other active listings for the same asset' do
          listing1 = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          listing2 = create(:pwb_sale_listing, realty_asset: realty_asset, active: false)

          listing2.activate!

          expect(listing1.reload).not_to be_active
          expect(listing2.reload).to be_active
        end

        it 'unarchives the listing when activated' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: false, archived: true)
          listing.activate!

          expect(listing.reload).not_to be_archived
        end
      end

      describe '#deactivate!' do
        it 'sets the listing as inactive' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          listing.deactivate!

          expect(listing.reload).not_to be_active
        end
      end

      describe '#archive!' do
        it 'archives a non-active listing' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: false, visible: true)
          listing.archive!

          expect(listing.reload).to be_archived
          expect(listing).not_to be_visible
        end

        it 'raises error when archiving an active listing' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)

          expect { listing.archive! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      describe '#unarchive!' do
        it 'unarchives an archived listing' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, archived: true)
          listing.unarchive!

          expect(listing.reload).not_to be_archived
        end
      end

      describe '#can_destroy?' do
        it 'returns false for active listing' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          expect(listing.can_destroy?).to be false
        end

        it 'returns true for non-active listing' do
          listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: false)
          expect(listing.can_destroy?).to be true
        end
      end

      describe '.active_listing scope' do
        it 'returns only active listings' do
          active_listing = create(:pwb_sale_listing, realty_asset: realty_asset, active: true)
          inactive_listing = create(:pwb_sale_listing, realty_asset: realty_asset2, active: false)

          expect(SaleListing.active_listing).to include(active_listing)
          expect(SaleListing.active_listing).not_to include(inactive_listing)
        end
      end

      describe '.not_archived scope' do
        it 'returns only non-archived listings' do
          non_archived = create(:pwb_sale_listing, realty_asset: realty_asset, archived: false)
          # Archived listings must have active: false to avoid callback unarchiving them
          archived = create(:pwb_sale_listing, realty_asset: realty_asset2, archived: true, active: false)

          expect(SaleListing.not_archived).to include(non_archived)
          expect(SaleListing.not_archived).not_to include(archived)
        end
      end
    end
  end
end
