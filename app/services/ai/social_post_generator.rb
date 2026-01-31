# frozen_string_literal: true

module Ai
  # Generates AI-powered social media posts for property listings.
  #
  # Creates platform-specific content optimized for Instagram, Facebook,
  # LinkedIn, Twitter, and TikTok with appropriate tone, hashtags, and
  # character limits.
  #
  # Usage:
  #   generator = Ai::SocialPostGenerator.new(
  #     property: prop,
  #     platform: :instagram,
  #     options: { category: 'just_listed', locale: 'en' }
  #   )
  #   post = generator.generate
  #
  class SocialPostGenerator < BaseService
    PLATFORM_CONFIGS = {
      instagram: {
        tone: 'engaging and visual',
        emoji_level: :high,
        hashtag_count: 15,
        include_cta: true,
        cta_style: 'link in bio'
      },
      facebook: {
        tone: 'informative and friendly',
        emoji_level: :medium,
        hashtag_count: 5,
        include_cta: true,
        cta_style: 'direct link'
      },
      linkedin: {
        tone: 'professional',
        emoji_level: :low,
        hashtag_count: 5,
        include_cta: true,
        cta_style: 'professional inquiry'
      },
      twitter: {
        tone: 'concise and punchy',
        emoji_level: :medium,
        hashtag_count: 2,
        include_cta: true,
        cta_style: 'link'
      },
      tiktok: {
        tone: 'trendy and fun',
        emoji_level: :high,
        hashtag_count: 6,
        include_cta: true,
        cta_style: 'link in bio'
      }
    }.freeze

    # Result object for generation responses
    Result = Struct.new(:success, :post, :error, :request_id, keyword_init: true) do
      def success?
        success
      end
    end

    attr_reader :property, :platform, :options

    def initialize(property:, platform:, options: {})
      @property = property
      @platform = platform.to_sym
      @options = {
        post_type: 'feed',
        category: 'just_listed',
        locale: 'en'
      }.merge(options)

      super(website: property.website, user: options[:user])
    end

    # Generate a single social media post
    #
    # @return [Result] Result object with the generated post or error
    #
    def generate
      request = create_generation_request(
        type: 'social_post',
        prop: nil,
        input_data: {
          platform: platform,
          post_type: options[:post_type],
          category: options[:category],
          property: property_attributes,
          config: platform_config
        },
        locale: options[:locale]
      )

      request.mark_processing!

      begin
        response = call_llm
        parsed = parse_response(response)

        # Run Fair Housing compliance check
        compliance_checker = FairHousingComplianceChecker.new
        compliance = compliance_checker.check(parsed[:caption])

        post = create_social_post(parsed, request)

        request.mark_completed!(
          output: {
            caption: parsed[:caption],
            hashtags: parsed[:hashtags],
            suggested_photos: parsed[:suggested_photos],
            best_posting_time: parsed[:best_posting_time],
            compliance: compliance
          },
          input_tokens: response.respond_to?(:input_tokens) ? response.input_tokens : nil,
          output_tokens: response.respond_to?(:output_tokens) ? response.output_tokens : nil
        )

        Result.new(success: true, post: post, request_id: request.id)
      rescue Ai::RateLimitError, Ai::ConfigurationError
        raise
      rescue Ai::Error => e
        request.mark_failed!(e.message)
        Result.new(success: false, error: e.message, request_id: request.id)
      rescue StandardError => e
        Rails.logger.error "[AI Social] Unexpected error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        request.mark_failed!("Unexpected error: #{e.message}")
        Result.new(success: false, error: "An unexpected error occurred", request_id: request.id)
      end
    end

    # Generate posts for multiple platforms at once
    #
    # @param platforms [Array<Symbol>] List of platforms to generate for
    # @return [Array<Result>] Array of results for each platform
    #
    def generate_batch(platforms: [:instagram, :facebook, :linkedin])
      platforms.map do |target_platform|
        generator = self.class.new(
          property: property,
          platform: target_platform,
          options: options
        )
        generator.generate
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

        Create a #{platform} #{options[:post_type]} post for this real estate listing:

        ## Property Details
        - Type: #{property_attributes[:property_type]}
        - Bedrooms: #{property_attributes[:bedrooms]}
        - Bathrooms: #{property_attributes[:bathrooms]}
        - Price: #{property_attributes[:price]}
        - Location: #{property_attributes[:city]}, #{property_attributes[:region]}
        - Key Features: #{property_attributes[:features].join(', ')}

        ## Post Category: #{options[:category].to_s.titleize}

        ## Platform Requirements
        - Platform: #{platform.to_s.titleize}
        - Tone: #{platform_config[:tone]}
        - Emoji usage: #{platform_config[:emoji_level]}
        - Include #{platform_config[:hashtag_count]} relevant hashtags
        - Call-to-action style: #{platform_config[:cta_style]}
        - Character limit for caption: #{caption_limit}

        #{category_instructions}

        #{platform_guidelines}

        Respond ONLY with valid JSON in this format:
        {
          "caption": "The main post caption (without hashtags)",
          "hashtags": "#hashtag1 #hashtag2 ...",
          "suggested_photos": ["exterior", "living_room", "kitchen"],
          "best_posting_time": "suggestion for optimal posting time"
        }
      PROMPT
    end

    def system_instructions
      <<~INSTRUCTIONS
        You are an expert social media manager specializing in real estate marketing.
        You create engaging, platform-optimized content that drives leads and engagement.

        Guidelines:
        - Write authentic, non-salesy content
        - Use platform-specific best practices
        - Include relevant local hashtags
        - Create curiosity that drives clicks
        - Follow Fair Housing guidelines (no discriminatory language)
        - Make content shareable and engaging
        - NEVER mention proximity to religious institutions or schools
        - NEVER describe neighborhood demographics
      INSTRUCTIONS
    end

    def category_instructions
      case options[:category].to_s.to_sym
      when :just_listed
        "Focus: Excitement about the new listing. Highlight unique features and create urgency."
      when :price_drop
        "Focus: Emphasize the value and opportunity. Mention price reduction and encourage quick action."
      when :open_house
        "Focus: Create excitement for the event. Include placeholder for date/time. Emphasize the opportunity to view in person."
      when :sold
        "Focus: Celebrate the successful sale. Build credibility and encourage other sellers to reach out."
      when :market_update
        "Focus: Provide market insights. Position the agent as a local market expert."
      else
        "Focus: Create engaging content that drives property inquiries."
      end
    end

    def platform_guidelines
      case platform
      when :instagram
        "Instagram tips: Use line breaks for readability. Front-load the hook. Mix popular and niche hashtags. Place emoji strategically."
      when :facebook
        "Facebook tips: Can be slightly longer. Ask questions to drive comments. Encourage shares. Make it conversational."
      when :linkedin
        "LinkedIn tips: Professional tone throughout. Focus on market expertise and investment value. Use minimal emoji. Keep hashtags industry-relevant."
      when :twitter
        "Twitter/X tips: Be concise and punchy. Leave room for retweets. Use 1-2 relevant hashtags maximum. Strong hook in first line."
      when :tiktok
        "TikTok tips: Trendy, casual language. Hook in first line. Use trending hashtags when relevant. Be fun and engaging."
      else
        ""
      end
    end

    def caption_limit
      Pwb::SocialMediaPost::CAPTION_LIMITS[platform] || 2000
    end

    def platform_config
      PLATFORM_CONFIGS[platform] || PLATFORM_CONFIGS[:instagram]
    end

    def property_attributes
      @property_attributes ||= {
        property_type: property.prop_type_key.presence || 'property',
        bedrooms: property.count_bedrooms || 0,
        bathrooms: property.count_bathrooms || 0,
        price: format_price,
        city: property.city.presence || 'the area',
        region: property.region.presence || '',
        features: extract_features,
        photo_count: property.prop_photos.count,
        listing_url: listing_url
      }
    end

    def format_price
      if property.for_sale? && property.respond_to?(:price_sale_current_cents) && property.price_sale_current_cents.to_i > 0
        currency = property.price_sale_current_currency || 'EUR'
        amount = property.price_sale_current_cents / 100
        "#{currency} #{number_with_delimiter(amount)}"
      elsif property.respond_to?(:price_rental_monthly_current_cents) && property.price_rental_monthly_current_cents.to_i > 0
        currency = property.price_rental_monthly_current_currency || 'EUR'
        amount = property.price_rental_monthly_current_cents / 100
        "#{currency} #{number_with_delimiter(amount)}/mo"
      else
        "Price on request"
      end
    end

    def extract_features
      features = property.features.pluck(:feature_key).first(5) rescue []
      features.presence || ['modern', 'well-maintained']
    end

    def listing_url
      website = property.website
      "#{website.primary_url}/properties/#{property.slug}"
    rescue StandardError
      "#"
    end

    def number_with_delimiter(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def parse_response(response)
      content = response.content || response.text || ''

      json_match = content.match(/\{[\s\S]*\}/)
      raise ApiError, "No valid JSON in response" unless json_match

      parsed = JSON.parse(json_match[0])

      {
        caption: sanitize_text(parsed['caption']),
        hashtags: sanitize_text(parsed['hashtags']),
        suggested_photos: parsed['suggested_photos'] || [],
        best_posting_time: parsed['best_posting_time']
      }
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse AI response: #{e.message}"
    end

    def sanitize_text(text)
      return '' if text.blank?

      text.to_s
          .gsub(/```\w*\n?/, '')
          .strip
    end

    def create_social_post(parsed, request)
      Pwb::SocialMediaPost.create!(
        website: property.website,
        ai_generation_request: request,
        postable: property,
        platform: platform.to_s,
        post_type: options[:post_type],
        caption: parsed[:caption],
        hashtags: parsed[:hashtags],
        selected_photos: select_photos(parsed[:suggested_photos]),
        link_url: listing_url,
        status: 'draft'
      )
    end

    def select_photos(suggestions)
      photos = property.prop_photos.ordered.limit(10) rescue []
      return [] if photos.empty?

      photos.first(4).map do |photo|
        {
          id: photo.id,
          url: photo.respond_to?(:optimized_image_url) ? photo.optimized_image_url : nil,
          suggested_crop: aspect_ratio_for_platform
        }
      end
    end

    def aspect_ratio_for_platform
      case platform
      when :instagram
        options[:post_type] == 'story' ? '9:16' : '1:1'
      when :facebook
        '1.91:1'
      when :linkedin
        '1.91:1'
      when :twitter
        '16:9'
      when :tiktok
        '9:16'
      else
        '1:1'
      end
    end
  end
end
