# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::FairHousingComplianceChecker do
  subject(:checker) { described_class.new }

  describe '#check' do
    context 'with compliant text' do
      let(:compliant_texts) do
        [
          'Beautiful 3-bedroom apartment with modern kitchen and spacious living room.',
          'Luxury villa with pool and garden. Perfect for entertaining guests.',
          'Cozy studio in city center. Walking distance to shops and restaurants.',
          'Newly renovated home with hardwood floors and updated appliances.'
        ]
      end

      it 'returns compliant for clean descriptions' do
        compliant_texts.each do |text|
          result = checker.check(text)
          expect(result[:compliant]).to be(true), "Expected '#{text}' to be compliant"
          expect(result[:violations]).to be_empty
        end
      end
    end

    context 'with familial status violations' do
      it 'flags no children language' do
        result = checker.check('No children allowed in this property')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'familial_status' }).to be(true)
      end

      it 'flags adult only communities' do
        result = checker.check('Adult only community')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'familial_status' }).to be(true)
      end

      it 'flags no kids language' do
        result = checker.check('No kids please')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'familial_status' }).to be(true)
      end
    end

    context 'with age violations' do
      it 'flags senior only communities' do
        result = checker.check('Senior only community')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'age' }).to be(true)
      end

      it 'flags elderly references' do
        result = checker.check('Perfect for elderly tenants')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'age' }).to be(true)
      end

      it 'flags young professional preferences' do
        result = checker.check('Ideal for young professional')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'age' }).to be(true)
      end
    end

    context 'with religious violations' do
      it 'flags near religious institution references' do
        result = checker.check('Property is near church and school')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'religion' }).to be(true)
      end

      it 'flags religious community references' do
        result = checker.check('Located in Christian community')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'religion' }).to be(true)
      end
    end

    context 'with race/ethnicity violations' do
      it 'flags racial neighborhood descriptions' do
        result = checker.check('Located in white neighborhood')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'race' }).to be(true)
      end

      it 'flags exclusive community language' do
        result = checker.check('Exclusive community with great amenities')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'race' }).to be(true)
      end
    end

    context 'with disability violations' do
      it 'flags must be able to requirements' do
        result = checker.check('Must be able to climb stairs')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'disability' }).to be(true)
      end

      it 'flags no wheelchair language' do
        result = checker.check('No wheelchair access available')
        expect(result[:compliant]).to be(false)
        expect(result[:violations].any? { |v| v[:category] == 'disability' }).to be(true)
      end
    end

    context 'with multiple violations' do
      it 'returns all violations found' do
        text = 'Adult only community near church'
        result = checker.check(text)
        expect(result[:compliant]).to be(false)
        expect(result[:violations].length).to be >= 2
      end
    end

    context 'with review suggestions' do
      it 'includes suggestions for borderline phrases' do
        result = checker.check('Walk to shops and restaurants')
        expect(result[:suggestions]).not_to be_empty
      end

      it 'includes suggestions for school proximity' do
        result = checker.check('Close to schools and parks')
        expect(result[:suggestions]).not_to be_empty
      end
    end

    context 'with empty or nil text' do
      it 'returns compliant for empty string' do
        result = checker.check('')
        expect(result[:compliant]).to be(true)
      end

      it 'returns compliant for nil' do
        result = checker.check(nil)
        expect(result[:compliant]).to be(true)
      end
    end
  end
end
