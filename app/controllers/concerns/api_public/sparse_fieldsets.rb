# frozen_string_literal: true

module ApiPublic
  # Concern for sparse fieldsets - allows clients to request only specific fields
  # Reduces payload size for bandwidth-constrained clients
  #
  # Usage:
  #   GET /api_public/v1/en/properties?fields=id,slug,title,primary_image_url
  #
  module SparseFieldsets
    extend ActiveSupport::Concern

    private

    # Filter a hash to only include specified fields
    #
    # @param data [Hash] The full data hash
    # @param allowed_fields [Array<Symbol>] Fields allowed to be requested
    # @return [Hash] Filtered hash with only requested fields
    def apply_sparse_fieldsets(data, allowed_fields:)
      requested_fields = parse_fields_param
      return data if requested_fields.blank?

      # Only allow whitelisted fields
      valid_fields = requested_fields & allowed_fields.map(&:to_s)
      return data if valid_fields.blank?

      # Filter the data
      data.slice(*valid_fields.map(&:to_sym))
    end

    # Apply sparse fieldsets to an array of records
    #
    # @param records [Array<Hash>] Array of record hashes
    # @param allowed_fields [Array<Symbol>] Fields allowed to be requested
    # @return [Array<Hash>] Array with filtered records
    def apply_sparse_fieldsets_to_collection(records, allowed_fields:)
      requested_fields = parse_fields_param
      return records if requested_fields.blank?

      # Only allow whitelisted fields
      valid_fields = requested_fields & allowed_fields.map(&:to_s)
      return records if valid_fields.blank?

      # Filter each record
      records.map { |record| record.slice(*valid_fields.map(&:to_sym)) }
    end

    # Parse the fields parameter from request
    #
    # @return [Array<String>] List of requested field names
    def parse_fields_param
      return [] unless params[:fields].present?

      params[:fields].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    # Check if sparse fieldsets are requested
    def sparse_fieldsets_requested?
      params[:fields].present?
    end

    # Property fields that can be requested via sparse fieldsets
    PROPERTY_ALLOWED_FIELDS = %i[
      id
      slug
      reference
      title
      description
      price_sale_current_cents
      price_rental_monthly_current_cents
      formatted_price
      currency
      count_bedrooms
      count_bathrooms
      count_garages
      constructed_area
      area_unit
      for_sale
      for_rent
      highlighted
      latitude
      longitude
      primary_image_url
      prop_photos
      created_at
      updated_at
    ].freeze

    # Link fields that can be requested via sparse fieldsets
    LINK_ALLOWED_FIELDS = %i[
      id
      slug
      title
      url
      position
      order
      visible
      external
    ].freeze

    # Testimonial fields that can be requested via sparse fieldsets
    TESTIMONIAL_ALLOWED_FIELDS = %i[
      id
      name
      role
      company
      content
      rating
      avatar_url
      featured
      visible
    ].freeze
  end
end
