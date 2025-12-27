# frozen_string_literal: true

require_dependency "pwb/application_controller"

module Pwb
  class SearchController < ApplicationController
    include Pagy::Method
    include SearchUrlHelper
    include SeoHelper
    include Search::PropertyFiltering
    include Search::MapMarkers
    include Search::FormSetup
    include HttpCacheable

    before_action :header_image_url
    before_action :setup_search_params_service
    before_action :normalize_url_params

    # ===================
    # Search Actions
    # ===================

    def search_ajax_for_sale
      perform_ajax_search(operation_type: "for_sale")
    end

    def search_ajax_for_rent
      perform_ajax_search(operation_type: "for_rent")
    end

    def buy
      perform_search(operation_type: "for_sale", page_slug: "buy")
    end

    def rent
      perform_search(operation_type: "for_rent", page_slug: "rent")
    end

    private

    # ===================
    # Unified Search Logic
    # ===================

    def perform_ajax_search(operation_type:)
      @operation_type = operation_type
      @properties = load_properties_for(operation_type)
      apply_search_filter(filtering_params(params))
      set_map_markers

      respond_to do |format|
        format.js { render "/pwb/search/search_ajax", layout: false }
        format.json { render_search_json }
      end
    end

    def perform_search(operation_type:, page_slug:)
      @operation_type = operation_type
      @page_slug = page_slug
      config = search_config_for(operation_type)

      setup_page(page_slug)
      
      # Apply pagination
      page_number = [@search_criteria[:page].to_i, 1].max
      per_page = 24

      @properties = load_properties_for(operation_type)
      @prices_from_collection = config[:prices_from]
      @prices_till_collection = config[:prices_till]

      set_common_search_inputs
      set_select_picker_texts
      apply_search_filter(filtering_params(params))
      apply_sorting
      set_map_markers
      calculate_facets if turbo_frame_request? || request.format.html?

      # Paginate results with Pagy
      @pagy, @properties = pagy(@properties, items: per_page, page: page_number)

      @search_defaults = params[:search].presence || {}
      @search_criteria_for_view = @search_criteria

      set_listing_page_seo(
        operation: operation_type,
        location: params.dig(:search, :in_locality),
        page: page_number
      )

      # Set canonical URL
      @canonical_url = @search_params_service.canonical_url(
        @search_criteria,
        locale: I18n.locale,
        operation: page_slug
      )

      # Set cache headers for search pages
      # Longer cache for unfiltered results, shorter for filtered
      cache_duration = params[:search].blank? ? 10.minutes : 2.minutes
      set_cache_control_headers(
        max_age: cache_duration,
        public: true,
        stale_while_revalidate: 1.hour
      )

      respond_to do |format|
        format.html do
          if turbo_frame_request?
            render partial: "pwb/search/search_results_frame", layout: false
          else
            render "/pwb/search/#{page_slug}"
          end
        end
        format.json { render_search_json }
      end
    end

    # ===================
    # Sorting
    # ===================

    def apply_sorting
      return unless @search_criteria[:sort].present?

      case @search_criteria[:sort]
      when 'price-asc'
        @properties = @properties.order(price_sale_current_cents: :asc, price_rental_monthly_current_cents: :asc)
      when 'price-desc'
        @properties = @properties.order(price_sale_current_cents: :desc, price_rental_monthly_current_cents: :desc)
      when 'newest'
        @properties = @properties.order(created_at: :desc)
      when 'oldest'
        @properties = @properties.order(created_at: :asc)
      end
    end

    # ===================
    # JSON Response
    # ===================

    def render_search_json
      render json: {
        html: render_to_string(partial: 'pwb/search/search_results', formats: [:html]),
        markers: @map_markers,
        facets: @facets,
        total_count: @pagy&.count || @properties.count,
        current_page: @pagy&.page || 1,
        total_pages: @pagy&.pages || 1
      }
    end

    # ===================
    # Configuration
    # ===================

    def search_config_for(operation_type)
      if operation_type == "for_rent"
        {
          prices_from: @current_website.rent_price_options_from,
          prices_till: @current_website.rent_price_options_till
        }
      else
        {
          prices_from: @current_website.sale_price_options_from,
          prices_till: @current_website.sale_price_options_till
        }
      end
    end

    def load_properties_for(operation_type)
      scope = @current_website.listed_properties.with_eager_loading.visible
      operation_type == "for_rent" ? scope.for_rent : scope.for_sale
    end

    def setup_page(page_slug)
      @page = @current_website.pages.find_by_slug(page_slug)
      @page_title = @current_agency.company_name

      if @page.present? && @page.page_title.present?
        @page_title = "#{@page.page_title} - #{@current_agency.company_name}"
      end
    end

    # ===================
    # Search Params Service
    # ===================

    def setup_search_params_service
      @search_params_service = SearchParamsService.new
      @search_criteria = @search_params_service.from_url_params(params)
    end

    # ===================
    # Faceted Search
    # ===================

    def calculate_facets
      cache_key = facets_cache_key

      @facets = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        base_scope = load_properties_for(@operation_type)

        SearchFacetsService.calculate(
          scope: base_scope,
          website: @current_website,
          operation_type: @operation_type
        )
      end
    end

    def facets_cache_key
      [
        "search_facets",
        @current_website.id,
        @operation_type,
        I18n.locale,
        @current_website.updated_at.to_i
      ].join("/")
    end

    # ===================
    # URL Normalization
    # ===================

    def normalize_url_params
      # Convert new URL format to legacy search params format for compatibility
      params[:search] ||= {}

      # Map new format params to legacy format
      if @search_criteria.present?
        map_criteria_to_search_params
      end

      # Also handle direct friendly params (backwards compatibility)
      if params[:type].present? || params[:features].present? || params[:state].present?
        friendly_params = parse_friendly_url_params(params)
        friendly_params.each do |key, value|
          params[:search][key] = value if value.present?
        end
      end
    end

    def map_criteria_to_search_params
      return unless @search_criteria

      # Property type
      if @search_criteria[:property_type].present?
        params[:search][:property_type] = @search_criteria[:property_type]
      end

      # Bedrooms/Bathrooms
      params[:search][:count_bedrooms] = @search_criteria[:bedrooms] if @search_criteria[:bedrooms]
      params[:search][:count_bathrooms] = @search_criteria[:bathrooms] if @search_criteria[:bathrooms]

      # Price - only set the filter matching the current operation to avoid
      # filtering by both sale AND rental prices (which would return no results)
      is_rental = action_name == 'rent' || action_name == 'search_ajax_for_rent'

      if @search_criteria[:price_min]
        if is_rental
          params[:search][:for_rent_price_from] = @search_criteria[:price_min]
        else
          params[:search][:for_sale_price_from] = @search_criteria[:price_min]
        end
      end

      if @search_criteria[:price_max]
        if is_rental
          params[:search][:for_rent_price_till] = @search_criteria[:price_max]
        else
          params[:search][:for_sale_price_till] = @search_criteria[:price_max]
        end
      end

      # Location
      params[:search][:in_zone] = @search_criteria[:zone] if @search_criteria[:zone]
      params[:search][:in_locality] = @search_criteria[:locality] if @search_criteria[:locality]

      # Features
      if @search_criteria[:features].present?
        params[:search][:features] = @search_criteria[:features]
      end
    end

    # ===================
    # Turbo Frame Detection
    # ===================

    def turbo_frame_request?
      request.headers["Turbo-Frame"].present?
    end
  end
end
