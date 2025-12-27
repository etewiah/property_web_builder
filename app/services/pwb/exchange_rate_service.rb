# frozen_string_literal: true

module Pwb
  # Service for managing currency exchange rates using European Central Bank data.
  #
  # Uses the eu_central_bank gem to fetch daily exchange rates from the ECB.
  # Rates are stored per-website in the exchange_rates JSON column.
  #
  # Supported currencies (ECB publishes ~30 currencies):
  # EUR, USD, GBP, CHF, JPY, AUD, CAD, CNY, HKD, NZD, SEK, NOK, DKK, PLN, CZK, etc.
  #
  # Usage:
  #   # Update rates for a single website
  #   Pwb::ExchangeRateService.update_rates(website)
  #
  #   # Update rates for all websites with multiple currencies
  #   Pwb::ExchangeRateService.update_all_rates
  #
  #   # Get conversion rate
  #   Pwb::ExchangeRateService.get_rate(website, 'EUR', 'USD')  # => 1.0845
  #
  #   # Convert a Money object
  #   Pwb::ExchangeRateService.convert(money, 'USD', website)
  #
  class ExchangeRateService
    class RateFetchError < StandardError; end

    # Common currencies for real estate markets
    COMMON_CURRENCIES = %w[EUR USD GBP CHF AUD CAD NZD SEK NOK DKK PLN CZK HUF].freeze

    class << self
      # Update exchange rates for a specific website
      #
      # @param website [Pwb::Website] the website to update rates for
      # @return [Hash] the updated rates
      # @raise [RateFetchError] if rates cannot be fetched
      def update_rates(website)
        base_currency = website.default_currency || "EUR"
        target_currencies = website.available_currencies || []

        # Skip if no additional currencies configured
        return {} if target_currencies.empty?

        # Remove base currency from targets (no self-conversion needed)
        target_currencies = target_currencies.reject { |c| c == base_currency }
        return {} if target_currencies.empty?

        bank = fetch_bank_rates

        rates = build_rates_hash(bank, base_currency, target_currencies)

        website.update!(
          exchange_rates: rates,
          exchange_rates_updated_at: Time.current
        )

        Rails.logger.info "[ExchangeRates] Updated #{rates.size} rates for website #{website.id}"
        rates
      rescue StandardError => e
        Rails.logger.error "[ExchangeRates] Failed to update rates for website #{website.id}: #{e.message}"
        raise RateFetchError, "Could not fetch exchange rates: #{e.message}"
      end

      # Update rates for all websites that have multiple currencies configured
      #
      # @return [Integer] number of websites updated
      def update_all_rates
        count = 0

        # Find websites with available_currencies set
        Website.where.not(available_currencies: nil)
               .where.not(available_currencies: [])
               .find_each do |website|
          update_rates(website)
          count += 1
        rescue RateFetchError => e
          Rails.logger.warn "[ExchangeRates] Skipping website #{website.id}: #{e.message}"
        end

        Rails.logger.info "[ExchangeRates] Updated rates for #{count} websites"
        count
      end

      # Get the exchange rate between two currencies for a website
      #
      # @param website [Pwb::Website] the website with stored rates
      # @param from_currency [String] source currency code (e.g., 'EUR')
      # @param to_currency [String] target currency code (e.g., 'USD')
      # @return [Float, nil] the exchange rate or nil if not available
      def get_rate(website, from_currency, to_currency)
        return 1.0 if from_currency == to_currency

        rates = website.exchange_rates
        return nil if rates.blank?

        base = website.default_currency || "EUR"

        if from_currency == base
          # Direct conversion from base
          rates[to_currency]&.to_f
        elsif to_currency == base
          # Inverse conversion to base
          rate = rates[from_currency]&.to_f
          rate ? (1.0 / rate) : nil
        else
          # Cross-rate through base currency
          from_rate = rates[from_currency]&.to_f
          to_rate = rates[to_currency]&.to_f
          (from_rate && to_rate) ? (to_rate / from_rate) : nil
        end
      end

      # Convert a Money object to a different currency
      #
      # @param money [Money] the money object to convert
      # @param to_currency [String] target currency code
      # @param website [Pwb::Website] the website with stored rates
      # @return [Money, nil] the converted money or nil if conversion not possible
      def convert(money, to_currency, website)
        return nil if money.nil?
        return money if money.currency.iso_code == to_currency

        rate = get_rate(website, money.currency.iso_code, to_currency)
        return nil unless rate

        converted_cents = (money.cents * rate).round
        Money.new(converted_cents, to_currency)
      end

      # Check if rates are stale (older than 24 hours)
      #
      # @param website [Pwb::Website] the website to check
      # @return [Boolean] true if rates need updating
      def rates_stale?(website)
        return true if website.exchange_rates_updated_at.nil?

        website.exchange_rates_updated_at < 24.hours.ago
      end

      # Get list of available currencies from ECB
      #
      # @return [Array<String>] list of currency codes
      def available_ecb_currencies
        bank = fetch_bank_rates
        # ECB rates are all relative to EUR
        currencies = bank.rates.keys.map { |key| key.split("_TO_").last }.uniq
        (["EUR"] + currencies).sort
      rescue StandardError
        COMMON_CURRENCIES
      end

      private

      def fetch_bank_rates
        bank = EuCentralBank.new
        bank.update_rates
        bank
      end

      def build_rates_hash(bank, base_currency, target_currencies)
        rates = {}

        target_currencies.each do |target|
          next if target == base_currency

          begin
            rate = if base_currency == "EUR"
                     # ECB rates are EUR-based, so direct lookup
                     bank.get_rate("EUR", target)
                   else
                     # Need cross-rate: base -> EUR -> target
                     base_to_eur = bank.get_rate(base_currency, "EUR")
                     eur_to_target = bank.get_rate("EUR", target)
                     base_to_eur * eur_to_target
                   end

            rates[target] = rate.to_f.round(6) if rate
          rescue Money::Bank::UnknownRate => e
            Rails.logger.warn "[ExchangeRates] Unknown rate for #{base_currency}->#{target}: #{e.message}"
          end
        end

        rates
      end
    end
  end
end
