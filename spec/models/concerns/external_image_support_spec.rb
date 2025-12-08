# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalImageSupport, type: :model do
  # Use PropPhoto as test subject since it includes ExternalImageSupport
  let(:website) { FactoryBot.create(:pwb_website) }
  let(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website) }
  let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

  describe 'validations' do
    it 'allows valid HTTP URLs' do
      photo.external_url = 'http://example.com/image.jpg'
      expect(photo).to be_valid
    end

    it 'allows valid HTTPS URLs' do
      photo.external_url = 'https://example.com/path/to/image.jpg'
      expect(photo).to be_valid
    end

    it 'allows URLs with query parameters' do
      photo.external_url = 'https://example.com/image.jpg?width=800&height=600'
      expect(photo).to be_valid
    end

    it 'allows blank external_url' do
      photo.external_url = ''
      expect(photo).to be_valid
    end

    it 'allows nil external_url' do
      photo.external_url = nil
      expect(photo).to be_valid
    end

    it 'rejects invalid URLs without protocol' do
      photo.external_url = 'example.com/image.jpg'
      expect(photo).not_to be_valid
      expect(photo.errors[:external_url]).to include(/must be a valid HTTP or HTTPS URL/)
    end

    it 'rejects malformed URLs' do
      photo.external_url = 'not-a-url'
      expect(photo).not_to be_valid
    end
  end

  describe '#external?' do
    it 'returns true when external_url is present' do
      photo.external_url = 'https://example.com/image.jpg'
      expect(photo.external?).to be true
    end

    it 'returns false when external_url is blank' do
      photo.external_url = ''
      expect(photo.external?).to be false
    end

    it 'returns false when external_url is nil' do
      photo.external_url = nil
      expect(photo.external?).to be false
    end
  end

  describe '#image_url' do
    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/images/property.jpg' }

      it 'returns the external URL' do
        expect(photo.image_url).to eq('https://cdn.example.com/images/property.jpg')
      end

      it 'ignores variant options for external URLs' do
        expect(photo.image_url(variant_options: { resize_to_limit: [200, 200] }))
          .to eq('https://cdn.example.com/images/property.jpg')
      end
    end

    context 'without external URL or attached image' do
      it 'returns nil' do
        expect(photo.image_url).to be_nil
      end
    end
  end

  describe '#thumbnail_url' do
    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/images/property.jpg' }

      it 'returns the external URL (cannot resize external images)' do
        expect(photo.thumbnail_url).to eq('https://cdn.example.com/images/property.jpg')
      end

      it 'ignores size parameter for external URLs' do
        expect(photo.thumbnail_url(size: [100, 100]))
          .to eq('https://cdn.example.com/images/property.jpg')
      end
    end

    context 'without external URL or attached image' do
      it 'returns nil' do
        expect(photo.thumbnail_url).to be_nil
      end
    end
  end

  describe '#has_image?' do
    it 'returns true when external URL is present' do
      photo.external_url = 'https://example.com/image.jpg'
      expect(photo.has_image?).to be true
    end

    it 'returns false when no external URL and no attached image' do
      expect(photo.has_image?).to be false
    end
  end
end
