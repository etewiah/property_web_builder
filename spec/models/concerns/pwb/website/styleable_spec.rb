# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteStyleable, type: :model do
  let(:website) { create(:pwb_website) }

  describe '#style_variables' do
    it 'returns default values when none are set' do
      website.style_variables_for_theme = {}
      vars = website.style_variables

      expect(vars['primary_color']).to eq('#e91b23')
      expect(vars['secondary_color']).to eq('#3498db')
      expect(vars['action_color']).to eq('green')
      expect(vars['body_style']).to eq('siteLayout.wide')
      expect(vars['theme']).to eq('light')
    end

    it 'returns stored values when set' do
      website.style_variables = { 'primary_color' => '#ff0000' }
      expect(website.style_variables['primary_color']).to eq('#ff0000')
    end
  end

  describe '#style_variables=' do
    it 'stores style variables in style_variables_for_theme' do
      custom_styles = { 'primary_color' => '#123456', 'theme' => 'dark' }
      website.style_variables = custom_styles

      expect(website.style_variables_for_theme['default']).to eq(custom_styles)
    end
  end

  describe '#body_style' do
    it 'returns empty string for wide layout' do
      website.style_variables = { 'body_style' => 'siteLayout.wide' }
      expect(website.body_style).to eq('')
    end

    it 'returns body-boxed for boxed layout' do
      website.style_variables = { 'body_style' => 'siteLayout.boxed' }
      expect(website.body_style).to eq('body-boxed')
    end

    it 'returns empty string when no style set' do
      website.style_variables_for_theme = {}
      expect(website.body_style).to eq('')
    end
  end

  describe '#theme_name=' do
    it 'sets theme name when theme exists' do
      # Assuming 'default' theme exists
      allow(Pwb::Theme).to receive(:where).with(name: 'default').and_return(double(count: 1))
      website.theme_name = 'default'
      expect(website.read_attribute(:theme_name)).to eq('default')
    end

    it 'does not set theme name when theme does not exist' do
      allow(Pwb::Theme).to receive(:where).with(name: 'nonexistent').and_return(double(count: 0))
      original_theme = website.theme_name
      website.theme_name = 'nonexistent'
      expect(website.read_attribute(:theme_name)).to eq(original_theme)
    end
  end

  describe '#render_google_analytics' do
    it 'returns false in non-production environment' do
      website.analytics_id = 'UA-12345'
      expect(website.render_google_analytics).to be false
    end

    it 'returns false when analytics_id is blank' do
      website.analytics_id = nil
      expect(website.render_google_analytics).to be false
    end
  end

  describe '#get_element_class' do
    it 'returns empty string when no associations defined' do
      website.style_variables_for_theme = {}
      expect(website.get_element_class('button')).to eq('')
    end

    it 'returns class name when defined in associations' do
      website.style_variables_for_theme = {
        'default' => {
          'associations' => { 'button' => 'btn-primary' }
        }
      }
      expect(website.get_element_class('button')).to eq('btn-primary')
    end
  end

  describe '#get_style_var' do
    it 'returns empty string when variable not defined' do
      website.style_variables_for_theme = {}
      expect(website.get_style_var('undefined_var')).to eq('')
    end

    it 'returns value when variable is defined' do
      website.style_variables_for_theme = {
        'default' => {
          'variables' => { 'header_height' => '60px' }
        }
      }
      expect(website.get_style_var('header_height')).to eq('60px')
    end
  end
end
