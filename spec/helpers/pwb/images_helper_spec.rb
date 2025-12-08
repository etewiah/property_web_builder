# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ImagesHelper, type: :helper do
  let(:website) { FactoryBot.create(:pwb_website) }
  let(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website) }

  describe '#photo_has_image?' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://example.com/image.jpg' }

      it 'returns true' do
        expect(helper.photo_has_image?(photo)).to be true
      end
    end

    context 'without external URL or attached image' do
      it 'returns false' do
        expect(helper.photo_has_image?(photo)).to be false
      end
    end

    context 'with nil photo' do
      it 'returns false' do
        expect(helper.photo_has_image?(nil)).to be false
      end
    end
  end

  describe '#photo_url' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/property.jpg' }

      it 'returns the external URL' do
        expect(helper.photo_url(photo)).to eq('https://cdn.example.com/property.jpg')
      end
    end

    context 'without external URL or attached image' do
      it 'returns nil' do
        expect(helper.photo_url(photo)).to be_nil
      end
    end

    context 'with nil photo' do
      it 'returns nil' do
        expect(helper.photo_url(nil)).to be_nil
      end
    end
  end

  describe '#photo_image_tag' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/property.jpg' }

      it 'returns an image tag with the external URL' do
        result = helper.photo_image_tag(photo, class: 'thumbnail')
        expect(result).to include('src="https://cdn.example.com/property.jpg"')
        expect(result).to include('class="thumbnail"')
      end
    end

    context 'without external URL or attached image' do
      it 'returns nil' do
        expect(helper.photo_image_tag(photo)).to be_nil
      end
    end

    context 'with nil photo' do
      it 'returns nil' do
        expect(helper.photo_image_tag(nil)).to be_nil
      end
    end
  end

  describe '#opt_image_tag' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/property.jpg' }

      it 'returns an image tag with the external URL' do
        result = helper.opt_image_tag(photo, class: 'photo')
        expect(result).to include('src="https://cdn.example.com/property.jpg"')
      end
    end

    context 'with nil photo' do
      it 'returns nil' do
        expect(helper.opt_image_tag(nil)).to be_nil
      end
    end
  end

  describe '#bg_image' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/bg.jpg' }

      it 'returns background-image style with the external URL' do
        result = helper.bg_image(photo)
        expect(result).to eq('background-image: url(https://cdn.example.com/bg.jpg);')
      end

      it 'supports gradient overlay' do
        result = helper.bg_image(photo, gradient: 'rgba(0,0,0,0.5), rgba(0,0,0,0.3)')
        expect(result).to include('linear-gradient(rgba(0,0,0,0.5), rgba(0,0,0,0.3))')
        expect(result).to include('url(https://cdn.example.com/bg.jpg)')
      end
    end

    context 'without external URL or attached image' do
      it 'returns background-image style with empty URL' do
        result = helper.bg_image(photo)
        expect(result).to eq('background-image: url();')
      end
    end
  end

  describe '#opt_image_url' do
    let(:photo) { Pwb::PropPhoto.new(realty_asset: realty_asset) }

    context 'with external URL' do
      before { photo.external_url = 'https://cdn.example.com/property.jpg' }

      it 'returns the external URL' do
        expect(helper.opt_image_url(photo)).to eq('https://cdn.example.com/property.jpg')
      end
    end

    context 'without external URL or attached image' do
      it 'returns empty string' do
        expect(helper.opt_image_url(photo)).to eq('')
      end
    end
  end
end
