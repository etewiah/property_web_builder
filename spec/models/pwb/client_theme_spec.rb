# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe ClientTheme, type: :model do
    # Subject needed for shoulda-matchers uniqueness validation
    subject { build(:pwb_client_theme) }

    describe 'validations' do
      it { should validate_presence_of(:name) }
      it { should validate_presence_of(:friendly_name) }
      it { should validate_uniqueness_of(:name) }

      it 'validates name format' do
        theme = build(:pwb_client_theme, name: 'Valid_name123')
        expect(theme).not_to be_valid
        expect(theme.errors[:name]).to include('must be lowercase letters, numbers, and underscores')

        theme.name = 'valid_name'
        expect(theme).to be_valid
      end

      it 'rejects names starting with numbers' do
        theme = build(:pwb_client_theme, name: '123theme')
        expect(theme).not_to be_valid
      end

      it 'rejects names with special characters' do
        theme = build(:pwb_client_theme, name: 'my-theme')
        expect(theme).not_to be_valid
      end
    end

    describe 'factory' do
      it 'creates a valid theme' do
        theme = create(:pwb_client_theme)
        expect(theme).to be_valid
        expect(theme).to be_persisted
      end

      it 'creates amsterdam theme with trait' do
        theme = create(:pwb_client_theme, :amsterdam)
        expect(theme.name).to eq('amsterdam')
        expect(theme.friendly_name).to eq('Amsterdam Modern')
      end

      it 'creates athens theme with trait' do
        theme = create(:pwb_client_theme, :athens)
        expect(theme.name).to eq('athens')
        expect(theme.friendly_name).to eq('Athens Classic')
      end

      it 'creates austin theme with trait' do
        theme = create(:pwb_client_theme, :austin)
        expect(theme.name).to eq('austin')
        expect(theme.friendly_name).to eq('Austin Bold')
      end

      it 'creates disabled theme with trait' do
        theme = create(:pwb_client_theme, :disabled)
        expect(theme.enabled).to be false
      end
    end

    describe 'scopes' do
      let!(:enabled_theme) { create(:pwb_client_theme, enabled: true) }
      let!(:disabled_theme) { create(:pwb_client_theme, :disabled) }

      describe '.enabled' do
        it 'returns only enabled themes' do
          expect(described_class.enabled).to include(enabled_theme)
          expect(described_class.enabled).not_to include(disabled_theme)
        end
      end

      describe '.by_name' do
        it 'finds theme by name' do
          expect(described_class.by_name(enabled_theme.name)).to eq(enabled_theme)
        end

        it 'returns nil for non-existent name' do
          expect(described_class.by_name('nonexistent')).to be_nil
        end
      end
    end

    describe '#config_for_website' do
      let(:theme) do
        create(:pwb_client_theme,
               default_config: {
                 'primary_color' => '#FF0000',
                 'secondary_color' => '#0000FF'
               })
      end

      context 'without website overrides' do
        let(:website) { build(:pwb_website, client_theme_config: {}) }

        it 'returns default config' do
          config = theme.config_for_website(website)
          expect(config['primary_color']).to eq('#FF0000')
          expect(config['secondary_color']).to eq('#0000FF')
        end
      end

      context 'with website overrides' do
        let(:website) { build(:pwb_website, client_theme_config: { 'primary_color' => '#00FF00' }) }

        it 'merges overrides with defaults' do
          config = theme.config_for_website(website)
          expect(config['primary_color']).to eq('#00FF00')
          expect(config['secondary_color']).to eq('#0000FF')
        end
      end

      context 'with nil website config' do
        let(:website) { build(:pwb_website, client_theme_config: nil) }

        it 'returns default config' do
          config = theme.config_for_website(website)
          expect(config['primary_color']).to eq('#FF0000')
        end
      end
    end

    describe '#generate_css_variables' do
      let(:theme) do
        create(:pwb_client_theme,
               default_config: {
                 'primary_color' => '#FF0000',
                 'font_heading' => 'Inter'
               })
      end

      it 'generates CSS :root block' do
        css = theme.generate_css_variables
        expect(css).to include(':root {')
        expect(css).to include('--primary-color: #FF0000')
        expect(css).to include('--font-heading: Inter')
      end

      it 'converts underscores to hyphens' do
        css = theme.generate_css_variables
        expect(css).to include('--primary-color')
        expect(css).not_to include('primary_color')
      end

      it 'accepts custom config' do
        css = theme.generate_css_variables('custom_var' => 'value')
        expect(css).to include('--custom-var: value')
      end

      it 'returns empty string for blank config' do
        expect(theme.generate_css_variables({})).to eq('')
        expect(theme.generate_css_variables(nil)).to eq('')
      end
    end

    describe '#as_api_json' do
      let(:theme) do
        create(:pwb_client_theme, :amsterdam)
      end

      it 'returns all expected keys' do
        json = theme.as_api_json

        expect(json).to have_key(:name)
        expect(json).to have_key(:friendly_name)
        expect(json).to have_key(:version)
        expect(json).to have_key(:description)
        expect(json).to have_key(:preview_image_url)
        expect(json).to have_key(:default_config)
        expect(json).to have_key(:color_schema)
        expect(json).to have_key(:font_schema)
        expect(json).to have_key(:layout_options)
      end

      it 'returns correct values' do
        json = theme.as_api_json

        expect(json[:name]).to eq('amsterdam')
        expect(json[:friendly_name]).to eq('Amsterdam Modern')
      end
    end

    describe '.options_for_select' do
      before do
        create(:pwb_client_theme, name: 'zebra', friendly_name: 'Zebra Theme')
        create(:pwb_client_theme, name: 'alpha', friendly_name: 'Alpha Theme')
        create(:pwb_client_theme, :disabled, name: 'disabled', friendly_name: 'Disabled Theme')
      end

      it 'returns enabled themes ordered by friendly_name' do
        options = described_class.options_for_select

        expect(options.length).to eq(2)
        expect(options.first).to eq(['Alpha Theme', 'alpha'])
        expect(options.last).to eq(['Zebra Theme', 'zebra'])
      end

      it 'does not include disabled themes' do
        options = described_class.options_for_select
        names = options.map(&:last)

        expect(names).not_to include('disabled')
      end
    end
  end
end
