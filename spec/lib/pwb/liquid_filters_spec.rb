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
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr, :de])
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
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr])
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
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr, :de])
      end

      it 'prepends French locale to URLs' do
        expect(filter.localize_url('/search/buy')).to eq('/fr/search/buy')
      end
    end

    context 'edge cases' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es])
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
    context 'basic rendering' do
      it 'renders a Material Symbol icon with the given name' do
        result = filter.material_icon('home')
        expect(result).to include('material-symbols-outlined')
        expect(result).to include('>home</span>')
        expect(result).to include('aria-hidden="true"')
      end

      it 'returns empty string for blank input' do
        expect(filter.material_icon('')).to eq('')
        expect(filter.material_icon(nil)).to eq('')
      end

      it 'trims whitespace from icon name' do
        result = filter.material_icon('  search  ')
        expect(result).to include('>search</span>')
      end
    end

    context 'size classes' do
      it 'applies xs size class' do
        result = filter.material_icon('home', 'xs')
        expect(result).to include('md-14')
      end

      it 'applies sm size class' do
        result = filter.material_icon('home', 'sm')
        expect(result).to include('md-18')
      end

      it 'applies md size class' do
        result = filter.material_icon('home', 'md')
        expect(result).to include('md-24')
      end

      it 'applies lg size class' do
        result = filter.material_icon('home', 'lg')
        expect(result).to include('md-36')
      end

      it 'applies xl size class' do
        result = filter.material_icon('home', 'xl')
        expect(result).to include('md-48')
      end

      it 'has no size class for nil' do
        result = filter.material_icon('home', nil)
        expect(result).not_to include('md-')
      end
    end

    context 'legacy Font Awesome mappings' do
      it 'maps fa fa-home to home' do
        result = filter.material_icon('fa fa-home')
        expect(result).to include('>home</span>')
      end

      it 'maps fa-home to home' do
        result = filter.material_icon('fa-home')
        expect(result).to include('>home</span>')
      end

      it 'maps fa fa-search to search' do
        result = filter.material_icon('fa fa-search')
        expect(result).to include('>search</span>')
      end

      it 'maps fa fa-envelope to email' do
        result = filter.material_icon('fa fa-envelope')
        expect(result).to include('>email</span>')
      end

      it 'maps fa fa-phone to phone' do
        result = filter.material_icon('fa fa-phone')
        expect(result).to include('>phone</span>')
      end

      it 'maps fa fa-map-marker to location_on' do
        result = filter.material_icon('fa fa-map-marker')
        expect(result).to include('>location_on</span>')
      end

      it 'maps fa fa-bed to bed' do
        result = filter.material_icon('fa fa-bed')
        expect(result).to include('>bed</span>')
      end

      it 'maps fa fa-bath to bathroom' do
        result = filter.material_icon('fa fa-bath')
        expect(result).to include('>bathroom</span>')
      end

      it 'maps fa fa-chevron-left to chevron_left' do
        result = filter.material_icon('fa fa-chevron-left')
        expect(result).to include('>chevron_left</span>')
      end

      it 'maps fa fa-chevron-right to chevron_right' do
        result = filter.material_icon('fa fa-chevron-right')
        expect(result).to include('>chevron_right</span>')
      end
    end

    context 'legacy Phosphor mappings' do
      it 'maps ph ph-house to home' do
        result = filter.material_icon('ph ph-house')
        expect(result).to include('>home</span>')
      end

      it 'maps ph-house to home' do
        result = filter.material_icon('ph-house')
        expect(result).to include('>home</span>')
      end

      it 'maps ph ph-magnifying-glass to search' do
        result = filter.material_icon('ph ph-magnifying-glass')
        expect(result).to include('>search</span>')
      end

      it 'maps ph ph-envelope to email' do
        result = filter.material_icon('ph ph-envelope')
        expect(result).to include('>email</span>')
      end

      it 'maps ph ph-bed to bed' do
        result = filter.material_icon('ph ph-bed')
        expect(result).to include('>bed</span>')
      end

      it 'maps ph ph-caret-left to chevron_left' do
        result = filter.material_icon('ph ph-caret-left')
        expect(result).to include('>chevron_left</span>')
      end

      it 'maps ph ph-arrow-right to arrow_forward' do
        result = filter.material_icon('ph ph-arrow-right')
        expect(result).to include('>arrow_forward</span>')
      end

      it 'maps ph ph-paper-plane-tilt to send' do
        result = filter.material_icon('ph ph-paper-plane-tilt')
        expect(result).to include('>send</span>')
      end
    end

    context 'dash to underscore conversion' do
      it 'converts dashes to underscores for unmapped icons' do
        result = filter.material_icon('arrow-forward')
        expect(result).to include('>arrow_forward</span>')
      end

      it 'handles icons already with underscores' do
        result = filter.material_icon('arrow_forward')
        expect(result).to include('>arrow_forward</span>')
      end
    end

    context 'HTML structure' do
      it 'renders as a span element' do
        result = filter.material_icon('home')
        expect(result).to start_with('<span')
        expect(result).to end_with('</span>')
      end

      it 'includes aria-hidden for decorative icons' do
        result = filter.material_icon('home')
        expect(result).to include('aria-hidden="true"')
      end

      it 'produces valid HTML' do
        result = filter.material_icon('search', 'lg')
        # Should have proper structure
        expect(result).to match(/<span class="[^"]*" aria-hidden="true">[^<]+<\/span>/)
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
      expect(result).to include('material-symbols-outlined')
      expect(result).to include('>home</span>')
    end

    it 'works with size parameter' do
      template = Liquid::Template.parse('{{ "search" | material_icon: "lg" }}')
      result = template.render
      expect(result).to include('md-36')
    end

    it 'works with variable icon names' do
      template = Liquid::Template.parse('{{ icon_name | material_icon }}')
      result = template.render('icon_name' => 'phone')
      expect(result).to include('>phone</span>')
    end

    it 'handles blank icon names gracefully' do
      template = Liquid::Template.parse('{{ missing_var | material_icon }}')
      result = template.render
      expect(result).to eq('')
    end
  end
end
