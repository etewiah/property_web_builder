# frozen_string_literal: true

module Pwb
  module Site
    # Controller for displaying external property listings from feed providers.
    # Handles search, property details, and similar properties for external feeds.
    class ExternalListingsController < Pwb::ApplicationController
      before_action :ensure_feed_enabled
      before_action :set_listing, only: [:show, :similar]

      # GET /external_listings
      # GET /external_listings/search
      def index
        @search_params = search_params
        @result = external_feed.search(@search_params)
        @filter_options = external_feed.filter_options(locale: I18n.locale)

        respond_to do |format|
          format.html
          format.json { render json: @result.to_h }
        end
      end

      # Alias for index with search semantics
      def search
        index
        render :index unless performed?
      end

      # GET /external_listings/:reference
      def show
        if @listing.nil?
          render "pwb/props/not_found", status: :not_found
          return
        end

        unless @listing.available?
          @status_message = case @listing.status
                            when :sold then t("external_feed.status.sold", default: "This property has been sold")
                            when :rented then t("external_feed.status.rented", default: "This property has been rented")
                            else t("external_feed.status.unavailable", default: "This property is no longer available")
                            end
          render "unavailable", status: :gone
          return
        end

        @similar = external_feed.similar(@listing, limit: 6, locale: I18n.locale)

        respond_to do |format|
          format.html
          format.json { render json: @listing.to_h }
        end
      end

      # GET /external_listings/:reference/similar
      def similar
        if @listing.nil?
          render json: { error: "Property not found" }, status: :not_found
          return
        end

        limit = (params[:limit] || 8).to_i.clamp(1, 20)
        @similar = external_feed.similar(@listing, limit: limit, locale: I18n.locale)

        respond_to do |format|
          format.html { render partial: "similar", locals: { properties: @similar } }
          format.json { render json: @similar.map(&:to_h) }
        end
      end

      # GET /external_listings/locations
      def locations
        @locations = external_feed.locations(locale: I18n.locale)
        render json: @locations
      end

      # GET /external_listings/property_types
      def property_types
        @property_types = external_feed.property_types(locale: I18n.locale)
        render json: @property_types
      end

      # GET /external_listings/filters
      def filters
        @filter_options = external_feed.filter_options(locale: I18n.locale)
        render json: @filter_options
      end

      private

      def ensure_feed_enabled
        unless external_feed.configured?
          redirect_to root_path, alert: t("external_feed.not_configured", default: "External listings are not available")
          return
        end

        unless external_feed.enabled?
          Rails.logger.warn("[ExternalListings] Feed configured but not available for website #{current_website.id}")
          # Still allow access, but results may be empty
        end
      end

      def external_feed
        @external_feed ||= current_website.external_feed
      end

      def set_listing
        @listing = external_feed.find(
          params[:reference],
          locale: I18n.locale,
          listing_type: listing_type_param
        )
      end

      def search_params
        permitted = params.permit(
          :listing_type,
          :location,
          :min_price,
          :max_price,
          :min_bedrooms,
          :max_bedrooms,
          :min_bathrooms,
          :max_bathrooms,
          :min_area,
          :max_area,
          :sort,
          :page,
          :per_page,
          property_types: [],
          features: []
        ).to_h.symbolize_keys

        # Set defaults
        permitted[:locale] = I18n.locale
        permitted[:listing_type] = permitted[:listing_type].present? ? permitted[:listing_type].to_sym : :sale
        permitted[:page] ||= 1

        permitted
      end

      def listing_type_param
        type = params[:listing_type] || params[:type] || "sale"
        type.to_sym
      end
    end
  end
end
