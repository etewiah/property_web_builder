# frozen_string_literal: true

module Pwb
  # Builds field schemas for API responses, providing rich metadata
  # for client-side editors including type information, validation rules,
  # UI hints, and content guidance.
  #
  # @example Building a field definition
  #   FieldSchemaBuilder.build_field_definition(:title, {
  #     type: :text,
  #     label: 'Page Title',
  #     required: true,
  #     max_length: 80
  #   })
  #
  class FieldSchemaBuilder
    # Field type definitions with component mapping and default configurations
    FIELD_TYPES = {
      # Text Types
      text: {
        component: 'TextInput',
        description: 'Single-line text input',
        default_validation: { max_length: 255 }
      },
      textarea: {
        component: 'TextareaInput',
        description: 'Multi-line plain text',
        default_validation: { max_length: 5000 },
        default_options: { rows: 4 }
      },
      html: {
        component: 'WysiwygEditor',
        description: 'Rich HTML content with formatting',
        default_validation: { max_length: 50_000 },
        default_options: {
          toolbar: %w[bold italic underline link list heading image]
        }
      },
      markdown: {
        component: 'MarkdownEditor',
        description: 'Markdown-formatted text',
        default_validation: { max_length: 50_000 }
      },

      # Numeric Types
      number: {
        component: 'NumberInput',
        description: 'Integer or decimal number',
        default_validation: {},
        default_options: { step: 1 }
      },
      currency: {
        component: 'CurrencyInput',
        description: 'Price with currency formatting',
        default_validation: { min: 0 },
        default_options: { currency_code: 'USD', locale: 'en-US' }
      },
      percentage: {
        component: 'PercentageInput',
        description: 'Percentage value (0-100)',
        default_validation: { min: 0, max: 100 }
      },

      # Contact Types
      email: {
        component: 'EmailInput',
        description: 'Email address',
        default_validation: {
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        }
      },
      phone: {
        component: 'PhoneInput',
        description: 'Phone number',
        default_validation: {}
      },
      url: {
        component: 'UrlInput',
        description: 'Web URL',
        default_validation: {
          pattern: '^(https?://|/).+'
        }
      },

      # Media Types
      image: {
        component: 'ImageInlinePicker',
        description: 'Image URL or upload',
        default_options: {
          accept: %w[image/jpeg image/png image/webp image/gif],
          max_size_mb: 5
        }
      },
      video: {
        component: 'VideoPicker',
        description: 'Video URL (YouTube, Vimeo, etc.)',
        default_options: {
          providers: %w[youtube vimeo]
        }
      },
      file: {
        component: 'FilePicker',
        description: 'File attachment',
        default_options: {
          max_size_mb: 10
        }
      },

      # Selection Types
      select: {
        component: 'SelectInput',
        description: 'Dropdown selection',
        default_options: { allow_empty: true }
      },
      radio: {
        component: 'RadioGroup',
        description: 'Radio button selection'
      },
      checkbox: {
        component: 'CheckboxInput',
        description: 'Boolean toggle'
      },
      boolean: {
        component: 'CheckboxInput',
        description: 'Boolean toggle (alias for checkbox)'
      },
      multi_select: {
        component: 'MultiSelectInput',
        description: 'Multiple selection',
        default_options: { max_selections: nil }
      },

      # Special Types
      icon: {
        component: 'IconPicker',
        description: 'Icon selector',
        default_options: { icon_set: 'lucide' }
      },
      color: {
        component: 'ColorPicker',
        description: 'Color value',
        default_options: { format: 'hex', presets: [] }
      },
      date: {
        component: 'DatePicker',
        description: 'Date selection',
        default_options: { format: 'YYYY-MM-DD' }
      },
      datetime: {
        component: 'DateTimePicker',
        description: 'Date and time selection',
        default_options: { format: 'YYYY-MM-DDTHH:mm' }
      },

      # Complex Types
      social_link: {
        component: 'SocialLinkInput',
        description: 'Social media profile URL',
        default_options: {
          platforms: %w[facebook twitter instagram linkedin youtube tiktok]
        }
      },
      map_embed: {
        component: 'MapEmbedEditor',
        description: 'Embedded map code',
        default_validation: { max_length: 5000 }
      },

      # Array Types
      array: {
        component: 'ArrayEditor',
        description: 'Repeatable list of items',
        default_options: { min_items: 0, max_items: 10 }
      },
      faq_array: {
        component: 'FaqEditor',
        description: 'FAQ items with question/answer pairs',
        default_options: { min_items: 1, max_items: 20 },
        item_schema: {
          question: { type: :text, label: 'Question', required: true },
          answer: { type: :textarea, label: 'Answer', required: true }
        }
      },
      feature_list: {
        component: 'FeatureListEditor',
        description: 'List of features (pipe-delimited or array)',
        default_options: { delimiter: '|', max_items: 20 }
      }
    }.freeze

    # Common content guidance presets
    CONTENT_GUIDANCE_PRESETS = {
      title: {
        recommended_length: '40-60 characters',
        seo_tip: 'Include your primary keyword naturally',
        best_practice: 'Keep it clear and compelling'
      },
      description: {
        recommended_length: '120-160 characters',
        seo_tip: 'This may appear in search results - make it count',
        best_practice: 'Summarize the key message concisely'
      },
      cta_button: {
        recommended_length: '2-5 words',
        best_practice: 'Use action verbs like "Get", "Start", "Discover"'
      },
      image: {
        best_practice: 'Use high-quality images optimized for web',
        seo_tip: 'Provide descriptive alt text for accessibility'
      }
    }.freeze

    class << self
      # Build a complete field definition with all metadata
      #
      # @param field_name [Symbol, String] the field identifier
      # @param config [Hash] field configuration options
      # @return [Hash] complete field definition for API response
      def build_field_definition(field_name, config = {})
        config = config.symbolize_keys if config.respond_to?(:symbolize_keys)
        type = (config[:type] || infer_type(field_name)).to_sym
        type_config = FIELD_TYPES[type] || FIELD_TYPES[:text]

        definition = {
          name: field_name.to_s,
          type: type.to_s,
          label: config[:label] || humanize_field_name(field_name),
          component: config[:component] || type_config[:component]
        }

        # Add optional fields only if present
        definition[:hint] = config[:hint] if config[:hint]
        definition[:placeholder] = config[:placeholder] if config[:placeholder]
        definition[:required] = config[:required] if config.key?(:required)

        # Build validation
        validation = build_validation(config, type_config)
        definition[:validation] = validation if validation.present?

        # Build options
        options = build_options(config, type_config)
        definition[:options] = options if options.present?

        # Add content guidance
        guidance = build_content_guidance(field_name, config, type)
        definition[:content_guidance] = guidance if guidance.present?

        # Add grouping and ordering
        definition[:group] = config[:group] if config[:group]
        definition[:paired_with] = config[:paired_with] if config[:paired_with]
        definition[:order] = config[:order] if config[:order]

        # Add item schema for array types
        if config[:item_schema]
          definition[:item_schema] = build_item_schema(config[:item_schema])
        elsif type_config[:item_schema]
          definition[:item_schema] = build_item_schema(type_config[:item_schema])
        end

        definition
      end

      # Build field definitions for a page part from PagePartLibrary
      #
      # @param page_part_key [String] the page part key
      # @return [Hash] field schema with fields and groups
      def build_for_page_part(page_part_key)
        definition = PagePartLibrary.definition(page_part_key)
        return nil unless definition

        fields_config = definition[:fields]

        # Handle legacy array-based field definitions
        if fields_config.is_a?(Array)
          return build_legacy_schema(fields_config)
        end

        # Handle new hash-based field definitions
        build_modern_schema(fields_config, definition[:field_groups])
      end

      # Infer field type from field name (fallback for legacy definitions)
      #
      # @param field_name [String, Symbol] the field name
      # @return [Symbol] the inferred field type
      def infer_type(field_name)
        name = field_name.to_s.downcase

        # Special array types
        return :faq_array if name == 'faq_items'
        return :feature_list if name.match?(/_(features|amenities)$/) && !name.include?('faq')

        # Image/Media fields
        return :image if name.match?(/_(image|photo|img|avatar|logo|banner|thumbnail|src)$/) ||
                         name.match?(/^(image|photo|background|avatar|logo|banner)(_|$)/) ||
                         name.start_with?('image_', 'photo_')

        # HTML/Rich text
        return :html if name.end_with?('_html') || name == 'content_html'

        # Email
        return :email if name.match?(/_(email|mail)$/) || name == 'email'

        # Phone
        return :phone if name.match?(/_(phone|tel|mobile|fax|telephone)$/) ||
                         %w[phone tel mobile fax].include?(name)

        # Currency
        return :currency if name.match?(/_(price|cost|amount|fee|rate|salary)$/)

        # Number
        return :number if name.match?(/_(count|number|value|qty|quantity|total|year|age|rating|score|order|index|columns|rows)$/)

        # URL
        return :url if name.match?(/_(url|link|href|website)$/) ||
                       %w[url website href].include?(name)

        # Social links
        return :social_link if %w[facebook twitter instagram linkedin youtube tiktok pinterest].include?(name)

        # Color
        return :color if name.match?(/_(color|colour)$/) || name.end_with?('_color', '_colour')

        # Icon
        return :icon if name.match?(/_(icon)$/) || name == 'icon'

        # Select/Choice
        return :select if name.match?(/_(style|type|layout|position|alignment|size|theme|variant|format|mode)$/) ||
                          %w[style layout position alignment size theme variant].include?(name)

        # Boolean
        return :boolean if name.match?(/^(is_|has_|show_|enable_|visible|active|featured|published)/) ||
                           name.match?(/_(enabled|visible|active|featured|published)$/)

        # Date
        return :date if name.match?(/_(date|day)$/) || %w[date start_date end_date].include?(name)

        # Map embed
        return :map_embed if name.match?(/_(map|embed|iframe)$/) || name == 'map_embed'

        # Textarea/Long text
        return :textarea if name.match?(/_(content|description|body|bio|text|summary|excerpt|intro|message|caption|quote|answer|details)$/) ||
                            %w[content description body bio summary excerpt intro message].include?(name)

        # Default
        :text
      end

      private

      def build_validation(config, type_config)
        validation = (type_config[:default_validation] || {}).dup

        # Override with explicit config
        %i[min_length max_length min max step pattern min_items max_items].each do |key|
          validation[key] = config[key] if config.key?(key)
        end

        validation.compact.presence
      end

      def build_options(config, type_config)
        options = (type_config[:default_options] || {}).dup

        # Override with explicit config
        %i[
          choices aspect_ratio recommended_size accept max_size_mb rows
          toolbar icon_set format presets platforms providers delimiter
          allow_empty currency_code locale step
        ].each do |key|
          options[key] = config[key] if config.key?(key)
        end

        # Add default value if specified
        options[:default] = config[:default] if config.key?(:default)

        options.compact.presence
      end

      def build_content_guidance(field_name, config, type)
        guidance = {}

        # Use explicit guidance from config
        if config[:content_guidance]
          guidance.merge!(config[:content_guidance])
        end

        # Add preset guidance based on field name patterns
        preset = detect_guidance_preset(field_name, type)
        if preset && CONTENT_GUIDANCE_PRESETS[preset]
          CONTENT_GUIDANCE_PRESETS[preset].each do |key, value|
            guidance[key] ||= value
          end
        end

        # Add type-specific guidance
        case type
        when :image
          guidance[:best_practice] ||= 'Use high-quality images optimized for web'
        when :html
          guidance[:best_practice] ||= 'Use headings and lists to structure content'
        when :url
          guidance[:best_practice] ||= 'Use relative URLs for internal links (/page) or full URLs for external (https://...)'
        end

        guidance.presence
      end

      def detect_guidance_preset(field_name, type)
        name = field_name.to_s.downcase

        return :title if name.match?(/^(title|heading|headline)$/) || name.end_with?('_title')
        return :description if name.match?(/_(description|summary|excerpt)$/)
        return :cta_button if name.match?(/_(button|cta)_?(text)?$/)
        return :image if type == :image

        nil
      end

      def build_item_schema(schema)
        schema.transform_values do |field_config|
          if field_config.is_a?(Hash)
            build_field_definition(field_config[:name] || 'item', field_config)
          else
            build_field_definition(field_config, {})
          end
        end
      end

      def build_legacy_schema(fields_array)
        {
          fields: fields_array.map do |field_name|
            build_field_definition(field_name, {})
          end,
          groups: []
        }
      end

      def build_modern_schema(fields_hash, field_groups)
        {
          fields: fields_hash.map do |field_name, field_config|
            build_field_definition(field_name, field_config || {})
          end,
          groups: build_field_groups(field_groups)
        }
      end

      def build_field_groups(groups_config)
        return [] unless groups_config

        groups_config.map do |key, config|
          {
            key: key.to_s,
            label: config[:label] || key.to_s.humanize,
            order: config[:order] || 999
          }
        end.sort_by { |g| g[:order] }
      end

      def humanize_field_name(field_name)
        field_name.to_s
                  .gsub(/[_-]/, ' ')
                  .gsub(/(\d+)/, ' \1 ')
                  .squeeze(' ')
                  .strip
                  .split
                  .map(&:capitalize)
                  .join(' ')
      end
    end
  end
end
