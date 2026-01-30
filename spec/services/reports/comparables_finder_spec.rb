# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::ComparablesFinder, type: :service do
  let(:website) { create(:pwb_website) }
  let(:subject_property) do
    create(:pwb_realty_asset, :with_location, :with_sale_listing,
           website: website,
           count_bedrooms: 3,
           count_bathrooms: 2,
           constructed_area: 150.0,
           year_construction: 2010,
           prop_type_key: 'apartment')
  end

  describe '#find' do
    context 'when no comparable properties exist' do
      it 'returns empty result' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        expect(result.comparables).to be_empty
        expect(result.total_found).to eq(0)
      end
    end

    context 'when comparable properties exist' do
      let!(:comparable1) do
        create(:pwb_realty_asset, :with_location, :with_sale_listing,
               website: website,
               count_bedrooms: 3,
               count_bathrooms: 2,
               constructed_area: 140.0,
               year_construction: 2012,
               prop_type_key: 'apartment',
               latitude: subject_property.latitude + 0.001,
               longitude: subject_property.longitude + 0.001)
      end

      let!(:comparable2) do
        create(:pwb_realty_asset, :with_location, :with_sale_listing,
               website: website,
               count_bedrooms: 4,
               count_bathrooms: 2,
               constructed_area: 160.0,
               year_construction: 2008,
               prop_type_key: 'apartment',
               latitude: subject_property.latitude + 0.002,
               longitude: subject_property.longitude + 0.002)
      end

      before do
        # Refresh the materialized view
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it 'finds comparable properties' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        expect(result.comparables.length).to be > 0
      end

      it 'excludes the subject property' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        property_ids = result.comparables.map { |c| c[:id] }
        expect(property_ids).not_to include(subject_property.id)
      end

      it 'calculates similarity scores' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        result.comparables.each do |comp|
          expect(comp[:similarity_score]).to be_a(Numeric)
          expect(comp[:similarity_score]).to be_between(0, 100)
        end
      end

      it 'calculates price adjustments' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        result.comparables.each do |comp|
          expect(comp[:adjustments]).to be_a(Hash)
        end
      end

      it 'sorts by similarity score descending' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        scores = result.comparables.map { |c| c[:similarity_score] }
        expect(scores).to eq(scores.sort.reverse)
      end

      it 'respects max_comparables option' do
        finder = described_class.new(
          subject: subject_property,
          website: website,
          options: { max_comparables: 1 }
        )
        result = finder.find

        expect(result.comparables.length).to be <= 1
      end

      it 'includes search criteria in result' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        expect(result.search_criteria).to include(
          radius_km: be_a(Numeric),
          months_back: be_a(Integer),
          property_type: 'apartment'
        )
      end
    end

    context 'with different website' do
      let!(:other_website) { create(:pwb_website) }
      let!(:other_property) do
        create(:pwb_realty_asset, :with_location, :with_sale_listing,
               website: other_website,
               count_bedrooms: 3,
               prop_type_key: 'apartment')
      end

      before do
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it 'does not include properties from other websites' do
        finder = described_class.new(subject: subject_property, website: website)
        result = finder.find

        property_ids = result.comparables.map { |c| c[:id] }
        expect(property_ids).not_to include(other_property.id)
      end
    end
  end

  describe 'adjustment calculations' do
    it 'adjusts for bedroom differences' do
      subject = build(:pwb_realty_asset, count_bedrooms: 3)
      comparable = { bedrooms: 2, price_cents: 300_000_00, constructed_area: 100 }

      finder = described_class.new(subject: subject, website: website)
      adjustments = finder.send(:calculate_adjustments, comparable.with_indifferent_access)

      expect(adjustments[:bedrooms]).to be_present
      expect(adjustments[:bedrooms][:difference]).to eq(1)
      expect(adjustments[:bedrooms][:adjustment_cents]).to eq(15_000_00)
    end

    it 'adjusts for size differences' do
      subject = build(:pwb_realty_asset, constructed_area: 150)
      comparable = { constructed_area: 100, price_cents: 300_000_00 }

      finder = described_class.new(subject: subject, website: website)
      adjustments = finder.send(:calculate_adjustments, comparable.with_indifferent_access)

      expect(adjustments[:size]).to be_present
      expect(adjustments[:size][:difference]).to eq(50)
    end
  end

  describe 'similarity scoring' do
    it 'gives higher score to more similar properties' do
      similar = {
        prop_type_key: 'apartment',
        count_bedrooms: 3,
        count_bathrooms: 2,
        constructed_area: 150,
        year_construction: 2010,
        latitude: subject_property.latitude,
        longitude: subject_property.longitude
      }.with_indifferent_access

      different = {
        prop_type_key: 'villa',
        count_bedrooms: 5,
        count_bathrooms: 4,
        constructed_area: 300,
        year_construction: 2000,
        latitude: subject_property.latitude + 0.1,
        longitude: subject_property.longitude + 0.1
      }.with_indifferent_access

      finder = described_class.new(subject: subject_property, website: website)

      similar_score = finder.send(:calculate_similarity, similar)
      different_score = finder.send(:calculate_similarity, different)

      expect(similar_score).to be > different_score
    end
  end
end
