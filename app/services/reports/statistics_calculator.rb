# frozen_string_literal: true

module Reports
  # Calculates market statistics from comparable properties.
  #
  # Computes key metrics like average price, median price, price per square foot,
  # and other market indicators useful for CMA reports.
  #
  # Usage:
  #   calculator = Reports::StatisticsCalculator.new(
  #     comparables: comparables,
  #     subject: realty_asset,
  #     currency: 'USD'
  #   )
  #   stats = calculator.calculate
  #
  class StatisticsCalculator
    Result = Struct.new(
      :average_price_cents,
      :median_price_cents,
      :price_per_sqft_cents,
      :price_range,
      :adjusted_average_cents,
      :adjusted_median_cents,
      :comparable_count,
      :currency,
      :statistics,
      keyword_init: true
    )

    def initialize(comparables:, subject:, currency: 'USD')
      @comparables = comparables || []
      @subject = subject
      @currency = currency
    end

    def calculate
      return empty_result if @comparables.empty?

      prices = extract_prices
      adjusted_prices = extract_adjusted_prices
      sizes = extract_sizes

      Result.new(
        average_price_cents: calculate_average(prices),
        median_price_cents: calculate_median(prices),
        price_per_sqft_cents: calculate_price_per_sqft(prices, sizes),
        price_range: calculate_price_range(prices),
        adjusted_average_cents: calculate_average(adjusted_prices),
        adjusted_median_cents: calculate_median(adjusted_prices),
        comparable_count: @comparables.length,
        currency: @currency,
        statistics: full_statistics(prices, adjusted_prices, sizes)
      )
    end

    private

    def extract_prices
      @comparables
        .map { |c| c[:price_cents] }
        .compact
        .select(&:positive?)
    end

    def extract_adjusted_prices
      @comparables
        .map { |c| c[:adjusted_price_cents] }
        .compact
        .select(&:positive?)
    end

    def extract_sizes
      @comparables
        .map { |c| c[:constructed_area] }
        .compact
        .select(&:positive?)
    end

    def calculate_average(values)
      return nil if values.empty?

      (values.sum.to_f / values.length).round
    end

    def calculate_median(values)
      return nil if values.empty?

      sorted = values.sort
      mid = sorted.length / 2

      if sorted.length.odd?
        sorted[mid]
      else
        ((sorted[mid - 1] + sorted[mid]) / 2.0).round
      end
    end

    def calculate_price_range(prices)
      return nil if prices.empty?

      {
        low_cents: prices.min,
        high_cents: prices.max,
        range_cents: prices.max - prices.min
      }
    end

    def calculate_price_per_sqft(prices, sizes)
      return nil if prices.empty? || sizes.empty?

      # Calculate average price per sqft across all comparables
      price_per_sqft_values = @comparables.filter_map do |c|
        next unless c[:price_cents]&.positive? && c[:constructed_area]&.positive?

        (c[:price_cents].to_f / c[:constructed_area]).round
      end

      return nil if price_per_sqft_values.empty?

      calculate_average(price_per_sqft_values)
    end

    def calculate_standard_deviation(values)
      return nil if values.length < 2

      mean = values.sum.to_f / values.length
      variance = values.sum { |v| (v - mean)**2 } / (values.length - 1)
      Math.sqrt(variance).round
    end

    def full_statistics(prices, adjusted_prices, sizes)
      {
        # Basic price statistics
        average_price: format_currency(calculate_average(prices)),
        median_price: format_currency(calculate_median(prices)),
        min_price: format_currency(prices.min),
        max_price: format_currency(prices.max),
        price_std_dev: format_currency(calculate_standard_deviation(prices)),

        # Adjusted price statistics
        adjusted_average_price: format_currency(calculate_average(adjusted_prices)),
        adjusted_median_price: format_currency(calculate_median(adjusted_prices)),

        # Size statistics
        average_size: calculate_average(sizes.map { |s| (s * 10).round }),
        median_size: calculate_median(sizes.map { |s| (s * 10).round }),
        min_size: sizes.min&.round,
        max_size: sizes.max&.round,

        # Price per sqft
        price_per_sqft: format_currency(calculate_price_per_sqft(prices, sizes)),
        average_price_per_sqft: format_currency(calculate_price_per_sqft(prices, sizes)),

        # Counts and ranges
        comparable_count: @comparables.length,
        price_range_cents: prices.empty? ? nil : (prices.max - prices.min),

        # Additional metrics
        similarity_scores: @comparables.map { |c| c[:similarity_score] }.compact,
        average_similarity: calculate_average(@comparables.map { |c| c[:similarity_score] }.compact),

        # Subject property context
        subject_size: @subject&.constructed_area,
        estimated_value_per_sqft: calculate_subject_value_estimate(adjusted_prices, sizes)
      }.compact
    end

    def calculate_subject_value_estimate(adjusted_prices, sizes)
      return nil if adjusted_prices.empty? || !@subject&.constructed_area&.positive?

      avg_adjusted = calculate_average(adjusted_prices)
      return nil unless avg_adjusted

      avg_size = calculate_average(sizes.map { |s| (s * 10).round / 10.0 })
      return nil unless avg_size&.positive?

      price_per_sqft = avg_adjusted.to_f / avg_size
      estimated_value = (price_per_sqft * @subject.constructed_area).round

      {
        price_per_sqft_cents: price_per_sqft.round,
        subject_size: @subject.constructed_area,
        estimated_value_cents: estimated_value,
        estimated_value_formatted: format_currency(estimated_value)
      }
    end

    def format_currency(cents)
      return nil unless cents

      cents.to_i
    end

    def empty_result
      Result.new(
        average_price_cents: nil,
        median_price_cents: nil,
        price_per_sqft_cents: nil,
        price_range: nil,
        adjusted_average_cents: nil,
        adjusted_median_cents: nil,
        comparable_count: 0,
        currency: @currency,
        statistics: { comparable_count: 0 }
      )
    end
  end
end
