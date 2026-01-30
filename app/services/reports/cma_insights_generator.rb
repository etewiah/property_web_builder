# frozen_string_literal: true

module Reports
  # Generates AI-powered insights for CMA (Comparative Market Analysis) reports.
  #
  # Takes comparable properties and market statistics to generate:
  # - Executive summary
  # - Market position analysis
  # - Pricing rationale
  # - Strengths and considerations
  # - Recommended listing price
  # - Estimated time to sell
  #
  # Follows the same pattern as Ai::ListingDescriptionGenerator.
  #
  # Usage:
  #   generator = Reports::CmaInsightsGenerator.new(
  #     report: market_report,
  #     comparables: comparables,
  #     statistics: statistics_result
  #   )
  #   result = generator.generate
  #
  #   if result.success?
  #     puts result.insights[:executive_summary]
  #   else
  #     puts result.error
  #   end
  #
  class CmaInsightsGenerator < ::Ai::BaseService
    Result = Struct.new(:success, :insights, :suggested_price, :request_id, :error, keyword_init: true) do
      def success?
        success
      end
    end

    def initialize(report:, comparables:, statistics:)
      @report = report
      @comparables = comparables
      @statistics = statistics
      @subject = report.subject_property
      super(website: report.website, user: report.user)
    end

    def generate
      request = create_generation_request(
        type: 'market_report',
        prop: nil,
        input_data: build_input_data,
        locale: 'en'
      )

      request.mark_processing!

      begin
        response = call_llm
        parsed = parse_response(response)

        request.mark_completed!(
          output: parsed,
          input_tokens: response.respond_to?(:input_tokens) ? response.input_tokens : response.usage&.input_tokens,
          output_tokens: response.respond_to?(:output_tokens) ? response.output_tokens : response.usage&.output_tokens
        )

        Result.new(
          success: true,
          insights: parsed[:insights],
          suggested_price: parsed[:suggested_price],
          request_id: request.id
        )
      rescue ::Ai::RateLimitError, ::Ai::ConfigurationError
        raise
      rescue ::Ai::Error => e
        request.mark_failed!(e.message)
        Result.new(success: false, error: e.message, request_id: request.id)
      rescue StandardError => e
        Rails.logger.error "[CmaInsightsGenerator] Unexpected error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        request.mark_failed!("Unexpected error: #{e.message}")
        Result.new(success: false, error: "An unexpected error occurred", request_id: request.id)
      end
    end

    private

    def call_llm
      chat(
        messages: build_messages,
        model: DEFAULT_MODEL
      )
    end

    def build_messages
      [
        { role: 'user', content: user_prompt }
      ]
    end

    def user_prompt
      <<~PROMPT
        You are an expert real estate appraiser and market analyst. Generate a professional CMA (Comparative Market Analysis) insight report.

        ## Subject Property
        #{format_subject_property}

        ## Comparable Properties (#{@comparables.length} found)
        #{format_comparables}

        ## Market Statistics
        #{format_statistics}

        ## Task
        Analyze the data and provide a comprehensive CMA report. Return your response as valid JSON in this exact format:

        {
          "executive_summary": "2-3 sentence overview of the property's market position and recommended pricing",
          "market_position": "How this property compares to the local market (above average, average, below average) with specific reasons",
          "pricing_rationale": "Detailed explanation of how the suggested price range was determined based on the comparable sales",
          "strengths": ["List 3-5 key strengths or selling points"],
          "considerations": ["List 2-3 factors that might affect marketability or require attention"],
          "recommendation": "Clear, actionable pricing recommendation with specific strategy",
          "time_to_sell_estimate": "Estimated days on market at the suggested price",
          "suggested_price_low_cents": #{calculate_suggested_low},
          "suggested_price_high_cents": #{calculate_suggested_high},
          "confidence_level": "high/medium/low based on comparable quality and quantity"
        }

        Important:
        - Return ONLY valid JSON, no additional text or markdown
        - Base your analysis on the actual comparable data provided
        - Be specific about how adjustments affect the price recommendation
        - Consider both the raw prices and the adjusted prices when making recommendations
        - The suggested prices should be in cents (e.g., $350,000 = 35000000)
      PROMPT
    end

    def format_subject_property
      return "No subject property specified" unless @subject

      details = []
      details << "Address: #{[@subject.street_address, @subject.city, @subject.postal_code].compact.join(', ')}"
      details << "Property Type: #{@subject.prop_type_key}"
      details << "Bedrooms: #{@subject.count_bedrooms}" if @subject.count_bedrooms.to_i > 0
      details << "Bathrooms: #{@subject.count_bathrooms}" if @subject.count_bathrooms.to_f > 0
      details << "Size: #{@subject.constructed_area} sqm" if @subject.constructed_area.to_f > 0
      details << "Year Built: #{@subject.year_construction}" if @subject.year_construction.to_i > 0
      details << "Garages: #{@subject.count_garages}" if @subject.count_garages.to_i > 0

      details.join("\n")
    end

    def format_comparables
      return "No comparable properties found" if @comparables.empty?

      @comparables.map.with_index do |comp, i|
        adjustments_text = format_adjustments(comp[:adjustments])
        <<~COMP
          ### Comparable #{i + 1}
          - Address: #{comp[:address]}
          - Sale Price: #{format_price(comp[:price_cents])}
          - Bedrooms: #{comp[:bedrooms]}, Bathrooms: #{comp[:bathrooms]}
          - Size: #{comp[:constructed_area]} sqm
          - Year Built: #{comp[:year_built]}
          - Similarity Score: #{comp[:similarity_score]}%
          - Distance: #{comp[:distance_km]} km
          - Adjustments: #{adjustments_text}
          - Adjusted Price: #{format_price(comp[:adjusted_price_cents])}
        COMP
      end.join("\n")
    end

    def format_adjustments(adjustments)
      return "None" if adjustments.nil? || adjustments.empty?

      adjustments.map do |key, adj|
        sign = adj[:adjustment_cents] >= 0 ? "+" : ""
        "#{key.to_s.humanize}: #{sign}#{format_price(adj[:adjustment_cents])}"
      end.join(", ")
    end

    def format_statistics
      return "No statistics available" unless @statistics

      stats = @statistics.respond_to?(:statistics) ? @statistics.statistics : @statistics

      lines = []
      lines << "Average Price: #{format_price(stats[:average_price] || @statistics.average_price_cents)}"
      lines << "Median Price: #{format_price(stats[:median_price] || @statistics.median_price_cents)}"
      lines << "Adjusted Average: #{format_price(stats[:adjusted_average_price] || @statistics.adjusted_average_cents)}"
      lines << "Adjusted Median: #{format_price(stats[:adjusted_median_price] || @statistics.adjusted_median_cents)}"
      lines << "Price per Sqft: #{format_price(stats[:price_per_sqft] || @statistics.price_per_sqft_cents)}/sqm"
      lines << "Comparable Count: #{stats[:comparable_count] || @statistics.comparable_count}"
      lines << "Average Similarity Score: #{stats[:average_similarity]}%"

      if range = @statistics.respond_to?(:price_range) ? @statistics.price_range : nil
        lines << "Price Range: #{format_price(range[:low_cents])} - #{format_price(range[:high_cents])}"
      end

      lines.compact.join("\n")
    end

    def format_price(cents)
      return "N/A" unless cents

      currency = @report.suggested_price_currency || 'USD'
      symbol = case currency
               when 'USD' then '$'
               when 'EUR' then '€'
               when 'GBP' then '£'
               else currency
               end

      "#{symbol}#{(cents / 100.0).round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    def calculate_suggested_low
      # Use adjusted median as baseline, reduce by 5%
      if @statistics&.adjusted_median_cents
        (@statistics.adjusted_median_cents * 0.95).round
      elsif @statistics&.median_price_cents
        (@statistics.median_price_cents * 0.95).round
      else
        0
      end
    end

    def calculate_suggested_high
      # Use adjusted median as baseline, increase by 5%
      if @statistics&.adjusted_median_cents
        (@statistics.adjusted_median_cents * 1.05).round
      elsif @statistics&.median_price_cents
        (@statistics.median_price_cents * 1.05).round
      else
        0
      end
    end

    def build_input_data
      {
        report_id: @report.id,
        report_type: @report.report_type,
        subject_property_id: @subject&.id,
        subject_property_class: @subject&.class&.name,
        comparable_count: @comparables.length,
        statistics_summary: {
          average_price: @statistics&.average_price_cents,
          median_price: @statistics&.median_price_cents,
          adjusted_average: @statistics&.adjusted_average_cents,
          adjusted_median: @statistics&.adjusted_median_cents
        }
      }.compact
    end

    def parse_response(response)
      content = response.content || response.text || ''

      # Extract JSON from response
      json_match = content.match(/\{[\s\S]*\}/)
      raise ::Ai::ApiError, "No valid JSON in response" unless json_match

      parsed = JSON.parse(json_match[0])

      {
        insights: {
          executive_summary: parsed['executive_summary'],
          market_position: parsed['market_position'],
          pricing_rationale: parsed['pricing_rationale'],
          strengths: parsed['strengths'] || [],
          considerations: parsed['considerations'] || [],
          recommendation: parsed['recommendation'],
          time_to_sell_estimate: parsed['time_to_sell_estimate'],
          confidence_level: parsed['confidence_level']
        },
        suggested_price: {
          low_cents: parsed['suggested_price_low_cents'],
          high_cents: parsed['suggested_price_high_cents'],
          currency: @report.suggested_price_currency || 'USD'
        }
      }
    rescue JSON::ParserError => e
      raise ::Ai::ApiError, "Failed to parse AI response: #{e.message}"
    end
  end
end
