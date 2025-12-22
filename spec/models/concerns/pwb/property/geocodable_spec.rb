# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertyGeocodable, type: :model do
  let(:website) { create(:pwb_website) }
  let(:prop) { create(:pwb_prop, website: website) }

  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  describe '#geocodeable_address' do
    it 'combines address components' do
      prop.street_address = '123 Main St'
      prop.city = 'London'
      prop.province = 'Greater London'
      prop.postal_code = 'SW1A 1AA'

      expect(prop.geocodeable_address).to eq('123 Main St , London , Greater London , SW1A 1AA')
    end

    it 'handles nil values gracefully' do
      prop.street_address = nil
      prop.city = 'London'
      prop.province = nil
      prop.postal_code = nil

      expect(prop.geocodeable_address).to eq(' , London ,  , ')
    end
  end

  describe '#needs_geocoding?' do
    it 'returns true when address exists but coordinates are missing' do
      prop.street_address = '123 Main St'
      prop.city = 'London'
      prop.latitude = nil
      prop.longitude = nil

      expect(prop.needs_geocoding?).to be true
    end

    it 'returns false when coordinates exist' do
      prop.street_address = '123 Main St'
      prop.city = 'London'
      prop.latitude = 51.5074
      prop.longitude = -0.1278

      expect(prop.needs_geocoding?).to be false
    end

    it 'returns false when coordinates already exist' do
      prop.street_address = nil
      prop.city = nil
      prop.province = nil
      prop.postal_code = nil
      prop.latitude = 51.5074
      prop.longitude = -0.1278

      expect(prop.needs_geocoding?).to be false
    end
  end

  describe '#show_map' do
    it 'returns true when coordinates exist and map is not hidden' do
      prop.latitude = 51.5074
      prop.longitude = -0.1278
      prop.hide_map = false

      expect(prop.show_map).to be true
    end

    it 'returns false when latitude is missing' do
      prop.latitude = nil
      prop.longitude = -0.1278
      prop.hide_map = false

      expect(prop.show_map).to be false
    end

    it 'returns false when longitude is missing' do
      prop.latitude = 51.5074
      prop.longitude = nil
      prop.hide_map = false

      expect(prop.show_map).to be false
    end

    it 'returns false when hide_map is true' do
      prop.latitude = 51.5074
      prop.longitude = -0.1278
      prop.hide_map = true

      expect(prop.show_map).to be false
    end
  end

  describe '#geocode_address_if_needed!' do
    it 'does not geocode when coordinates already exist' do
      prop.latitude = 51.5074
      prop.longitude = -0.1278

      expect(prop).not_to receive(:geocode)
      prop.geocode_address_if_needed!
    end

    it 'geocodes when coordinates are missing' do
      prop.latitude = nil
      prop.longitude = nil
      prop.street_address = '123 Main St'

      expect(prop).to receive(:geocode)
      prop.geocode_address_if_needed!
    end
  end
end
