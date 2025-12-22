# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertyDisplayable, type: :model do
  let(:website) { create(:pwb_website) }
  let(:prop) { create(:pwb_prop, website: website) }

  describe '#url_friendly_title' do
    it 'parameterizes the title' do
      prop.title = 'Beautiful Beach House'
      expect(prop.url_friendly_title).to eq('beautiful-beach-house')
    end

    it 'returns "show" for short or empty titles' do
      prop.title = 'Hi'
      expect(prop.url_friendly_title).to eq('show')

      prop.title = nil
      expect(prop.url_friendly_title).to eq('show')

      prop.title = ''
      expect(prop.url_friendly_title).to eq('show')
    end

    it 'handles special characters' do
      prop.title = 'Apartamento en Málaga - Vista al Mar!'
      expect(prop.url_friendly_title).to eq('apartamento-en-malaga-vista-al-mar')
    end
  end

  describe '#contextual_show_path' do
    before do
      prop.title = 'Test Property'
      I18n.locale = :en
    end

    it 'returns sale path for for_sale' do
      path = prop.contextual_show_path('for_sale')
      expect(path).to include('/buy/')
      expect(path).to include(prop.id.to_s)
    end

    it 'returns rent path for for_rent' do
      path = prop.contextual_show_path('for_rent')
      expect(path).to include('/rent/')
      expect(path).to include(prop.id.to_s)
    end

    it 'defaults based on property availability' do
      prop.for_sale = false
      prop.for_rent_long_term = true
      path = prop.contextual_show_path(nil)
      expect(path).to include('/rent/')
    end

    it 'defaults to sale when for_sale is true' do
      prop.for_sale = true
      path = prop.contextual_show_path(nil)
      expect(path).to include('/buy/')
    end
  end

  describe '#ordered_photo' do
    let!(:photo1) { create(:pwb_prop_photo, prop: prop, sort_order: 1) }
    let!(:photo2) { create(:pwb_prop_photo, prop: prop, sort_order: 2) }
    let!(:photo3) { create(:pwb_prop_photo, prop: prop, sort_order: 3) }

    before { prop.reload }

    it 'returns photo at specified position (1-indexed)' do
      expect(prop.ordered_photo(1)).to eq(photo1)
      expect(prop.ordered_photo(2)).to eq(photo2)
      expect(prop.ordered_photo(3)).to eq(photo3)
    end

    it 'returns nil for out of bounds position' do
      expect(prop.ordered_photo(4)).to be_nil
      expect(prop.ordered_photo(0)).to be_nil
    end
  end

  describe '#primary_image_url' do
    context 'when property has photos with attached images' do
      let!(:photo) { create(:pwb_prop_photo, :with_image, prop: prop, sort_order: 1) }

      before { prop.reload }

      it 'returns the URL of the first photo' do
        expect(prop.primary_image_url).to be_present
        expect(prop.primary_image_url).to include('/rails/active_storage')
      end
    end

    context 'when property has no photos' do
      it 'returns empty string' do
        expect(prop.primary_image_url).to eq('')
      end
    end
  end

  describe '#extras_for_display' do
    before do
      allow(prop).to receive(:get_features).and_return({
        'propertyFeatures.pool' => true,
        'propertyFeatures.garden' => true,
        'propertyFeatures.garage' => true
      })
      allow(I18n).to receive(:t).with('propertyFeatures.pool').and_return('Swimming Pool')
      allow(I18n).to receive(:t).with('propertyFeatures.garden').and_return('Garden')
      allow(I18n).to receive(:t).with('propertyFeatures.garage').and_return('Garage')
    end

    it 'returns translated feature names' do
      extras = prop.extras_for_display
      expect(extras).to include('Swimming Pool', 'Garden', 'Garage')
    end

    it 'sorts features alphabetically' do
      extras = prop.extras_for_display
      expect(extras).to eq(['Garden', 'Garage', 'Swimming Pool'])
    end
  end
end
