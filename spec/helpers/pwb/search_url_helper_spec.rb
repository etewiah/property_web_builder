# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SearchUrlHelper, type: :helper do
    describe '#feature_to_slug' do
      it 'converts global_key to URL-friendly slug' do
        expect(helper.feature_to_slug('features.private_pool')).to eq('private-pool')
      end

      it 'converts type global_key to slug' do
        expect(helper.feature_to_slug('types.apartment')).to eq('apartment')
      end

      it 'handles underscores' do
        expect(helper.feature_to_slug('features.air_conditioning')).to eq('air-conditioning')
      end

      it 'returns nil for blank input' do
        expect(helper.feature_to_slug(nil)).to be_nil
        expect(helper.feature_to_slug('')).to be_nil
      end

      it 'handles simple keys without prefix' do
        expect(helper.feature_to_slug('pool')).to eq('pool')
      end
    end

    describe '#tag_prefix' do
      it 'returns correct prefix for property-features' do
        expect(helper.tag_prefix('property-features')).to eq('features')
      end

      it 'returns correct prefix for property-amenities' do
        expect(helper.tag_prefix('property-amenities')).to eq('amenities')
      end

      it 'returns correct prefix for property-types' do
        expect(helper.tag_prefix('property-types')).to eq('types')
      end

      it 'returns correct prefix for property-states' do
        expect(helper.tag_prefix('property-states')).to eq('states')
      end

      it 'extracts last segment for unknown tags' do
        expect(helper.tag_prefix('custom-category')).to eq('category')
      end
    end

    describe '#slug_to_feature' do
      let(:website) { create(:pwb_website, subdomain: 'search-url-test') }

      before do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_field_key, global_key: 'features.private_pool', website: website)
        end
        ActsAsTenant.current_tenant = website
      end

      after do
        ActsAsTenant.current_tenant = nil
      end

      it 'converts slug back to global_key' do
        result = helper.slug_to_feature('private-pool', 'property-features')
        expect(result).to eq('features.private_pool')
      end

      it 'returns nil for blank input' do
        expect(helper.slug_to_feature(nil, 'property-features')).to be_nil
        expect(helper.slug_to_feature('', 'property-features')).to be_nil
      end

      it 'returns nil for non-existent feature' do
        result = helper.slug_to_feature('nonexistent-feature', 'property-features')
        expect(result).to be_nil
      end
    end

    describe '#search_url_with_features' do
      it 'returns base path when no params' do
        result = helper.search_url_with_features(base_path: '/en/buy')
        expect(result).to eq('/en/buy')
      end

      it 'adds features parameter' do
        result = helper.search_url_with_features(
          base_path: '/en/buy',
          features: ['features.private_pool', 'features.sea_views']
        )
        expect(result).to include('/en/buy?')
        expect(result).to include('features=private-pool%2Csea-views')
      end

      it 'adds type parameter' do
        result = helper.search_url_with_features(
          base_path: '/en/buy',
          type: 'types.apartment'
        )
        expect(result).to include('type=apartment')
      end

      it 'adds state parameter' do
        result = helper.search_url_with_features(
          base_path: '/en/buy',
          state: 'states.new_build'
        )
        expect(result).to include('state=new-build')
      end

      it 'passes through additional params' do
        result = helper.search_url_with_features(
          base_path: '/en/buy',
          bedrooms: 3,
          price_from: 100000
        )
        expect(result).to include('bedrooms=3')
        expect(result).to include('price_from=100000')
      end

      it 'combines multiple parameters' do
        result = helper.search_url_with_features(
          base_path: '/en/buy',
          type: 'types.villa',
          features: ['features.pool'],
          bedrooms: 4
        )
        expect(result).to include('type=villa')
        expect(result).to include('features=pool')
        expect(result).to include('bedrooms=4')
      end
    end

    describe '#parse_friendly_url_params' do
      let(:website) { create(:pwb_website, subdomain: 'parse-url-test') }

      before do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_field_key, global_key: 'features.pool', website: website)
          create(:pwb_field_key, global_key: 'types.apartment', website: website)
          create(:pwb_field_key, global_key: 'states.new', website: website)
        end
        ActsAsTenant.current_tenant = website
      end

      after do
        ActsAsTenant.current_tenant = nil
      end

      it 'parses features from comma-separated slugs' do
        result = helper.parse_friendly_url_params(features: 'pool')
        expect(result[:features]).to include('features.pool')
      end

      it 'parses property type' do
        result = helper.parse_friendly_url_params(type: 'apartment')
        expect(result[:property_type]).to eq('types.apartment')
      end

      it 'parses property state' do
        result = helper.parse_friendly_url_params(state: 'new')
        expect(result[:property_state]).to eq('states.new')
      end

      it 'passes through bedroom count' do
        result = helper.parse_friendly_url_params(bedrooms: '3')
        expect(result[:count_bedrooms]).to eq('3')
      end

      it 'passes through bathroom count' do
        result = helper.parse_friendly_url_params(bathrooms: '2')
        expect(result[:count_bathrooms]).to eq('2')
      end

      it 'passes through price params' do
        result = helper.parse_friendly_url_params(
          for_sale_price_from: '100000',
          for_sale_price_till: '500000'
        )
        expect(result[:for_sale_price_from]).to eq('100000')
        expect(result[:for_sale_price_till]).to eq('500000')
      end

      it 'passes through features_match mode' do
        result = helper.parse_friendly_url_params(features_match: 'any')
        expect(result[:features_match]).to eq('any')
      end
    end

    describe '#search_filter_description' do
      it 'includes property type' do
        result = helper.search_filter_description(property_type: 'types.apartment')
        expect(result).to be_present
      end

      it 'includes features' do
        result = helper.search_filter_description(features: ['features.pool'])
        expect(result).to be_present
      end

      it 'combines type and features' do
        result = helper.search_filter_description(
          property_type: 'types.villa',
          features: ['features.pool', 'features.garden']
        )
        expect(result).to be_present
      end

      it 'returns empty string for empty params' do
        result = helper.search_filter_description({})
        expect(result).to eq('')
      end
    end
  end
end
