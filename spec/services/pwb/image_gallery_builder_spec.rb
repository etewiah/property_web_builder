# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ImageGalleryBuilder do
  let(:website) { create(:pwb_website) }

  # Set tenant for the entire spec
  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  # Mock URL helper that responds to url_for
  let(:url_helper) do
    helper = double('url_helper')
    allow(helper).to receive(:url_for) do |arg|
      if arg.respond_to?(:variant)
        "/rails/active_storage/variant/#{arg.id}"
      else
        "/rails/active_storage/blobs/#{arg.try(:id) || 'test'}"
      end
    end
    helper
  end

  describe '#initialize' do
    it 'accepts a website and url_helper' do
      builder = described_class.new(website, url_helper: url_helper)
      expect(builder).to be_a(described_class)
    end

    it 'accepts custom limits' do
      builder = described_class.new(website, url_helper: url_helper, limits: { content: 10 })
      expect(builder).to be_a(described_class)
    end
  end

  describe '#build' do
    subject(:builder) { described_class.new(website, url_helper: url_helper) }

    context 'with no photos' do
      it 'returns an empty array' do
        expect(builder.build).to eq([])
      end
    end

    context 'with content photos' do
      let!(:content) { create(:pwb_content, website: website) }
      let!(:content_photo) { create(:content_photo, :with_image, content: content) }

      it 'includes content photos in the result' do
        result = builder.build
        content_images = result.select { |img| img[:type] == 'content' }
        expect(content_images.length).to eq(1)
      end

      it 'formats content photo correctly' do
        result = builder.content_photos.first
        expect(result[:id]).to eq("content_#{content_photo.id}")
        expect(result[:type]).to eq('content')
        expect(result[:filename]).to be_present
      end
    end

    context 'with website photos' do
      let!(:website_photo) { create(:website_photo, :with_image, website: website) }

      it 'includes website photos in the result' do
        result = builder.build
        website_images = result.select { |img| img[:type] == 'website' }
        expect(website_images.length).to eq(1)
      end

      it 'formats website photo correctly' do
        result = builder.website_photos.first
        expect(result[:id]).to eq("website_#{website_photo.id}")
        expect(result[:type]).to eq('website')
      end
    end

    context 'with property photos' do
      let!(:realty_asset) { create(:pwb_realty_asset, website: website, reference: 'REF-123') }
      let!(:prop_photo) { create(:prop_photo, :with_image, realty_asset: realty_asset) }

      it 'includes property photos in the result' do
        result = builder.build
        property_images = result.select { |img| img[:type] == 'property' }
        expect(property_images.length).to eq(1)
      end

      it 'formats property photo correctly' do
        result = builder.property_photos.first
        expect(result[:id]).to eq("prop_#{prop_photo.id}")
        expect(result[:type]).to eq('property')
        expect(result[:description]).to eq('REF-123')
      end
    end

    context 'with photos from another website' do
      let(:other_website) { create(:pwb_website) }

      before do
        # Create content under the other website's tenant context
        ActsAsTenant.with_tenant(other_website) do
          other_content = Pwb::Content.create!(website: other_website, key: 'test', tag: 'test')
          other_photo = Pwb::ContentPhoto.create!(content: other_content)
          other_photo.image.attach(
            io: StringIO.new('fake image data'),
            filename: 'other.jpg',
            content_type: 'image/jpeg'
          )
        end
      end

      it 'does not include photos from other websites' do
        result = builder.build
        expect(result).to be_empty
      end
    end

    context 'with photos without attached images' do
      let!(:content) { create(:pwb_content, website: website) }
      let!(:content_photo_no_image) { create(:content_photo, content: content) }

      it 'skips photos without attached images' do
        result = builder.build
        expect(result).to be_empty
      end
    end
  end

  describe 'respects limits' do
    subject(:builder) { described_class.new(website, url_helper: url_helper, limits: { content: 2 }) }

    let!(:content) { create(:pwb_content, website: website) }

    before do
      5.times { create(:content_photo, :with_image, content: content) }
    end

    it 'limits content photos to specified amount' do
      result = builder.content_photos
      expect(result.length).to eq(2)
    end
  end
end
