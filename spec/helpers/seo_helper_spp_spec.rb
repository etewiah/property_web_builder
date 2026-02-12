# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeoHelper, type: :helper do
  let(:website) { create(:pwb_website) }
  let(:property) { create(:pwb_realty_asset, website: website) }

  before do
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe '#spp_live_url_for' do
    context 'with active, visible SppListing' do
      let!(:spp_listing) do
        create(:pwb_spp_listing, :published,
               realty_asset: property,
               listing_type: 'sale',
               live_url: 'https://nice-villa-sale.spp.example.com/')
      end

      it 'returns the SPP live URL' do
        expect(helper.spp_live_url_for(property)).to eq('https://nice-villa-sale.spp.example.com/')
      end

      it 'returns the URL when scoped by matching listing_type' do
        expect(helper.spp_live_url_for(property, 'sale')).to eq('https://nice-villa-sale.spp.example.com/')
      end

      it 'returns nil when scoped by non-matching listing_type' do
        expect(helper.spp_live_url_for(property, 'rental')).to be_nil
      end
    end

    context 'with active but not visible SppListing' do
      let!(:spp_listing) do
        create(:pwb_spp_listing,
               realty_asset: property,
               active: true,
               visible: false,
               live_url: 'https://hidden.spp.example.com/')
      end

      it 'returns nil' do
        expect(helper.spp_live_url_for(property)).to be_nil
      end
    end

    context 'with no SppListing' do
      it 'returns nil' do
        expect(helper.spp_live_url_for(property)).to be_nil
      end
    end

    context 'with inactive SppListing' do
      let!(:spp_listing) do
        create(:pwb_spp_listing,
               realty_asset: property,
               active: false,
               visible: true,
               live_url: 'https://inactive.spp.example.com/')
      end

      it 'returns nil' do
        expect(helper.spp_live_url_for(property)).to be_nil
      end
    end

    context 'with multiple listing types' do
      let!(:sale_spp) do
        create(:pwb_spp_listing, :published,
               realty_asset: property,
               listing_type: 'sale',
               live_url: 'https://villa-sale.spp.example.com/')
      end
      let!(:rental_spp) do
        create(:pwb_spp_listing,
               realty_asset: property,
               listing_type: 'rental',
               active: true,
               visible: true,
               live_url: 'https://villa-rental.spp.example.com/')
      end

      it 'returns sale URL when scoped to sale' do
        expect(helper.spp_live_url_for(property, 'sale')).to eq('https://villa-sale.spp.example.com/')
      end

      it 'returns rental URL when scoped to rental' do
        expect(helper.spp_live_url_for(property, 'rental')).to eq('https://villa-rental.spp.example.com/')
      end
    end
  end
end
