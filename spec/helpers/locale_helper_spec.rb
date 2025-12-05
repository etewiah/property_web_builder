# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocaleHelper, type: :helper do
  describe '#locale_to_base' do
    it 'converts full locale with region to base locale' do
      expect(helper.locale_to_base('en-UK')).to eq('en')
      expect(helper.locale_to_base('en-US')).to eq('en')
      expect(helper.locale_to_base('pt-BR')).to eq('pt')
      expect(helper.locale_to_base('pt-PT')).to eq('pt')
      expect(helper.locale_to_base('es-MX')).to eq('es')
    end

    it 'returns base locale unchanged' do
      expect(helper.locale_to_base('en')).to eq('en')
      expect(helper.locale_to_base('es')).to eq('es')
      expect(helper.locale_to_base('fr')).to eq('fr')
    end

    it 'handles uppercase locale codes' do
      expect(helper.locale_to_base('EN-UK')).to eq('en')
      expect(helper.locale_to_base('EN')).to eq('en')
    end

    it 'returns default "en" for nil locale' do
      expect(helper.locale_to_base(nil)).to eq('en')
    end

    it 'returns default "en" for blank locale' do
      expect(helper.locale_to_base('')).to eq('en')
    end

    it 'handles symbol locales' do
      expect(helper.locale_to_base(:'en-UK')).to eq('en')
      expect(helper.locale_to_base(:es)).to eq('es')
    end
  end

  describe '#locale_variant' do
    it 'extracts variant from full locale' do
      expect(helper.locale_variant('en-UK')).to eq('UK')
      expect(helper.locale_variant('en-US')).to eq('US')
      expect(helper.locale_variant('pt-BR')).to eq('BR')
    end

    it 'returns nil for base locale without variant' do
      expect(helper.locale_variant('en')).to be_nil
      expect(helper.locale_variant('es')).to be_nil
    end

    it 'returns nil for blank locale' do
      expect(helper.locale_variant(nil)).to be_nil
      expect(helper.locale_variant('')).to be_nil
    end
  end

  describe '#supported_locales_for_content' do
    it 'converts full locales to unique base locales' do
      result = helper.supported_locales_for_content(['en-UK', 'en-US', 'es', 'pt-BR'])
      expect(result).to eq(%w[en es pt])
    end

    it 'removes duplicates from same base language' do
      result = helper.supported_locales_for_content(['en-UK', 'en-US', 'en-AU'])
      expect(result).to eq(['en'])
    end

    it 'filters out blank locales' do
      result = helper.supported_locales_for_content(['en-UK', '', nil, 'es'])
      expect(result).to eq(%w[en es])
    end

    it 'returns default ["en"] for blank input' do
      expect(helper.supported_locales_for_content(nil)).to eq(['en'])
      expect(helper.supported_locales_for_content([])).to eq(['en'])
    end
  end

  describe '#build_locale_details' do
    it 'builds locale detail hashes with full, base, and label' do
      result = helper.build_locale_details(['en-UK', 'es'])

      expect(result.length).to eq(2)

      en_detail = result[0]
      expect(en_detail[:full]).to eq('en-UK')
      expect(en_detail[:base]).to eq('en')
      expect(en_detail[:label]).to eq('English (UK)')

      es_detail = result[1]
      expect(es_detail[:full]).to eq('es')
      expect(es_detail[:base]).to eq('es')
      expect(es_detail[:label]).to eq('Spanish')
    end

    it 'handles various locale formats' do
      result = helper.build_locale_details(['pt-BR', 'fr', 'de'])

      expect(result[0][:label]).to eq('Portuguese (Brazil)')
      expect(result[1][:label]).to eq('French')
      expect(result[2][:label]).to eq('German')
    end

    it 'handles unknown locale codes gracefully' do
      result = helper.build_locale_details(['xyz'])
      expect(result[0][:label]).to eq('XYZ')
    end

    it 'handles unknown variants gracefully' do
      result = helper.build_locale_details(['en-ZZ'])
      expect(result[0][:label]).to eq('English (ZZ)')
    end

    it 'filters out blank locales' do
      result = helper.build_locale_details(['en-UK', '', 'es'])
      expect(result.length).to eq(2)
      expect(result.map { |d| d[:base] }).to eq(%w[en es])
    end

    it 'returns default English for blank input' do
      expect(helper.build_locale_details(nil)).to eq([{ full: 'en', base: 'en', label: 'English' }])
      expect(helper.build_locale_details([])).to eq([{ full: 'en', base: 'en', label: 'English' }])
    end
  end

  describe '#build_locale_label' do
    it 'returns base language name without variant' do
      expect(helper.build_locale_label('en')).to eq('English')
      expect(helper.build_locale_label('es')).to eq('Spanish')
      expect(helper.build_locale_label('fr')).to eq('French')
    end

    it 'returns language name with variant in parentheses' do
      expect(helper.build_locale_label('en', 'UK')).to eq('English (UK)')
      expect(helper.build_locale_label('en', 'US')).to eq('English (US)')
      expect(helper.build_locale_label('pt', 'BR')).to eq('Portuguese (Brazil)')
    end

    it 'uses friendly names for known variants' do
      expect(helper.build_locale_label('en', 'AU')).to eq('English (Australia)')
      expect(helper.build_locale_label('es', 'MX')).to eq('Spanish (Mexico)')
    end

    it 'falls back to uppercase code for unknown languages' do
      expect(helper.build_locale_label('xyz')).to eq('XYZ')
    end
  end

  describe '#base_to_full_locale' do
    it 'finds full locale matching base locale' do
      supported = ['en-UK', 'es', 'pt-BR', 'fr']

      expect(helper.base_to_full_locale('en', supported)).to eq('en-UK')
      expect(helper.base_to_full_locale('es', supported)).to eq('es')
      expect(helper.base_to_full_locale('pt', supported)).to eq('pt-BR')
    end

    it 'returns base locale if no match found' do
      supported = ['en-UK', 'es']
      expect(helper.base_to_full_locale('fr', supported)).to eq('fr')
    end

    it 'returns base locale for blank supported locales' do
      expect(helper.base_to_full_locale('en', nil)).to eq('en')
      expect(helper.base_to_full_locale('en', [])).to eq('en')
    end
  end

  describe '#locale_for_url_path' do
    it 'returns nil for default English locale' do
      expect(helper.locale_for_url_path('en')).to be_nil
      expect(helper.locale_for_url_path('en-UK')).to be_nil
      expect(helper.locale_for_url_path('en-US')).to be_nil
    end

    it 'returns base locale for non-default locales' do
      expect(helper.locale_for_url_path('es')).to eq('es')
      expect(helper.locale_for_url_path('pt-BR')).to eq('pt')
      expect(helper.locale_for_url_path('fr')).to eq('fr')
    end

    it 'allows custom default locale' do
      expect(helper.locale_for_url_path('es', 'es')).to be_nil
      expect(helper.locale_for_url_path('en', 'es')).to eq('en')
    end
  end

  describe '#normalize_locale_for_content' do
    it 'is an alias for locale_to_base' do
      expect(helper.normalize_locale_for_content('en-UK')).to eq(helper.locale_to_base('en-UK'))
      expect(helper.normalize_locale_for_content('pt-BR')).to eq(helper.locale_to_base('pt-BR'))
    end
  end
end
