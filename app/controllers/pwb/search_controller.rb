# frozen_string_literal: true

require_dependency "pwb/application_controller"

module Pwb
  class SearchController < ApplicationController
    include SearchUrlHelper
    include SeoHelper
    include Search::PropertyFiltering
    include Search::MapMarkers
    include Search::FormSetup

    before_action :header_image_url
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
      render "/pwb/search/search_ajax", layout: false
    end

    def perform_search(operation_type:, page_slug:)
      @operation_type = operation_type
      config = search_config_for(operation_type)

      setup_page(page_slug)
      @properties = load_properties_for(operation_type).limit(45)
      @prices_from_collection = config[:prices_from]
      @prices_till_collection = config[:prices_till]

      set_common_search_inputs
      set_select_picker_texts
      apply_search_filter(filtering_params(params))
      set_map_markers
      calculate_facets if params[:include_facets] || request.format.html?

      @search_defaults = params[:search].presence || {}

      set_listing_page_seo(
        operation: operation_type,
        location: params.dig(:search, :in_locality),
        page: params[:page].to_i > 0 ? params[:page].to_i : 1
      )

      render "/pwb/search/#{page_slug}"
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
      return unless params[:type].present? || params[:features].present? || params[:state].present?

      friendly_params = parse_friendly_url_params(params)
      params[:search] ||= {}
      friendly_params.each do |key, value|
        params[:search][key] = value if value.present?
      end
    end
  end
end
