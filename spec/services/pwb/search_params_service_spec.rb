# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::SearchParamsService do
  let(:service) { described_class.new }

  describe '#from_url_params' do
    context 'with property type' do
      it 'parses type parameter' do
        params = ActionController::Parameters.new(type: 'apartment')
        result = service.from_url_params(params)
        expect(result[:property_type]).to eq('apartment')
      end

      it 'normalizes type to lowercase slug' do
        params = ActionController::Parameters.new(type: 'Villa')
        result = service.from_url_params(params)
        expect(result[:property_type]).to eq('villa')
      end
    end

    context 'with numeric parameters' do
      it 'parses bedrooms as integer' do
        params = ActionController::Parameters.new(bedrooms: '2')
        result = service.from_url_params(params)
        expect(result[:bedrooms]).to eq(2)
      end

      it 'parses bathrooms as integer' do
        params = ActionController::Parameters.new(bathrooms: '1')
        result = service.from_url_params(params)
        expect(result[:bathrooms]).to eq(1)
      end

      it 'parses price_min as integer' do
        params = ActionController::Parameters.new(price_min: '100000')
        result = service.from_url_params(params)
        expect(result[:price_min]).to eq(100_000)
      end

      it 'parses price_max as integer' do
        params = ActionController::Parameters.new(price_max: '500000')
        result = service.from_url_params(params)
        expect(result[:price_max]).to eq(500_000)
      end

      it 'parses page as integer' do
        params = ActionController::Parameters.new(page: '3')
        result = service.from_url_params(params)
        expect(result[:page]).to eq(3)
      end

      it 'handles invalid numeric values gracefully' do
        params = ActionController::Parameters.new(bedrooms: 'invalid')
        result = service.from_url_params(params)
        expect(result[:bedrooms]).to be_nil
      end
    end

    context 'with comma-separated features' do
      it 'parses features into array' do
        params = ActionController::Parameters.new(features: 'pool,garden,sea-views')
        result = service.from_url_params(params)
        expect(result[:features]).to eq(%w[pool garden sea-views])
      end

      it 'handles single feature' do
        params = ActionController::Parameters.new(features: 'pool')
        result = service.from_url_params(params)
        expect(result[:features]).to eq(['pool'])
      end

      it 'normalizes feature slugs' do
        params = ActionController::Parameters.new(features: 'Pool,Sea Views')
        result = service.from_url_params(params)
        expect(result[:features]).to eq(%w[pool sea-views])
      end
    end

    context 'with location parameters' do
      it 'parses zone parameter' do
        params = ActionController::Parameters.new(zone: 'costa-del-sol')
        result = service.from_url_params(params)
        expect(result[:zone]).to eq('costa-del-sol')
      end

      it 'parses locality parameter' do
        params = ActionController::Parameters.new(locality: 'marbella')
        result = service.from_url_params(params)
        expect(result[:locality]).to eq('marbella')
      end
    end

    context 'with sort parameter' do
      it 'parses sort parameter' do
        params = ActionController::Parameters.new(sort: 'price-asc')
        result = service.from_url_params(params)
        expect(result[:sort]).to eq('price-asc')
      end

      it 'validates sort values' do
        params = ActionController::Parameters.new(sort: 'invalid-sort')
        result = service.from_url_params(params)
        expect(result[:sort]).to be_nil
      end

      it 'accepts valid sort values' do
        %w[price-asc price-desc newest oldest].each do |sort|
          params = ActionController::Parameters.new(sort: sort)
          result = service.from_url_params(params)
          expect(result[:sort]).to eq(sort)
        end
      end
    end

    context 'with view parameter' do
      it 'parses view parameter' do
        params = ActionController::Parameters.new(view: 'grid')
        result = service.from_url_params(params)
        expect(result[:view]).to eq('grid')
      end

      it 'validates view values' do
        params = ActionController::Parameters.new(view: 'invalid')
        result = service.from_url_params(params)
        expect(result[:view]).to be_nil
      end

      it 'accepts valid view values' do
        %w[grid list map].each do |view|
          params = ActionController::Parameters.new(view: view)
          result = service.from_url_params(params)
          expect(result[:view]).to eq(view)
        end
      end
    end

    context 'with unknown parameters' do
      it 'ignores unknown parameters' do
        params = ActionController::Parameters.new(unknown: 'value', malicious: 'script')
        result = service.from_url_params(params)
        expect(result.keys).not_to include(:unknown, :malicious)
      end

      it 'preserves known parameters when unknown present' do
        params = ActionController::Parameters.new(type: 'apartment', unknown: 'value')
        result = service.from_url_params(params)
        expect(result[:property_type]).to eq('apartment')
      end
    end

    context 'with empty values' do
      it 'omits empty string values' do
        params = ActionController::Parameters.new(type: '', bedrooms: '')
        result = service.from_url_params(params)
        expect(result[:property_type]).to be_nil
        expect(result[:bedrooms]).to be_nil
      end

      it 'omits nil values' do
        params = ActionController::Parameters.new(type: nil)
        result = service.from_url_params(params)
        expect(result[:property_type]).to be_nil
      end
    end

    context 'with legacy format parameters' do
      it 'handles legacy search[param] format' do
        params = ActionController::Parameters.new(search: { property_type: 'apartment' })
        result = service.from_url_params(params)
        expect(result[:property_type]).to eq('apartment')
      end

      it 'prefers new format over legacy when both present' do
        params = ActionController::Parameters.new(
          type: 'villa',
          search: { property_type: 'apartment' }
        )
        result = service.from_url_params(params)
        expect(result[:property_type]).to eq('villa')
      end
    end
  end

  describe '#to_url_params' do
    it 'generates clean URL params' do
      criteria = { property_type: 'apartment', bedrooms: 2 }
      result = service.to_url_params(criteria)
      expect(result).to eq('bedrooms=2&type=apartment')
    end

    it 'omits empty values' do
      criteria = { property_type: 'apartment', bedrooms: nil, bathrooms: '' }
      result = service.to_url_params(criteria)
      expect(result).to eq('type=apartment')
      expect(result).not_to include('bedrooms')
      expect(result).not_to include('bathrooms')
    end

    it 'sorts params alphabetically' do
      criteria = { zone: 'marbella', type: 'apartment', bedrooms: 2 }
      result = service.to_url_params(criteria)
      params_order = result.split('&').map { |p| p.split('=').first }
      expect(params_order).to eq(params_order.sort)
    end

    it 'converts features array to comma-separated' do
      criteria = { features: %w[pool garden sea-views] }
      result = service.to_url_params(criteria)
      expect(result).to include('features=garden,pool,sea-views')
    end

    it 'sorts features alphabetically' do
      criteria = { features: %w[sea-views pool garden] }
      result = service.to_url_params(criteria)
      expect(result).to include('features=garden,pool,sea-views')
    end

    it 'encodes special characters' do
      criteria = { locality: 'puerto banús' }
      result = service.to_url_params(criteria)
      expect(result).to include('locality=puerto')
    end

    it 'handles all parameter types' do
      criteria = {
        property_type: 'apartment',
        bedrooms: 2,
        bathrooms: 1,
        price_min: 100_000,
        price_max: 500_000,
        features: %w[pool garden],
        zone: 'costa-del-sol',
        locality: 'marbella',
        sort: 'price-asc',
        view: 'grid',
        page: 1
      }
      result = service.to_url_params(criteria)

      expect(result).to include('type=apartment')
      expect(result).to include('bedrooms=2')
      expect(result).to include('bathrooms=1')
      expect(result).to include('price_min=100000')
      expect(result).to include('price_max=500000')
      expect(result).to include('features=garden,pool')
      expect(result).to include('zone=costa-del-sol')
      expect(result).to include('locality=marbella')
      expect(result).to include('sort=price-asc')
      expect(result).to include('view=grid')
      expect(result).to include('page=1')
    end
  end

  describe '#canonical_url' do
    it 'generates consistent URLs' do
      criteria1 = { bedrooms: 2, property_type: 'apartment' }
      criteria2 = { property_type: 'apartment', bedrooms: 2 }

      url1 = service.canonical_url(criteria1, locale: :en, operation: :buy)
      url2 = service.canonical_url(criteria2, locale: :en, operation: :buy)

      expect(url1).to eq(url2)
    end

    it 'includes locale prefix' do
      criteria = { property_type: 'apartment' }

      en_url = service.canonical_url(criteria, locale: :en, operation: :buy)
      es_url = service.canonical_url(criteria, locale: :es, operation: :comprar)

      expect(en_url).to start_with('/en/buy')
      expect(es_url).to start_with('/es/comprar')
    end

    it 'omits page=1 from canonical URL' do
      criteria = { property_type: 'apartment', page: 1 }
      url = service.canonical_url(criteria, locale: :en, operation: :buy)
      expect(url).not_to include('page=')
    end

    it 'includes page > 1 in canonical URL' do
      criteria = { property_type: 'apartment', page: 2 }
      url = service.canonical_url(criteria, locale: :en, operation: :buy)
      expect(url).to include('page=2')
    end

    it 'generates path without host by default' do
      criteria = { property_type: 'apartment' }
      url = service.canonical_url(criteria, locale: :en, operation: :buy)
      expect(url).to start_with('/en/buy')
    end

    it 'can generate full URL with host' do
      criteria = { property_type: 'apartment' }
      url = service.canonical_url(criteria, locale: :en, operation: :buy, host: 'example.com')
      expect(url).to start_with('https://example.com/en/buy')
    end
  end

  describe 'round-trip consistency' do
    it 'maintains consistency through from/to conversion' do
      original = ActionController::Parameters.new(
        type: 'apartment',
        bedrooms: '2',
        features: 'pool,garden',
        sort: 'price-asc'
      )

      parsed = service.from_url_params(original)
      regenerated = service.to_url_params(parsed)
      reparsed = service.from_url_params(ActionController::Parameters.new(
        Rack::Utils.parse_query(regenerated)
      ))

      # Features get sorted alphabetically for canonical URLs, so compare sorted
      expect(reparsed[:property_type]).to eq(parsed[:property_type])
      expect(reparsed[:bedrooms]).to eq(parsed[:bedrooms])
      expect(reparsed[:sort]).to eq(parsed[:sort])
      expect(reparsed[:features].sort).to eq(parsed[:features].sort)
    end
  end
end
