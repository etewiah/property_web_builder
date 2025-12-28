# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe IconHelper, type: :helper do
    describe '#icon' do
      context 'basic rendering' do
        it 'renders a Material Symbol icon' do
          result = helper.icon(:home)
          expect(result).to have_css('span.material-symbols-outlined', text: 'home')
        end

        it 'includes aria-hidden by default for decorative icons' do
          result = helper.icon(:search)
          expect(result).to have_css('span[aria-hidden="true"]')
        end

        it 'works with string icon names' do
          result = helper.icon('phone')
          expect(result).to have_css('span.material-symbols-outlined', text: 'phone')
        end
      end

      context 'size options' do
        it 'applies xs size class' do
          result = helper.icon(:home, size: :xs)
          expect(result).to have_css('span.md-14')
        end

        it 'applies sm size class' do
          result = helper.icon(:home, size: :sm)
          expect(result).to have_css('span.md-18')
        end

        it 'applies md size class (default)' do
          result = helper.icon(:home, size: :md)
          expect(result).to have_css('span.md-24')
        end

        it 'applies lg size class' do
          result = helper.icon(:home, size: :lg)
          expect(result).to have_css('span.md-36')
        end

        it 'applies xl size class' do
          result = helper.icon(:home, size: :xl)
          expect(result).to have_css('span.md-48')
        end
      end

      context 'filled variant' do
        it 'adds filled class when option is true' do
          result = helper.icon(:star, filled: true)
          expect(result).to have_css('span.filled')
        end

        it 'does not add filled class when option is false' do
          result = helper.icon(:star, filled: false)
          expect(result).not_to have_css('span.filled')
        end
      end

      context 'custom classes' do
        it 'applies additional CSS classes' do
          result = helper.icon(:home, class: 'text-red-500')
          expect(result).to have_css('span.text-red-500')
        end
      end

      context 'accessibility' do
        it 'uses aria-label for meaningful icons' do
          result = helper.icon(:warning, aria: { label: 'Warning message' })
          expect(result).to have_css('span[aria-label="Warning message"]')
          expect(result).to have_css('span[role="img"]')
        end

        it 'is aria-hidden for decorative icons (default)' do
          result = helper.icon(:home)
          expect(result).to have_css('span[aria-hidden="true"]')
        end
      end

      context 'legacy icon name aliasing' do
        it 'maps fa-home to home' do
          result = helper.icon('fa-home')
          expect(result).to have_css('span.material-symbols-outlined', text: 'home')
        end

        it 'maps fa-envelope to email' do
          result = helper.icon('fa-envelope')
          expect(result).to have_css('span.material-symbols-outlined', text: 'email')
        end

        it 'maps ph-house to home' do
          result = helper.icon('ph-house')
          expect(result).to have_css('span.material-symbols-outlined', text: 'home')
        end

        it 'maps ph-magnifying-glass to search' do
          result = helper.icon('ph-magnifying-glass')
          expect(result).to have_css('span.material-symbols-outlined', text: 'search')
        end
      end

      context 'semantic aliases' do
        it 'maps bedroom to bed' do
          result = helper.icon(:bedroom)
          expect(result).to have_css('span.material-symbols-outlined', text: 'bed')
        end

        it 'maps bathroom to bathroom' do
          result = helper.icon(:bathroom)
          expect(result).to have_css('span.material-symbols-outlined', text: 'bathroom')
        end

        it 'maps location to location_on' do
          result = helper.icon(:location)
          expect(result).to have_css('span.material-symbols-outlined', text: 'location_on')
        end

        it 'maps envelope to email' do
          result = helper.icon(:envelope)
          expect(result).to have_css('span.material-symbols-outlined', text: 'email')
        end
      end

      context 'validation' do
        it 'raises error for unknown icons in test environment' do
          expect { helper.icon(:completely_unknown_icon_xyz) }
            .to raise_error(ArgumentError, /Unknown icon/)
        end
      end
    end

    describe '#icon_button' do
      it 'renders icon inside a button' do
        result = helper.icon_button(:menu)
        expect(result).to have_css('button span.material-symbols-outlined', text: 'menu')
      end

      it 'applies icon-button class by default' do
        result = helper.icon_button(:menu)
        expect(result).to have_css('button.icon-button')
      end

      it 'allows custom button class' do
        result = helper.icon_button(:menu, button_class: 'nav-toggle')
        expect(result).to have_css('button.nav-toggle')
      end

      it 'sets button type attribute' do
        result = helper.icon_button(:menu, type: 'submit')
        expect(result).to have_css('button[type="submit"]')
      end

      it 'uses aria-label on button when provided' do
        result = helper.icon_button(:menu, aria: { label: 'Open menu' })
        expect(result).to have_css('button[aria-label="Open menu"]')
      end
    end

    describe '#brand_icon' do
      it 'renders an SVG element' do
        result = helper.brand_icon(:facebook)
        expect(result).to have_css('svg.brand-icon')
      end

      it 'includes brand-specific class' do
        result = helper.brand_icon(:instagram)
        expect(result).to have_css('svg.brand-icon-instagram')
      end

      it 'uses default size of 24' do
        result = helper.brand_icon(:linkedin)
        expect(result).to have_css('svg[width="24"][height="24"]')
      end

      it 'allows custom size' do
        result = helper.brand_icon(:youtube, size: 32)
        expect(result).to have_css('svg[width="32"][height="32"]')
      end

      it 'is aria-hidden' do
        result = helper.brand_icon(:facebook)
        expect(result).to have_css('svg[aria-hidden="true"]')
      end

      it 'uses SVG sprite reference' do
        result = helper.brand_icon(:facebook)
        expect(result).to have_css('use[href="#icon-facebook"]')
      end

      it 'raises error for unknown brand in test environment' do
        expect { helper.brand_icon(:unknown_brand_xyz) }
          .to raise_error(ArgumentError, /Unknown brand icon/)
      end
    end

    describe '#social_icon_link' do
      it 'renders a link with brand icon' do
        result = helper.social_icon_link(:facebook, 'https://facebook.com/example')
        expect(result).to have_css('a svg.brand-icon-facebook')
      end

      it 'opens in new tab' do
        result = helper.social_icon_link(:instagram, 'https://instagram.com/example')
        expect(result).to have_css('a[target="_blank"]')
      end

      it 'includes noopener noreferrer' do
        result = helper.social_icon_link(:linkedin, 'https://linkedin.com/example')
        expect(result).to have_css('a[rel="noopener noreferrer"]')
      end

      it 'includes accessible aria-label' do
        result = helper.social_icon_link(:twitter, 'https://twitter.com/example')
        expect(result).to have_css('a[aria-label*="Twitter"]')
      end

      it 'returns nil for blank URL' do
        expect(helper.social_icon_link(:facebook, '')).to be_nil
        expect(helper.social_icon_link(:facebook, nil)).to be_nil
      end

      it 'applies custom size to icon' do
        result = helper.social_icon_link(:facebook, 'https://facebook.com/example', size: 32)
        expect(result).to have_css('svg[width="32"]')
      end
    end
  end
end
