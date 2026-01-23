# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe ListedProperty, 'image URL generation', type: :model do
    # Disable automatic refresh during test setup
    before(:each) do
      allow_any_instance_of(Pwb::RealtyAsset).to receive(:refresh_properties_view)
      allow_any_instance_of(Pwb::SaleListing).to receive(:refresh_properties_view)
      allow_any_instance_of(Pwb::RentalListing).to receive(:refresh_properties_view)
    end

    let(:website) { create(:pwb_website) }
    let!(:asset) { create(:pwb_realty_asset, website: website) }
    let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

    before { Pwb::ListedProperty.refresh }

    let(:property) { Pwb::ListedProperty.find(asset.id) }

    describe '#primary_image_url' do
      context 'with external URL photo' do
        let!(:photo) do
          create(:pwb_prop_photo,
                 realty_asset_id: asset.id,
                 external_url: 'https://external-cdn.example.com/property.jpg',
                 sort_order: 1)
        end

        before { Pwb::ListedProperty.refresh }

        it 'returns the external URL directly' do
          expect(property.primary_image_url).to eq('https://external-cdn.example.com/property.jpg')
        end
      end

      context 'with ActiveStorage image' do
        let!(:photo) { create(:pwb_prop_photo, :with_image, realty_asset_id: asset.id, sort_order: 1) }
        let(:expected_url) { 'https://cdn.example.com/attached-image.jpg' }

        before do
          Pwb::ListedProperty.refresh
          # Stub the url method on the attachment
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_return(expected_url)
        end

        it 'calls image.url (not rails_blob_url)' do
          expect(property.primary_image_url).to eq(expected_url)
        end
      end

      context 'with no photos' do
        it 'returns empty string' do
          expect(property.primary_image_url).to eq('')
        end
      end

      context 'when photo has no image' do
        let!(:photo) { create(:pwb_prop_photo, realty_asset_id: asset.id, sort_order: 1) }

        before { Pwb::ListedProperty.refresh }

        it 'returns empty string' do
          expect(property.primary_image_url).to eq('')
        end
      end
    end

    describe '#as_json serialization' do
      context 'with external URL photos' do
        let!(:photo) do
          create(:pwb_prop_photo,
                 realty_asset_id: asset.id,
                 external_url: 'https://external.example.com/image.jpg',
                 sort_order: 1)
        end

        before { Pwb::ListedProperty.refresh }

        it 'includes correct url in prop_photos' do
          json = property.as_json
          expect(json['prop_photos']).to be_an(Array)
          expect(json['prop_photos'].first['url']).to eq('https://external.example.com/image.jpg')
        end

        it 'includes primary_image_url with external URL' do
          json = property.as_json
          expect(json['primary_image_url']).to eq('https://external.example.com/image.jpg')
        end
      end

      context 'with ActiveStorage photos' do
        let!(:photo) { create(:pwb_prop_photo, :with_image, realty_asset_id: asset.id, sort_order: 1) }
        let(:cdn_url) { 'https://cdn.example.com/image.jpg' }

        before do
          Pwb::ListedProperty.refresh
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attached?).and_return(true)
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_return(cdn_url)
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:variable?).and_return(false)
        end

        it 'includes CDN url in prop_photos' do
          json = property.as_json
          expect(json['prop_photos']).to be_an(Array)
          expect(json['prop_photos'].first['url']).to eq(cdn_url)
        end
      end

      context 'with no photos' do
        it 'returns empty array for prop_photos' do
          json = property.as_json
          expect(json['prop_photos']).to eq([])
        end

        it 'returns empty string for primary_image_url' do
          json = property.as_json
          expect(json['primary_image_url']).to eq('')
        end
      end
    end

    describe 'URL consistency with PropPhoto#image_url' do
      let!(:photo) { create(:pwb_prop_photo, :with_image, realty_asset_id: asset.id, sort_order: 1) }
      let(:cdn_url) { 'https://cdn.example.com/consistent-url.jpg' }

      before do
        Pwb::ListedProperty.refresh
        # Both should use the same url generation mechanism
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attached?).and_return(true)
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_return(cdn_url)
      end

      it 'generates same URL as PropPhoto#image_url' do
        # Reload to get fresh photo
        reloaded_photo = Pwb::PropPhoto.find(photo.id)
        prop_photo_url = reloaded_photo.image_url

        listed_property_url = property.as_json['prop_photos'].first['url']

        expect(listed_property_url).to eq(prop_photo_url)
      end
    end

    describe 'variant URL generation' do
      let!(:photo) { create(:pwb_prop_photo, :with_image, realty_asset_id: asset.id, sort_order: 1) }
      let(:variant_url) { 'https://cdn.example.com/variant.jpg' }

      before do
        Pwb::ListedProperty.refresh
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attached?).and_return(true)
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:variable?).and_return(true)
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_return('https://cdn.example.com/original.jpg')
      end

      it 'generates variants using image.variant(...).processed.url' do
        variant_double = double('variant')
        processed_double = double('processed')

        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:variant).and_return(variant_double)
        allow(variant_double).to receive(:processed).and_return(processed_double)
        allow(processed_double).to receive(:url).and_return(variant_url)

        json = property.as_json
        expect(json['prop_photos'].first['variants']).to be_a(Hash)
        expect(json['prop_photos'].first['variants']['thumbnail']).to eq(variant_url)
      end
    end

    describe 'error handling' do
      let!(:photo) { create(:pwb_prop_photo, :with_image, realty_asset_id: asset.id, sort_order: 1) }

      before { Pwb::ListedProperty.refresh }

      context 'when url generation fails' do
        before do
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attached?).and_return(true)
          allow_any_instance_of(ActiveStorage::Attached::One).to receive(:url).and_raise(StandardError.new('URL generation failed'))
        end

        it 'logs warning and returns nil/empty for primary_image_url' do
          expect(Rails.logger).to receive(:warn).with(/Failed to generate primary image URL/)
          expect(property.primary_image_url).to eq('')
        end
      end
    end
  end
end
