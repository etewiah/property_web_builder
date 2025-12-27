# frozen_string_literal: true

module Pwb
  # Handles currency preference selection for visitors.
  #
  # Stores the user's preferred display currency in session and cookie.
  # This affects how prices are displayed but not how they are stored or searched.
  #
  class CurrenciesController < ApplicationController
    # POST /set_currency
    #
    # Sets the user's preferred display currency.
    # Validates that the currency is available for this website.
    #
    # @param currency [String] ISO currency code (e.g., 'USD', 'GBP')
    # @return [JSON] success status
    #
    def set
      currency = params[:currency]&.upcase

      if valid_currency?(currency)
        # Store in session for current visit
        session[:preferred_currency] = currency

        # Store in cookie for return visits (1 year expiry)
        cookies[:preferred_currency] = {
          value: currency,
          expires: 1.year.from_now,
          httponly: true
        }

        respond_to do |format|
          format.html { redirect_back(fallback_location: root_path) }
          format.json { render json: { success: true, currency: currency } }
          format.turbo_stream { redirect_back(fallback_location: root_path) }
        end
      else
        respond_to do |format|
          format.html do
            flash[:error] = t("currency.invalid", default: "Invalid currency selected")
            redirect_back(fallback_location: root_path)
          end
          format.json { render json: { success: false, error: "Invalid currency" }, status: :unprocessable_entity }
          format.turbo_stream { redirect_back(fallback_location: root_path) }
        end
      end
    end

    private

    # Validate that the currency is available for this website
    #
    # @param currency [String] currency code to validate
    # @return [Boolean] true if currency is valid
    #
    def valid_currency?(currency)
      return false if currency.blank?

      available = available_currencies_for_website
      available.include?(currency)
    end

    # Get list of available currencies for the current website
    #
    # @return [Array<String>] list of currency codes
    #
    def available_currencies_for_website
      base = current_website&.default_currency || "EUR"
      additional = current_website&.available_currencies || []

      ([base] + additional).map(&:upcase).uniq
    end
  end
end
