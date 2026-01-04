# frozen_string_literal: true

module Pwb
  # SearchFilterOption manages property types, features, and other search filter options.
  #
  # This model provides a unified way to manage all filter options that appear in search forms,
  # supporting both internal listings and external feed integrations.
  #
  # @example Creating a property type
  #   SearchFilterOption.create!(
  #     website: website,
  #     filter_type: 'property_type',
  #     global_key: 'apartment',
  #     external_code: '1-1',
  #     translations: { 'en' => 'Apartment', 'es' => 'Apartamento' }
  #   )
  #
  # @example Getting options for search form
  #   SearchFilterOption.property_types.visible.show_in_search.ordered
  #
  # @example Mapping to external provider
  #   option.external_mapping_for('resales_online') # => "1-1"
  #
  class SearchFilterOption < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_search_filter_options'

    # Filter type constants
    PROPERTY_TYPE = 'property_type'
    FEATURE = 'feature'
    AMENITY = 'amenity'
    LOCATION = 'location'

    FILTER_TYPES = [PROPERTY_TYPE, FEATURE, AMENITY, LOCATION].freeze

    # Associations
    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :parent, class_name: 'Pwb::SearchFilterOption', optional: true
    has_many :children, class_name: 'Pwb::SearchFilterOption', foreign_key: :parent_id, dependent: :nullify

    # Translatable attribute using Mobility (uses container backend from config)
    # Stores in the 'translations' JSONB column
    translates :label

    # Validations
    validates :filter_type, presence: true, inclusion: { in: FILTER_TYPES }
    validates :global_key, presence: true,
                           uniqueness: { scope: %i[website_id filter_type] },
                           format: { with: /\A[a-z0-9_-]+\z/, message: 'only allows lowercase letters, numbers, hyphens, and underscores' }

    # Scopes by filter type
    scope :property_types, -> { where(filter_type: PROPERTY_TYPE) }
    scope :features, -> { where(filter_type: FEATURE) }
    scope :amenities, -> { where(filter_type: AMENITY) }
    scope :locations, -> { where(filter_type: LOCATION) }

    # Visibility scopes
    scope :visible, -> { where(visible: true) }
    scope :show_in_search, -> { where(show_in_search: true) }
    scope :hidden, -> { where(visible: false) }

    # Ordering
    scope :ordered, -> { order(:sort_order, :created_at) }

    # Hierarchy scopes
    scope :roots, -> { where(parent_id: nil) }
    scope :with_children, -> { includes(:children) }

    # External code scopes
    scope :with_external_code, -> { where.not(external_code: nil) }
    scope :by_external_code, ->(code) { where(external_code: code) }

    # Callbacks
    before_validation :generate_global_key, if: -> { global_key.blank? && translations.present? }

    # Get the display label for the current locale
    #
    # @return [String] The localized label or global_key as fallback
    def display_label
      label.presence || translations_label || global_key.to_s.titleize
    end

    # Get label from translations JSONB for current locale
    #
    # @return [String, nil]
    def translations_label
      locale = I18n.locale.to_s
      translations.dig(locale) || translations.dig('en') || translations.values.first
    end

    # Set label in translations for a specific locale
    #
    # @param locale [String, Symbol] The locale
    # @param value [String] The label value
    def set_translation(locale, value)
      self.translations = translations.merge(locale.to_s => value)
    end

    # Get external mapping for a specific provider
    #
    # @param provider [String, Symbol] The provider name
    # @return [String, nil] The external code for this provider
    def external_mapping_for(provider)
      # First check explicit mappings in metadata
      mapping = metadata.dig('external_mappings', provider.to_s)
      return mapping if mapping.present?

      # Fall back to the primary external_code
      external_code
    end

    # Set external mapping for a specific provider
    #
    # @param provider [String, Symbol] The provider name
    # @param code [String] The external code
    def set_external_mapping(provider, code)
      self.metadata = metadata.deep_merge('external_mappings' => { provider.to_s => code })
    end

    # Check if this option has an external mapping
    #
    # @param provider [String, Symbol, nil] Optional specific provider to check
    # @return [Boolean]
    def has_external_mapping?(provider = nil)
      if provider
        external_mapping_for(provider).present?
      else
        external_code.present? || metadata.dig('external_mappings').present?
      end
    end

    # Get the feature param name for external API (features only)
    #
    # @return [String, nil]
    def feature_param_name
      return nil unless filter_type == FEATURE

      metadata['param_name']
    end

    # Set the feature param name for external API
    #
    # @param name [String] The API param name (e.g., 'p_Pool')
    def feature_param_name=(name)
      self.metadata = metadata.merge('param_name' => name)
    end

    # Get the category for this option
    #
    # @return [String, nil]
    def category
      metadata['category']
    end

    # Set the category
    #
    # @param value [String] The category name
    def category=(value)
      self.metadata = metadata.merge('category' => value)
    end

    # Check if this is a root option (no parent)
    #
    # @return [Boolean]
    def root?
      parent_id.nil?
    end

    # Get all ancestors
    #
    # @return [Array<SearchFilterOption>]
    def ancestors
      result = []
      current = parent
      while current
        result.unshift(current)
        current = current.parent
      end
      result
    end

    # Get all descendants
    #
    # @return [Array<SearchFilterOption>]
    def descendants
      result = []
      children.each do |child|
        result << child
        result.concat(child.descendants)
      end
      result
    end

    # Build options array for select dropdowns
    #
    # @return [Hash] { value: global_key, label: display_label }
    def to_option
      {
        value: global_key,
        label: display_label,
        external_code: external_code,
        icon: icon
      }.compact
    end

    # Class methods for bulk operations
    class << self
      # Get all options formatted for a search form select/checkbox
      #
      # @return [Array<Hash>]
      def to_options
        ordered.map(&:to_option)
      end

      # Find by external code for a provider
      #
      # @param code [String] The external code
      # @param provider [String, nil] Optional provider name
      # @return [SearchFilterOption, nil]
      def find_by_external_code(code, provider: nil)
        if provider
          # Check metadata mappings first
          found = where("metadata->'external_mappings'->>? = ?", provider.to_s, code).first
          return found if found
        end

        # Fall back to primary external_code
        by_external_code(code).first
      end

      # Import options from an array of hashes
      #
      # @param website [Website] The website to import for
      # @param filter_type [String] The filter type
      # @param options [Array<Hash>] Options with :value, :label, :external_code, etc.
      # @return [Array<SearchFilterOption>] Created options
      def import_options(website:, filter_type:, options:)
        options.map.with_index do |opt, index|
          find_or_create_by!(
            website: website,
            filter_type: filter_type,
            global_key: opt[:value] || opt[:global_key]
          ) do |record|
            record.external_code = opt[:external_code] || opt[:value]
            record.translations = { I18n.locale.to_s => opt[:label] }
            record.sort_order = opt[:sort_order] || index
            record.icon = opt[:icon]
          end
        end
      end
    end

    private

    # Generate a URL-safe global_key from the English translation
    def generate_global_key
      source = translations['en'] || translations.values.first
      return unless source.present?

      self.global_key = source.to_s
                              .downcase
                              .gsub(/[^a-z0-9\s-]/, '')
                              .gsub(/\s+/, '-').squeeze('-')
                              .truncate(50, omission: '')
    end
  end
end
