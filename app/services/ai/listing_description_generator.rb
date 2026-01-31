# frozen_string_literal: true

module Ai
  # Generates AI-powered property listing descriptions.
  #
  # Takes a property's attributes and generates:
  # - Title/headline
  # - Full description
  # - Meta description (for SEO)
  #
  # Includes Fair Housing compliance checking and supports
  # custom writing rules per website.
  #
  # Usage:
  #   generator = Ai::ListingDescriptionGenerator.new(
  #     property: prop,
  #     locale: 'en',
  #     tone: 'professional'
  #   )
  #   result = generator.generate
  #
  #   if result.success?
  #     puts result.title
  #     puts result.description
  #   else
  #     puts result.error
  #   end
  #
  class ListingDescriptionGenerator < BaseService
    TONES = %w[professional casual luxury warm modern].freeze
    MAX_DESCRIPTION_LENGTH = 2000
    MAX_TITLE_LENGTH = 80
    MAX_META_DESCRIPTION_LENGTH = 160

    # Result object for generation responses
    Result = Struct.new(:success, :title, :description, :meta_description, :compliance, :request_id, :error, keyword_init: true) do
      def success?
        success
      end
    end

    def initialize(property:, locale: 'en', tone: 'professional', user: nil)
      @property = property
      @locale = locale
      @tone = TONES.include?(tone) ? tone : 'professional'
      super(website: property.website, user: user)
    end

    # Generate a new listing description
    #
    # @return [Result] Result object with generated content or error
    #
    def generate
      # Note: We don't save the prop association because properties can be
      # RealtyAsset, ListedProperty, or Prop models. The property details
      # are captured in input_data for audit purposes.
      request = create_generation_request(
        type: 'listing_description',
        prop: nil,
        input_data: property_context.merge(property_id: @property.id, property_class: @property.class.name),
        locale: @locale
      )

      request.mark_processing!

      begin
        response = call_llm
        parsed = parse_response(response)

        # Check Fair Housing compliance
        compliance_checker = FairHousingComplianceChecker.new
        compliance = compliance_checker.check("#{parsed[:title]} #{parsed[:description]}")

        request.mark_completed!(
          output: {
            title: parsed[:title],
            description: parsed[:description],
            meta_description: parsed[:meta_description],
            compliance: compliance
          },
          # RubyLLM::Message has tokens directly, not nested under usage
          input_tokens: response.respond_to?(:input_tokens) ? response.input_tokens : response.usage&.input_tokens,
          output_tokens: response.respond_to?(:output_tokens) ? response.output_tokens : response.usage&.output_tokens
        )

        Result.new(
          success: true,
          title: parsed[:title],
          description: parsed[:description],
          meta_description: parsed[:meta_description],
          compliance: compliance,
          request_id: request.id
        )
      rescue Ai::RateLimitError, Ai::ConfigurationError
        # Let rate limit and configuration errors propagate to controller
        raise
      rescue Ai::Error => e
        request.mark_failed!(e.message)
        Result.new(success: false, error: e.message, request_id: request.id)
      rescue StandardError => e
        Rails.logger.error "[AI] Unexpected error (provider: #{current_provider}, model: #{default_model}): #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        request.mark_failed!("Unexpected error: #{e.message}")
        error_msg = if Rails.env.production?
                      "An unexpected error occurred (provider: #{current_provider}). Check request #{request.id} for details."
                    else
                      "Unexpected error (#{current_provider}/#{default_model}): #{e.message}"
                    end
        Result.new(success: false, error: error_msg, request_id: request.id)
      end
    end

    private

    def call_llm
      chat(messages: build_messages)
    end

    def build_messages
      [
        { role: 'user', content: user_prompt }
      ]
    end

    def user_prompt
      <<~PROMPT
        #{system_instructions}

        Property Details:
        #{format_property_details}

        #{writing_rules_section}

        Generate a compelling listing for this property. Return your response in the following JSON format:
        {
          "title": "A catchy headline (max #{MAX_TITLE_LENGTH} characters)",
          "description": "Full property description (max #{MAX_DESCRIPTION_LENGTH} characters)",
          "meta_description": "SEO-optimized summary (max #{MAX_META_DESCRIPTION_LENGTH} characters)"
        }

        Important:
        - Return ONLY valid JSON, no additional text
        - Use #{language_name(@locale)} language
        - Apply a #{@tone} tone
        - Focus on key selling points and unique features
        - Do NOT include discriminatory language or preferences regarding race, religion, familial status, etc.
      PROMPT
    end

    def system_instructions
      <<~INSTRUCTIONS
        You are an expert real estate copywriter creating property listings.

        Guidelines:
        - Write compelling, accurate descriptions that highlight the property's best features
        - Be specific about measurements, rooms, and amenities
        - Create emotional appeal while remaining factual
        - Optimize for search engines without keyword stuffing
        - NEVER include language that could violate Fair Housing laws
        - Avoid mentioning proximity to religious institutions or schools as selling points
        - Do not describe the neighborhood demographics or suggest who should live there
      INSTRUCTIONS
    end

    def writing_rules_section
      rules = Pwb::AiWritingRule.for_prompt(@website)
      return "" if rules.empty?

      <<~RULES
        Additional Writing Guidelines (follow these specific rules):
        #{rules.map.with_index { |rule, i| "#{i + 1}. #{rule}" }.join("\n")}
      RULES
    end

    def format_property_details
      details = []

      # Basic info
      details << "Type: #{property_type}"
      details << "Listing Type: #{listing_type}"

      # Location
      location_parts = [@property.city, @property.region, @property.country].compact.reject(&:blank?)
      details << "Location: #{location_parts.join(', ')}" if location_parts.any?

      # Size and rooms
      details << "Bedrooms: #{@property.count_bedrooms}" if @property.count_bedrooms.to_i > 0
      details << "Bathrooms: #{@property.count_bathrooms}" if @property.count_bathrooms.to_f > 0
      details << "Constructed Area: #{format_area(@property.constructed_area)}" if @property.constructed_area.to_f > 0
      details << "Plot Area: #{format_area(@property.plot_area)}" if @property.plot_area.to_f > 0

      # Price
      details << "Price: #{format_price}" if has_price?

      # Features
      features = @property.features.pluck(:feature_key) rescue []
      details << "Features: #{features.join(', ')}" if features.any?

      # Additional details
      details << "Year Built: #{@property.year_construction}" if @property.year_construction.to_i > 0
      details << "Garages: #{@property.count_garages}" if @property.count_garages.to_i > 0
      details << "Furnished: Yes" if @property.respond_to?(:furnished?) && @property.furnished?

      # Existing description (for context)
      existing_desc = @property.description
      details << "Current Description: #{existing_desc[0..500]}" if existing_desc.present?

      details.join("\n")
    end

    def property_context
      {
        type: property_type,
        listing_type: listing_type,
        city: @property.city,
        region: @property.region,
        country: @property.country,
        bedrooms: @property.count_bedrooms,
        bathrooms: @property.count_bathrooms,
        constructed_area: @property.constructed_area,
        plot_area: @property.plot_area,
        year_built: @property.year_construction,
        features: (@property.features.pluck(:feature_key) rescue []),
        tone: @tone,
        locale: @locale
      }.compact
    end

    def property_type
      @property.prop_type_key.presence || 'property'
    end

    def listing_type
      if @property.for_sale?
        'sale'
      elsif @property.respond_to?(:for_rent?) && @property.for_rent?
        'rental'
      elsif @property.respond_to?(:for_rent_long_term?) && (@property.for_rent_long_term? || @property.for_rent_short_term?)
        'rental'
      else
        'listing'
      end
    end

    def has_price?
      return false unless @property.respond_to?(:price_sale_current_cents) || @property.respond_to?(:price_rental_monthly_current_cents)

      (@property.respond_to?(:price_sale_current_cents) && @property.price_sale_current_cents.to_i > 0) ||
        (@property.respond_to?(:price_rental_monthly_current_cents) && @property.price_rental_monthly_current_cents.to_i > 0)
    end

    def format_price
      if @property.for_sale? && @property.respond_to?(:price_sale_current_cents) && @property.price_sale_current_cents.to_i > 0
        currency = @property.respond_to?(:price_sale_current_currency) ? @property.price_sale_current_currency : 'EUR'
        amount = @property.price_sale_current_cents / 100.0
        "#{currency || 'EUR'} #{number_with_delimiter(amount.to_i)}"
      elsif @property.respond_to?(:price_rental_monthly_current_cents) && @property.price_rental_monthly_current_cents.to_i > 0
        currency = @property.respond_to?(:price_rental_monthly_current_currency) ? @property.price_rental_monthly_current_currency : 'EUR'
        amount = @property.price_rental_monthly_current_cents / 100.0
        "#{currency || 'EUR'} #{number_with_delimiter(amount.to_i)}/month"
      else
        nil
      end
    end

    def format_area(area)
      return nil if area.to_f <= 0

      unit = (@property.respond_to?(:area_unit) && @property.area_unit == 'sqft') ? 'sq ft' : 'm²'
      "#{number_with_delimiter(area.round)} #{unit}"
    end

    def number_with_delimiter(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def language_name(locale)
      case locale.to_s.split('-').first
      when 'en' then 'English'
      when 'es' then 'Spanish'
      when 'fr' then 'French'
      when 'de' then 'German'
      when 'pt' then 'Portuguese'
      when 'it' then 'Italian'
      when 'nl' then 'Dutch'
      when 'ru' then 'Russian'
      when 'zh' then 'Chinese'
      when 'ja' then 'Japanese'
      else 'English'
      end
    end

    def parse_response(response)
      content = response.content || response.text || ''

      # Try to extract JSON from the response
      json_match = content.match(/\{[\s\S]*\}/)
      raise ApiError, "No valid JSON in response" unless json_match

      parsed = JSON.parse(json_match[0])

      {
        title: sanitize_output(parsed['title'], MAX_TITLE_LENGTH),
        description: sanitize_output(parsed['description'], MAX_DESCRIPTION_LENGTH),
        meta_description: sanitize_output(parsed['meta_description'], MAX_META_DESCRIPTION_LENGTH)
      }
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse AI response: #{e.message}"
    end

    def sanitize_output(text, max_length)
      return '' if text.blank?

      # Remove any potential injection attempts or markdown artifacts
      cleaned = text.to_s
                   .gsub(/```\w*\n?/, '')  # Remove code blocks
                   .strip
                   .truncate(max_length)

      cleaned
    end
  end
end
