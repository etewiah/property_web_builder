# frozen_string_literal: true

# CurrencyHelper
#
# Provides currency conversion and display helpers for property prices.
# Works with the ExchangeRateService to show prices in the user's preferred currency.
#
# Display approach: Shows original price with converted price in parentheses
# Example: "€250,000 (~$270,000 USD)"
#
# This is a "display-only" conversion - search and filtering still use
# the original listing currency to keep database queries simple and fast.
#
# Usage in views:
#   <%= display_price(property.price_sale_current) %>
#   <%= display_price(property.contextual_price('for_sale'), show_conversion: false) %>
#
module CurrencyHelper
  # Display a price with optional currency conversion
  #
  # @param money [Money] the price to display
  # @param show_conversion [Boolean] whether to show converted price
  # @param no_cents [Boolean] whether to hide cents (default true for real estate)
  # @return [String] formatted price string (HTML safe)
  #
  # @example
  #   display_price(Money.new(25000000, 'EUR'))
  #   # => "€250,000" (if user currency is EUR)
  #   # => "€250,000 <span class='text-gray-500'>(~$270,000 USD)</span>" (if user currency is USD)
  #
  def display_price(money, show_conversion: true, no_cents: true)
    return nil if money.nil? || money.cents.zero?

    original = money.format(no_cents: no_cents)

    if show_conversion && should_show_conversion?(money)
      converted = convert_for_display(money, no_cents: no_cents)
      if converted
        "#{original} <span class=\"text-gray-500 text-sm\">(~#{converted})</span>".html_safe
      else
        original
      end
    else
      original
    end
  end

  # Display price with explicit target currency
  #
  # @param money [Money] the price to convert
  # @param target_currency [String] the target currency code
  # @return [String] formatted converted price or nil
  #
  def display_price_in(money, target_currency, no_cents: true)
    return nil if money.nil? || money.cents.zero?

    converted = Pwb::ExchangeRateService.convert(money, target_currency, current_website)
    converted&.format(no_cents: no_cents)
  end

  # Get the user's preferred display currency
  #
  # Priority:
  # 1. Session preference (set via currency selector)
  # 2. Cookie preference (persisted across sessions)
  # 3. Website's default currency
  #
  # @return [String] currency code (e.g., 'EUR', 'USD')
  #
  def user_preferred_currency
    session[:preferred_currency] ||
      cookies[:preferred_currency] ||
      current_website&.default_currency ||
      "EUR"
  end

  # Get list of currencies available for this website
  #
  # @return [Array<String>] list of currency codes
  #
  def available_display_currencies
    base = current_website&.default_currency || "EUR"
    additional = current_website&.available_currencies || []

    ([base] + additional).uniq
  end

  # Check if multiple currencies are available
  #
  # @return [Boolean] true if currency selector should be shown
  #
  def multiple_currencies_available?
    available_display_currencies.size > 1
  end

  # Get currency symbol for a currency code
  #
  # @param currency_code [String] ISO currency code
  # @return [String] currency symbol
  #
  def currency_symbol(currency_code)
    Money::Currency.find(currency_code)&.symbol || currency_code
  end

  # Build options for currency selector dropdown
  #
  # @return [Array<Array>] options for select helper [["€ EUR", "EUR"], ...]
  #
  def currency_select_options
    available_display_currencies.map do |code|
      currency = Money::Currency.find(code)
      label = currency ? "#{currency.symbol} #{code}" : code
      [label, code]
    end
  end

  private

  # Check if we should show a converted price
  #
  # @param money [Money] the original price
  # @return [Boolean] true if conversion should be shown
  #
  def should_show_conversion?(money)
    return false unless current_website
    return false unless multiple_currencies_available?

    preferred = user_preferred_currency
    preferred.present? && preferred != money.currency.iso_code
  end

  # Convert price for display purposes
  #
  # @param money [Money] the original price
  # @param no_cents [Boolean] whether to hide cents
  # @return [String, nil] formatted converted price or nil if conversion failed
  #
  def convert_for_display(money, no_cents: true)
    return nil unless current_website

    target = user_preferred_currency
    return nil if target == money.currency.iso_code

    converted = Pwb::ExchangeRateService.convert(money, target, current_website)
    return nil unless converted

    # Format with currency code for clarity
    "#{converted.format(no_cents: no_cents)} #{target}"
  end
end
