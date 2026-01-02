# frozen_string_literal: true

module Pwb
  # Helper module for generating external listing URLs
  # Provides consistent URL generation for external listings across views
  module ExternalListingUrlHelper
    # Generate the show path for an external listing
    # Uses the new URL pattern: /external/for-sale/:reference/:title or /external/for-rent/:reference/:title
    #
    # @param listing [Object] External listing object with reference, title, and listing_type
    # @return [String] The show path for the listing
    def external_listing_show_path(listing)
      return "#" unless listing&.reference.present?

      friendly_title = external_url_friendly_title(listing)

      if listing.listing_type == :rental
        external_show_for_rent_path(
          reference: listing.reference,
          url_friendly_title: friendly_title
        )
      else
        external_show_for_sale_path(
          reference: listing.reference,
          url_friendly_title: friendly_title
        )
      end
    end

    # Generate the show URL (full URL) for an external listing
    #
    # @param listing [Object] External listing object
    # @return [String] The full show URL for the listing
    def external_listing_show_url(listing)
      return "#" unless listing&.reference.present?

      friendly_title = external_url_friendly_title(listing)

      if listing.listing_type == :rental
        external_show_for_rent_url(
          reference: listing.reference,
          url_friendly_title: friendly_title
        )
      else
        external_show_for_sale_url(
          reference: listing.reference,
          url_friendly_title: friendly_title
        )
      end
    end

    # Generate the index path for external listings based on listing type
    #
    # @param listing_type [Symbol, String] :sale, :rental, "sale", or "rental"
    # @return [String] The index path
    def external_listings_index_path(listing_type = :sale)
      listing_type.to_sym == :rental ? external_rent_path : external_buy_path
    end

    # Generate the index URL for external listings based on listing type
    #
    # @param listing_type [Symbol, String] :sale, :rental, "sale", or "rental"
    # @return [String] The index URL
    def external_listings_index_url(listing_type = :sale)
      listing_type.to_sym == :rental ? external_rent_url : external_buy_url
    end

    # Generate the index path with search parameters
    #
    # @param listing_type [Symbol] :sale or :rental
    # @param params [Hash] Additional search parameters
    # @return [String] The index path with query string
    def external_listings_search_path(listing_type, params = {})
      base_path = external_listings_index_path(listing_type)
      query = params.reject { |_, v| v.blank? }.to_query
      query.present? ? "#{base_path}?#{query}" : base_path
    end

    # Generate a URL-friendly title from the listing
    #
    # @param listing [Object] External listing object with title method
    # @return [String] Parameterized title or "property"
    def external_url_friendly_title(listing)
      return "property" unless listing&.title.present?

      listing.title.length > 2 ? listing.title.parameterize : "property"
    end

    # Generate pagination path for external listings
    #
    # @param listing_type [Symbol] :sale or :rental
    # @param page [Integer] Page number
    # @param current_params [Hash] Current search parameters to preserve
    # @return [String] The paginated path
    def external_listings_page_path(listing_type, page, current_params = {})
      params_with_page = current_params.merge(page: page).reject { |_, v| v.blank? }
      params_with_page.delete(:page) if page == 1
      external_listings_search_path(listing_type, params_with_page)
    end
  end
end
