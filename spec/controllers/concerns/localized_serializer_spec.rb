# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocalizedSerializer, type: :controller do
  # Create a test controller that includes the concern
  controller(ApplicationController) do
    include LocalizedSerializer

    def index
      render plain: 'ok'
    end
  end

  # Mock object that responds to locale accessors
  let(:mock_object) do
    obj = double('TranslatableObject')
    allow(obj).to receive(:respond_to?).and_return(false)
    allow(obj).to receive(:respond_to?).with('title_en').and_return(true)
    allow(obj).to receive(:respond_to?).with('title_es').and_return(true)
    allow(obj).to receive(:respond_to?).with('title_fr').and_return(true)
    allow(obj).to receive(:respond_to?).with('description_en').and_return(true)
    allow(obj).to receive(:respond_to?).with('description_es').and_return(true)
    allow(obj).to receive(:respond_to?).with('description_fr').and_return(true)
    allow(obj).to receive(:title_en).and_return('Beach House')
    allow(obj).to receive(:title_es).and_return('Casa de Playa')
    allow(obj).to receive(:title_fr).and_return('Maison de Plage')
    allow(obj).to receive(:description_en).and_return('Beautiful property')
    allow(obj).to receive(:description_es).and_return('Propiedad hermosa')
    allow(obj).to receive(:description_fr).and_return('Belle propriété')
    obj
  end

  describe '#serialize_translated_attributes' do
    it 'returns hash with all locale variants for given attributes' do
      result = controller.serialize_translated_attributes(mock_object, :title, :description)

      expect(result).to include(
        'title-en' => 'Beach House',
        'title-es' => 'Casa de Playa',
        'title-fr' => 'Maison de Plage',
        'description-en' => 'Beautiful property',
        'description-es' => 'Propiedad hermosa',
        'description-fr' => 'Belle propriété'
      )
    end

    it 'generates keys for all BASE_LOCALES' do
      result = controller.serialize_translated_attributes(mock_object, :title)

      Pwb::Config::BASE_LOCALES.each do |locale|
        expect(result).to have_key("title-#{locale}")
      end
    end

    it 'returns nil for locales where accessor does not exist' do
      limited_object = double('LimitedObject')
      allow(limited_object).to receive(:respond_to?).and_return(false)
      allow(limited_object).to receive(:respond_to?).with('title_en').and_return(true)
      allow(limited_object).to receive(:title_en).and_return('English Title')

      result = controller.serialize_translated_attributes(limited_object, :title)

      expect(result['title-en']).to eq('English Title')
      expect(result['title-es']).to be_nil
      expect(result['title-fr']).to be_nil
    end
  end

  describe '#serialize_translated_attribute' do
    it 'works for a single attribute' do
      result = controller.serialize_translated_attribute(mock_object, :title)

      expect(result['title-en']).to eq('Beach House')
      expect(result['title-es']).to eq('Casa de Playa')
      expect(result).not_to have_key('description-en')
    end
  end

  describe '#current_translation' do
    it 'returns translation for current I18n locale' do
      I18n.with_locale(:es) do
        result = controller.current_translation(mock_object, :title)
        expect(result).to eq('Casa de Playa')
      end
    end

    it 'returns nil when accessor does not exist for locale' do
      limited_object = double('LimitedObject')
      allow(limited_object).to receive(:respond_to?).with('title_de').and_return(false)

      I18n.with_locale(:de) do
        result = controller.current_translation(limited_object, :title)
        expect(result).to be_nil
      end
    end
  end
end
