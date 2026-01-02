# frozen_string_literal: true

module Pwb
  # Service for managing search filter configuration.
  # Provides a unified interface for accessing search options that works for
  # both internal listings and external feeds.
  #
  # Configuration is stored in the website's search_config JSON column and
  # deep-merged with sensible defaults.
  #
  # @example Basic usage
  #   config = Pwb::SearchConfig.new(website)
  #   config.price_presets          # => [50000, 100000, 200000, ...]
  #   config.bedroom_options        # => ["Any", 1, 2, 3, 4, 5, "6+"]
  #   config.enabled_filters        # => [[:reference, {...}], [:price, {...}], ...]
  #
  # @example With listing type
  #   config = Pwb::SearchConfig.new(website, listing_type: :rental)
  #   config.price_presets          # => [500, 1000, 1500, ...] (rental prices)
  #
  # @see docs/architecture/SEARCH_OPTIONS_STRATEGY.md
  class SearchConfig
    # Default sale price presets (EUR)
    DEFAULT_SALE_PRESETS = [
      50_000, 100_000, 150_000, 200_000, 300_000, 400_000, 500_000,
      750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000, 5_000_000
    ].freeze

    # Default rental price presets (EUR/month)
    DEFAULT_RENTAL_PRESETS = [
      250, 500, 750, 1_000, 1_250, 1_500, 2_000, 2_500, 3_000, 4_000, 5_000, 7_500, 10_000
    ].freeze

    # Default area presets (sqm)
    DEFAULT_AREA_PRESETS = [
      25, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1_000, 1_500, 2_000
    ].freeze

    # Default bedroom options
    DEFAULT_BEDROOM_OPTIONS = ["Any", 1, 2, 3, 4, 5, "6+"].freeze

    # Default bathroom options
    DEFAULT_BATHROOM_OPTIONS = ["Any", 1, 2, 3, 4, "5+"].freeze

    # Comprehensive defaults - used when website has no custom config
    DEFAULT_CONFIG = {
      filters: {
        reference: {
          enabled: true,
          position: 0,
          input_type: "text"
        },
        price: {
          enabled: true,
          position: 1,
          input_type: "dropdown_with_manual",
          sale: {
            min: 0,
            max: 10_000_000,
            default_min: nil,
            default_max: nil,
            step: 50_000,
            presets: DEFAULT_SALE_PRESETS
          },
          rental: {
            min: 0,
            max: 20_000,
            default_min: nil,
            default_max: nil,
            step: 100,
            presets: DEFAULT_RENTAL_PRESETS
          }
        },
        bedrooms: {
          enabled: true,
          position: 2,
          input_type: "dropdown",
          min: 0,
          max: 10,
          default_min: nil,
          default_max: nil,
          options: DEFAULT_BEDROOM_OPTIONS,
          show_max_filter: false
        },
        bathrooms: {
          enabled: true,
          position: 3,
          input_type: "dropdown",
          min: 0,
          max: 8,
          default_min: nil,
          default_max: nil,
          options: DEFAULT_BATHROOM_OPTIONS,
          show_max_filter: false
        },
        area: {
          enabled: true,
          position: 4,
          input_type: "dropdown_with_manual",
          unit: "sqm",
          min: 0,
          max: 5000,
          default_min: nil,
          default_max: nil,
          step: 25,
          presets: DEFAULT_AREA_PRESETS
        },
        property_type: {
          enabled: true,
          position: 5,
          input_type: "checkbox",
          allow_multiple: true
        },
        location: {
          enabled: true,
          position: 6,
          input_type: "dropdown",
          allow_multiple: false
        },
        features: {
          enabled: false,
          position: 7,
          input_type: "checkbox",
          allow_multiple: true
        }
      },
      display: {
        show_results_map: false,
        map_default_expanded: false,
        results_per_page_options: [12, 24, 48],
        default_results_per_page: 24,
        default_sort: "newest",
        sort_options: %w[price_asc price_desc newest updated],
        show_save_search: true,
        show_favorites: true,
        card_layout: "grid",
        show_active_filters: true
      },
      listing_types: {
        sale: { enabled: true, is_default: true },
        rental: { enabled: true, is_default: false }
      }
    }.freeze

    attr_reader :website, :listing_type

    # Initialize a new SearchConfig instance
    #
    # @param website [Pwb::Website] The website to get configuration for
    # @param listing_type [Symbol, String, nil] The listing type (:sale or :rental)
    def initialize(website, listing_type: nil)
      @website = website
      @listing_type = normalize_listing_type(listing_type)
    end

    # Main configuration accessor - merges website config with defaults
    #
    # @return [Hash] The complete merged configuration
    def config
      @config ||= deep_merge_config(DEFAULT_CONFIG.deep_dup, website_config)
    end

    # Get all enabled filters in display order
    #
    # @return [Array<Array(Symbol, Hash)>] Array of [filter_key, config] pairs
    def enabled_filters
      config[:filters]
        .select { |_, cfg| cfg[:enabled] }
        .sort_by { |_, cfg| cfg[:position] || 999 }
        .map { |key, cfg| [key, cfg] }
    end

    # Get specific filter configuration
    #
    # @param name [Symbol, String] The filter name
    # @return [Hash, nil] The filter configuration
    def filter(name)
      config.dig(:filters, name.to_sym)
    end

    # Check if a specific filter is enabled
    #
    # @param name [Symbol, String] The filter name
    # @return [Boolean]
    def filter_enabled?(name)
      filter(name)&.dig(:enabled) == true
    end

    # ============================================
    # Price Configuration
    # ============================================

    # Price configuration for current listing type
    #
    # @return [Hash] Price configuration
    def price_config
      filter(:price)&.dig(listing_type) || filter(:price)&.dig(:sale) || {}
    end

    # Get price presets for current listing type
    #
    # @return [Array<Integer>]
    def price_presets
      price_config[:presets] || (listing_type == :rental ? DEFAULT_RENTAL_PRESETS : DEFAULT_SALE_PRESETS)
    end

    # Get price input type
    #
    # @return [String] "dropdown", "manual", or "dropdown_with_manual"
    def price_input_type
      filter(:price)&.dig(:input_type) || "dropdown_with_manual"
    end

    # Get default min price
    #
    # @return [Integer, nil]
    def default_min_price
      price_config[:default_min]
    end

    # Get default max price
    #
    # @return [Integer, nil]
    def default_max_price
      price_config[:default_max]
    end

    # Get price step for manual input
    #
    # @return [Integer]
    def price_step
      price_config[:step] || (listing_type == :rental ? 100 : 50_000)
    end

    # Get min allowed price
    #
    # @return [Integer]
    def min_price
      price_config[:min] || 0
    end

    # Get max allowed price
    #
    # @return [Integer]
    def max_price
      price_config[:max] || (listing_type == :rental ? 20_000 : 10_000_000)
    end

    # ============================================
    # Bedroom/Bathroom Configuration
    # ============================================

    # Get bedroom options for dropdowns
    #
    # @return [Array]
    def bedroom_options
      filter(:bedrooms)&.dig(:options) || DEFAULT_BEDROOM_OPTIONS.dup
    end

    # Get bathroom options for dropdowns
    #
    # @return [Array]
    def bathroom_options
      filter(:bathrooms)&.dig(:options) || DEFAULT_BATHROOM_OPTIONS.dup
    end

    # Get default min bedrooms
    #
    # @return [Integer, nil]
    def default_min_bedrooms
      filter(:bedrooms)&.dig(:default_min)
    end

    # Get default min bathrooms
    #
    # @return [Integer, nil]
    def default_min_bathrooms
      filter(:bathrooms)&.dig(:default_min)
    end

    # Check if max bedroom filter should be shown
    #
    # @return [Boolean]
    def show_max_bedrooms?
      filter(:bedrooms)&.dig(:show_max_filter) == true
    end

    # Check if max bathroom filter should be shown
    #
    # @return [Boolean]
    def show_max_bathrooms?
      filter(:bathrooms)&.dig(:show_max_filter) == true
    end

    # ============================================
    # Area Configuration
    # ============================================

    # Get area presets
    #
    # @return [Array<Integer>]
    def area_presets
      filter(:area)&.dig(:presets) || DEFAULT_AREA_PRESETS.dup
    end

    # Get area unit
    #
    # @return [String] "sqm" or "sqft"
    def area_unit
      filter(:area)&.dig(:unit) || "sqm"
    end

    # Get area input type
    #
    # @return [String]
    def area_input_type
      filter(:area)&.dig(:input_type) || "dropdown_with_manual"
    end

    # Get default min area
    #
    # @return [Integer, nil]
    def default_min_area
      filter(:area)&.dig(:default_min)
    end

    # Get default max area
    #
    # @return [Integer, nil]
    def default_max_area
      filter(:area)&.dig(:default_max)
    end

    # ============================================
    # Display Configuration
    # ============================================

    # Check if results map should be shown
    #
    # @return [Boolean]
    def show_map?
      config.dig(:display, :show_results_map) == true
    end

    # Check if map should be expanded by default
    #
    # @return [Boolean]
    def map_default_expanded?
      config.dig(:display, :map_default_expanded) == true
    end

    # Get default sort option
    #
    # @return [String]
    def default_sort
      config.dig(:display, :default_sort) || "newest"
    end

    # Get available sort options
    #
    # @return [Array<String>]
    def sort_options
      config.dig(:display, :sort_options) || %w[price_asc price_desc newest updated]
    end

    # Get results per page options
    #
    # @return [Array<Integer>]
    def results_per_page_options
      config.dig(:display, :results_per_page_options) || [12, 24, 48]
    end

    # Get default results per page
    #
    # @return [Integer]
    def default_results_per_page
      config.dig(:display, :default_results_per_page) || 24
    end

    # Check if active filters should be shown
    #
    # @return [Boolean]
    def show_active_filters?
      config.dig(:display, :show_active_filters) != false
    end

    # Check if save search should be shown
    #
    # @return [Boolean]
    def show_save_search?
      config.dig(:display, :show_save_search) != false
    end

    # Check if favorites should be shown
    #
    # @return [Boolean]
    def show_favorites?
      config.dig(:display, :show_favorites) != false
    end

    # Get card layout type
    #
    # @return [String] "grid" or "list"
    def card_layout
      config.dig(:display, :card_layout) || "grid"
    end

    # ============================================
    # Listing Type Configuration
    # ============================================

    # Get enabled listing types
    #
    # @return [Array<Symbol>]
    def enabled_listing_types
      config[:listing_types]
        .select { |_, cfg| cfg[:enabled] }
        .keys
    end

    # Get the default listing type
    #
    # @return [Symbol]
    def default_listing_type
      config[:listing_types]
        .find { |_, cfg| cfg[:is_default] }
        &.first || :sale
    end

    # Check if a listing type is enabled
    #
    # @param type [Symbol, String] The listing type
    # @return [Boolean]
    def listing_type_enabled?(type)
      config.dig(:listing_types, type.to_sym, :enabled) == true
    end

    # ============================================
    # View Helpers
    # ============================================

    # Generate filter options hash for views
    # This provides all the data needed to render the search form
    #
    # @return [Hash]
    def filter_options_for_view
      {
        filters: enabled_filters.to_h,
        price: price_config,
        price_presets: price_presets,
        price_input_type: price_input_type,
        default_min_price: default_min_price,
        default_max_price: default_max_price,
        bedroom_options: bedroom_options,
        bathroom_options: bathroom_options,
        default_min_bedrooms: default_min_bedrooms,
        default_min_bathrooms: default_min_bathrooms,
        area_presets: area_presets,
        area_unit: area_unit,
        listing_types: enabled_listing_types,
        default_listing_type: default_listing_type,
        sort_options: sort_options_for_view,
        default_sort: default_sort,
        results_per_page_options: results_per_page_options,
        default_results_per_page: default_results_per_page,
        display: config[:display]
      }
    end

    # Get sort options formatted for select dropdown
    #
    # @return [Array<Hash>] Array of {value:, label:} hashes
    def sort_options_for_view
      sort_options.map do |opt|
        {
          value: opt,
          label: I18n.t("external_feed.sort.#{opt}", default: opt.titleize)
        }
      end
    end

    # Get listing types formatted for radio buttons/tabs
    #
    # @return [Array<Hash>] Array of {value:, label:, is_default:} hashes
    def listing_types_for_view
      enabled_listing_types.map do |type|
        type_config = config.dig(:listing_types, type)
        {
          value: type.to_s,
          label: I18n.t("external_feed.listing_types.#{type}", default: type.to_s.titleize),
          is_default: type_config[:is_default] == true
        }
      end
    end

    # Get bedroom options formatted for select dropdown
    #
    # @return [Array<Hash>] Array of {value:, label:} hashes
    def bedroom_options_for_view
      options = bedroom_options.map do |opt|
        if opt == "Any"
          { value: "", label: I18n.t("search.any", default: "Any") }
        elsif opt.is_a?(String) && opt.include?("+")
          { value: opt.gsub("+", ""), label: opt }
        else
          { value: opt.to_s, label: "#{opt}+" }
        end
      end
      options
    end

    # Get bathroom options formatted for select dropdown
    #
    # @return [Array<Hash>] Array of {value:, label:} hashes
    def bathroom_options_for_view
      bathroom_options.map do |opt|
        if opt == "Any"
          { value: "", label: I18n.t("search.any", default: "Any") }
        elsif opt.is_a?(String) && opt.include?("+")
          { value: opt.gsub("+", ""), label: opt }
        else
          { value: opt.to_s, label: "#{opt}+" }
        end
      end
    end

    private

    # Get website-specific configuration
    #
    # @return [Hash]
    def website_config
      (website.search_config || {}).deep_symbolize_keys
    end

    # Normalize listing type to symbol
    #
    # @param type [Symbol, String, nil]
    # @return [Symbol]
    def normalize_listing_type(type)
      return :sale if type.blank?

      type_sym = type.to_s.downcase.to_sym
      # Handle common aliases
      case type_sym
      when :for_sale, :buy, :sale
        :sale
      when :for_rent, :rent, :rental
        :rental
      else
        type_sym
      end
    end

    # Deep merge configurations, preferring custom values over defaults
    # but keeping default values when custom is nil
    #
    # @param default [Hash] Default configuration
    # @param custom [Hash] Custom configuration to merge
    # @return [Hash] Merged configuration
    def deep_merge_config(default, custom)
      default.deep_merge(custom) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_config(old_val, new_val)
        elsif new_val.nil?
          old_val
        else
          new_val
        end
      end
    end
  end
end
