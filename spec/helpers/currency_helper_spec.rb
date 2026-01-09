# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CurrencyHelper, type: :helper do
  let(:website) { create(:pwb_website, default_currency: 'EUR', available_currencies: %w[USD GBP]) }

  before do
    # Set up current website context
    allow(helper).to receive(:current_website).and_return(website)
    allow(helper).to receive(:session).and_return({})
    allow(helper).to receive(:cookies).and_return({})
  end

  describe '#display_price' do
    let(:price) { Money.new(25_000_000, 'EUR') } # €250,000

    context 'with nil price' do
      it 'returns nil' do
        expect(helper.display_price(nil)).to be_nil
      end
    end

    context 'with zero price' do
      it 'returns nil' do
        expect(helper.display_price(Money.new(0, 'EUR'))).to be_nil
      end
    end

    context 'when user has not selected a different currency' do
      it 'returns formatted price without conversion' do
        result = helper.display_price(price)
        expect(result).to include('€')
        expect(result).to include('250,000')
        expect(result).not_to include('(~')
      end
    end

    context 'when show_conversion is false' do
      it 'returns only the original price' do
        allow(helper).to receive(:session).and_return({ preferred_currency: 'USD' })
        result = helper.display_price(price, show_conversion: false)
        expect(result).to include('€')
        expect(result).not_to include('(~')
      end
    end
  end

  describe '#user_preferred_currency' do
    context 'with session preference' do
      it 'returns session currency' do
        allow(helper).to receive(:session).and_return({ preferred_currency: 'USD' })
        expect(helper.user_preferred_currency).to eq('USD')
      end
    end

    context 'with cookie preference' do
      it 'returns cookie currency' do
        allow(helper).to receive(:session).and_return({})
        allow(helper).to receive(:cookies).and_return({ preferred_currency: 'GBP' })
        expect(helper.user_preferred_currency).to eq('GBP')
      end
    end

    context 'with no preference' do
      it 'returns website default currency' do
        expect(helper.user_preferred_currency).to eq('EUR')
      end
    end
  end

  describe '#available_display_currencies' do
    it 'includes the default currency' do
      expect(helper.available_display_currencies).to include('EUR')
    end

    it 'includes additional currencies' do
      expect(helper.available_display_currencies).to include('USD', 'GBP')
    end

    it 'returns unique values' do
      website.update(available_currencies: %w[EUR USD EUR])
      result = helper.available_display_currencies
      expect(result.count('EUR')).to eq(1)
    end
  end

  describe '#multiple_currencies_available?' do
    context 'with multiple currencies' do
      it 'returns true' do
        expect(helper.multiple_currencies_available?).to be true
      end
    end

    context 'with only default currency' do
      before do
        website.update(available_currencies: [])
      end

      it 'returns false' do
        expect(helper.multiple_currencies_available?).to be false
      end
    end
  end

  describe '#currency_symbol' do
    it 'returns € for EUR' do
      expect(helper.currency_symbol('EUR')).to eq('€')
    end

    it 'returns $ for USD' do
      expect(helper.currency_symbol('USD')).to eq('$')
    end

    it 'returns £ for GBP' do
      expect(helper.currency_symbol('GBP')).to eq('£')
    end

    it 'returns code for unknown currency' do
      expect(helper.currency_symbol('XXX')).to eq('XXX')
    end
  end

  describe '#currency_select_options' do
    it 'returns array of label/value pairs' do
      options = helper.currency_select_options
      expect(options).to be_an(Array)
      expect(options.first).to be_an(Array)
      expect(options.first.size).to eq(2)
    end

    it 'includes symbols in labels' do
      options = helper.currency_select_options
      labels = options.map(&:first)
      expect(labels.join).to include('€')
    end
  end
end
