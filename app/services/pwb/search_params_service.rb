# frozen_string_literal: true

module Pwb
  # Service to handle URL parameter parsing and generation for property search.
  #
  # This service provides a clean, consistent interface for:
  # - Parsing URL query parameters into search criteria
  # - Generating clean URL query strings from search criteria
  # - Creating canonical URLs for SEO
  #
  # URL Format Examples:
  #   /en/buy?type=apartment&bedrooms=2&price_min=100000
  #   /en/rent?features=pool,garden&sort=price-asc&view=grid
  #
  class SearchParamsService
    VALID_SORTS = %w[price-asc price-desc newest oldest].freeze
    VALID_VIEWS = %w[grid list map].freeze

    # Parameter mapping: URL param name => internal criteria key
    PARAM_MAPPING = {
      'type' => :property_type,
      'bedrooms' => :bedrooms,
      'bathrooms' => :bathrooms,
      'price_min' => :price_min,
      'price_max' => :price_max,
      'features' => :features,
      'zone' => :zone,
      'locality' => :locality,
      'sort' => :sort,
      'view' => :view,
      'page' => :page
    }.freeze

    # Reverse mapping for URL generation
    CRITERIA_TO_PARAM = PARAM_MAPPING.invert.freeze

    # Parse URL parameters into search criteria hash
    #
    # @param params [ActionController::Parameters] URL query parameters
    # @return [Hash] Normalized search criteria
    def from_url_params(params)
      criteria = {}

      # Handle new format parameters
      parse_type(params, criteria)
      parse_numeric_params(params, criteria)
      parse_features(params, criteria)
      parse_location_params(params, criteria)
      parse_sort(params, criteria)
      parse_view(params, criteria)
      parse_page(params, criteria)

      # Handle legacy format (search[param]) as fallback
      if params[:search].present?
        parse_legacy_params(params[:search], criteria)
      end

      criteria.compact
    end

    # Generate URL query string from search criteria
    #
    # @param criteria [Hash] Search criteria
    # @return [String] URL query string (without leading ?)
    def to_url_params(criteria)
      params = {}

      criteria.each do |key, value|
        next if value.nil? || value == '' || (value.is_a?(Array) && value.empty?)

        url_key = CRITERIA_TO_PARAM[key] || key.to_s
        
        case key
        when :features
          # Sort features alphabetically and join with comma
          params[url_key] = Array(value).map(&:to_s).sort.join(',')
        when :property_type
          params['type'] = value.to_s
        else
          params[url_key] = value.to_s
        end
      end

      # Sort params alphabetically for consistent URLs
      params.sort.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    end

    # Generate canonical URL for SEO
    #
    # @param criteria [Hash] Search criteria
    # @param locale [Symbol] Locale (e.g., :en, :es)
    # @param operation [Symbol] Operation type (e.g., :buy, :rent, :comprar)
    # @param host [String, nil] Optional host for full URL
    # @return [String] Canonical URL path or full URL
    def canonical_url(criteria, locale:, operation:, host: nil)
      # Remove page=1 from canonical URL
      clean_criteria = criteria.reject { |k, v| k == :page && v.to_i <= 1 }
      
      query_string = to_url_params(clean_criteria)
      path = "/#{locale}/#{operation}"
      path += "?#{query_string}" if query_string.present?

      if host
        "https://#{host}#{path}"
      else
        path
      end
    end

    private

    def parse_type(params, criteria)
      return unless params[:type].present?

      criteria[:property_type] = normalize_slug(params[:type])
    end

    def parse_numeric_params(params, criteria)
      %i[bedrooms bathrooms price_min price_max].each do |param|
        value = params[param]
        next unless value.present?

        parsed = value.to_s.gsub(/[^\d]/, '').to_i
        criteria[param] = parsed if parsed > 0
      end
    end

    def parse_features(params, criteria)
      return unless params[:features].present?

      features = params[:features].to_s.split(',').map { |f| normalize_slug(f) }.compact
      criteria[:features] = features if features.any?
    end

    def parse_location_params(params, criteria)
      criteria[:zone] = normalize_slug(params[:zone]) if params[:zone].present?
      criteria[:locality] = normalize_slug(params[:locality]) if params[:locality].present?
    end

    def parse_sort(params, criteria)
      return unless params[:sort].present?

      sort = params[:sort].to_s.downcase
      criteria[:sort] = sort if VALID_SORTS.include?(sort)
    end

    def parse_view(params, criteria)
      return unless params[:view].present?

      view = params[:view].to_s.downcase
      criteria[:view] = view if VALID_VIEWS.include?(view)
    end

    def parse_page(params, criteria)
      return unless params[:page].present?

      page = params[:page].to_s.to_i
      criteria[:page] = page if page > 0
    end

    def parse_legacy_params(search_params, criteria)
      # Only fill in values not already set by new format
      if search_params[:property_type].present? && criteria[:property_type].nil?
        criteria[:property_type] = normalize_slug(search_params[:property_type])
      end

      if search_params[:count_bedrooms].present? && criteria[:bedrooms].nil?
        criteria[:bedrooms] = search_params[:count_bedrooms].to_i
      end

      if search_params[:count_bathrooms].present? && criteria[:bathrooms].nil?
        criteria[:bathrooms] = search_params[:count_bathrooms].to_i
      end

      # Legacy price format
      if search_params[:for_sale_price_from].present? && criteria[:price_min].nil?
        criteria[:price_min] = search_params[:for_sale_price_from].to_i
      end

      if search_params[:for_sale_price_till].present? && criteria[:price_max].nil?
        criteria[:price_max] = search_params[:for_sale_price_till].to_i
      end

      # Legacy features format
      if search_params[:features].present? && criteria[:features].nil?
        features = Array(search_params[:features]).map { |f| normalize_slug(f) }.compact
        criteria[:features] = features if features.any?
      end
    end

    def normalize_slug(value)
      return nil if value.blank?

      value.to_s
           .downcase
           .strip
           .gsub(/\s+/, '-')
           .gsub(/[^a-z0-9\-]/, '')
    end
  end
end
