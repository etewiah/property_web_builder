# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::ExchangeRateService do
  let(:website) do
    create(:pwb_website,
           default_currency: 'EUR',
           available_currencies: ['USD', 'GBP'],
           exchange_rates: {})
  end

  describe '.update_rates' do
    context 'when ECB API is available' do
      it 'updates exchange rates for the website' do
        expect(website.exchange_rates).to eq({})

        # Mock the ECB bank
        bank = instance_double(EuCentralBank)
        allow(EuCentralBank).to receive(:new).and_return(bank)
        allow(bank).to receive(:update_rates)
        allow(bank).to receive(:get_rate).with('EUR', 'USD').and_return(1.1)
        allow(bank).to receive(:get_rate).with('EUR', 'GBP').and_return(0.85)

        described_class.update_rates(website)

        website.reload
        expect(website.exchange_rates).to be_present
        expect(website.exchange_rates['USD']).to eq(1.1)
        expect(website.exchange_rates['GBP']).to eq(0.85)
      end
    end

    context 'when website has no available currencies' do
      let(:website) { create(:pwb_website, available_currencies: []) }

      it 'returns empty hash' do
        result = described_class.update_rates(website)
        expect(result).to eq({})
      end
    end

    context 'when available currencies only contains default' do
      let(:website) { create(:pwb_website, default_currency: 'EUR', available_currencies: ['EUR']) }

      it 'returns empty hash' do
        result = described_class.update_rates(website)
        expect(result).to eq({})
      end
    end
  end

  describe '.get_rate' do
    before do
      # Service stores rates as { 'USD' => 1.1, 'GBP' => 0.85 }
      website.update(exchange_rates: {
        'USD' => 1.1,
        'GBP' => 0.85,
        '_updated_at' => Time.current.iso8601
      })
    end

    it 'returns the exchange rate from base to target currency' do
      rate = described_class.get_rate(website, 'EUR', 'USD')
      expect(rate).to eq(1.1)
    end

    it 'returns inverse rate from target to base currency' do
      rate = described_class.get_rate(website, 'USD', 'EUR')
      expect(rate).to be_within(0.01).of(0.909) # 1/1.1
    end

    it 'returns cross-rate between non-base currencies' do
      rate = described_class.get_rate(website, 'USD', 'GBP')
      expect(rate).to be_within(0.01).of(0.773) # 0.85/1.1
    end

    it 'returns 1.0 for same currency' do
      rate = described_class.get_rate(website, 'EUR', 'EUR')
      expect(rate).to eq(1.0)
    end

    it 'returns nil for unknown currency pair' do
      rate = described_class.get_rate(website, 'EUR', 'JPY')
      expect(rate).to be_nil
    end
  end

  describe '.convert' do
    before do
      website.update(exchange_rates: {
        'USD' => 1.1,
        'GBP' => 0.85,
        '_updated_at' => Time.current.iso8601
      })
    end

    let(:eur_price) { Money.new(25000000, 'EUR') } # €250,000

    it 'converts money to target currency' do
      result = described_class.convert(eur_price, 'USD', website)

      expect(result).to be_a(Money)
      expect(result.currency.iso_code).to eq('USD')
      expect(result.cents).to eq(27500000) # 250,000 * 1.1 = 275,000 USD
    end

    it 'returns nil for unsupported conversion' do
      result = described_class.convert(eur_price, 'JPY', website)
      expect(result).to be_nil
    end

    it 'returns same money object for same currency' do
      result = described_class.convert(eur_price, 'EUR', website)

      expect(result).to eq(eur_price)
    end

    it 'returns nil for nil money' do
      result = described_class.convert(nil, 'USD', website)
      expect(result).to be_nil
    end
  end

  describe '.update_all_rates' do
    it 'updates rates for all websites with available currencies' do
      _website_without_currencies = create(:pwb_website, available_currencies: [])
      website_with_currencies = create(:pwb_website, available_currencies: ['USD'])

      # Mock the ECB bank
      bank = instance_double(EuCentralBank)
      allow(EuCentralBank).to receive(:new).and_return(bank)
      allow(bank).to receive(:update_rates)
      allow(bank).to receive(:get_rate).and_return(1.1)

      count = described_class.update_all_rates

      expect(count).to be >= 1
      website_with_currencies.reload
      expect(website_with_currencies.exchange_rates).to be_present
    end
  end

  describe '.rates_stale?' do
    context 'with no rates' do
      it 'returns true' do
        website.update(exchange_rates: {})
        expect(described_class.rates_stale?(website)).to be true
      end
    end

    context 'with recent rates' do
      it 'returns false' do
        website.update(exchange_rates: {
          'USD' => 1.1,
          '_updated_at' => Time.current.iso8601
        })
        expect(described_class.rates_stale?(website)).to be false
      end
    end

    context 'with old rates' do
      it 'returns true' do
        website.update(exchange_rates: {
          'USD' => 1.1,
          '_updated_at' => 25.hours.ago.iso8601
        })
        expect(described_class.rates_stale?(website)).to be true
      end
    end
  end
end
