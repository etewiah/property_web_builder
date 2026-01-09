# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::LiquidFilters do
  # Create a test class that includes the module
  let(:filter_class) do
    Class.new do
      include Pwb::LiquidFilters

      # Mock context for locale access
      attr_accessor :context

      def initialize(context = nil)
        @context = context
      end
    end
  end

  let(:filter) { filter_class.new }

  describe '#localize_url' do
    context 'when locale is not default (e.g., Spanish)' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return(%i[en es fr de])
      end

      it 'prepends locale to internal URLs' do
        expect(filter.localize_url('/search/buy')).to eq('/es/search/buy')
      end

      it 'prepends locale to contact URL' do
        expect(filter.localize_url('/contact')).to eq('/es/contact')
      end

      it 'handles URLs without leading slash' do
        expect(filter.localize_url('about')).to eq('/es/about')
      end

      it 'does not modify external URLs with https' do
        expect(filter.localize_url('https://example.com/page')).to eq('https://example.com/page')
      end

      it 'does not modify external URLs with http' do
        expect(filter.localize_url('http://example.com/page')).to eq('http://example.com/page')
      end

      it 'does not modify protocol-relative URLs' do
        expect(filter.localize_url('//cdn.example.com/image.jpg')).to eq('//cdn.example.com/image.jpg')
      end

      it 'does not modify anchor-only links' do
        expect(filter.localize_url('#section')).to eq('#section')
      end

      it 'returns empty string for blank input' do
        expect(filter.localize_url('')).to eq('')
      end

      it 'returns nil for nil input' do
        expect(filter.localize_url(nil)).to be_nil
      end

      it 'does not double-localize URLs that already have a locale' do
        expect(filter.localize_url('/es/search/buy')).to eq('/es/search/buy')
        expect(filter.localize_url('/en/contact')).to eq('/en/contact')
        expect(filter.localize_url('/fr/about')).to eq('/fr/about')
      end
    end

    context 'when locale is default (English)' do
      before do
        allow(I18n).to receive(:locale).and_return(:en)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return(%i[en es fr])
      end

      it 'does not modify URLs when using default locale' do
        expect(filter.localize_url('/search/buy')).to eq('/search/buy')
      end

      it 'does not modify contact URL in default locale' do
        expect(filter.localize_url('/contact')).to eq('/contact')
      end
    end

    context 'with French locale' do
      before do
        allow(I18n).to receive(:locale).and_return(:fr)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return(%i[en es fr de])
      end

      it 'prepends French locale to URLs' do
        expect(filter.localize_url('/search/buy')).to eq('/fr/search/buy')
      end
    end

    context 'edge cases' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return(%i[en es])
      end

      it 'handles root path' do
        expect(filter.localize_url('/')).to eq('/es/')
      end

      it 'handles paths with query strings' do
        expect(filter.localize_url('/search/buy?type=apartment')).to eq('/es/search/buy?type=apartment')
      end

      it 'handles paths with fragments' do
        expect(filter.localize_url('/about#team')).to eq('/es/about#team')
      end

      it 'handles mailto links (external)' do
        # mailto is not http/https but should not be modified
        expect(filter.localize_url('mailto:test@example.com')).to eq('/es/mailto:test@example.com')
      end

      it 'handles tel links' do
        # tel is not a path, but our filter treats it as internal
        # This is acceptable - these links typically come from external URL fields
        expect(filter.localize_url('tel:+1234567890')).to eq('/es/tel:+1234567890')
      end
    end
  end

  describe '#material_icon' do
    def expect_icon_markup(result, icon_name:, size_class: 'icon-md')
      expect(result).to include('<svg')
      expect(result).to include(%(class="icon #{size_class}"))
      expect(result).to include(%(data-icon-name="#{icon_name}"))
      expect(result).to include('aria-hidden="true"')
      expect(result.strip).to end_with('</svg>')
    end

    context 'basic rendering' do
      it 'renders an inline SVG with the mapped Lucide icon' do
        result = filter.material_icon('home')
        expect_icon_markup(result, icon_name: 'house')
      end

      it 'returns empty string for blank input' do
        expect(filter.material_icon('')).to eq('')
        expect(filter.material_icon(nil)).to eq('')
      end

      it 'trims whitespace from icon name' do
        result = filter.material_icon('  search  ')
        expect_icon_markup(result, icon_name: 'search')
      end
    end

    context 'size classes' do
      {
        'xs' => 'icon-xs',
        'sm' => 'icon-sm',
        'md' => 'icon-md',
        'lg' => 'icon-lg',
        'xl' => 'icon-xl'
      }.each do |size, class_name|
        it "applies #{size} size class" do
          result = filter.material_icon('home', size)
          expect(result).to include(%(class="icon #{class_name}"))
        end
      end

      it 'defaults to md when size is nil' do
        result = filter.material_icon('home', nil)
        expect(result).to include('class="icon icon-md"')
      end
    end

    context 'legacy Font Awesome mappings' do
      {
        'fa fa-home' => 'house',
        'fa-home' => 'house',
        'fa fa-search' => 'search',
        'fa fa-envelope' => 'mail',
        'fa fa-phone' => 'phone',
        'fa fa-map-marker' => 'map-pin',
        'fa fa-bed' => 'bed',
        'fa fa-bath' => 'bath',
        'fa fa-chevron-left' => 'chevron-left',
        'fa fa-chevron-right' => 'chevron-right'
      }.each do |input, lucide|
        it "maps #{input} to #{lucide}" do
          result = filter.material_icon(input)
          expect_icon_markup(result, icon_name: lucide)
        end
      end
    end

    context 'legacy Phosphor mappings' do
      {
        'ph ph-house' => 'house',
        'ph-house' => 'house',
        'ph ph-magnifying-glass' => 'search',
        'ph ph-envelope' => 'mail',
        'ph ph-bed' => 'bed',
        'ph ph-caret-left' => 'chevron-left',
        'ph ph-arrow-right' => 'arrow-right',
        'ph ph-paper-plane-tilt' => 'send'
      }.each do |input, lucide|
        it "maps #{input} to #{lucide}" do
          result = filter.material_icon(input)
          expect_icon_markup(result, icon_name: lucide)
        end
      end
    end

    context 'dash to underscore conversion' do
      it 'converts dashed names to underscores before mapping' do
        result = filter.material_icon('arrow-forward')
        expect_icon_markup(result, icon_name: 'arrow-right')
      end

      it 'handles existing underscore names' do
        result = filter.material_icon('arrow_forward')
        expect_icon_markup(result, icon_name: 'arrow-right')
      end
    end

    context 'HTML structure' do
      it 'renders an SVG element' do
        result = filter.material_icon('home')
        expect(result).to include('<svg')
        expect(result.strip).to end_with('</svg>')
      end

      it 'includes aria-hidden for decorative icons' do
        result = filter.material_icon('home')
        expect(result).to include('aria-hidden="true"')
      end
    end
  end

  describe '#brand_icon' do
    it 'renders an SVG element for brand icons' do
      result = filter.brand_icon('facebook')
      expect(result).to include('<svg')
      expect(result).to include('</svg>')
      expect(result).to include('#icon-facebook')
    end

    it 'returns empty string for blank input' do
      expect(filter.brand_icon('')).to eq('')
      expect(filter.brand_icon(nil)).to eq('')
    end

    it 'uses default size of 24' do
      result = filter.brand_icon('facebook')
      expect(result).to include('width="24"')
      expect(result).to include('height="24"')
    end

    it 'accepts custom size' do
      result = filter.brand_icon('instagram', 32)
      expect(result).to include('width="32"')
      expect(result).to include('height="32"')
    end

    it 'includes aria-hidden for decorative icons' do
      result = filter.brand_icon('linkedin')
      expect(result).to include('aria-hidden="true"')
    end

    it 'adds brand-specific CSS class' do
      result = filter.brand_icon('youtube')
      expect(result).to include('brand-icon-youtube')
    end

    it 'maps twitter to x' do
      result = filter.brand_icon('twitter')
      expect(result).to include('#icon-x')
    end

    it 'maps x-twitter to x' do
      result = filter.brand_icon('x-twitter')
      expect(result).to include('#icon-x')
    end

    it 'strips legacy FA brand prefixes' do
      result = filter.brand_icon('fab fa-facebook')
      expect(result).to include('#icon-facebook')
    end
  end

  describe 'integration with Liquid templates' do
    before do
      # Register filters with Liquid
      Liquid::Template.register_filter(Pwb::LiquidFilters)
    end

    it 'works as a Liquid filter' do
      template = Liquid::Template.parse('{{ "home" | material_icon }}')
      result = template.render
      expect(result).to include('data-icon-name="house"')
      expect(result).to include('class="icon icon-md"')
    end

    it 'works with size parameter' do
      template = Liquid::Template.parse('{{ "search" | material_icon: "lg" }}')
      result = template.render
      expect(result).to include('class="icon icon-lg"')
    end

    it 'works with variable icon names' do
      template = Liquid::Template.parse('{{ icon_name | material_icon }}')
      result = template.render('icon_name' => 'phone')
      expect(result).to include('data-icon-name="phone"')
    end

    it 'handles blank icon names gracefully' do
      template = Liquid::Template.parse('{{ missing_var | material_icon }}')
      result = template.render
      expect(result).to eq('')
    end
  end
end
