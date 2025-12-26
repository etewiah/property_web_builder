# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Media, 'CDN URL generation', type: :model do
  let(:website) { create(:pwb_website) }

  # Ensure ActiveStorage URL options are set for test environment
  # Must use before(:each) as ActiveStorage::Current uses thread-local storage
  before do
    ActiveStorage::Current.url_options = {
      host: 'localhost',
      port: 3000,
      protocol: 'http'
    }
  end

  describe '#url' do
    context 'with attached file' do
      let(:media) do
        media = build(:pwb_media, website: website)
        media.file.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )
        media.save!
        media
      end

      it 'returns a URL for the file' do
        expect(media.url).to be_present
      end

      it 'returns a String URL' do
        # Direct URLs should be strings
        url = media.url
        expect(url).to be_a(String)
      end

      it 'returns a valid URL format' do
        url = media.url
        # URL should start with http:// or https:// or /
        expect(url).to match(%r{\Ahttps?://|/})
      end
    end

    context 'without attached file' do
      let(:media) do
        # Create media without file attachment
        media = Pwb::Media.new(website: website, filename: 'no_file.jpg')
        media.save(validate: false)
        media
      end

      it 'returns nil' do
        expect(media.file.attached?).to be false
        expect(media.url).to be_nil
      end
    end
  end

  describe '#variant_url' do
    context 'with attached image' do
      let(:media) do
        media = build(:pwb_media, website: website)
        media.file.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )
        media.save!
        media
      end

      it 'returns a URL for the :thumb variant' do
        url = media.variant_url(:thumb)
        expect(url).to be_present
      end

      it 'returns a URL for the :small variant' do
        url = media.variant_url(:small)
        expect(url).to be_present
      end

      it 'returns a URL for the :medium variant' do
        url = media.variant_url(:medium)
        expect(url).to be_present
      end

      it 'returns a URL for the :large variant' do
        url = media.variant_url(:large)
        expect(url).to be_present
      end

      it 'returns original URL for unknown variant names' do
        url = media.variant_url(:unknown)
        # Both should return the original file URL (format may have timestamp differences)
        expect(url).to be_present
        expect(url).to match(%r{\Ahttps?://|/})
        # Should return the same blob path (not a variant path)
        expect(url).to include('/rails/active_storage/disk/')
        expect(url).not_to include('/representations/')
      end

      it 'returns a valid URL format' do
        url = media.variant_url(:thumb)
        # URL should be a valid format
        expect(url).to match(%r{\Ahttps?://|/})
      end

      # This test verifies CDN behavior in production-like environments
      # In test environment with Disk service, redirect URLs are expected
      it 'does not use redirect path when CDN is configured', skip: 'Only applies in production with R2 service' do
        url = media.variant_url(:thumb)
        expect(url).not_to include('/rails/active_storage/representations/redirect/')
      end
    end

    context 'with non-image file' do
      let(:media) do
        media = build(:pwb_media, website: website)
        media.file.attach(
          io: StringIO.new('test content'),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
        media.save!
        media
      end

      it 'returns a valid URL (same format as original)' do
        # Non-image files can't have variants, should return a URL
        variant_url = media.variant_url(:thumb)
        original_url = media.url

        # Both should be present
        expect(variant_url).to be_present
        expect(original_url).to be_present

        # Both should be valid URL formats
        expect(variant_url).to match(%r{\Ahttps?://|/})
        expect(original_url).to match(%r{\Ahttps?://|/})
      end
    end

    context 'without attached file' do
      let(:media) do
        # Create media without file attachment
        media = Pwb::Media.new(website: website, filename: 'no_file.jpg')
        media.save(validate: false)
        media
      end

      it 'returns nil' do
        expect(media.file.attached?).to be false
        expect(media.variant_url(:thumb)).to be_nil
      end
    end
  end
end
