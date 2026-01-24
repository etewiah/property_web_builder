# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Testimonial, type: :model do
    let(:website) { create(:pwb_website) }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
      it { is_expected.to belong_to(:author_photo).class_name('Pwb::Media').optional }
    end

    describe 'validations' do
      subject { build(:pwb_testimonial, website: website) }

      it { is_expected.to validate_presence_of(:author_name) }
      it { is_expected.to validate_presence_of(:quote) }

      describe 'quote length' do
        it 'requires minimum 10 characters' do
          testimonial = build(:pwb_testimonial, website: website, quote: 'Short')
          expect(testimonial).not_to be_valid
          expect(testimonial.errors[:quote]).to include(match(/too short/))
        end

        it 'allows up to 1000 characters' do
          testimonial = build(:pwb_testimonial, website: website, quote: 'A' * 1000)
          expect(testimonial).to be_valid
        end

        it 'rejects over 1000 characters' do
          testimonial = build(:pwb_testimonial, website: website, quote: 'A' * 1001)
          expect(testimonial).not_to be_valid
          expect(testimonial.errors[:quote]).to include(match(/too long/))
        end
      end

      describe 'rating validation' do
        it 'allows ratings from 1 to 5' do
          (1..5).each do |rating|
            testimonial = build(:pwb_testimonial, website: website, rating: rating)
            expect(testimonial).to be_valid
          end
        end

        it 'allows nil rating' do
          testimonial = build(:pwb_testimonial, website: website, rating: nil)
          expect(testimonial).to be_valid
        end

        it 'rejects rating below 1' do
          testimonial = build(:pwb_testimonial, website: website, rating: 0)
          expect(testimonial).not_to be_valid
          expect(testimonial.errors[:rating]).to be_present
        end

        it 'rejects rating above 5' do
          testimonial = build(:pwb_testimonial, website: website, rating: 6)
          expect(testimonial).not_to be_valid
          expect(testimonial.errors[:rating]).to be_present
        end

        it 'rejects non-integer ratings' do
          testimonial = build(:pwb_testimonial, website: website, rating: 4.5)
          expect(testimonial).not_to be_valid
        end
      end

      describe 'position validation' do
        it 'must be an integer >= 0' do
          testimonial = build(:pwb_testimonial, website: website, position: -1)
          expect(testimonial).not_to be_valid
        end
      end
    end

    describe 'scopes' do
      let!(:visible_testimonial) { create(:pwb_testimonial, website: website, visible: true) }
      let!(:hidden_testimonial) { create(:pwb_testimonial, :hidden, website: website) }
      let!(:featured_testimonial) { create(:pwb_testimonial, :featured, website: website) }

      describe '.visible' do
        it 'returns only visible testimonials' do
          expect(Testimonial.visible).to include(visible_testimonial, featured_testimonial)
          expect(Testimonial.visible).not_to include(hidden_testimonial)
        end
      end

      describe '.featured' do
        it 'returns only featured testimonials' do
          expect(Testimonial.featured).to include(featured_testimonial)
          expect(Testimonial.featured).not_to include(visible_testimonial)
        end
      end

      describe '.ordered' do
        let!(:testimonial1) { create(:pwb_testimonial, website: website, position: 2, created_at: 2.days.ago) }
        let!(:testimonial2) { create(:pwb_testimonial, website: website, position: 1, created_at: 1.day.ago) }
        let!(:testimonial3) { create(:pwb_testimonial, website: website, position: 2, created_at: Time.current) }

        it 'orders by position asc, then created_at desc' do
          result = Testimonial.ordered.where(id: [testimonial1, testimonial2, testimonial3].map(&:id))
          expect(result.first).to eq(testimonial2)
          # For same position, most recent first
        end
      end
    end

    describe 'instance methods' do
      describe '#author_photo_url' do
        context 'without author_photo' do
          let(:testimonial) { create(:pwb_testimonial, website: website, author_photo: nil) }

          it 'returns nil' do
            expect(testimonial.author_photo_url).to be_nil
          end
        end

        context 'with author_photo' do
          let(:media) { create(:pwb_media, website: website) }
          let(:testimonial) { create(:pwb_testimonial, website: website, author_photo: media) }

          it 'delegates to author_photo.image_url' do
            allow(media).to receive(:image_url).and_return('https://example.com/photo.jpg')
            expect(testimonial.author_photo_url).to eq('https://example.com/photo.jpg')
          end
        end
      end

      describe '#as_api_json' do
        let(:testimonial) do
          create(:pwb_testimonial,
            website: website,
            author_name: 'John Doe',
            author_role: 'CEO',
            quote: 'Great service, highly recommended!',
            rating: 5,
            position: 1
          )
        end

        it 'returns correct structure' do
          json = testimonial.as_api_json

          expect(json[:id]).to eq(testimonial.id)
          expect(json[:quote]).to eq('Great service, highly recommended!')
          expect(json[:author_name]).to eq('John Doe')
          expect(json[:author_role]).to eq('CEO')
          expect(json[:rating]).to eq(5)
          expect(json[:position]).to eq(1)
        end

        it 'includes author_photo when present' do
          media = create(:pwb_media, website: website)
          testimonial.update!(author_photo: media)
          allow(media).to receive(:image_url).and_return('https://example.com/photo.jpg')

          json = testimonial.as_api_json
          expect(json[:author_photo]).to eq('https://example.com/photo.jpg')
        end

        it 'returns nil for author_photo when not present' do
          json = testimonial.as_api_json
          expect(json[:author_photo]).to be_nil
        end
      end
    end

    describe 'multi-tenancy' do
      let(:website_a) { create(:pwb_website) }
      let(:website_b) { create(:pwb_website) }
      let!(:testimonial_a) { create(:pwb_testimonial, website: website_a) }
      let!(:testimonial_b) { create(:pwb_testimonial, website: website_b) }

      it 'testimonial belongs to specific website' do
        expect(testimonial_a.website).to eq(website_a)
        expect(testimonial_b.website).to eq(website_b)
      end
    end

    describe 'factory traits' do
      it 'creates featured testimonial' do
        testimonial = create(:pwb_testimonial, :featured, website: website)
        expect(testimonial.featured).to be true
      end

      it 'creates hidden testimonial' do
        testimonial = create(:pwb_testimonial, :hidden, website: website)
        expect(testimonial.visible).to be false
      end
    end
  end
end
