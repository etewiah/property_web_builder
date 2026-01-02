# frozen_string_literal: true

module Pwb
  module Site
    # Controller for displaying external property listings from feed providers.
    # Handles search, property details, and similar properties for external feeds.
    class ExternalListingsController < Pwb::ApplicationController
      include SeoHelper
      include HttpCacheable
      include CacheHelper

      before_action :ensure_feed_enabled
      before_action :set_listing, only: [:show, :show_for_sale, :show_for_rent, :similar, :legacy_show]

      # GET /external/buy - Properties for sale
      def buy
        @listing_type = :sale
        perform_index_search(:sale)
      end

      # GET /external/rent - Properties for rent
      def rent
        @listing_type = :rental
        perform_index_search(:rental)
      end

      # GET /external/for-sale/:reference/:url_friendly_title
      def show_for_sale
        @listing_type = :sale
        perform_show
      end

      # GET /external/for-rent/:reference/:url_friendly_title
      def show_for_rent
        @listing_type = :rental
        perform_show
      end

      # Legacy redirect: GET /external_listings and /external_listings/search
      def legacy_index
        listing_type = params[:listing_type]&.to_sym
        redirect_path = listing_type == :rental ? external_rent_path : external_buy_path

        # Preserve search params
        redirect_params = params.permit(
          :location, :min_price, :max_price, :min_bedrooms, :max_bedrooms,
          :min_bathrooms, :max_bathrooms, :min_area, :max_area, :sort, :page,
          property_types: [], features: []
        ).to_h.reject { |_, v| v.blank? }

        redirect_to "#{redirect_path}?#{redirect_params.to_query}".chomp("?"), status: :moved_permanently
      end

      # Legacy redirect: GET /external_listings/:reference
      def legacy_show
        set_listing
        if @listing.nil?
          render "pwb/props/not_found", status: :not_found
          return
        end

        # Redirect to new URL pattern
        new_path = if @listing.listing_type == :rental
                     external_show_for_rent_path(
                       reference: @listing.reference,
                       url_friendly_title: url_friendly_title(@listing)
                     )
                   else
                     external_show_for_sale_path(
                       reference: @listing.reference,
                       url_friendly_title: url_friendly_title(@listing)
                     )
                   end
        redirect_to new_path, status: :moved_permanently
      end

      # GET /external_listings (kept for backward compatibility, redirects to new URL)
      # GET /external_listings/search
      def index
        @search_params = search_params
        @result = external_feed.search(@search_params)
        @filter_options = external_feed.filter_options(locale: I18n.locale)

        # Setup search config for consistent filter options across the site
        listing_type = @search_params[:listing_type] == :rental ? :rental : :sale
        @search_config = Pwb::SearchConfig.new(current_website, listing_type: listing_type)

        # SEO setup
        set_external_listings_seo

        # HTTP caching - longer cache for unfiltered results
        cache_duration = has_active_filters? ? 2.minutes : 10.minutes
        set_cache_control_headers(
          max_age: cache_duration,
          public: true,
          stale_while_revalidate: 1.hour
        )

        respond_to do |format|
          format.html do
            if turbo_frame_request?
              render partial: "search_results_frame", layout: false
            else
              render :index
            end
          end
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

        # SEO for property detail page
        set_external_listing_detail_seo

        # HTTP caching for property details
        set_cache_control_headers(
          max_age: 15.minutes,
          public: true,
          stale_while_revalidate: 1.hour
        )

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

      # Shared logic for buy/rent index pages
      def perform_index_search(listing_type)
        @search_params = search_params.merge(listing_type: listing_type)
        @result = external_feed.search(@search_params)
        @filter_options = external_feed.filter_options(locale: I18n.locale)

        # Setup search config for consistent filter options across the site
        @search_config = Pwb::SearchConfig.new(current_website, listing_type: listing_type)

        # SEO setup
        set_external_listings_seo

        # HTTP caching - longer cache for unfiltered results
        cache_duration = has_active_filters? ? 2.minutes : 10.minutes
        set_cache_control_headers(
          max_age: cache_duration,
          public: true,
          stale_while_revalidate: 1.hour
        )

        respond_to do |format|
          format.html do
            if turbo_frame_request?
              render partial: "search_results_frame", layout: false
            else
              render :index
            end
          end
          format.json { render json: @result.to_h }
        end
      end

      # Shared logic for show_for_sale/show_for_rent pages
      def perform_show
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

        # SEO for property detail page
        set_external_listing_detail_seo

        # HTTP caching for property details
        set_cache_control_headers(
          max_age: 15.minutes,
          public: true,
          stale_while_revalidate: 1.hour
        )

        respond_to do |format|
          format.html { render :show }
          format.json { render json: @listing.to_h }
        end
      end

      # Generate URL-friendly title from listing
      def url_friendly_title(listing)
        listing&.title.present? && listing.title.length > 2 ? listing.title.parameterize : "property"
      end

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

      # Check if there are any active search filters
      def has_active_filters?
        @search_params[:min_price].present? ||
          @search_params[:max_price].present? ||
          @search_params[:min_bedrooms].present? ||
          @search_params[:max_bedrooms].present? ||
          @search_params[:min_bathrooms].present? ||
          @search_params[:max_bathrooms].present? ||
          @search_params[:location].present? ||
          @search_params[:property_types].present? ||
          @search_params[:features].present?
      end

      # Set SEO meta tags for external listings page
      def set_external_listings_seo
        listing_type_sym = @search_params[:listing_type]
        listing_type = listing_type_sym == :rental ? "rent" : "buy"
        location = @search_params[:location]

        # Build page title
        if location.present?
          @page_title = t("external_feed.seo.title_with_location",
                          type: listing_type.capitalize,
                          location: location,
                          default: "Properties to #{listing_type.capitalize} in #{location}")
        else
          @page_title = t("external_feed.seo.title",
                          type: listing_type.capitalize,
                          default: "Properties to #{listing_type.capitalize}")
        end
        @page_title = "#{@page_title} | #{@current_agency&.company_name || current_website.company_display_name}"

        # Meta description
        count = @result&.total_count || 0
        @meta_description = t("external_feed.seo.description",
                              count: count,
                              type: listing_type,
                              default: "Browse #{count} properties available to #{listing_type}. Find your perfect property today.")

        # Canonical URL using new URL pattern - remove pagination for canonical
        base_url = listing_type_sym == :rental ? external_rent_url : external_buy_url
        canonical_query = canonical_params.to_query
        @canonical_url = canonical_query.present? ? "#{base_url}?#{canonical_query}" : base_url
      end

      # Get canonical URL params (remove page and listing_type params for canonical)
      def canonical_params
        # listing_type is now in the URL path, not needed as query param
        params.permit(:location).to_h.reject { |_, v| v.blank? }
      end

      # Check if request is a Turbo Frame request
      def turbo_frame_request?
        request.headers["Turbo-Frame"].present?
      end

      # Set SEO for property detail page
      def set_external_listing_detail_seo
        # Page title
        @page_title = "#{@listing.title} | #{@current_agency&.company_name || current_website.company_display_name}"

        # Meta description
        location_parts = [@listing.location, @listing.province].compact.join(", ")
        features = []
        features << "#{@listing.bedrooms} #{t('external_feed.features.bedrooms', default: 'bedrooms')}" if @listing.bedrooms.present?
        features << "#{@listing.bathrooms} #{t('external_feed.features.bathrooms', default: 'bathrooms')}" if @listing.bathrooms.present?
        features << "#{@listing.built_area.to_i}m²" if @listing.built_area.present?

        @meta_description = t("external_feed.seo.property_description",
                              title: @listing.title,
                              price: @listing.formatted_price,
                              location: location_parts,
                              features: features.join(", "),
                              default: "#{@listing.title} - #{@listing.formatted_price}. #{features.join(', ')} in #{location_parts}.")

        # Canonical URL using new URL pattern with listing type in path
        friendly_title = url_friendly_title(@listing)
        @canonical_url = if @listing.listing_type == :rental
                           external_show_for_rent_url(reference: @listing.reference, url_friendly_title: friendly_title)
                         else
                           external_show_for_sale_url(reference: @listing.reference, url_friendly_title: friendly_title)
                         end

        # Open Graph / Social sharing meta
        @og_title = @listing.title
        @og_description = @meta_description
        @og_image = @listing.main_image
        @og_type = "website"
      end
    end
  end
end
