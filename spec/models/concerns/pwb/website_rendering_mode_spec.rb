# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe WebsiteRenderingMode, type: :model do
    # Set up tenant settings to allow default theme
    before(:all) do
      Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
        ts.default_available_themes = %w[default brisbane bologna barcelona biarritz]
      end
    end

    describe 'validations' do
      describe 'rendering_mode' do
        it 'accepts valid rendering modes' do
          website = build(:pwb_website, rendering_mode: 'rails')
          expect(website).to be_valid

          # For client mode, we need a valid theme
          create(:pwb_client_theme, :amsterdam)
          website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'amsterdam')
          expect(website).to be_valid
        end

        it 'rejects invalid rendering modes' do
          website = build(:pwb_website)
          website.rendering_mode = 'invalid'
          expect(website).not_to be_valid
          expect(website.errors[:rendering_mode]).to be_present
        end
      end

      describe 'client_theme_name' do
        it 'is required when client rendering' do
          website = build(:pwb_website, rendering_mode: 'client', client_theme_name: nil)
          expect(website).not_to be_valid
          expect(website.errors[:client_theme_name]).to include("can't be blank")
        end

        it 'is not required when rails rendering' do
          website = build(:pwb_website, rendering_mode: 'rails', client_theme_name: nil)
          expect(website).to be_valid
        end
      end

      describe 'client_theme_must_exist' do
        it 'validates that client theme exists' do
          website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'nonexistent')
          expect(website).not_to be_valid
          expect(website.errors[:client_theme_name]).to include('is not a valid client theme')
        end

        it 'accepts existing enabled themes' do
          create(:pwb_client_theme, name: 'valid_theme')
          website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'valid_theme')
          expect(website).to be_valid
        end

        it 'rejects disabled themes' do
          create(:pwb_client_theme, :disabled, name: 'disabled_theme')
          website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'disabled_theme')
          expect(website).not_to be_valid
        end
      end

      describe 'rendering_mode_immutable' do
        it 'allows changing rendering_mode before content created' do
          website = create(:pwb_website, rendering_mode: 'rails')
          expect(website.rendering_mode_locked?).to be false

          create(:pwb_client_theme, :amsterdam)
          website.rendering_mode = 'client'
          website.client_theme_name = 'amsterdam'
          expect(website).to be_valid
        end

        it 'prevents changing rendering_mode after content created' do
          website = create(:pwb_website, :provisioned_with_content, rendering_mode: 'rails')
          expect(website.rendering_mode_locked?).to be true

          create(:pwb_client_theme, :amsterdam)
          website.rendering_mode = 'client'
          website.client_theme_name = 'amsterdam'
          expect(website).not_to be_valid
          expect(website.errors[:rendering_mode]).to include('cannot be changed after website has content')
        end
      end
    end

    describe '#rails_rendering?' do
      it 'returns true for rails mode' do
        website = build(:pwb_website, rendering_mode: 'rails')
        expect(website.rails_rendering?).to be true
      end

      it 'returns false for client mode' do
        create(:pwb_client_theme, :amsterdam)
        website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'amsterdam')
        expect(website.rails_rendering?).to be false
      end
    end

    describe '#client_rendering?' do
      it 'returns false for rails mode' do
        website = build(:pwb_website, rendering_mode: 'rails')
        expect(website.client_rendering?).to be false
      end

      it 'returns true for client mode' do
        create(:pwb_client_theme, :amsterdam)
        website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'amsterdam')
        expect(website.client_rendering?).to be true
      end
    end

    describe '#client_theme' do
      it 'returns nil for rails rendering' do
        website = build(:pwb_website, :rails_rendering)
        expect(website.client_theme).to be_nil
      end

      it 'returns the client theme object for client rendering' do
        theme = create(:pwb_client_theme, :amsterdam)
        website = build(:pwb_website, :client_rendering)
        expect(website.client_theme).to eq(theme)
      end
    end

    describe '#effective_client_theme_config' do
      it 'returns empty hash for rails rendering' do
        website = build(:pwb_website, :rails_rendering)
        expect(website.effective_client_theme_config).to eq({})
      end

      it 'returns merged config for client rendering' do
        theme = create(:pwb_client_theme,
                       name: 'test_theme',
                       default_config: { 'primary_color' => '#FF0000', 'secondary_color' => '#0000FF' })
        website = build(:pwb_website,
                        rendering_mode: 'client',
                        client_theme_name: 'test_theme',
                        client_theme_config: { 'primary_color' => '#00FF00' })

        config = website.effective_client_theme_config
        expect(config['primary_color']).to eq('#00FF00')
        expect(config['secondary_color']).to eq('#0000FF')
      end
    end

    describe '#client_theme_css_variables' do
      it 'returns empty string for rails rendering' do
        website = build(:pwb_website, :rails_rendering)
        expect(website.client_theme_css_variables).to eq('')
      end

      it 'returns CSS variables for client rendering' do
        create(:pwb_client_theme,
               name: 'css_theme',
               default_config: { 'primary_color' => '#FF0000' })
        website = build(:pwb_website, rendering_mode: 'client', client_theme_name: 'css_theme')

        css = website.client_theme_css_variables
        expect(css).to include(':root {')
        expect(css).to include('--primary-color: #FF0000')
      end
    end

    describe '#rendering_mode_locked?' do
      it 'returns false for new website' do
        website = create(:pwb_website)
        expect(website.rendering_mode_locked?).to be false
      end

      it 'returns false for provisioned website without content' do
        website = create(:pwb_website, provisioning_completed_at: 1.day.ago)
        expect(website.rendering_mode_locked?).to be false
      end

      it 'returns true for provisioned website with content' do
        website = create(:pwb_website, :provisioned_with_content)
        expect(website.rendering_mode_locked?).to be true
      end
    end

    describe '#rendering_mode_changeable?' do
      it 'returns true when not locked' do
        website = create(:pwb_website)
        expect(website.rendering_mode_changeable?).to be true
      end

      it 'returns false when locked' do
        website = create(:pwb_website, :provisioned_with_content)
        expect(website.rendering_mode_changeable?).to be false
      end
    end

    describe 'factory traits' do
      it 'creates rails_rendering website' do
        website = create(:pwb_website, :rails_rendering)
        expect(website.rendering_mode).to eq('rails')
        expect(website.rails_rendering?).to be true
      end

      it 'creates client_rendering website' do
        website = create(:pwb_website, :client_rendering)
        expect(website.rendering_mode).to eq('client')
        expect(website.client_rendering?).to be true
        expect(website.client_theme).to be_present
      end

      it 'creates client_rendering_with_overrides website' do
        website = create(:pwb_website, :client_rendering_with_overrides)
        expect(website.client_theme_config['primary_color']).to eq('#00FF00')
        expect(website.effective_client_theme_config['primary_color']).to eq('#00FF00')
      end
    end
  end
end
