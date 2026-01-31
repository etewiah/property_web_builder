# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Video::Generator do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user) }
  let(:property) do
    create(:pwb_realty_asset, website: website).tap do |asset|
      # Create enough photos to meet minimum requirement
      create_list(:pwb_prop_photo, 5, realty_asset: asset)
      asset.reload # Reload to pick up the new photos
    end
  end

  describe '#initialize' do
    it 'accepts required parameters' do
      generator = described_class.new(property: property, website: website)

      expect(generator.send(:property)).to eq(property)
      expect(generator.send(:website)).to eq(website)
    end

    it 'accepts optional user' do
      generator = described_class.new(property: property, website: website, user: user)

      expect(generator.send(:user)).to eq(user)
    end

    it 'merges options with defaults' do
      generator = described_class.new(
        property: property,
        website: website,
        options: { format: :horizontal_16_9 }
      )

      options = generator.send(:options)
      expect(options[:format]).to eq(:horizontal_16_9)
      expect(options[:style]).to eq(:professional) # default
    end

    it 'symbolizes option keys' do
      generator = described_class.new(
        property: property,
        website: website,
        options: { 'format' => :square_1_1 }
      )

      options = generator.send(:options)
      expect(options[:format]).to eq(:square_1_1)
    end
  end

  describe '#generate' do
    before do
      # Mock the job to prevent actual enqueuing
      allow(GenerateListingVideoJob).to receive(:perform_later)
    end

    context 'with valid inputs' do
      it 'returns a successful result' do
        result = described_class.new(property: property, website: website).generate

        expect(result.success?).to be true
        expect(result.video).to be_a(Pwb::ListingVideo)
        expect(result.error).to be_nil
      end

      it 'creates a ListingVideo record' do
        expect {
          described_class.new(property: property, website: website).generate
        }.to change(Pwb::ListingVideo, :count).by(1)
      end

      it 'sets correct video attributes' do
        result = described_class.new(
          property: property,
          website: website,
          user: user,
          options: { format: :horizontal_16_9, style: :luxury, voice: :onyx }
        ).generate

        video = result.video
        expect(video.website).to eq(website)
        expect(video.realty_asset).to eq(property)
        expect(video.user).to eq(user)
        expect(video.format).to eq('horizontal_16_9')
        expect(video.style).to eq('luxury')
        expect(video.voice).to eq('onyx')
        expect(video.status).to eq('pending')
      end

      it 'generates a title from the property address' do
        property.update!(street_address: '123 Main Street')

        result = described_class.new(property: property, website: website).generate

        expect(result.video.title).to eq('Video for 123 Main Street')
      end

      it 'falls back to city for title when no street address' do
        property.update!(street_address: nil, city: 'Barcelona')

        result = described_class.new(property: property, website: website).generate

        expect(result.video.title).to eq('Video for Barcelona')
      end

      it 'uses default title when no address info' do
        property.update!(street_address: nil, city: nil)

        result = described_class.new(property: property, website: website).generate

        expect(result.video.title).to eq('Video for Property')
      end

      it 'enqueues the generation job' do
        expect(GenerateListingVideoJob).to receive(:perform_later).with(
          video_id: kind_of(Integer),
          website_id: website.id
        )

        described_class.new(property: property, website: website).generate
      end

      it 'builds branding from website and user' do
        result = described_class.new(property: property, website: website, user: user).generate

        branding = result.video.branding
        expect(branding).to have_key('primary_color')
        expect(branding['primary_color']).to eq('#2563eb')
      end
    end

    context 'validation errors' do
      it 'fails when property is nil' do
        result = described_class.new(property: nil, website: website).generate

        expect(result.success?).to be false
        expect(result.error).to eq('Property is required')
      end

      it 'fails when website is nil' do
        result = described_class.new(property: property, website: nil).generate

        expect(result.success?).to be false
        expect(result.error).to eq('Website is required')
      end

      it 'fails when property has no photos' do
        property_without_photos = create(:pwb_realty_asset, website: website)

        result = described_class.new(property: property_without_photos, website: website).generate

        expect(result.success?).to be false
        expect(result.error).to eq('Property has no photos')
      end

      it 'fails when property has fewer than minimum required photos' do
        property_with_few_photos = create(:pwb_realty_asset, website: website)
        create_list(:pwb_prop_photo, 2, realty_asset: property_with_few_photos)
        property_with_few_photos.reload

        result = described_class.new(property: property_with_few_photos, website: website).generate

        expect(result.success?).to be false
        expect(result.error).to include('At least')
        expect(result.error).to include('photos required')
      end

      it 'fails with invalid format' do
        result = described_class.new(
          property: property,
          website: website,
          options: { format: :invalid_format }
        ).generate

        expect(result.success?).to be false
        expect(result.error).to include('Invalid format')
      end

      it 'fails with invalid style' do
        result = described_class.new(
          property: property,
          website: website,
          options: { style: :invalid_style }
        ).generate

        expect(result.success?).to be false
        expect(result.error).to include('Invalid style')
      end

      it 'fails with invalid voice' do
        result = described_class.new(
          property: property,
          website: website,
          options: { voice: :invalid_voice }
        ).generate

        expect(result.success?).to be false
        expect(result.error).to include('Invalid voice')
      end
    end

    context 'when an error occurs during creation' do
      before do
        allow(Pwb::ListingVideo).to receive(:create!).and_raise(StandardError, 'Database error')
      end

      it 'catches the error and returns failure' do
        result = described_class.new(property: property, website: website).generate

        expect(result.success?).to be false
        expect(result.error).to eq('Database error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Video::Generator.*Database error/)

        described_class.new(property: property, website: website).generate
      end
    end

    context 'format options' do
      described_class::FORMATS.each do |format|
        it "accepts #{format} format" do
          result = described_class.new(
            property: property,
            website: website,
            options: { format: format }
          ).generate

          expect(result.success?).to be true
          expect(result.video.format).to eq(format.to_s)
        end
      end
    end

    context 'style options' do
      described_class::STYLES.each do |style|
        it "accepts #{style} style" do
          result = described_class.new(
            property: property,
            website: website,
            options: { style: style }
          ).generate

          expect(result.success?).to be true
          expect(result.video.style).to eq(style.to_s)
        end
      end
    end

    context 'voice options' do
      described_class::VOICES.each do |voice|
        it "accepts #{voice} voice" do
          result = described_class.new(
            property: property,
            website: website,
            options: { voice: voice }
          ).generate

          expect(result.success?).to be true
          expect(result.video.voice).to eq(voice.to_s)
        end
      end
    end
  end

  describe 'multi-tenant isolation' do
    let(:other_website) { create(:pwb_website) }
    let(:other_property) do
      create(:pwb_realty_asset, website: other_website).tap do |asset|
        create_list(:pwb_prop_photo, 5, realty_asset: asset)
        asset.reload
      end
    end

    before do
      allow(GenerateListingVideoJob).to receive(:perform_later)
    end

    it 'creates video associated with correct website' do
      result = described_class.new(property: property, website: website).generate

      expect(result.video.website).to eq(website)
      expect(result.video.website).not_to eq(other_website)
    end

    it 'enqueues job with correct website_id' do
      expect(GenerateListingVideoJob).to receive(:perform_later).with(
        hash_including(website_id: website.id)
      )

      described_class.new(property: property, website: website).generate
    end
  end

  describe 'Result struct' do
    it 'has success? method' do
      result = Video::Generator::Result.new(success: true)
      expect(result.success?).to be true

      result = Video::Generator::Result.new(success: false)
      expect(result.success?).to be false
    end

    it 'can hold video and error' do
      video = build(:listing_video)
      result = Video::Generator::Result.new(success: true, video: video, error: nil)

      expect(result.video).to eq(video)
      expect(result.error).to be_nil
    end
  end
end
