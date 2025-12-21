# frozen_string_literal: true

require_dependency "pwb/application_controller"

module Pwb
  class SearchController < ApplicationController
    include SearchUrlHelper
    include SeoHelper

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
    # Map Markers
    # ===================

    def set_map_markers
      @map_markers = @properties.filter_map do |property|
        next unless property.show_map

        {
          id: property.id,
          title: property.title,
          show_url: property.contextual_show_path(@operation_type),
          image_url: property.primary_image_url,
          display_price: property.contextual_price_with_currency(@operation_type),
          position: {
            lat: property.latitude,
            lng: property.longitude
          }
        }
      end
    end

    # ===================
    # Search Filtering
    # ===================

    def filtering_params(params)
      return [] unless params[:search]

      params[:search].slice(
        :in_locality, :in_zone,
        :for_sale_price_from, :for_sale_price_till,
        :for_rent_price_from, :for_rent_price_till,
        :property_type, :property_state,
        :count_bathrooms, :count_bedrooms
      )
    end

    def feature_params
      return {} unless params[:search]
      params[:search].permit(:features_match, features: [])
    end

    def apply_search_filter(search_filtering_params)
      search_filtering_params.each do |key, value|
        next if value.blank? || value == "propertyTypes."

        if price_field?(key)
          value = convert_price_to_cents(value)
        end

        @properties = @properties.public_send(key, value) if value.present?
      end

      apply_feature_filters
    end

    def price_field?(key)
      %w[for_sale_price_from for_sale_price_till for_rent_price_from for_rent_price_till].include?(key.to_s)
    end

    def convert_price_to_cents(value)
      currency_string = @current_website.default_currency || "usd"
      currency = Money::Currency.find(currency_string)
      value.gsub(/\D/, "").to_i * currency.subunit_to_unit
    end

    def apply_feature_filters
      fp = feature_params
      return if fp[:features].blank?

      feature_keys = parse_feature_keys(fp[:features])
      return if feature_keys.empty?

      @properties = if fp[:features_match] == 'any'
                      @properties.with_any_features(feature_keys)
                    else
                      @properties.with_features(feature_keys)
                    end
    end

    def parse_feature_keys(features_param)
      case features_param
      when String then features_param.split(',').map(&:strip).reject(&:blank?)
      when Array then features_param.reject(&:blank?)
      else []
      end
    end

    # ===================
    # Search Form Setup
    # ===================

    def set_select_picker_texts
      @select_picker_texts = {
        noneSelectedText: I18n.t("selectpicker.noneSelectedText"),
        noneResultsText: I18n.t("selectpicker.noneResultsText"),
        countSelectedText: I18n.t("selectpicker.countSelectedText")
      }.to_json
    end

    def set_common_search_inputs
      @property_types = FieldKey.get_options_by_tag("property-types")
      @property_types.unshift OpenStruct.new(value: "", label: "")
      @property_states = FieldKey.get_options_by_tag("property-states")
      @property_features = FieldKey.get_options_by_tag("property-features")
      @property_amenities = FieldKey.get_options_by_tag("property-amenities")
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

    # ===================
    # Header Image
    # ===================

    def header_image_url
      lc_photo = ContentPhoto.find_by_block_key("landing_img")
      @header_image_url = lc_photo.present? ? lc_photo.optimized_image_url : nil
    end
  end
end
