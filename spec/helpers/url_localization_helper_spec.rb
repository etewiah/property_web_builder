# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UrlLocalizationHelper do
  # Create a test class that includes the helper
  let(:helper_class) do
    Class.new do
      include UrlLocalizationHelper
    end
  end

  let(:helper) { helper_class.new }

  describe '#localized_url' do
    context 'when locale is not default (e.g., Spanish)' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr, :de])
      end

      it 'prepends locale to internal URLs' do
        expect(helper.localized_url('/search/buy')).to eq('/es/search/buy')
      end

      it 'prepends locale to contact URL' do
        expect(helper.localized_url('/contact')).to eq('/es/contact')
      end

      it 'handles URLs without leading slash' do
        expect(helper.localized_url('about')).to eq('/es/about')
      end

      it 'does not modify external URLs with https' do
        expect(helper.localized_url('https://example.com/page')).to eq('https://example.com/page')
      end

      it 'does not modify external URLs with http' do
        expect(helper.localized_url('http://example.com/page')).to eq('http://example.com/page')
      end

      it 'does not modify protocol-relative URLs' do
        expect(helper.localized_url('//cdn.example.com/image.jpg')).to eq('//cdn.example.com/image.jpg')
      end

      it 'does not modify anchor-only links' do
        expect(helper.localized_url('#section')).to eq('#section')
      end

      it 'returns empty string for blank input' do
        expect(helper.localized_url('')).to eq('')
      end

      it 'returns nil for nil input' do
        expect(helper.localized_url(nil)).to be_nil
      end

      it 'does not double-localize URLs that already have a locale' do
        expect(helper.localized_url('/es/search/buy')).to eq('/es/search/buy')
        expect(helper.localized_url('/en/contact')).to eq('/en/contact')
        expect(helper.localized_url('/fr/about')).to eq('/fr/about')
      end
    end

    context 'when locale is default (English)' do
      before do
        allow(I18n).to receive(:locale).and_return(:en)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr])
      end

      it 'does not modify URLs when using default locale' do
        expect(helper.localized_url('/search/buy')).to eq('/search/buy')
      end

      it 'does not modify contact URL in default locale' do
        expect(helper.localized_url('/contact')).to eq('/contact')
      end
    end

    context 'with French locale' do
      before do
        allow(I18n).to receive(:locale).and_return(:fr)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr, :de])
      end

      it 'prepends French locale to URLs' do
        expect(helper.localized_url('/search/buy')).to eq('/fr/search/buy')
      end
    end
  end

  describe '#localize_html_urls' do
    context 'when locale is not default (e.g., Spanish)' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr, :de])
      end

      it 'localizes href attributes in anchor tags' do
        html = '<a href="/search/buy">Search</a>'
        expect(helper.localize_html_urls(html)).to eq('<a href="/es/search/buy">Search</a>')
      end

      it 'localizes multiple href attributes' do
        html = '<a href="/search/buy">Buy</a> <a href="/contact">Contact</a>'
        result = helper.localize_html_urls(html)
        expect(result).to include('href="/es/search/buy"')
        expect(result).to include('href="/es/contact"')
      end

      it 'handles single-quoted href attributes' do
        html = "<a href='/search/buy'>Search</a>"
        expect(helper.localize_html_urls(html)).to eq('<a href="/es/search/buy">Search</a>')
      end

      it 'does not modify external URLs' do
        html = '<a href="https://external.com/page">External</a>'
        expect(helper.localize_html_urls(html)).to eq(html)
      end

      it 'does not modify anchor-only links' do
        html = '<a href="#section">Jump</a>'
        expect(helper.localize_html_urls(html)).to eq(html)
      end

      it 'does not double-localize already localized URLs' do
        html = '<a href="/es/search/buy">Search</a>'
        expect(helper.localize_html_urls(html)).to eq(html)
      end

      it 'handles complex HTML with mixed URLs' do
        html = <<~HTML
          <div class="hero">
            <a href="/search/buy" class="btn">Ver Propiedades</a>
            <a href="https://facebook.com" class="social">Facebook</a>
            <a href="#features">Features</a>
            <a href="/contact">Contact</a>
          </div>
        HTML

        result = helper.localize_html_urls(html)
        expect(result).to include('href="/es/search/buy"')
        expect(result).to include('href="https://facebook.com"')
        expect(result).to include('href="#features"')
        expect(result).to include('href="/es/contact"')
      end

      it 'preserves other HTML attributes' do
        html = '<a href="/search/buy" class="btn btn-primary" id="cta" data-turbo="false">Search</a>'
        result = helper.localize_html_urls(html)
        expect(result).to include('href="/es/search/buy"')
        expect(result).to include('class="btn btn-primary"')
        expect(result).to include('id="cta"')
        expect(result).to include('data-turbo="false"')
      end

      it 'handles URLs with query strings' do
        html = '<a href="/search/buy?type=apartment">Search</a>'
        expect(helper.localize_html_urls(html)).to eq('<a href="/es/search/buy?type=apartment">Search</a>')
      end

      it 'handles URLs with fragments' do
        html = '<a href="/about#team">Team</a>'
        expect(helper.localize_html_urls(html)).to eq('<a href="/es/about#team">Team</a>')
      end

      it 'returns blank content unchanged' do
        expect(helper.localize_html_urls('')).to eq('')
        expect(helper.localize_html_urls(nil)).to be_nil
      end
    end

    context 'when locale is default (English)' do
      before do
        allow(I18n).to receive(:locale).and_return(:en)
        allow(I18n).to receive(:default_locale).and_return(:en)
      end

      it 'does not modify any URLs' do
        html = '<a href="/search/buy">Search</a> <a href="/contact">Contact</a>'
        expect(helper.localize_html_urls(html)).to eq(html)
      end
    end

    context 'edge cases' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
        allow(I18n).to receive(:default_locale).and_return(:en)
        allow(I18n).to receive(:available_locales).and_return([:en, :es])
      end

      it 'handles button elements with href-like attributes' do
        # Button data attributes should not be touched (not href)
        html = '<button data-url="/search/buy">Search</button>'
        expect(helper.localize_html_urls(html)).to eq(html)
      end

      it 'handles root path' do
        html = '<a href="/">Home</a>'
        expect(helper.localize_html_urls(html)).to eq('<a href="/es/">Home</a>')
      end

      it 'handles link elements' do
        # Link href should also be processed
        html = '<link href="/stylesheet.css" rel="stylesheet">'
        # CSS files should get locale prefix (though unusual)
        # This is expected behavior - only external URLs are excluded
        expect(helper.localize_html_urls(html)).to eq('<link href="/es/stylesheet.css" rel="stylesheet">')
      end
    end
  end
end
